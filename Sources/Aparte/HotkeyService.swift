import AppKit
import ApplicationServices
import Carbon
import AparteCore

@MainActor final class HotkeyService {
    static let eventMarker: Int64 = EventIdentity.marker
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var matcher = GestureMatcher()
    private var localMonitor: Any?
    var capturingBinding = false
    var allowsLocalTest: (() -> Bool)?
    private(set) var lastDelivery = "Global shortcut"
    var active = false
    var onDown: (() -> Void)?
    var onUp: (() -> Void)?
    var onCancel: (() -> Void)?
    var onInteraction: (() -> Void)?
    var onDisabled: (() -> Void)?
    var binding: Shortcut { get { matcher.binding } set { matcher.binding = newValue } }
    var isRunning: Bool { tap.map { CFMachPortIsValid($0) && CGEvent.tapIsEnabled(tap: $0) } ?? false }
    func installLocalTestHandler() {
        guard localMonitor == nil else { return }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged, .leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self, !self.isRunning, !self.capturingBinding,
                  self.allowsLocalTest?() == true || self.matcher.ownsGesture,
                  let cg = event.cgEvent else { return event }
            return self.handle(cg.type, cg, delivery: "In-app shortcut only") == nil ? nil : event
        }
    }
    func start() -> Bool {
        if let tap { CGEvent.tapEnable(tap: tap, enable: true); return true }
        // Posting is a separate capability, checked before an actual clipboard paste.
        // Test the real suppressing tap instead of using its unrelated preflight gate.
        guard AXIsProcessTrusted() else { return false }
        let events: [CGEventType] = [.keyDown, .keyUp, .flagsChanged, .leftMouseDown, .rightMouseDown, .otherMouseDown, .scrollWheel]
        let mask = events.reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
        let callback: CGEventTapCallBack = { _, type, event, context in
            guard let context else { return Unmanaged.passUnretained(event) }
            return MainActor.assumeIsolated {
                let service = Unmanaged<HotkeyService>.fromOpaque(context).takeUnretainedValue()
                return service.handle(type, event)
            }
        }
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: mask, callback: callback, userInfo: Unmanaged.passUnretained(self).toOpaque()) else { return false }
        self.tap = tap; source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes); CGEvent.tapEnable(tap: tap, enable: true); return true
    }
    func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil; source = nil
    }
    func shutdown() { stop(); if let localMonitor { NSEvent.removeMonitor(localMonitor) }; localMonitor = nil }
    private func handle(_ type: CGEventType, _ event: CGEvent, delivery: String = "Global shortcut") -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            DispatchQueue.main.async { self.onDisabled?() }
            if let tap, AXIsProcessTrusted() { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        if event.getIntegerValueField(.eventSourceUserData) == Self.eventMarker { return Unmanaged.passUnretained(event) }
        let action: GestureMatcher.Action
        switch type {
        case .keyDown, .keyUp:
            action = matcher.key(UInt16(event.getIntegerValueField(.keyboardEventKeycode)), down: type == .keyDown, flags: event.flags.rawValue, repeated: event.getIntegerValueField(.keyboardEventAutorepeat) != 0, active: active, allowNewBinding: !capturingBinding)
        case .flagsChanged: action = matcher.flags(event.flags.rawValue)
        default: if active { onInteraction?() }; return Unmanaged.passUnretained(event)
        }
        // Dispatch coordinator work after this short callback has returned.
        switch action {
        case .down: lastDelivery = delivery; DispatchQueue.main.async { self.onDown?() }; return nil
        case .up: DispatchQueue.main.async { self.onUp?() }; return type == .flagsChanged ? Unmanaged.passUnretained(event) : nil
        case .escape: DispatchQueue.main.async { self.onCancel?() }; return nil
        case .consume: return nil
        case .interaction: onInteraction?(); return Unmanaged.passUnretained(event)
        case .pass: return Unmanaged.passUnretained(event)
        }
    }
    static var secureInput: Bool { IsSecureEventInputEnabled() }
    static func modifiersClear(_ binding: Shortcut) -> Bool { CGEventSource.flagsState(.combinedSessionState).rawValue & binding.modifiers == 0 }
}
