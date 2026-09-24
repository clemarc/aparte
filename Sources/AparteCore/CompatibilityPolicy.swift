import Foundation

/// Operational support is separate from completed compatibility evidence.
public struct CompatibilityCatalog: Decodable {
    public struct Adapter: Decodable {
        public let bundleID: String
        public let method: String
        public let roles: [String]
        public let appVersion: String?
        public let osVersion: String?
    }
    public let schema: Int
    public let validated: [Adapter]
    public let overrides: [Adapter]
    public let genericClipboardRoles: [String]
    public func adapter(bundleID: String, role: String, appVersion: String?, osVersion: String) -> Adapter? {
        guard schema == 3 else { return nil }
        return overrides.first {
            $0.bundleID == bundleID && $0.roles.contains(role) &&
            ($0.appVersion == nil || $0.appVersion == appVersion) &&
            ($0.osVersion == nil || $0.osVersion == osVersion) &&
            ["selectedText", "clipboard"].contains($0.method)
        }
    }
    /// App-specific methods are optional. Standard editable controls get clipboard
    /// insertion even when their app has never appeared in the catalog.
    public func insertionMethod(bundleID: String, role: String, appVersion: String?, osVersion: String,
                                secure: Bool, enabled: Bool?, editable: Bool?,
                                valueSettable: Bool, selectedTextSettable: Bool) -> String? {
        guard schema == 3, !secure, enabled != false, editable != false else { return nil }
        if let adapter = adapter(bundleID: bundleID, role: role, appVersion: appVersion, osVersion: osVersion) {
            return adapter.method
        }
        guard genericClipboardRoles.contains(role), editable == true || valueSettable || selectedTextSettable else { return nil }
        return "clipboard"
    }

}
