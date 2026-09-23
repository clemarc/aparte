import AppKit
import SwiftUI
import AparteCore
import AparteSpeech

@main struct AparteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene { Settings { Text("Aparté settings are available from the menu bar.").padding() } }
}
@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    private var item: NSStatusItem?
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item?.button?.title = "Aparté · Needs setup"
        let menu = NSMenu(); menu.addItem(withTitle: "Quit Aparté", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"); item?.menu = menu
    }
}
