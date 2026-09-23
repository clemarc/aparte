import Foundation
public struct ClipboardRepresentation: Sendable, Equatable { public let type: String; public let data: Data; public init(type: String, data: Data) { self.type = type; self.data = data } }
public struct ClipboardSnapshot: Sendable, Equatable {
    public let items: [[ClipboardRepresentation]]
    public let changeCount: Int
    public init(items: [[ClipboardRepresentation]], changeCount: Int) throws {
        guard items.reduce(0, { $0 + $1.reduce(0, { $0 + $1.data.count }) }) <= 8 * 1024 * 1024,
              items.allSatisfy({ !$0.isEmpty }) else { throw AparteError.clipboardUnavailable }
        self.items = items; self.changeCount = changeCount
    }
}
public enum ClipboardPolicy {
    public static func owns(expectedCount: Int, actualCount: Int, expectedMarker: String, actualMarker: String?, expectedText: String, actualText: String?) -> Bool {
        expectedCount == actualCount && expectedMarker == actualMarker && expectedText == actualText
    }
    public static func allowedType(_ type: String) -> Bool {
        let lower = type.lowercased()
        return !lower.contains("promise") && !lower.contains("promised") && !lower.contains("lazy")
    }
}
