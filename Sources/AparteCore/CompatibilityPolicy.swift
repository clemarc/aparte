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
    public let enabled: [Adapter]
    public func adapter(bundleID: String, role: String, appVersion: String?, osVersion: String) -> Adapter? {
        guard schema == 2 else { return nil }
        return enabled.first {
            $0.bundleID == bundleID && $0.roles.contains(role) &&
            ($0.appVersion == nil || $0.appVersion == appVersion) &&
            ($0.osVersion == nil || $0.osVersion == osVersion) &&
            ["selectedText", "clipboard"].contains($0.method)
        }
    }
}
