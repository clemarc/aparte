import AppKit
import SwiftUI
import AparteCore
import ServiceManagement
import AVFoundation

@main struct AparteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene { Settings { Text("Open Aparté’s menu bar item for Settings.").padding() } }
}
@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    private var item: NSStatusItem!
    private var coordinator: Coordinator!
    private var settingsWindow: NSWindow?
    private var recoveryWindow: NSWindow?
    private var indicator: NSPanel?
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        coordinator = Coordinator()
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.target = self; item.button?.action = #selector(showMenu)
        coordinator.onStatus = { [weak self] in self?.updateStatus() }
        updateStatus()
        if !UserDefaults.standard.bool(forKey: "onboardingSeen") { showSettings(); UserDefaults.standard.set(true, forKey: "onboardingSeen") }
    }
    private func updateStatus() {
        guard item != nil else { return }
        let status = coordinator.state == .recording ? "Recording \(Int(coordinator.elapsed))s" : coordinator.state.rawValue
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
    @objc private func cancel() { coordinator.cancel() }
    @objc private func quit() { NSApp.terminate(nil) }
    func applicationWillTerminate(_ notification: Notification) { coordinator.shutdown() }
}

struct IndicatorView: View {
    @ObservedObject var model: Coordinator
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: model.state == .recording ? "mic.fill" : "waveform").foregroundStyle(model.state == .recording ? .red : .primary)
            VStack(alignment: .leading) { Text(model.state.rawValue).font(.headline); Text(model.state == .recording ? "\(Int(model.elapsed))s · Release to finish · Esc cancels" : "Please wait · Esc cancels").font(.caption) }
        }.padding().frame(maxWidth: .infinity).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}
struct RecoveryView: View {
    @ObservedObject var model: Coordinator
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(model.recoveryUncertain ? "Insertion unconfirmed — check the target before copying" : "Your last dictation").font(.headline)
            if let text = model.recoveryText {
                ScrollView { Text(text).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }
                Text("Kept in memory for five minutes. Lock, quit, discard or the next recording clears it. A new recording replaces this result.").font(.caption).foregroundStyle(.secondary)
                HStack { Button("Copy (replaces clipboard)") { model.copyRecovery() }; Button("Discard", role: .destructive) { model.discardRecovery() } }
            } else { Text("No pending result.") }
        }.padding(24)
    }
}
struct SettingsView: View {
    @ObservedObject var model: Coordinator
    @State private var loginStatus = SMAppService.mainApp.status
    @State private var loginError = ""
    @State private var recordingBinding = false
    @State private var bindingMonitor: Any?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Aparté").font(.largeTitle.bold())
                Text("Hold to speak. Release to transcribe on this Mac.").font(.title3)
                Text("Speak once Recording appears. The default shortcut is Control–Option–Space. Escape cancels. No Return is sent.")
                GroupBox("Status · \(model.state.rawValue)") { VStack(alignment: .leading) { Text(model.notice); Text(model.modelStatus).foregroundStyle(.secondary) }.frame(maxWidth: .infinity, alignment: .leading).padding(6) }
                GroupBox("1 · Permissions") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Microphone is used only during a hold. Accessibility enables the shortcut and interaction with the original text field.")
                        Text(model.permissionSummary).font(.caption).textSelection(.enabled)
                        HStack { Button("Enable Microphone") { Task { _ = await PermissionStatus.requestMicrophone(); model.recheck() } }; Button("Accessibility Settings") { PermissionStatus.open("Accessibility") }; Button("Recheck") { model.recheck() } }
                        if AVCaptureDevice.authorizationStatus(for: .audio) == .denied || AVCaptureDevice.authorizationStatus(for: .audio) == .restricted { Button("Microphone Settings") { PermissionStatus.open("Microphone") } }
                        if model.tapFailed { Text("Event tap could not start. Review Input Monitoring if macOS requires it, then quit/reopen Aparté and recheck."); Button("Input Monitoring Settings") { PermissionStatus.open("ListenEvent") } }
                        Text("After changing macOS access, a restart may be needed. Aparté never changes security settings for you.").font(.caption).foregroundStyle(.secondary)
                    }.padding(6)
                }
                GroupBox("2 · Local model") {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(model.catalog?.models ?? []) { entry in
                            VStack(alignment: .leading, spacing: 5) {
                                Text(entry.displayName).bold()
                                Text("\(ByteCountFormatter.string(fromByteCount: entry.installedBytes, countStyle: .file)) installed · \(ByteCountFormatter.string(fromByteCount: entry.temporaryBytes, countStyle: .file)) free space needed for installation. First preparation may take several seconds or longer.").font(.caption)
                                HStack { Button("Download") { model.installModel(entry.id) }; Button("Import…") { model.importModel(entry.id) }; Button("Prepare / Use") { model.prepare(entry.id) }.disabled(!model.installed(entry.id)); Button("Delete", role: .destructive) { model.deleteModel(entry.id) }.disabled(!model.installed(entry.id)) }.disabled(model.sessionBusy || model.installing)
                            }
                        }
                        if model.installing { ProgressView(value: model.installProgress); Button("Cancel installation") { model.cancelInstall() } }
                        Text("Downloads require your click. Installed models work offline; nothing is downloaded during dictation.").font(.caption)
                    }.padding(6)
                }
                GroupBox("3 · Preferences") {
                    VStack(alignment: .leading, spacing: 10) {
                        Picker("Language", selection: $model.preferences.language) { Text("Auto").tag("auto"); Text("English").tag("en"); Text("French").tag("fr") }.onChange(of: model.preferences.language) { model.persist() }.disabled(model.sessionBusy)
                        HStack { Text("Shortcut: \(shortcutLabel)"); Button(recordingBinding ? "Press a chord…" : "Change…") { captureBinding() }; Button("Reset") { model.preferences.shortcut = .standard; model.persist() } }.disabled(model.sessionBusy)
                        Toggle("Test shortcut (does not record)", isOn: $model.bindingTest)
                        Text("Use Control, Option or Command plus a key. Fn/Globe, bare letters, modifier-only and reserved bindings are unsupported. Key names use US physical positions. A successful test cannot rule out every app conflict.").font(.caption)
                        Toggle("Launch at login", isOn: Binding(get: { loginStatus == .enabled }, set: { enabled in
                            do { if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }; loginError = "" } catch { loginError = "Registration failed; install in ~/Applications/Aparte.app and retry." }
                            loginStatus = SMAppService.mainApp.status
                        }))
                        Text("Login registration: \(loginDescription) \(loginError)").font(.caption)
                        if loginStatus == .requiresApproval { Button("Open Login Items") { SMAppService.openSystemSettingsLoginItems() } }
                    }.padding(6)
                }
                GroupBox("Privacy & compatibility") { Text("Transcription happens on this Mac. No audio or transcript history is saved. Your target app and the system clipboard (including Universal Clipboard) may process or sync inserted text. Clipboard restoration cannot undo another app’s reads. Unvalidated targets use Recovery. See the supplied compatibility evidence before relying on automatic insertion.").padding(6) }
                Text("Diagnostics: Aparté 0.4.0 · WhisperKit 1.1.0 · macOS \(ProcessInfo.processInfo.operatingSystemVersionString) · model \(model.preferences.model). Diagnostics contain no transcript or audio.").font(.caption).foregroundStyle(.secondary)
            }.padding(24)
        }.onAppear { loginStatus = SMAppService.mainApp.status }.onDisappear { stopBindingCapture() }
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
    private var shortcutLabel: String {
        let s = model.preferences.shortcut
        let modifiers = [(Shortcut.control,"⌃"),(Shortcut.option,"⌥"),(Shortcut.shift,"⇧"),(Shortcut.command,"⌘")].filter { s.modifiers & $0.0 != 0 }.map(\.1).joined()
        let names: [UInt16: String] = [0:"A",1:"S",2:"D",3:"F",4:"H",5:"G",6:"Z",7:"X",8:"C",9:"V",10:"§",11:"B",12:"Q",13:"W",14:"E",15:"R",16:"Y",17:"T",18:"1",19:"2",20:"3",21:"4",22:"6",23:"5",24:"=",25:"9",26:"7",27:"−",28:"8",29:"0",30:"]",31:"O",32:"U",33:"[",34:"I",35:"P",37:"L",38:"J",39:"’",40:"K",41:";",42:"\\",43:",",44:"/",45:"N",46:"M",47:".",49:"Space",50:"`"]
        return modifiers + (names[s.key] ?? "Unknown")
    }
    private func captureBinding() {
        guard !recordingBinding else { stopBindingCapture(); return }; recordingBinding = true
        bindingMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode != 53 {
                let proposed = Shortcut(key: event.keyCode, modifiers: UInt64(event.modifierFlags.rawValue) & Shortcut.mask)
                if proposed.isValid { model.preferences.shortcut = proposed; model.persist(); model.notice = "Shortcut saved. Use the binding test to check it." }
                else { model.notice = "Unsupported or reserved shortcut. Keep the previous binding." }
            }
            stopBindingCapture(); return nil
        }
    }
    private func stopBindingCapture() { if let bindingMonitor { NSEvent.removeMonitor(bindingMonitor) }; bindingMonitor = nil; recordingBinding = false }
}
