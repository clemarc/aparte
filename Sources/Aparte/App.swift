import AppKit
import SwiftUI
import AparteCore
import ServiceManagement
import AVFoundation
import Carbon

@main struct AparteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene { Settings { Text("Open Aparté’s menu bar item for Settings.").padding() } }
}
@MainActor final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var item: NSStatusItem!
    private var coordinator: Coordinator!
    private var settingsWindow: NSWindow?
    private var recoveryWindow: NSWindow?
    private var indicator: NSPanel?
    private var launchedInBackground = false
    private var reopenRequested = false
    func applicationWillFinishLaunching(_ notification: Notification) {
        // Preserve quiet login/service startup, but make an explicit Open visible.
        let event = NSAppleEventManager.shared().currentAppleEvent
        let reason = event?.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue
        launchedInBackground = reason == keyAELaunchedAsLogInItem || reason == keyAELaunchedAsServiceItem
            || event?.paramDescriptor(forKeyword: keyAELaunchedAsLogInItem) != nil
            || event?.paramDescriptor(forKeyword: keyAELaunchedAsServiceItem) != nil
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        coordinator = Coordinator()
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.target = self; item.button?.action = #selector(showMenu)
        coordinator.onStatus = { [weak self] in self?.updateStatus() }
        updateStatus()
        if !launchedInBackground || reopenRequested {
            showSettings()
        }
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        reopenRequested = true
        if coordinator != nil { showSettings() }
        return false // We restore the retained Settings window ourselves.
    }
    private func updateStatus() {
        guard item != nil else { return }
        let status = coordinator.notice.hasPrefix("Busy —") ? "Busy" : (coordinator.state == .recording ? "Recording \(Int(coordinator.elapsed))s" : coordinator.state.rawValue)
        item.button?.title = "Aparté · \(status)"; item.button?.setAccessibilityLabel("Aparté: \(status). \(coordinator.notice)")
        item.button?.toolTip = coordinator.notice
        let visible = [.startingCapture, .recording, .transcribing, .inserting].contains(coordinator.state)
        if visible {
            if indicator == nil {
                let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 320, height: 62), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
                panel.level = .floating; panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = true
                panel.ignoresMouseEvents = true; panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
                panel.contentView = NSHostingView(rootView: IndicatorView(model: coordinator)); indicator = panel
            }
            if let screen = NSScreen.main { indicator?.setFrameOrigin(NSPoint(x: screen.visibleFrame.midX - 160, y: screen.visibleFrame.minY + 38)) }
            indicator?.orderFrontRegardless()
        } else { indicator?.orderOut(nil) }
    }
    @objc private func showMenu() {
        let menu = NSMenu()
        let status = NSMenuItem(title: coordinator.notice, action: nil, keyEquivalent: ""); status.isEnabled = false; menu.addItem(status)
        menu.addItem(.separator())
        add(menu, "Settings & Setup…", #selector(showSettings))
        add(menu, "Recovery…", #selector(showRecovery), enabled: coordinator.recoveryText != nil)
        add(menu, "Cancel current dictation", #selector(cancel), enabled: coordinator.sessionBusy)
        menu.addItem(.separator()); add(menu, "Quit Aparté", #selector(quit))
        item.menu = menu; item.button?.performClick(nil); item.menu = nil
    }
    private func add(_ menu: NSMenu, _ title: String, _ action: Selector, enabled: Bool = true) { let entry = NSMenuItem(title: title, action: action, keyEquivalent: ""); entry.target = self; entry.isEnabled = enabled; menu.addItem(entry) }
    @objc func showSettings() {
        if settingsWindow == nil {
            settingsWindow = makeWindow("Aparté — Settings & Setup", size: NSSize(width: 630, height: 720), root: SettingsView(model: coordinator))
        }
        settingsWindow?.delegate = self
        if settingsWindow?.isMiniaturized == true { settingsWindow?.deminiaturize(nil) }
        settingsWindow?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    @objc private func showRecovery() {
        if recoveryWindow == nil { recoveryWindow = makeWindow("Aparté — Recovery", size: NSSize(width: 560, height: 330), root: RecoveryView(model: coordinator)) }
        recoveryWindow?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    private func makeWindow<V: View>(_ title: String, size: NSSize, root: V) -> NSWindow {
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = title; window.contentView = NSHostingView(rootView: root); window.isReleasedWhenClosed = false; window.center(); return window
    }
    func windowWillClose(_ notification: Notification) { if (notification.object as? NSWindow) === settingsWindow { coordinator.closeSetupTests() } }
    @objc private func cancel() { coordinator.cancel() }
    @objc private func quit() { NSApp.terminate(nil) }
    func applicationWillTerminate(_ notification: Notification) { coordinator.shutdown() }
}

struct IndicatorView: View {
    @ObservedObject var model: Coordinator
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: model.state == .recording ? "mic.fill" : "waveform").foregroundStyle(model.state == .recording ? .red : .primary)
            VStack(alignment: .leading) { Text(model.state.rawValue).font(.headline); Text(model.state == .recording ? "\(Int(model.elapsed))s · \(model.microphoneTestActive ? "Stop to finish" : "Release to finish") · Esc cancels" : "Please wait · Esc cancels").font(.caption) }
        }.padding().frame(maxWidth: .infinity).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}
struct RecoveryView: View {
    @ObservedObject var model: Coordinator
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(model.recoveryUncertain ? "Insertion unconfirmed — check the target before copying" : "Your last dictation").font(.headline)
            if let text = model.recoveryText {
                Text(model.recoveryReason).font(.callout).foregroundStyle(.secondary)
                ScrollView { Text(text).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }
                Text("Kept in Aparté for five minutes. The clipboard may retain or sync this text after Recovery expires. Lock, quit, discard or the next recording clears Aparté's copy.").font(.caption).foregroundStyle(.secondary)
                HStack { Button("Copy again (replaces clipboard)") { model.copyRecovery() }; Button("Discard", role: .destructive) { model.discardRecovery() } }
            } else { Text("No pending result.") }
        }.padding(24)
    }
}
struct SettingsView: View {
    @ObservedObject var model: Coordinator
    @State private var loginStatus = SMAppService.mainApp.status
    @State private var loginError = ""
    @State private var bindingPreview = "Press modifiers, then a key."
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Aparté").font(.largeTitle.bold())
                Text("Hold to speak. Release to transcribe on this Mac.").font(.title3)
                Text("Speak once Recording appears. The default shortcut is Control–Option–Space. Escape cancels. No Return is sent.")
                GroupBox("Status · \(model.state.rawValue)") { VStack(alignment: .leading) { Text(model.readinessSummary).font(.headline); Text(model.notice); Text(model.modelStatus).foregroundStyle(.secondary) }.frame(maxWidth: .infinity, alignment: .leading).padding(6) }
                GroupBox("1 · Permissions") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Microphone is used during a hold or an explicit recording test. Accessibility enables the global shortcut and interaction with the original text field.")
                        Text(model.permissionSummary).font(.caption).textSelection(.enabled)
                        Text(model.shortcutStatus).font(.caption)
                        if !model.permissionSummary.contains("Accessibility: Granted") { Text("If Settings already shows access granted, quit and reopen this installed Aparté. Rebuilds can change the identity macOS approved.").font(.caption) }
                        HStack { Button("Enable Microphone") { Task { _ = await PermissionStatus.requestMicrophone(); model.recheck() } }; Button("Accessibility Settings") { PermissionStatus.open("Accessibility") }; Button("Recheck") { model.recheck() } }
                        if AVCaptureDevice.authorizationStatus(for: .audio) == .denied || AVCaptureDevice.authorizationStatus(for: .audio) == .restricted { Button("Microphone Settings") { PermissionStatus.open("Microphone") } }
                        if model.tapFailed { Text("Event tap could not start. Review Input Monitoring if macOS requires it, then quit/reopen Aparté and recheck."); Button("Input Monitoring Settings") { PermissionStatus.open("ListenEvent") } }
                        Text("After changing macOS access, a restart may be needed. Aparté never changes security settings for you.").font(.caption).foregroundStyle(.secondary)
                    }.padding(6)
                }
                GroupBox("2 · Local model") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Compare measured choices on this M5 Pro (48 GB). Smaller numbers are better for preparation time, warm decoding and process memory; accuracy is measured separately on a synthetic English/French corpus.").font(.caption).foregroundStyle(.secondary)
                        Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 6) {
                            GridRow {
                                Text("Model").bold().frame(width: 82, alignment: .leading)
                                Text("Disk").bold().frame(width: 80, alignment: .leading)
                                Text("Prepare").bold().frame(width: 72, alignment: .leading)
                                Text("8 s p95").bold().frame(width: 70, alignment: .leading)
                                Text("Peak RAM").bold().frame(width: 80, alignment: .leading)
                            }
                            ForEach(model.catalog?.models ?? []) { entry in
                                let comparison = modelComparison(entry.id)
                                GridRow {
                                    Text(entry.id.capitalized).frame(width: 82, alignment: .leading)
                                    Text(ByteCountFormatter.string(fromByteCount: entry.installedBytes, countStyle: .file)).frame(width: 80, alignment: .leading)
                                    Text(comparison.prepare).frame(width: 72, alignment: .leading)
                                    Text(comparison.warmP95).frame(width: 70, alignment: .leading)
                                    Text(comparison.peakMemory).frame(width: 80, alignment: .leading)
                                }
                            }
                        }.font(.caption).accessibilityLabel("Model comparison: disk, preparation, warm eight-second decode p95, and peak process memory")
                        Text("Base: fastest, but failed the fixed technical-term gate. Small: recommended; passed every fixed synthetic gate. Medium and turbo offer larger models for comparison, with different speed and memory costs. These are file-decode measurements, not microphone-to-insertion latency; RAM is peak whole-process RSS, not model-only memory.").font(.caption).foregroundStyle(.secondary)
                        Divider()
                        ForEach(model.catalog?.models ?? []) { entry in
                            VStack(alignment: .leading, spacing: 5) {
                                Text(entry.displayName).bold()
                                Text("\(ByteCountFormatter.string(fromByteCount: entry.installedBytes, countStyle: .file)) installed · \(ByteCountFormatter.string(fromByteCount: entry.temporaryBytes, countStyle: .file)) free space needed for installation. First preparation may take several seconds or longer.").font(.caption)
                                Text("Measured preparation: \(modelComparison(entry.id).prepare) on this Mac; OS and cache state can change it. \(modelComparison(entry.id).quality)").font(.caption).foregroundStyle(.secondary)
                                HStack { Button("Download") { model.installModel(entry.id) }; Button("Import…") { model.importModel(entry.id) }; Button("Prepare / Use") { model.prepare(entry.id) }.disabled(!model.installed(entry.id)); Button("Delete", role: .destructive) { model.deleteModel(entry.id) }.disabled(!model.installed(entry.id)) }.disabled(model.sessionBusy || model.installing)
                            }
                        }
                        if model.installing { ProgressView(value: model.installProgress); Button("Cancel installation") { model.cancelInstall() } }
                        Text("Downloads require your click. Installed models work offline; nothing is downloaded during dictation.").font(.caption)
                        Text("To compare your own accent, select Prepare / Use, speak the same English phrase in the Microphone test below, then switch models and repeat. Aparté does not save recordings or transcripts; copy results yourself if you want a lasting side-by-side record.").font(.caption).foregroundStyle(.secondary)
                    }.padding(6)
                }
                GroupBox("3 · Test dictation") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Microphone → transcription").font(.headline)
                        Text("Start, wait for Recording, speak, then Stop. This test only needs a prepared model and Microphone access.").font(.caption)
                        HStack {
                            Button("Start recording") { model.startMicrophoneTest() }.disabled(!model.canStartMicrophoneTest || model.recordingBinding)
                            Button("Stop & transcribe") { model.stopMicrophoneTest() }.disabled(!model.microphoneTestActive)
                            Button("Cancel") { model.cancel("Test cancelled.") }.disabled(!model.sessionBusy)
                        }
                        ProgressView(value: model.inputLevel).accessibilityLabel("Microphone input level")
                        Text(model.inputStatus).font(.caption).textSelection(.enabled)
                        Button("Sound Input Settings") {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.Sound-Settings.extension?input") { NSWorkspace.shared.open(url) }
                        }
                        Divider()
                        Text("Shortcut → transcription → text box").font(.headline)
                        Text("Click in the box, hold \(model.preferences.shortcut.displayLabel), speak after Recording appears, then release. Text is inserted at your caret or replaces your selection. Keep focus here until it finishes.").font(.caption)
                        SetupEditor(model: model).frame(height: 120)
                        Text("This uses the real microphone and speech engine. In-app shortcut delivery is labelled separately; it does not validate insertion into another app.").font(.caption).foregroundStyle(.secondary)
                        Text(model.testStatus).accessibilityLabel("Test status: \(model.testStatus)")
                        if model.lastResultWasTest, let text = model.recoveryText {
                            Text("Transcribed text").font(.headline)
                            ScrollView { Text(text).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }.frame(minHeight: 40, maxHeight: 100)
                        }
                        Button("Clear test results") { model.closeSetupTests() }
                        Text("Tests are temporary: cleared after five minutes, when Setup closes, on lock or quit. No recordings or transcripts are saved.").font(.caption).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(6)
                }
                GroupBox("4 · Preferences") {
                    VStack(alignment: .leading, spacing: 10) {
                        Picker("Language", selection: $model.preferences.language) { Text("Auto").tag("auto"); Text("English").tag("en"); Text("French").tag("fr") }.onChange(of: model.preferences.language) { model.persist() }.disabled(model.sessionBusy)
                        HStack {
                            Text("Shortcut: \(model.preferences.shortcut.displayLabel)")
                            Button(model.recordingBinding ? "Cancel change" : "Change…") { model.recordingBinding.toggle(); model.bindingTest = false; bindingPreview = "Press modifiers, then a key." }
                            Button("Reset") { model.recordingBinding = false; model.preferences.shortcut = .standard; model.persist() }
                        }.disabled(model.sessionBusy)
                        if model.recordingBinding {
                            ShortcutRecorder(preview: { bindingPreview = $0 }, accept: { chord in
                                if let chord { model.preferences.shortcut = chord; model.persist(); model.notice = "Shortcut saved: \(chord.displayLabel). Test it in the text box above." }
                                model.recordingBinding = false
                            }).frame(height: 44)
                            Text(bindingPreview).font(.headline).accessibilityLabel("Shortcut entered: \(bindingPreview)")
                        }
                        Toggle("Check shortcut detection only (does not record)", isOn: $model.bindingTest).disabled(model.sessionBusy || model.recordingBinding)
                        Text("Use Control, Option or Command plus a key. Fn/Globe, bare letters, modifier-only and reserved bindings are unsupported. Key names use US physical positions. A successful test cannot rule out every app conflict.").font(.caption)
                        Toggle("Launch at login", isOn: Binding(get: { loginStatus == .enabled }, set: { enabled in
                            do { if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }; loginError = "" } catch { loginError = "Registration failed; install in ~/Applications/Aparte.app and retry." }
                            loginStatus = SMAppService.mainApp.status
                        }))
                        Text("Login registration: \(loginDescription) \(loginError)").font(.caption)
                        if loginStatus == .requiresApproval { Button("Open Login Items") { SMAppService.openSystemSettingsLoginItems() } }
                    }.padding(6)
                }
                GroupBox("Privacy & compatibility") { Text("Transcription happens on this Mac. No audio or transcript history is saved. After a failed insertion, Recovery puts your transcript on the system clipboard for manual paste; it may remain there after Aparté's five-minute Recovery expires or sync through Universal Clipboard. An unconfirmed paste may already have inserted text, so check before pasting again. Editable text fields across apps can receive automatic insertion. Secure, read-only and inaccessible controls use Recovery. Clipboard preservation may request data from its owning app; see the supplied compatibility limits.").padding(6) }
                Text("Diagnostics: Aparté 0.4.12 · WhisperKit 1.1.0 · macOS \(ProcessInfo.processInfo.operatingSystemVersionString) · model \(model.preferences.model). Diagnostics contain no transcript or audio.").font(.caption).foregroundStyle(.secondary)
            }.padding(24)
        }.onAppear { loginStatus = SMAppService.mainApp.status; model.recheck() }.onDisappear { model.closeSetupTests() }
    }
    private var loginDescription: String {
        switch loginStatus {
        case .notRegistered: return "Off"
        case .enabled: return "On"
        case .requiresApproval: return "Awaiting approval in Login Items"
        case .notFound: return "App not found; install at the stable path"
        @unknown default: return "Unknown; recheck Login Items"
        }
    }
    private func modelComparison(_ id: String) -> (prepare: String, warmP95: String, peakMemory: String, quality: String) {
        switch id {
        case "base": return ("6.2 s", "0.218 s", "318 MB", "Technical terms: 50% (failed 80% gate).")
        case "small": return ("18.3 s", "0.533 s", "842 MB", "All fixed synthetic quality gates passed; recommended default.")
        case "medium": return ("10.3 s", "1.137 s", "2.51 GB", "All fixed synthetic quality gates passed; English/French WER 0.43%/0.85%; technical terms 91.7%.")
        case "turbo": return ("94 s", "0.625 s", "3.24 GB", "All fixed synthetic quality gates passed; English/French WER 0.43%/1.91%.")
        default: return ("Unknown", "Unknown", "Unknown", "No measurements available.")
        }
    }
}
