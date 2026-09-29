import AppKit
import SwiftUI
import AVFoundation
import AparteCore
import AparteSpeech

@MainActor final class Coordinator: ObservableObject {
    @Published private(set) var state: SessionState = .needsSetup
    @Published var notice = "Install a model and review permissions to get started."
    @Published private(set) var permissionSummary = PermissionStatus().summary
    @Published private(set) var microphonePermission = PermissionStatus().microphone
    @Published var preferences = Preferences.decode(UserDefaults.standard.data(forKey: "preferences.v1"))
    @Published private(set) var recoveryText: String?
    @Published private(set) var recoveryUncertain = false
    @Published private(set) var recoveryReason = ""
    @Published private(set) var elapsed = 0.0
    @Published private(set) var modelLoaded = false
    @Published var modelStatus = "Not prepared"
    @Published var installProgress = 0.0
    @Published var installing = false
    @Published var tapFailed = false
    @Published var bindingTest = false { didSet { tapGesture.reset() } }
    @Published var recordingBinding = false { didSet { hotkey.capturingBinding = recordingBinding } }
    @Published private(set) var readinessSummary = "Checking setup…"
    @Published private(set) var setupReadiness = SetupReadiness(microphone: false, accessibility: false, model: false, shortcut: false)
    @Published private(set) var shortcutStatus = "Not checked"
    @Published private(set) var testStatus = "Choose a test below. Audio and results stay in memory."
    @Published private(set) var lastResultWasTest = false
    @Published private(set) var inputStatus = "Input level appears while recording; no audio is captured while idle."
    @Published private(set) var inputLevel = 0.0
    weak var testEditor: SetupTextView?
    private enum Destination { case external, microphoneTest, setupField }
    private var destination: Destination?
    private var testReceipt: TestInsertionReceipt?
    private var sessionDelivery = ""
    private var testExpires: Date?
    var microphoneTestActive: Bool { destination == .microphoneTest && [.startingCapture, .recording].contains(state) }
    var canStartMicrophoneTest: Bool { modelLoaded && PermissionStatus().microphone == .authorized && !sessionBusy }
    private var recoveryExpires: Date?
    private var machine = SessionMachine()
    let hotkey = HotkeyService()
    private let audio = AudioCapture()
    private let speech = Transcriber()
    private let targetService = TargetService()
    private let clipboard = ClipboardService()
    private var target: TargetContext?
    private var ticket: CaptureTicket?
    private var switchedAwayAt: Date?
    private var returnedAt: Date?
    private var targetMismatchSince: Date?
    private var deferredText: String?
    private var deferredExpires: Date?
    private var returnRequested = false
    private var startup: Task<Void, Never>?
    private var operation: Task<Void, Never>?
    private var preparation: Task<Void, Never>?
    private var modelGeneration = UUID()
    private var deadline: Task<Void, Never>?
    private var audioDrains = 0
    private var audioDraining: Bool { audioDrains > 0 }
    private var startedAt: Date?
    private var tapGesture = DoubleTapGesture()
    private var modifierStart: Task<Void, Never>?
    private var watchdog: Timer?
    private var observers: [NSObjectProtocol] = []
    private var memoryPressure: DispatchSourceMemoryPressure?
    let modelsRoot = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent(Bundle.main.bundleIdentifier == "dev.aparte.Aparte.dew" ? "Aparte Dew/Models" : "Aparte/Models", isDirectory: true)
    let catalog: ModelCatalog?
    var onStatus: (() -> Void)?

    init() {
        catalog = Bundle.main.url(forResource: "Models", withExtension: "json").flatMap { try? ModelCatalog.load($0) }
        hotkey.binding = preferences.shortcut
        hotkey.onDown = { [weak self] in self?.shortcutDown() }
        hotkey.onUp = { [weak self] in self?.shortcutUp() }
        hotkey.onCancel = { [weak self] in self?.cancel("Cancelled") }
        hotkey.onInteraction = { [weak self] pid, clicked in self?.observeInteraction(targetPID: pid, clicked: clicked) }
        hotkey.onDisabled = { [weak self] in self?.cancel("Shortcut tap interrupted. Recheck permissions.") }
        targetService.onInvalidated = { [weak self] notification in self?.observeTargetChange(notification) }
        hotkey.allowsLocalTest = { [weak self] in self?.testEditor?.isFocused == true || self?.bindingTest == true || self?.destination == .microphoneTest }
        hotkey.canBegin = { [weak self] in
            guard let self else { return false }
            if self.bindingTest { return true }
            if self.machine.id != nil { return self.machine.state == .startingCapture || self.machine.state == .recording }
            return !self.sessionBusy && !HotkeyService.secureInput && ((self.testEditor?.isFocused == true && self.setupReadiness.canTestMicrophone) || self.setupReadiness.canDictate)
        }
        hotkey.installLocalTestHandler()
        watchdog = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in MainActor.assumeIsolated { self?.tick() } }
        let workspace = NSWorkspace.shared.notificationCenter
        for event in [NSWorkspace.willSleepNotification, NSWorkspace.sessionDidResignActiveNotification, NSWorkspace.willPowerOffNotification] {
            observers.append(workspace.addObserver(forName: event, object: nil, queue: .main) { [weak self] _ in MainActor.assumeIsolated { self?.suspend() } })
        }
        observers.append(workspace.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in MainActor.assumeIsolated { self?.activatedApplication(); self?.targetService.prepareCurrentApplication() } })
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in MainActor.assumeIsolated { self?.recheck() } })
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(screenLocked), name: NSNotification.Name("com.apple.screenIsLocked"), object: nil)
        memoryPressure = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical], queue: .main)
        memoryPressure?.setEventHandler { [weak self] in Task { @MainActor in self?.unloadIfIdle() } }; memoryPressure?.resume()
        recheck(prepareModel: false)
        preparation = Task {
            try? await ModelStore(root: modelsRoot).cleanInterruptedStages()
            preparation = nil
            if installed(preferences.model) { prepare(preferences.model) } else { refresh() }
        }
    }
    var sessionBusy: Bool { machine.id != nil || machine.engineBusy || audioDraining || startup != nil || operation != nil || preparation != nil }
    func installed(_ id: String) -> Bool { FileManager.default.fileExists(atPath: modelsRoot.appendingPathComponent(id).appendingPathComponent("tokenizer.json").path) }
    func persist() { tapGesture.reset(); modifierStart?.cancel(); modifierStart = nil; UserDefaults.standard.set(try? JSONEncoder().encode(preferences), forKey: "preferences.v1"); hotkey.binding = preferences.shortcut }
    func recheck(prepareModel: Bool = true) {
        let permissions = PermissionStatus(); permissionSummary = permissions.summary
        if permissions.accessibility {
            if !sessionBusy { hotkey.stop() }
            tapFailed = !hotkey.start()
            targetService.prepareCurrentApplication()
        } else {
            hotkey.stop(); tapFailed = false
            if destination == .external { cancel("Accessibility is unavailable to this running app. Reopen the installed Aparté after granting it.") }
        }
        if prepareModel, !sessionBusy, !modelLoaded, installed(preferences.model) { prepare(preferences.model) }
        refresh()
    }
    private func refresh() {
        let permissions = PermissionStatus()
        microphonePermission = permissions.microphone
        let readiness = SetupReadiness(microphone: permissions.microphone == .authorized, accessibility: permissions.accessibility, model: modelLoaded, shortcut: hotkey.isRunning && !tapFailed)
        setupReadiness = readiness
        readinessSummary = readiness.canDictate ? "Ready. Dictation works across apps in accessible editable text fields; other contexts use Recovery." : readiness.blockers.joined(separator: " · ")
        if preparation != nil && !installing { readinessSummary = "Preparing \(preferences.model)… Wait for the model to finish loading." }
        shortcutStatus = hotkey.isRunning ? "Global shortcut listener active" : "Global listener unavailable. The test text box can still receive the shortcut inside Aparté."
        if machine.id == nil && !machine.engineBusy && preparation == nil && !audioDraining && startup == nil && operation == nil {
            machine.prepared(readiness.canDictate)
        }
        state = machine.state
        if recoveryText != nil && state == .ready { state = .recovery }
        hotkey.active = machine.id != nil || machine.engineBusy
        onStatus?()
    }
    func prepare(_ id: String) {
        guard !sessionBusy, !installing, let manifest = catalog?.models.first(where: { $0.id == id }) else { notice = "Finish the current operation first."; return }
        let previous = preferences.model
        let generation = UUID(); modelGeneration = generation
        machine.preparing(); modelLoaded = false; modelStatus = "Preparing \(id)…"
        preparation = Task {
            do {
                try await speech.load(directory: modelsRoot.appendingPathComponent(id), manifest: manifest)
                guard !Task.isCancelled, modelGeneration == generation else { throw AparteError.cancelled }
                preferences.model = id
                if !SpeechLanguages.supports(preferences.language, model: id) { preferences.language = "auto"; notice = "This model cannot use the previous language. Language changed to Auto." }
                else { notice = preferences.gesture == .hold ? "Hold your shortcut when Ready. Speak after Recording appears." : "Double-tap your shortcut when Ready; tap once more to stop." }
                persist(); modelLoaded = true; modelStatus = "\(id.capitalized) prepared"
            } catch {
                modelStatus = "Model load failed (\(id))."
                machine.fail()
                modelLoaded = await speech.activeModelID == previous
                if modelLoaded { modelStatus = "Kept \(previous); requested switch failed." }
                notice = (error as? AparteError)?.localizedDescription ?? "Model could not be prepared. Verify or reinstall it."
            }
            preparation = nil; refresh()
        }
        refresh()
    }
    func startMicrophoneTest() { bindingTest = false; begin(manualTest: true) }
    func stopMicrophoneTest() { if destination == .microphoneTest { release() } }
    private func shortcutDown() {
        if bindingTest && preferences.gesture == .hold { begin(); return }
        if preferences.gesture == .doubleTap {
            switch tapGesture.press(at: ProcessInfo.processInfo.systemUptime) {
            case .none: break
            case .start:
                if bindingTest { testStatus = "\(hotkey.lastDelivery): start detected. Tap once to complete detection; no audio recorded."; notice = testStatus; onStatus?() }
                else { begin(); if machine.id == nil { tapGesture.reset() } }
            case .stop:
                if bindingTest { testStatus = "\(hotkey.lastDelivery): double-tap start and tap stop detected. No audio recorded."; notice = testStatus; onStatus?() }
                else { release() }
            }
            return
        }
        if preferences.shortcut.key == Shortcut.modifierOnlyKey {
            modifierStart?.cancel()
            modifierStart = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(180))
                guard !Task.isCancelled, !HotkeyService.modifiersClear(preferences.shortcut) else { return }
                begin()
            }
        } else { begin() }
    }
    private func shortcutUp() {
        if bindingTest && preferences.gesture == .hold { release(); return }
        if preferences.gesture == .doubleTap {
            tapGesture.release(at: ProcessInfo.processInfo.systemUptime)
            return
        }
        modifierStart?.cancel(); modifierStart = nil
        if destination != .microphoneTest { release() }
    }
    func invalidateTestTarget() { if destination == .setupField { machine.invalidateTarget() } }
    func closeSetupTests() {
        if destination == .microphoneTest || destination == .setupField { cancel("Setup test closed. Recording cancelled.") }
        if lastResultWasTest { discardRecovery() }
        testEditor?.clear(); testExpires = nil; lastResultWasTest = false
        bindingTest = false; recordingBinding = false
        testStatus = "Test cleared. No audio or transcript was saved."
        inputStatus = "Input level appears while recording; no audio is captured while idle."; inputLevel = 0
    }
    private func activatedApplication() {
        guard machine.id != nil else { return }
        guard let target else { machine.invalidateTarget(); return }
        if NSWorkspace.shared.frontmostApplication?.processIdentifier == target.process.processIdentifier {
            if switchedAwayAt != nil { returnedAt = Date() }
            resumeDeferredIfReady()
        } else {
            if switchedAwayAt == nil { switchedAwayAt = Date() }
            returnedAt = nil
        }
    }
    private func observeTargetChange(_ notification: String) {
        guard machine.id != nil else { return }
        if notification == kAXValueChangedNotification as String ||
            notification == kAXSelectedTextChangedNotification as String ||
            notification == kAXUIElementDestroyedNotification as String {
            machine.invalidateTarget(); return
        }
        guard let target else { machine.invalidateTarget(); return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self, self.machine.id != nil else { return }
            if NSWorkspace.shared.frontmostApplication?.processIdentifier != target.process.processIdentifier {
                if self.switchedAwayAt == nil { self.switchedAwayAt = Date() }
                self.returnedAt = nil
            } else if self.switchedAwayAt == nil { self.machine.invalidateTarget() }
        }
    }
    private func observeInteraction(targetPID: pid_t?, clicked: Bool) {
        guard machine.id != nil else { return }
        guard let target else { machine.invalidateTarget(); return }
        if let targetPID, targetPID != target.process.processIdentifier {
            if switchedAwayAt == nil { switchedAwayAt = Date() }
            returnedAt = nil
            return
        }
        if targetPID == target.process.processIdentifier && !clicked {
            machine.invalidateTarget(); return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self, self.machine.id != nil else { return }
            guard NSWorkspace.shared.frontmostApplication?.processIdentifier == target.process.processIdentifier else {
                if self.switchedAwayAt == nil { self.switchedAwayAt = Date() }
                self.returnedAt = nil
                return
            }
            if clicked, let departure = self.switchedAwayAt {
                if self.targetService.validAfterReturn(target, recentClick: self.hotkey.recentClickReceipt, since: departure) {
                    self.resumeDeferredIfReady()
                }
                return // An unproven return click keeps the result pending.
            }
            self.machine.invalidateTarget()
        }
    }
    private func begin(manualTest: Bool = false) {
        guard !hotkey.capturingBinding else { return }
        if bindingTest && !manualTest { notice = "\(hotkey.lastDelivery) detected: \(preferences.shortcut.displayLabel). Release to finish the test."; testStatus = notice; onStatus?(); return }
        guard !sessionBusy else { notice = "Busy — this hold was ignored."; onStatus?(); return }
        switchedAwayAt = nil; returnedAt = nil; targetMismatchSince = nil; deferredText = nil; deferredExpires = nil; returnRequested = false
        let localReceipt = manualTest ? nil : testEditor?.receipt()
        let local = manualTest || localReceipt != nil
        let permissions = PermissionStatus()
        guard modelLoaded, permissions.microphone == .authorized else { testStatus = "Prepare a model and grant Microphone before recording."; notice = testStatus; recheck(); return }
        if !local {
            guard permissions.canDictate, hotkey.isRunning, !HotkeyService.secureInput else { notice = "Global dictation unavailable. \(readinessSummary)"; recheck(); return }
            do { target = try targetService.capture(recentClick: hotkey.recentClickPoint) } catch { notice = "Secure or read-only context. Dictation refused."; onStatus?(); return }
        } else { target = nil }
        destination = manualTest ? .microphoneTest : (local ? .setupField : .external)
        sessionDelivery = manualTest ? "Start recording button" : hotkey.lastDelivery
        testReceipt = localReceipt
        machine.prepared(true, clearError: true)
        guard let id = machine.begin() else { return }
        discardRecovery(); lastResultWasTest = false; startedAt = Date(); elapsed = 0
        if local { testStatus = manualTest ? "Starting microphone…" : "\(sessionDelivery) received. Starting microphone…"; testExpires = Date().addingTimeInterval(300) }
        inputStatus = "Waiting for audio from the system default input…"; inputLevel = 0
        notice = "Starting microphone…"; let newTicket = CaptureTicket(); ticket = newTicket
        refresh()
        startup = Task {
            do {
                try await audio.start(ticket: newTicket, onConfigurationChange: { [weak self] in
                    Task { @MainActor in
                        guard let self, self.machine.isCapturing(id) else { return }
                        self.cancel("Audio input changed during recording. Try again with the current default microphone.")
                    }
                }) { [weak self] in Task { @MainActor in
                    guard let self, self.machine.started(id) else { return }
                    self.startedAt = Date(); self.notice = self.destination == .microphoneTest ? "Recording — press Stop to transcribe, Escape to cancel." : (self.preferences.gesture == .doubleTap ? "Recording — tap shortcut to stop, Escape to cancel." : "Recording — release to transcribe, Escape to cancel.")
                    if self.destination != .external { self.testStatus = self.notice }; self.refresh()
                } }
            } catch { if machine.id == id { machine.fail(); notice = (error as? AparteError)?.localizedDescription ?? "Microphone failed to start (\((error as NSError).domain), \((error as NSError).code)). Check Sound → Input." } }
            if machine.id == nil && destination != .external { testStatus = notice; destination = nil }
            startup = nil; refresh()
        }
    }
    private func release() {
        if bindingTest, machine.id == nil {
            testStatus = "\(hotkey.lastDelivery): shortcut pressed and released. No audio recorded."
            notice = testStatus; onStatus?(); return
        }
        guard let id = machine.id else { return }
        if machine.state == .startingCapture { cancel("Released before capture started; nothing recorded."); return }
        guard machine.release(id) else { return }
        ticket?.cancel(); audioDrains += 1; notice = "Transcribing locally…"; refresh()
        if destination != .external { testStatus = notice }
        operation = Task {
            defer { deadline?.cancel(); deadline = nil; operation = nil; destination = nil; testReceipt = nil; machine.unwind(); if machine.id == nil { targetService.stopObserving() }; refresh() }
            do {
                let samples: [Float]
                do { samples = try await audio.stop(discard: false); audioDrains -= 1 }
                catch { audioDrains -= 1; throw error }
                ticket = nil
                guard machine.id == id, !Task.isCancelled else { return }
                deadline = Task { try? await Task.sleep(for: .seconds(30)); guard !Task.isCancelled, self.machine.id == id else { return }; self.cancel(AparteError.timeout.localizedDescription); self.machine.fail(); self.refresh() }
                let diagnostics = AudioDiagnostics(samples)
                inputLevel = 0; inputStatus = "\(audio.status.name) · \(diagnostics.summary)"
                if let problem = diagnostics.problem {
                    notice = problem; if destination != .external { testStatus = problem }
                    machine.finish(id); return
                }
                let result = try await speech.transcribe(samples, language: preferences.language)
                guard machine.decoded(id), !Task.isCancelled else { return }
                deadline?.cancel(); deadline = nil
                if result.noSpeech { notice = "Audio was captured, but no usable speech was recognized. Try a clear sentence and check the selected language."; if destination != .external { testStatus = notice }; machine.finish(id); return }
                if destination == .microphoneTest || destination == .setupField {
                    let isField = destination == .setupField
                    let inserted = isField && !machine.invalidatedTarget && testReceipt.map { testEditor?.apply(result.text, receipt: $0) == true } == true
                    recoveryText = result.text; recoveryUncertain = false; recoveryReason = "Setup test result."; lastResultWasTest = true
                    recoveryExpires = Date().addingTimeInterval(300); testExpires = recoveryExpires
                    testStatus = isField ? (inserted ? "Inserted into the test text box using \(sessionDelivery.lowercased())." : "Text box lost focus or changed. Result shown below; nothing inserted.") : "Microphone test complete. Transcribed locally in \(String(format: "%.2f", result.seconds)) s."
                    notice = testStatus; machine.finish(id, recovery: true); return
                }
                await insert(result.text, id: id)
            } catch {
                if machine.id == id { machine.fail(); notice = (error as? AparteError)?.localizedDescription ?? "Transcription failed. Retry or prepare the model again."; if destination != .external { testStatus = notice } }
            }
        }
    }
    private func insert(_ text: String, id: UUID) async {
        guard machine.id == id else { return }
        guard let target else { recover(text, id: id, uncertain: false, reason: targetService.captureFailure); return }
        guard target.method != nil else { recover(text, id: id, uncertain: false, reason: "This input control is not exposed as an editable text field. Click inside the destination text input before dictating."); return }
        guard !machine.invalidatedTarget else { recover(text, id: id, uncertain: false, reason: "The original field changed while dictating. Nothing was inserted."); return }
        if NSWorkspace.shared.frontmostApplication?.processIdentifier != target.process.processIdentifier {
            if switchedAwayAt == nil { switchedAwayAt = Date() }
            deferOriginal(text, id: id)
            requestOriginalWindow(target, text: text, id: id)
            return
        }
        guard validOriginal(target) else {
            if switchedAwayAt != nil {
                deferOriginal(text, id: id)
                requestOriginalWindow(target, text: text, id: id)
            }
            else { recover(text, id: id, uncertain: false, reason: "The original app, field or selection changed while dictating. Nothing was inserted.") }
            return
        }
        state = .inserting; notice = "Waiting for shortcut modifiers to clear…"; onStatus?()
        let until = ContinuousClock.now.advanced(by: .seconds(2))
        while !HotkeyService.modifiersClear(preferences.shortcut), .now < until {
            try? await Task.sleep(for: .milliseconds(20)); guard machine.id == id, !Task.isCancelled else { return }
        }
        guard machine.id == id else { return }
        guard !machine.invalidatedTarget, validOriginal(target) else { recover(text, id: id, uncertain: false, reason: "The original input changed before insertion. Nothing was inserted."); return }
        guard HotkeyService.modifiersClear(preferences.shortcut) else { recover(text, id: id, uncertain: false, reason: "Shortcut modifiers were still held after two seconds. Release them before the next dictation."); return }
        if target.method == "selectedText" {
            targetService.stopObserving() // Own mutation must not invalidate itself.
            switch targetService.insertSelectedText(text, into: target) {
            case .attempted: recover(text, id: id, uncertain: true, reason: "Text insertion was attempted once. Check the target before copying this backup.")
            case .uncertain: recover(text, id: id, uncertain: true, reason: "The text field returned an error after the insertion attempt. No second attempt was made.")
            case .unattempted: recover(text, id: id, uncertain: false, reason: "The original field stopped accepting selected-text insertion. Nothing was inserted.")
            }
            return
        }
        guard PermissionStatus().posting else { recover(text, id: id, uncertain: false, reason: "macOS currently denies paste-key posting to this running app. Recheck Accessibility and reopen the installed Aparté."); return }
        do {
            let snapshot = try await clipboard.snapshot()
            guard machine.id == id, !Task.isCancelled else { return }
            guard !machine.invalidatedTarget, validOriginal(target), HotkeyService.modifiersClear(preferences.shortcut) else { recover(text, id: id, uncertain: false, reason: "Focus, selection or held modifiers changed while saving the clipboard. Nothing was pasted."); return }
            try clipboard.write(text, snapshot: snapshot)
            guard machine.id == id, !machine.invalidatedTarget, validOriginal(target) else { clipboard.restore(); recover(text, id: id, uncertain: false, reason: "The target changed before paste dispatch. Nothing was pasted."); return }
            targetService.stopObserving()
            if clipboard.dispatchPaste() { recover(text, id: id, uncertain: true, reason: "Paste sent once. Check the target before manually pasting again to avoid duplication.") }
            else { recover(text, id: id, uncertain: false, reason: "Paste could not be dispatched because clipboard ownership or macOS posting access changed.") }
        } catch { recover(text, id: id, uncertain: false, reason: (error as? ClipboardFailure)?.localizedDescription ?? "The clipboard could not be preserved. Nothing was pasted.") }
    }
    private func validOriginal(_ target: TargetContext) -> Bool {
        if let departure = switchedAwayAt {
            return targetService.validAfterReturn(target, recentClick: hotkey.recentClickReceipt, since: departure)
        }
        return targetService.valid(target)
    }
    private func deferOriginal(_ text: String, id: UUID) {
        guard machine.id == id else { return }
        deferredText = text; deferredExpires = Date().addingTimeInterval(2)
        recoveryText = text; recoveryExpires = deferredExpires; recoveryUncertain = false
        recoveryReason = "Returning to the original window and checking its original text field. No paste has been attempted."
        notice = recoveryReason; refresh()
    }
    private func requestOriginalWindow(_ target: TargetContext, text: String, id: UUID) {
        guard !returnRequested, machine.id == id else { return }
        returnRequested = true
        guard targetService.canReturnToOriginal(target) else {
            recover(text, id: id, uncertain: false, reason: "The original window or field changed while dictating. Nothing was inserted.")
            return
        }
        if !targetService.requestReturnToOriginal(target) {
            recover(text, id: id, uncertain: false, reason: "macOS did not bring back the original window. Nothing was inserted.")
        }
        // Activation is a request, not a synchronous focus guarantee. The normal
        // frontmost/window/field/selection checks below decide whether to paste.
    }
    private func resumeDeferredIfReady() {
        guard let text = deferredText, let id = machine.id, let target, !machine.invalidatedTarget,
              NSWorkspace.shared.frontmostApplication?.processIdentifier == target.process.processIdentifier,
              returnedAt.map({ Date().timeIntervalSince($0) >= 0.35 }) == true,
              validOriginal(target) else { return }
        deferredText = nil; deferredExpires = nil; recoveryText = nil; recoveryExpires = nil; recoveryReason = ""
        Task { await self.insert(text, id: id) }
    }
    private func recover(_ text: String, id: UUID, uncertain: Bool, reason: String) {
        guard machine.id == id else { return }
        deferredText = nil; deferredExpires = nil; switchedAwayAt = nil; returnedAt = nil; targetMismatchSince = nil; returnRequested = false
        targetService.stopObserving()
        recoveryText = text; recoveryExpires = Date().addingTimeInterval(300); recoveryUncertain = uncertain; recoveryReason = reason
        let copied = clipboard.copyRecovery(text)
        recoveryReason += copied ? " Transcript is on the clipboard for manual paste." : " Clipboard changed after Aparté's paste attempt; use Copy in Recovery if needed."
        notice = recoveryReason
        machine.finish(id, recovery: true); refresh()
    }
    func discardRecovery() {
        if deferredText != nil { cancel("Pending original-field insertion discarded.") }
        recoveryText = nil; recoveryExpires = nil; recoveryUncertain = false; recoveryReason = ""; refresh()
    }
    func copyRecovery() {
        if deferredText != nil, let id = machine.id {
            deferredText = nil; deferredExpires = nil; switchedAwayAt = nil; returnedAt = nil
            machine.finish(id, recovery: true); targetService.stopObserving(); target = nil
            recoveryReason = "Automatic insertion into the original field was cancelled when you copied this result."
        }
        if let recoveryText { clipboard.copyExplicit(recoveryText); notice = "Copied. Clipboard replaced intentionally." }
        onStatus?()
    }
    func cancel(_ reason: String = "Cancelled") {
        modifierStart?.cancel(); modifierStart = nil; tapGesture.reset()
        if destination == .microphoneTest || destination == .setupField { testStatus = reason }
        let wasDeferring = deferredText != nil
        let wasActive = ticket != nil || machine.engineBusy || startup != nil || audioDraining
        ticket?.cancel(); startup?.cancel(); operation?.cancel(); deadline?.cancel(); deadline = nil
        machine.cancel(); targetService.stopObserving(); target = nil; testReceipt = nil; destination = nil
        deferredText = nil; deferredExpires = nil; switchedAwayAt = nil; returnedAt = nil; targetMismatchSince = nil; returnRequested = false; clipboard.restore(); notice = reason
        if wasDeferring { recoveryText = nil; recoveryExpires = nil; recoveryUncertain = false; recoveryReason = "" }
        if wasActive {
            audioDrains += 1
            Task { _ = try? await audio.stop(discard: true); audioDrains -= 1; ticket = nil; refresh() }
        }
        refresh()
    }
    private var ticks = 0
    private func tick() {
        ticks += 1
        if state == .startingCapture || state == .recording {
            let status = audio.status
            inputLevel = status.level
            inputStatus = "\(status.name) · \(String(format: "%.1f", status.seconds)) s received"
        } else { inputLevel = 0 }
        if machine.id != nil {
            elapsed = Date().timeIntervalSince(startedAt ?? Date())
            if machine.state == .recording && (elapsed >= 60 || audio.limitReached) { cancel("60-second limit reached. Recording discarded.") }
            else if machine.state == .startingCapture && elapsed > 5 { cancel("Microphone did not start. Recheck the default input device.") }
            else if let target, !machine.invalidatedTarget {
                if NSWorkspace.shared.frontmostApplication?.processIdentifier != target.process.processIdentifier {
                    if switchedAwayAt == nil { switchedAwayAt = Date() }
                    returnedAt = nil
                    targetMismatchSince = nil
                } else if switchedAwayAt == nil {
                    if targetService.valid(target) { targetMismatchSince = nil }
                    else if let since = targetMismatchSince, Date().timeIntervalSince(since) >= 0.3 { machine.invalidateTarget() }
                    else if targetMismatchSince == nil { targetMismatchSince = Date() }
                } else if returnedAt == nil { returnedAt = Date() }
            }
        }
        if let text = deferredText, let id = machine.id {
            if machine.invalidatedTarget {
                recover(text, id: id, uncertain: false, reason: "The original field changed before return. Nothing was inserted.")
            } else if let expiry = deferredExpires, Date() >= expiry {
                recover(text, id: id, uncertain: false, reason: "The original field did not become verifiably focused after the return request. Nothing was inserted.")
            } else { resumeDeferredIfReady() }
        }
        if let expiry = recoveryExpires, Date() >= expiry { discardRecovery(); notice = "Recovery expired." }
        if let expiry = testExpires, Date() >= expiry { closeSetupTests() }
        if ticks % 20 == 0 {
            let permissions = PermissionStatus()
            if machine.id != nil && (permissions.microphone != .authorized || ((destination == .external || deferredText != nil) && !permissions.canDictate)) { cancel("Permission revoked. Recheck access in Settings.") }
            let changed = permissionSummary != permissions.summary
            permissionSummary = permissions.summary
            if changed { recheck() }
        }
        if machine.state == .recording { onStatus?() }
    }
    @objc private func screenLocked() { suspend() }
    private func suspend() { cancel("Session suspended; pending audio and result discarded."); discardRecovery(); closeSetupTests() }
    private func unloadIfIdle() {
        guard !sessionBusy, modelLoaded else { return }
        modelLoaded = false; modelStatus = "Unloaded after memory pressure. Prepare before dictating."; refresh()
        Task { try? await speech.unload() }
    }
    func shutdown() { suspend(); clipboard.restore(); hotkey.shutdown(); targetService.releaseAccessibility(); watchdog?.invalidate() }
}

extension Coordinator {
    func importModel(_ id: String) {
        guard !sessionBusy, !installing else { notice = "Finish the current operation first."; return }
        let panel = NSOpenPanel(); panel.canChooseFiles = false; panel.canChooseDirectories = true; panel.allowsMultipleSelection = false
        panel.message = "Choose the \(id) directory matching the bundled manifest (including tokenizer files)."
        guard panel.runModal() == .OK, let source = panel.url else { return }
        installModel(id, source: source)
    }
    func installModel(_ id: String, source: URL? = nil) {
        guard !sessionBusy, !installing, let manifest = catalog?.models.first(where: { $0.id == id }) else { return }
        installing = true; installProgress = 0; modelStatus = source == nil ? "Downloading \(id)…" : "Verifying import…"
        let store = ModelStore(root: modelsRoot)
        let generation = UUID(); modelGeneration = generation
        preparation = Task {
            do {
                try await store.install(manifest, importing: source) { progress in Task { @MainActor in if self.modelGeneration == generation && self.installing { self.installProgress = progress } } }
                modelStatus = "\(id.capitalized) installed. Prepare it before use."
            } catch { modelStatus = Task.isCancelled ? "Installation cancelled. Existing model preserved." : "Install failed. Check network, space or matching assets; retry or import." }
            modelGeneration = UUID(); installing = false; preparation = nil; refresh()
        }
    }
    func cancelInstall() { if installing { preparation?.cancel() } }
    func deleteModel(_ id: String) {
        guard !sessionBusy, !installing else { notice = "Finish the current operation before deleting a model."; return }
        preparation = Task {
            do {
                if id == preferences.model { try await speech.unload(); modelLoaded = false }
                try await ModelStore(root: modelsRoot).delete(id); modelStatus = "\(id.capitalized) removed."
            } catch { modelStatus = "Could not remove model." }
            preparation = nil; refresh()
        }
    }
}
