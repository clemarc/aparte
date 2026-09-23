import AppKit
import ApplicationServices
import AparteCore

struct CompatibilityCatalog: Decodable {
    struct Adapter: Decodable {
        let bundleID: String
        let method: String
        let roles: [String]
        let appVersion: String?
        let osVersion: String?
    }
    let validated: [Adapter]
    let candidates: [Adapter]
}
struct TargetContext {
    let process: NSRunningApplication
    let launched: Date?
    let window: AXUIElement
    let element: AXUIElement
    let selection: CFTypeRef?
    let method: String?
}
@MainActor final class TargetService {
    private let system = AXUIElementCreateSystemWide()
    private let catalog: CompatibilityCatalog?
    private var observer: AXObserver?
    var onInvalidated: (() -> Void)?
    init() {
        catalog = Bundle.main.url(forResource: "Compatibility", withExtension: "json").flatMap { try? Data(contentsOf: $0) }.flatMap { try? JSONDecoder().decode(CompatibilityCatalog.self, from: $0) }
        AXUIElementSetMessagingTimeout(system, 0.05)
    }
    func value(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
        var result: CFTypeRef?; guard AXUIElementCopyAttributeValue(element, attribute as CFString, &result) == .success else { return nil }; return result
    }
    private func element(_ object: CFTypeRef?) -> AXUIElement? {
        guard let object, CFGetTypeID(object) == AXUIElementGetTypeID() else { return nil }; return (object as! AXUIElement)
    }
    func capture() throws -> TargetContext? {
        stopObserving()
        guard !HotkeyService.secureInput else { throw AparteError.unsafeTarget }
        guard let app = NSWorkspace.shared.frontmostApplication, app.processIdentifier != getpid(), !app.isTerminated else { return nil }
        let axApp = AXUIElementCreateApplication(app.processIdentifier); AXUIElementSetMessagingTimeout(axApp, 0.05)
        guard let focused = element(value(system, kAXFocusedUIElementAttribute)), let window = element(value(axApp, kAXFocusedWindowAttribute)) else { return nil }
        AXUIElementSetMessagingTimeout(focused, 0.05)
        let role = value(focused, kAXRoleAttribute) as? String ?? ""
        let subrole = value(focused, kAXSubroleAttribute) as? String ?? ""
        guard subrole != kAXSecureTextFieldSubrole, role != kAXSecureTextFieldSubrole,
              (value(focused, kAXEnabledAttribute) as? Bool) != false,
              (value(focused, "AXEditable") as? Bool) != false else { throw AparteError.unsafeTarget }
        let version = app.bundleURL.flatMap(Bundle.init(url:))?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let os = ProcessInfo.processInfo.operatingSystemVersion
        let osVersion = "\(os.majorVersion).\(os.minorVersion)"
        let adapter = catalog?.validated.first { $0.bundleID == app.bundleIdentifier && $0.roles.contains(role) && $0.appVersion == version && $0.osVersion == osVersion }
        let context = TargetContext(process: app, launched: app.launchDate, window: window, element: focused, selection: value(focused, kAXSelectedTextRangeAttribute), method: adapter?.method)
        observe(app: axApp, focused: focused, pid: app.processIdentifier)
        return context
    }
    func valid(_ target: TargetContext) -> Bool {
        guard !HotkeyService.secureInput, AXIsProcessTrusted(), !target.process.isTerminated,
              target.process.launchDate == target.launched, NSWorkspace.shared.frontmostApplication?.processIdentifier == target.process.processIdentifier else { return false }
        let app = AXUIElementCreateApplication(target.process.processIdentifier); AXUIElementSetMessagingTimeout(app, 0.05)
        guard let current = element(value(system, kAXFocusedUIElementAttribute)), CFEqual(current, target.element),
              let window = element(value(app, kAXFocusedWindowAttribute)), CFEqual(window, target.window),
              (value(current, kAXSubroleAttribute) as? String) != kAXSecureTextFieldSubrole,
              (value(current, kAXEnabledAttribute) as? Bool) != false,
              (value(current, "AXEditable") as? Bool) != false else { return false }
        let selection = value(current, kAXSelectedTextRangeAttribute)
        switch (target.selection, selection) { case (.none, .none): return target.method == "clipboard"
        case let (.some(a), .some(b)): return CFEqual(a,b)
        default: return false }
    }
    enum AXOutcome { case unattempted, attempted, uncertain }
    func insertSelectedText(_ text: String, into target: TargetContext) -> AXOutcome {
        guard target.method == "selectedText", valid(target) else { return .unattempted }
        var settable = DarwinBoolean(false)
        guard AXUIElementIsAttributeSettable(target.element, kAXSelectedTextAttribute as CFString, &settable) == .success, settable.boolValue else { return .unattempted }
        // Exactly one potentially mutating call. Even a failure is not retried.
        let result = AXUIElementSetAttributeValue(target.element, kAXSelectedTextAttribute as CFString, text as CFString)
        return result == .success ? .attempted : .uncertain
    }
    private func observe(app: AXUIElement, focused: AXUIElement, pid: pid_t) {
        var created: AXObserver?
        let callback: AXObserverCallback = { _, _, _, refcon in
            guard let refcon else { return }
            MainActor.assumeIsolated { Unmanaged<TargetService>.fromOpaque(refcon).takeUnretainedValue().onInvalidated?() }
        }
        guard AXObserverCreate(pid, callback, &created) == .success, let created else { return }
        observer = created
        let pointer = Unmanaged.passUnretained(self).toOpaque()
        for notification in [kAXFocusedUIElementChangedNotification, kAXFocusedWindowChangedNotification] { AXObserverAddNotification(created, app, notification as CFString, pointer) }
        for notification in [kAXSelectedTextChangedNotification, kAXValueChangedNotification, kAXUIElementDestroyedNotification] { AXObserverAddNotification(created, focused, notification as CFString, pointer) }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(created), .commonModes)
    }
    func stopObserving() {
        if let observer { CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes) }; observer = nil
    }
}
