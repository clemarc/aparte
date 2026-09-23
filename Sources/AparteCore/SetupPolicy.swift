import Foundation

/// Capability-specific readiness: in-app diagnostics never imply cross-app readiness.
public struct SetupReadiness: Equatable, Sendable {
    public let microphone, accessibility, model, shortcut: Bool
    public init(microphone: Bool, accessibility: Bool, model: Bool, shortcut: Bool) {
        self.microphone = microphone; self.accessibility = accessibility; self.model = model; self.shortcut = shortcut
    }
    public var canTestMicrophone: Bool { microphone && model }
    public var canDictate: Bool { canTestMicrophone && accessibility && shortcut }
    public var blockers: [String] {
        var result: [String] = []
        if !microphone { result.append("Grant Microphone access") }
        if !accessibility { result.append("Grant Accessibility access to this installed app") }
        if !model { result.append("Prepare the selected local model") }
        if accessibility && !shortcut { result.append("Restart the shortcut listener with Recheck; reopen Aparté if macOS still denies it") }
        return result
    }
}

/// Revision + UTF-16 selection metadata for the app-owned diagnostic editor.
/// Never a compatibility adapter for a different app.
public struct TestInsertionReceipt: Sendable {
    private let revision: UInt64
    private let selection: NSRange
    public init(revision: UInt64, selection: NSRange) { self.revision = revision; self.selection = selection }
    public func matches(revision: UInt64, selection: NSRange, isFocused: Bool, textLength: Int) -> Bool {
        isFocused && self.revision == revision && self.selection == selection && selection.location != NSNotFound && selection.location <= textLength && selection.length <= textLength - selection.location
    }
}
