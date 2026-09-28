import AppKit
import SwiftUI
import AparteCore
import ServiceManagement
import AVFoundation
import Carbon

enum AppVersion {
    static var displayName: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "Aparté" }
    static var isDevelopment: Bool { Bundle.main.bundleIdentifier == "dev.aparte.Aparte.dew" }
    static var current: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown" }
    static var detailed: String {
        guard let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String else { return current }
        return "\(current) (build \(build))"
    }
}

@main struct AparteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene {
        Settings { EmptyView() }
            .commands {
                CommandGroup(replacing: .appSettings) {
                    Button("Open workspace…") { delegate.showSettings() }.keyboardShortcut(",", modifiers: .command)
                    Button("Show menu companion") { DispatchQueue.main.async { delegate.showMenu() } }
                }
            }
    }
}
@MainActor final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var item: NSStatusItem!
    private var coordinator: Coordinator!
    private var settingsWindow: NSWindow?
    private var recoveryWindow: NSWindow?
    private var indicator: NSPanel?
    private var companion: NSPopover?
    private let navigation = WorkspaceNavigation()
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
        item.button?.image = AparteBrand.menuImage
        item.button?.imagePosition = .imageLeading
        let label = coordinator.state == .ready ? "" : (coordinator.state == .needsSetup ? "Setup" : status)
        item.button?.title = [AppVersion.isDevelopment ? "Dew" : "", label].filter { !$0.isEmpty }.joined(separator: " · ")
        item.button?.setAccessibilityLabel("\(AppVersion.displayName) \(AppVersion.detailed): \(status). \(coordinator.notice)")
        item.button?.toolTip = "\(AppVersion.displayName) \(AppVersion.detailed) · \(status)\n\(coordinator.notice)"
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
    @objc func showMenu() {
        if companion?.isShown == true { companion?.performClose(nil); return }
        if companion == nil {
            let popover = NSPopover(); popover.behavior = .transient
            let host = NSHostingController(rootView: MenuCompanionView(model: coordinator, open: { [weak self] section in
                guard let self else { return }; self.companion?.performClose(nil)
                if let section { self.navigation.section = section }; self.showSettings()
            }, recovery: { [weak self] in self?.companion?.performClose(nil); self?.showRecovery() }, quit: { [weak self] in self?.quit() }))
            // Report SwiftUI's changing preferred size when status/Recovery adds rows.
            host.sizingOptions = [.preferredContentSize]
            popover.contentViewController = host
            popover.contentSize = NSSize(width: 320, height: max(300, host.view.fittingSize.height))
            companion = popover
        }
        if let button = item.button { companion?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY) }
    }
    @objc func showSettings() {
        if settingsWindow == nil {
            settingsWindow = makeWindow("\(AppVersion.displayName) \(AppVersion.detailed)", size: NSSize(width: 1040, height: 780), root: WorkspaceView(model: coordinator, navigation: navigation, showRecovery: { [weak self] in self?.showRecovery() }))
            settingsWindow?.minSize = NSSize(width: 860, height: 630)
            settingsWindow?.setFrameAutosaveName("AparteWorkspace")
        }
        settingsWindow?.delegate = self
        if settingsWindow?.isMiniaturized == true { settingsWindow?.deminiaturize(nil) }
        settingsWindow?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    @objc private func showRecovery() {
        if recoveryWindow == nil { recoveryWindow = makeWindow("\(AppVersion.displayName) — Recovery", size: NSSize(width: 560, height: 330), root: RecoveryView(model: coordinator)) }
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
