import AppKit
import SwiftUI
import AVFoundation
import AparteCore
import AparteSpeech

@MainActor final class Coordinator: ObservableObject {
    @Published private(set) var state: SessionState = .needsSetup
    @Published var notice = "Install a model and review permissions to get started."
    @Published private(set) var permissionSummary = PermissionStatus().summary
    @Published var preferences = Preferences.decode(UserDefaults.standard.data(forKey: "preferences.v1"))
    @Published private(set) var recoveryText: String?
    @Published private(set) var recoveryUncertain = false
    @Published private(set) var elapsed = 0.0
    @Published private(set) var modelLoaded = false
    @Published var modelStatus = "Not prepared"
    @Published var installProgress = 0.0
    @Published var installing = false
    @Published var tapFailed = false
    @Published var bindingTest = false
    private var recoveryExpires: Date?
    private var machine = SessionMachine()
    let hotkey = HotkeyService()
    private let audio = AudioCapture()
    private let speech = Transcriber()
    private let targetService = TargetService()
    private let clipboard = ClipboardService()
    private var target: TargetContext?
    private var ticket: CaptureTicket?
    private var startup: Task<Void, Never>?
    private var operation: Task<Void, Never>?
    private var preparation: Task<Void, Never>?
    private var modelGeneration = UUID()
    private var deadline: Task<Void, Never>?
    private var audioDrains = 0
    private var audioDraining: Bool { audioDrains > 0 }
    private var startedAt: Date?
    private var watchdog: Timer?
    private var observers: [NSObjectProtocol] = []
    private var memoryPressure: DispatchSourceMemoryPressure?
    let modelsRoot = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Aparte/Models", isDirectory: true)
    let catalog: ModelCatalog?
    var onStatus: (() -> Void)?

    init() {
        catalog = Bundle.main.url(forResource: "Models", withExtension: "json").flatMap { try? ModelCatalog.load($0) }
        hotkey.binding = preferences.shortcut
        hotkey.onDown = { [weak self] in self?.begin() }
        hotkey.onUp = { [weak self] in self?.release() }
        hotkey.onCancel = { [weak self] in self?.cancel("Cancelled") }
        hotkey.onInteraction = { [weak self] in self?.machine.invalidateTarget() }
        hotkey.onDisabled = { [weak self] in self?.cancel("Shortcut tap interrupted. Recheck permissions.") }
        targetService.onInvalidated = { [weak self] in self?.machine.invalidateTarget() }
        watchdog = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in MainActor.assumeIsolated { self?.tick() } }
        let workspace = NSWorkspace.shared.notificationCenter
        for event in [NSWorkspace.willSleepNotification, NSWorkspace.sessionDidResignActiveNotification, NSWorkspace.willPowerOffNotification] {
            observers.append(workspace.addObserver(forName: event, object: nil, queue: .main) { [weak self] _ in MainActor.assumeIsolated { self?.suspend() } })
        }
        observers.append(workspace.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in MainActor.assumeIsolated { self?.machine.invalidateTarget() } })
        observers.append(NotificationCenter.default.addObserver(forName: .AVAudioEngineConfigurationChange, object: nil, queue: .main) { [weak self] _ in MainActor.assumeIsolated { if self?.machine.id != nil { self?.cancel("Microphone configuration changed. Retry with the current default input.") } } })
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(screenLocked), name: NSNotification.Name("com.apple.screenIsLocked"), object: nil)
        memoryPressure = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical], queue: .main)
        memoryPressure?.setEventHandler { [weak self] in Task { @MainActor in self?.unloadIfIdle() } }; memoryPressure?.resume()
        recheck()
        preparation = Task {
            try? await ModelStore(root: modelsRoot).cleanInterruptedStages()
            preparation = nil
            if installed(preferences.model) { prepare(preferences.model) } else { refresh() }
        }
    }
    var sessionBusy: Bool { machine.id != nil || machine.engineBusy || audioDraining || startup != nil || operation != nil || preparation != nil }
    func installed(_ id: String) -> Bool { FileManager.default.fileExists(atPath: modelsRoot.appendingPathComponent(id).appendingPathComponent("tokenizer.json").path) }
    func persist() { UserDefaults.standard.set(try? JSONEncoder().encode(preferences), forKey: "preferences.v1"); hotkey.binding = preferences.shortcut }
    func recheck() {
        let permissions = PermissionStatus(); permissionSummary = permissions.summary
        if permissions.canDictate { tapFailed = !hotkey.start() }
        else if machine.id != nil { cancel("Permissions changed. Open Settings and recheck.") }
        refresh()
    }
    private func refresh() {
        if machine.id == nil && !machine.engineBusy && preparation == nil && !audioDraining && startup == nil && operation == nil {
            machine.prepared(modelLoaded && PermissionStatus().canDictate && hotkey.isRunning && !tapFailed)
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
                preferences.model = id; persist(); modelLoaded = true; modelStatus = "\(id.capitalized) prepared"; notice = "Hold your shortcut when Ready. Speak after Recording appears."
            } catch {
                modelStatus = "Model load failed (\(id))."
                modelLoaded = await speech.activeModelID == previous
                if modelLoaded { modelStatus = "Kept \(previous); requested switch failed." }
                notice = (error as? AparteError)?.localizedDescription ?? "Model could not be prepared. Verify or reinstall it."
            }
            preparation = nil; refresh()
        }
        refresh()
    }
    private func begin() {
        if bindingTest { notice = "Shortcut detected. Release it to finish the test. Other apps may still conflict."; onStatus?(); return }
        guard !sessionBusy else { notice = "Busy — this hold was ignored."; onStatus?(); return }
        guard modelLoaded, PermissionStatus().canDictate, !HotkeyService.secureInput else { notice = "Not ready. Recheck model, microphone and Accessibility in Settings."; recheck(); return }
        do { target = try targetService.capture() } catch { notice = "Secure or read-only context. Dictation refused."; onStatus?(); return }
        machine.prepared(true)
        guard let id = machine.begin() else { return }
        discardRecovery(); startedAt = Date(); elapsed = 0
        notice = "Starting microphone…"; let newTicket = CaptureTicket(); ticket = newTicket
        refresh()
        startup = Task {
            do {
                try await audio.start(ticket: newTicket) { [weak self] in Task { @MainActor in
                    guard let self, self.machine.started(id) else { return }
                    self.startedAt = Date(); self.notice = "Recording — release to transcribe, Escape to cancel."; self.refresh()
                } }
            } catch { if machine.id == id { machine.cancel(); notice = (error as? AparteError)?.localizedDescription ?? "Microphone failed to start." } }
            startup = nil; refresh()
        }
    }
    private func release() {
        guard let id = machine.id else { return }
        if machine.state == .startingCapture { cancel("Released before capture started; nothing recorded."); return }
        guard machine.release(id) else { return }
        ticket?.cancel(); audioDrains += 1; notice = "Transcribing locally…"; refresh()
        operation = Task {
            defer { deadline?.cancel(); deadline = nil; operation = nil; machine.unwind(); targetService.stopObserving(); refresh() }
            do {
                let samples: [Float]
                do { samples = try await audio.stop(discard: false); audioDrains -= 1 }
                catch { audioDrains -= 1; throw error }
                ticket = nil
                guard machine.id == id, !Task.isCancelled else { return }
                deadline = Task { try? await Task.sleep(for: .seconds(30)); guard !Task.isCancelled, self.machine.id == id else { return }; self.cancel(AparteError.timeout.localizedDescription) }
                let result = try await speech.transcribe(samples, language: preferences.language)
                guard machine.decoded(id), !Task.isCancelled else { return }
                deadline?.cancel(); deadline = nil
                if result.noSpeech { notice = "No speech detected."; machine.finish(id); return }
                await insert(result.text, id: id)
            } catch {
                if machine.id == id { machine.cancel(); notice = (error as? AparteError)?.localizedDescription ?? "Transcription failed. Retry or prepare the model again." }
            }
        }
    }
    private func insert(_ text: String, id: UUID) async {
        guard machine.id == id else { return }
        guard let target, target.method != nil, !machine.invalidatedTarget, targetService.valid(target) else { recover(text, id: id, uncertain: false); return }
        state = .inserting; notice = "Waiting for shortcut modifiers to clear…"; onStatus?()
        let until = ContinuousClock.now.advanced(by: .seconds(2))
        while !HotkeyService.modifiersClear(preferences.shortcut), .now < until {
            try? await Task.sleep(for: .milliseconds(20)); guard machine.id == id, !Task.isCancelled else { return }
        }
        guard machine.id == id, !machine.invalidatedTarget, targetService.valid(target), HotkeyService.modifiersClear(preferences.shortcut) else { recover(text, id: id, uncertain: false); return }
        if target.method == "selectedText" {
            targetService.stopObserving() // Own mutation must not invalidate itself.
            switch targetService.insertSelectedText(text, into: target) {
            case .attempted: recover(text, id: id, uncertain: true)
            case .uncertain: recover(text, id: id, uncertain: true)
            case .unattempted: recover(text, id: id, uncertain: false)
            }
            return
        }
        do {
            let snapshot = try await clipboard.snapshot()
            guard machine.id == id, !Task.isCancelled else { return }
            guard !machine.invalidatedTarget, targetService.valid(target), HotkeyService.modifiersClear(preferences.shortcut) else { recover(text, id: id, uncertain: false); return }
            try clipboard.write(text, snapshot: snapshot)
            guard machine.id == id, !machine.invalidatedTarget, targetService.valid(target) else { clipboard.restore(); recover(text, id: id, uncertain: false); return }
            targetService.stopObserving()
            if clipboard.dispatchPaste() { recover(text, id: id, uncertain: true) }
            else { recover(text, id: id, uncertain: false) }
        } catch { recover(text, id: id, uncertain: false) }
    }
    private func recover(_ text: String, id: UUID, uncertain: Bool) {
        guard machine.id == id else { return }
        recoveryText = text; recoveryExpires = Date().addingTimeInterval(300); recoveryUncertain = uncertain
        notice = uncertain ? "Insertion unconfirmed — check the target before copying." : "Automatic insertion unavailable. Open Recovery to view, copy or discard."
        machine.finish(id, recovery: true); refresh()
    }
    func discardRecovery() { recoveryText = nil; recoveryExpires = nil; recoveryUncertain = false; refresh() }
    func copyRecovery() { if let recoveryText { clipboard.copyExplicit(recoveryText); notice = "Copied. Clipboard replaced intentionally." }; onStatus?() }
    func cancel(_ reason: String = "Cancelled") {
        let wasActive = machine.id != nil || machine.engineBusy || startup != nil
        ticket?.cancel(); startup?.cancel(); operation?.cancel(); deadline?.cancel(); deadline = nil
        machine.cancel(); targetService.stopObserving(); target = nil; clipboard.restore(); notice = reason
        if wasActive {
            audioDrains += 1
            Task { _ = try? await audio.stop(discard: true); audioDrains -= 1; ticket = nil; refresh() }
        }
        refresh()
    }
    private var ticks = 0
    private func tick() {
        ticks += 1
        if machine.id != nil {
            elapsed = Date().timeIntervalSince(startedAt ?? Date())
            if machine.state == .recording && (elapsed >= 60 || audio.limitReached) { cancel("60-second limit reached. Recording discarded.") }
            else if machine.state == .startingCapture && elapsed > 5 { cancel("Microphone did not start. Recheck the default input device.") }
            else if let target, !machine.invalidatedTarget, !targetService.valid(target) { machine.invalidateTarget() }
        }
        if let expiry = recoveryExpires, Date() >= expiry { discardRecovery(); notice = "Recovery expired." }
        if ticks % 20 == 0 {
            if machine.id != nil && !PermissionStatus().canDictate { cancel("Permission revoked. Recheck access in Settings.") }
            permissionSummary = PermissionStatus().summary
        }
        if machine.state == .recording { onStatus?() }
    }
    @objc private func screenLocked() { suspend() }
    private func suspend() { cancel("Session suspended; pending audio and result discarded."); discardRecovery() }
    private func unloadIfIdle() {
        guard !sessionBusy, modelLoaded else { return }
        modelLoaded = false; modelStatus = "Unloaded after memory pressure. Prepare before dictating."; refresh()
        Task { try? await speech.unload() }
    }
    func shutdown() { suspend(); clipboard.restore(); hotkey.stop(); watchdog?.invalidate() }
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
