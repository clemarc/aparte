import XCTest
@testable import AparteCore

final class CompatibilityPolicyTests: XCTestCase {
    func testShippingAdaptersEnabledIndependentlyOfValidationEvidence() throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: "Resources/Compatibility.json"))
        let catalog = try JSONDecoder().decode(CompatibilityCatalog.self, from: data)
        XCTAssertTrue(catalog.validated.isEmpty, "Enabling adapters must not invent live evidence")
        XCTAssertEqual(catalog.enabled.count, 5)
        for id in ["com.apple.TextEdit", "com.apple.Terminal", "com.microsoft.VSCode", "com.google.Chrome", "com.tinyspeck.slackmacgap"] {
            XCTAssertNotNil(catalog.adapter(bundleID: id, role: "AXTextArea", appVersion: "test", osVersion: "26.6"))
            XCTAssertNil(catalog.adapter(bundleID: id, role: "AXSecureTextField", appVersion: "test", osVersion: "26.6"))
            XCTAssertNil(catalog.adapter(bundleID: id, role: "AXGroup", appVersion: "test", osVersion: "26.6"))
        }
        XCTAssertNil(catalog.adapter(bundleID: "unknown", role: "AXTextArea", appVersion: "test", osVersion: "26.6"))
    }

    func testScopedVersionsUnknownSchemasAndMethodsFailClosed() throws {
        func catalog(schema: Int = 2, method: String = "clipboard") throws -> CompatibilityCatalog {
            let json = """
            {"schema":\(schema),"validated":[],"enabled":[{"bundleID":"test","roles":["AXTextArea"],"method":"\(method)","appVersion":"1","osVersion":"26.6"}]}
            """
            return try JSONDecoder().decode(CompatibilityCatalog.self, from: Data(json.utf8))
        }
        let scoped = try catalog()
        XCTAssertNotNil(scoped.adapter(bundleID: "test", role: "AXTextArea", appVersion: "1", osVersion: "26.6"))
        XCTAssertNil(scoped.adapter(bundleID: "test", role: "AXTextArea", appVersion: nil, osVersion: "26.6"))
        XCTAssertNil(scoped.adapter(bundleID: "test", role: "AXTextArea", appVersion: "2", osVersion: "26.6"))
        XCTAssertNil(scoped.adapter(bundleID: "test", role: "AXTextArea", appVersion: "1", osVersion: "14.0"))
        for c in [try catalog(schema: 99), try catalog(method: "wholeField")] {
            XCTAssertNil(c.adapter(bundleID: "test", role: "AXTextArea", appVersion: "1", osVersion: "26.6"))
        }
    }
}
