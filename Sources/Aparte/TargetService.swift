import AppKit
import ApplicationServices
import AparteCore

struct TargetContext {
    let process: NSRunningApplication
    let launched: Date?
    let window: AXUIElement
    let element: AXUIElement
    let selection: CFTypeRef?
    let method: String?
    let clickPoint: CGPoint?
}
@MainActor final class TargetService {
    private let system = AXUIElementCreateSystemWide()
    private let catalog: CompatibilityCatalog?
    private var observer: AXObserver?
    private var enhancedProcesses: [pid_t: (process: NSRunningApplication, accepted: Bool)] = [:]
    var onInvalidated: ((String) -> Void)?
    private(set) var captureFailure = "No destination was captured."
    init() {
        catalog = Bundle.main.url(forResource: "Compatibility", withExtension: "json").flatMap { try? Data(contentsOf: $0) }.flatMap { try? JSONDecoder().decode(CompatibilityCatalog.self, from: $0) }
        AXUIElementSetMessagingTimeout(system, 0.05)
    }
    private func read(_ element: AXUIElement, _ attribute: String) -> (CFTypeRef?, AXError) {
        var result: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, attribute as CFString, &result)
        return (error == .success ? result : nil, error)
    }
    func value(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? { read(element, attribute).0 }
    private func belongs(_ element: AXUIElement, to pid: pid_t) -> Bool {
        var owner: pid_t = 0
        return AXUIElementGetPid(element, &owner) == .success && owner == pid
    }
    private func errorDescription(_ error: AXError) -> String {
        switch error {
        case .success: return "no element returned"
        case .noValue: return "no focused element exposed"
        case .attributeUnsupported: return "focus attribute unsupported"
        case .cannotComplete: return "Accessibility request timed out or could not complete"
        case .apiDisabled: return "Accessibility API unavailable"
        case .invalidUIElement: return "element no longer exists"
        default: return "Accessibility error \(error.rawValue)"
        }
    }
    private func focusedElement(in app: AXUIElement, pid: pid_t) -> (AXUIElement?, String) {
        // FocusedUIElement is an application attribute. Some apps also support the
        // system-wide convenience lookup; use that only as a guarded fallback.
        let primary = read(app, kAXFocusedUIElementAttribute)
        if let focused = element(primary.0) {
            return belongs(focused, to: pid) ? (focused, "") : (nil, "focused element belongs to another process")
        }
        let fallback = read(system, kAXFocusedUIElementAttribute)
        if let focused = element(fallback.0) {
            return belongs(focused, to: pid) ? (focused, "") : (nil, "system focus belongs to another process")
        }
        let windowResult = focusedElementInActiveWindow(app: app, pid: pid)
        if let focused = windowResult.0 { return (focused, "") }
        return (nil, "app: \(errorDescription(primary.1)); system: \(errorDescription(fallback.1)); active window: \(windowResult.1)")
    }
    private func focusedElementInActiveWindow(app: AXUIElement, pid: pid_t) -> (AXUIElement?, String) {
        guard let window = element(value(app, kAXFocusedWindowAttribute)), belongs(window, to: pid) else {
            return (nil, "no focused window exposed")
        }
        AXUIElementSetMessagingTimeout(window, 0.05)
        if let direct = element(value(window, kAXFocusedUIElementAttribute)), belongs(direct, to: pid) {
            return (direct, "")
        }
        // Some apps omit the focused-element link yet mark the actual control as
        // focused. Inspect only the active window, with a strict time/node bound.
        var queue: [(AXUIElement, Int)] = [(window, 0)]
        var index = 0
        var match: AXUIElement?
        var truncated = false
        let deadline = Date().addingTimeInterval(0.3)
        while index < queue.count, index < 96, Date() < deadline {
            let (current, depth) = queue[index]; index += 1
            AXUIElementSetMessagingTimeout(current, 0.05)
            if depth > 0, (value(current, kAXFocusedAttribute) as? Bool) == true {
                let role = value(current, kAXRoleAttribute) as? String ?? ""
                if catalog?.genericClipboardRoles.contains(role) == true, belongs(current, to: pid) {
                    if match != nil { return (nil, "multiple focused text controls") }
                    match = current
                }
            }
            guard depth < 10 else { continue }
            var raw: CFArray?
            if AXUIElementCopyAttributeValues(current, kAXChildrenAttribute as CFString, 0, 32, &raw) == .success,
               let children = raw as? [AXUIElement] {
                if children.count > 96 - queue.count { truncated = true }
                for child in children.prefix(96 - queue.count) { queue.append((child, depth + 1)) }
            }
        }
        if truncated || index < queue.count || Date() >= deadline { return (nil, "focused-control scan exceeded its safety limit") }
        return match.map { ($0, "") } ?? (nil, "no uniquely focused editable control exposed")
    }
    private func focusedWindow(in app: AXUIElement, field: AXUIElement, pid: pid_t) -> AXUIElement? {
        let appWindow = element(value(app, kAXFocusedWindowAttribute))
        let fieldWindow = element(value(field, kAXWindowAttribute))
        if let appWindow, let fieldWindow, !CFEqual(appWindow, fieldWindow) { return nil }
        guard let window = appWindow ?? fieldWindow, belongs(window, to: pid) else { return nil }
        return window
    }
    private func clickedEditableElement(in app: AXUIElement, pid: pid_t, point: CGPoint) -> (AXUIElement?, String) {
        guard point.x.isFinite, point.y.isFinite,
              let window = element(value(app, kAXFocusedWindowAttribute)), belongs(window, to: pid) else {
            return (nil, "no active window for the recent click")
        }
        var hit: AXUIElement?
        let error = AXUIElementCopyElementAtPosition(app, Float(point.x), Float(point.y), &hit)
        guard error == .success, let hit, belongs(hit, to: pid) else {
            return (nil, "recent click could not be hit-tested in this app")
        }
        var current: AXUIElement? = hit
        var field: AXUIElement?
        var inWindow = false
        for _ in 0..<12 {
            guard let item = current, belongs(item, to: pid) else { break }
            AXUIElementSetMessagingTimeout(item, 0.05)
            if CFEqual(item, window) { inWindow = true; break }
            let role = value(item, kAXRoleAttribute) as? String ?? ""
            let subrole = value(item, kAXSubroleAttribute) as? String ?? ""
            if role == kAXSecureTextFieldSubrole || subrole == kAXSecureTextFieldSubrole ||
                (value(item, kAXEnabledAttribute) as? Bool) == false {
                return (nil, "recent click was in a secure or disabled control")
            }
            if field == nil, catalog?.genericClipboardRoles.contains(role) == true {
                guard (value(item, "AXEditable") as? Bool) != false else {
                    return (nil, "recent click was in a read-only text control")
                }
                field = item
            }
            if let itemWindow = element(value(item, kAXWindowAttribute)) {
                guard belongs(itemWindow, to: pid), CFEqual(itemWindow, window) else {
                    return (nil, "recent click belongs to another window")
                }
                inWindow = true
            }
            current = element(value(item, kAXParentAttribute))
        }
        guard inWindow, let field else { return (nil, "recent click did not identify editable text in the active window") }
        return (field, "")
    }
    private func element(_ object: CFTypeRef?) -> AXUIElement? {
        guard let object, CFGetTypeID(object) == AXUIElementGetTypeID() else { return nil }; return (object as! AXUIElement)
    }
    /// Electron documents this app attribute for assistive clients. It enables
    /// its accessibility tree, not macOS permissions, and never changes focus.
    func prepareCurrentApplication() {
        guard AXIsProcessTrusted(), let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != getpid(), !app.isTerminated else { return }
        let element = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(element, 0.05)
        prepareAccessibility(element, process: app)
    }
    private func hasChromiumRuntime(_ process: NSRunningApplication) -> Bool {
        guard let bundle = process.bundleURL else { return false }
        let directory = bundle.appendingPathComponent("Contents/Frameworks", isDirectory: true)
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: directory.path) else { return false }
        return names.contains { name in
            name.hasSuffix(".framework") && FileManager.default.fileExists(atPath:
                directory.appendingPathComponent(name).appendingPathComponent("Versions/Current/Resources/icudtl.dat").path)
        }
    }
    private func prepareAccessibility(_ app: AXUIElement, process: NSRunningApplication) {
        let attribute = "AXManualAccessibility"
        // Some apps accept the documented setter without reporting it as
        // settable. An unsupported setter fails harmlessly; no TCC state changes.
        if (value(app, attribute) as? Bool) != true {
            _ = AXUIElementSetAttributeValue(app, attribute as CFString, kCFBooleanTrue)
        }
        // Chromium exposes native chrome before its web-content tree. Its macOS
        // implementation recognizes this assistive-technology request and may
        // enable full accessibility after a short delay. Send once per process.
        guard hasChromiumRuntime(process),
              enhancedProcesses[process.processIdentifier]?.process.launchDate != process.launchDate else { return }
        let accepted = AXUIElementSetAttributeValue(app, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue) == .success
        enhancedProcesses[process.processIdentifier] = (process, accepted)
    }
    func releaseAccessibility() {
        for request in enhancedProcesses.values where request.accepted && !request.process.isTerminated {
            let app = AXUIElementCreateApplication(request.process.processIdentifier)
            AXUIElementSetMessagingTimeout(app, 0.05)
            _ = AXUIElementSetAttributeValue(app, "AXEnhancedUserInterface" as CFString, kCFBooleanFalse)
        }
        enhancedProcesses.removeAll()
    }
    func capture(recentClick: CGPoint? = nil) throws -> TargetContext? {
        stopObserving()
        guard !HotkeyService.secureInput else { throw AparteError.unsafeTarget }
        guard let app = NSWorkspace.shared.frontmostApplication, !app.isTerminated else {
            captureFailure = "No running foreground app was found when recording began."; return nil
        }
        guard app.processIdentifier != getpid() else {
            captureFailure = "Aparté was still the foreground app. Click the destination text field before holding the shortcut, or focus the Setup test box."; return nil
        }
        let name = app.localizedName ?? "The foreground app"
        guard let catalog, catalog.schema == 3 else {
            captureFailure = "Insertion configuration could not be loaded. Reinstall the local app; your dictation is available in Recovery."; return nil
        }
        let axApp = AXUIElementCreateApplication(app.processIdentifier); AXUIElementSetMessagingTimeout(axApp, 0.05)
        prepareAccessibility(axApp, process: app)
        let resolution = focusedElement(in: axApp, pid: app.processIdentifier)
        let clicked = resolution.0 == nil ? recentClick.map { clickedEditableElement(in: axApp, pid: app.processIdentifier, point: $0) } : nil
        guard let focused = resolution.0 ?? clicked?.0 else {
            let clickReason = clicked?.1 ?? "no recent click in an editable field"
            captureFailure = "\(name) did not expose a focused input (\(resolution.1); \(clickReason)). Click its text field immediately before holding the shortcut."; return nil
        }
        AXUIElementSetMessagingTimeout(focused, 0.05)
        guard let window = focusedWindow(in: axApp, field: focused, pid: app.processIdentifier) else {
            captureFailure = "\(name) exposed a focused element, but its original window could not be identified consistently. Nothing will be inserted."; return nil
        }
        let role = value(focused, kAXRoleAttribute) as? String ?? ""
        let subrole = value(focused, kAXSubroleAttribute) as? String ?? ""
        guard subrole != kAXSecureTextFieldSubrole, role != kAXSecureTextFieldSubrole,
              (value(focused, kAXEnabledAttribute) as? Bool) != false,
              (value(focused, "AXEditable") as? Bool) != false else { throw AparteError.unsafeTarget }
        let version = app.bundleURL.flatMap(Bundle.init(url:))?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let os = ProcessInfo.processInfo.operatingSystemVersion
        let osVersion = "\(os.majorVersion).\(os.minorVersion)"
        guard let chosenMethod = insertionMethod(for: focused, app: app, role: role, subrole: subrole, version: version, osVersion: osVersion) else {
            captureFailure = "\(name)’s focused control is not exposed as a supported editable text field. Click inside its text input before dictating; your text is available in Recovery."; return nil
        }
        let selection = value(focused, kAXSelectedTextRangeAttribute)
        var method = chosenMethod
        if method == "selectedText" {
            var settable = DarwinBoolean(false)
            // Decide before any mutation; never fall back after an AX write attempt.
            if selection == nil || AXUIElementIsAttributeSettable(focused, kAXSelectedTextAttribute as CFString, &settable) != .success || !settable.boolValue { method = "clipboard" }
        }
        captureFailure = ""
        let context = TargetContext(process: app, launched: app.launchDate, window: window, element: focused, selection: selection, method: method, clickPoint: resolution.0 == nil ? recentClick : nil)
        observe(app: axApp, focused: focused, pid: app.processIdentifier)
        return context
    }
    private func settable(_ element: AXUIElement, _ attribute: String) -> Bool {
        var result = DarwinBoolean(false)
        return AXUIElementIsAttributeSettable(element, attribute as CFString, &result) == .success && result.boolValue
    }
    private func insertionMethod(for field: AXUIElement, app: NSRunningApplication, role: String? = nil, subrole: String? = nil, version: String? = nil, osVersion: String? = nil) -> String? {
        let actualRole = role ?? (value(field, kAXRoleAttribute) as? String ?? "")
        let actualSubrole = subrole ?? (value(field, kAXSubroleAttribute) as? String ?? "")
        let os = ProcessInfo.processInfo.operatingSystemVersion
        let appVersion = version ?? app.bundleURL.flatMap(Bundle.init(url:))?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        // Inspect capabilities only: never read or write the full AXValue payload.
        return catalog?.insertionMethod(bundleID: app.bundleIdentifier ?? "", role: actualRole,
            appVersion: appVersion, osVersion: osVersion ?? "\(os.majorVersion).\(os.minorVersion)",
            secure: HotkeyService.secureInput || actualRole == kAXSecureTextFieldSubrole || actualSubrole == kAXSecureTextFieldSubrole,
            enabled: value(field, kAXEnabledAttribute) as? Bool, editable: value(field, "AXEditable") as? Bool,
            valueSettable: settable(field, kAXValueAttribute), selectedTextSettable: settable(field, kAXSelectedTextAttribute))
    }
    func valid(_ target: TargetContext) -> Bool {
        guard !HotkeyService.secureInput, AXIsProcessTrusted(), !target.process.isTerminated,
              target.process.launchDate == target.launched, NSWorkspace.shared.frontmostApplication?.processIdentifier == target.process.processIdentifier else { return false }
        let app = AXUIElementCreateApplication(target.process.processIdentifier); AXUIElementSetMessagingTimeout(app, 0.05)
        let currentFocus = focusedElement(in: app, pid: target.process.processIdentifier).0
        if let currentFocus, !CFEqual(currentFocus, target.element) { return false }
        let current = currentFocus ?? target.clickPoint.flatMap { clickedEditableElement(in: app, pid: target.process.processIdentifier, point: $0).0 }
        guard let current, CFEqual(current, target.element),
              let window = focusedWindow(in: app, field: current, pid: target.process.processIdentifier), CFEqual(window, target.window),
              (value(current, kAXSubroleAttribute) as? String) != kAXSecureTextFieldSubrole,
              (value(current, kAXEnabledAttribute) as? Bool) != false,
              (value(current, "AXEditable") as? Bool) != false,
              insertionMethod(for: current, app: target.process) != nil else { return false }
        let selection = value(current, kAXSelectedTextRangeAttribute)
        switch (target.selection, selection) { case (.none, .none): return target.method == "clipboard"
        case let (.some(a), .some(b)): return CFEqual(a,b)
        default: return false }
    }
    func validAfterReturn(_ target: TargetContext, recentClick: (point: CGPoint, time: Date)?, since departure: Date) -> Bool {
        guard valid(target) else { return false }
        guard target.clickPoint != nil else { return true }
        // A successful AX focus restoration can replace the earlier click proof.
        // A fallback click alone still needs a fresh receipt after departure.
        if (value(target.element, kAXFocusedAttribute) as? Bool) == true { return true }
        guard let recentClick, recentClick.time > departure else { return false }
        let app = AXUIElementCreateApplication(target.process.processIdentifier)
        AXUIElementSetMessagingTimeout(app, 0.05)
        guard let clicked = clickedEditableElement(in: app, pid: target.process.processIdentifier, point: recentClick.point).0 else { return false }
        return CFEqual(clicked, target.element)
    }
    func canReturnToOriginal(_ target: TargetContext) -> Bool {
        guard AXIsProcessTrusted(), !HotkeyService.secureInput, !target.process.isTerminated,
              target.process.launchDate == target.launched else { return false }
        let app = AXUIElementCreateApplication(target.process.processIdentifier)
        AXUIElementSetMessagingTimeout(app, 0.05)
        guard let window = focusedWindow(in: app, field: target.element, pid: target.process.processIdentifier),
              CFEqual(window, target.window),
              (value(target.element, kAXSubroleAttribute) as? String) != kAXSecureTextFieldSubrole,
              (value(target.element, kAXEnabledAttribute) as? Bool) != false,
              (value(target.element, "AXEditable") as? Bool) != false,
              insertionMethod(for: target.element, app: target.process) != nil else { return false }
        let selection = value(target.element, kAXSelectedTextRangeAttribute)
        switch (target.selection, selection) {
        case (.none, .none): return target.method == "clipboard"
        case let (.some(original), .some(current)): return CFEqual(original, current)
        default: return false
        }
    }
    func requestReturnToOriginal(_ target: TargetContext) -> Bool {
        guard canReturnToOriginal(target), target.process.activate(options: []) else { return false }
        AXUIElementSetMessagingTimeout(target.window, 0.05)
        AXUIElementSetMessagingTimeout(target.element, 0.05)
        guard AXUIElementPerformAction(target.window, kAXRaiseAction as CFString) == .success else { return false }
        _ = AXUIElementSetAttributeValue(target.element, kAXFocusedAttribute as CFString, kCFBooleanTrue)
        return true
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
        let callback: AXObserverCallback = { _, _, notification, refcon in
            guard let refcon else { return }
            MainActor.assumeIsolated { Unmanaged<TargetService>.fromOpaque(refcon).takeUnretainedValue().onInvalidated?(notification as String) }
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
