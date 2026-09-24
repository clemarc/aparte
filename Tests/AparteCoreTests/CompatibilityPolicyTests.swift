import XCTest
@testable import AparteCore

final class CompatibilityPolicyTests: XCTestCase {
    func testShippingOverridesAreSeparateFromValidationEvidence() throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: "Resources/Compatibility.json"))
        let catalog = try JSONDecoder().decode(CompatibilityCatalog.self, from: data)
        XCTAssertTrue(catalog.validated.isEmpty, "Enabling adapters must not invent live evidence")
        XCTAssertEqual(catalog.overrides.count, 5)
        for id in ["com.apple.TextEdit", "com.apple.Terminal", "com.microsoft.VSCode", "com.google.Chrome", "com.tinyspeck.slackmacgap"] {
            XCTAssertNotNil(catalog.adapter(bundleID: id, role: "AXTextArea", appVersion: "test", osVersion: "26.6"))
            XCTAssertNil(catalog.adapter(bundleID: id, role: "AXSecureTextField", appVersion: "test", osVersion: "26.6"))
            XCTAssertNil(catalog.adapter(bundleID: id, role: "AXGroup", appVersion: "test", osVersion: "26.6"))
        }
        XCTAssertNil(catalog.adapter(bundleID: "unknown", role: "AXTextArea", appVersion: "test", osVersion: "26.6"))
    }

    func testScopedVersionsUnknownSchemasAndMethodsFailClosed() throws {
        func catalog(schema: Int = 3, method: String = "clipboard") throws -> CompatibilityCatalog {
            let json = """
            {"schema":\(schema),"validated":[],"genericClipboardRoles":["AXTextArea","AXTextField","AXComboBox"],"overrides":[{"bundleID":"test","roles":["AXTextArea"],"method":"\(method)","appVersion":"1","osVersion":"26.6"}]}
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
    func testAnyAppCanUseStandardEditableFieldsWithoutAnOverride() throws {
        let catalog = try JSONDecoder().decode(CompatibilityCatalog.self, from: Data(contentsOf: URL(fileURLWithPath: "Resources/Compatibility.json")))
        for app in ["unlisted.native.app", "unlisted.browser.app", ""] {
            for role in ["AXTextArea", "AXTextField", "AXComboBox"] {
                XCTAssertEqual(catalog.insertionMethod(bundleID: app, role: role, appVersion: nil, osVersion: "26.6", secure: false, enabled: true, editable: nil, valueSettable: true, selectedTextSettable: false), "clipboard")
                XCTAssertEqual(catalog.insertionMethod(bundleID: app, role: role, appVersion: nil, osVersion: "26.6", secure: false, enabled: true, editable: true, valueSettable: false, selectedTextSettable: false), "clipboard")
            }
        }
    }

    func testGenericTargetsRequireEditableEvidenceAndNeverAcceptUnknownRoles() throws {
        let catalog = try JSONDecoder().decode(CompatibilityCatalog.self, from: Data(contentsOf: URL(fileURLWithPath: "Resources/Compatibility.json")))
        XCTAssertNil(catalog.insertionMethod(bundleID: "any.app", role: "AXTextArea", appVersion: nil, osVersion: "26.6", secure: false, enabled: true, editable: nil, valueSettable: false, selectedTextSettable: false))
        for role in ["AXGroup", "AXWebArea", "AXStaticText", "AXWindow", "AXSecureTextField"] {
            XCTAssertNil(catalog.insertionMethod(bundleID: "any.app", role: role, appVersion: nil, osVersion: "26.6", secure: false, enabled: true, editable: true, valueSettable: true, selectedTextSettable: true))
        }
    }

    func testSecureDisabledAndReadOnlyOverrideAllPositiveEvidence() throws {
        let catalog = try JSONDecoder().decode(CompatibilityCatalog.self, from: Data(contentsOf: URL(fileURLWithPath: "Resources/Compatibility.json")))
        for app in ["com.apple.TextEdit", "com.apple.Terminal", "any.app"] {
            for (secure, enabled, editable) in [(true, true, true), (false, false, true), (false, true, false)] {
                XCTAssertNil(catalog.insertionMethod(bundleID: app, role: "AXTextArea", appVersion: nil, osVersion: "26.6", secure: secure, enabled: enabled, editable: editable, valueSettable: true, selectedTextSettable: true))
            }
        }
        XCTAssertEqual(catalog.insertionMethod(bundleID: "com.apple.Terminal", role: "AXTextArea", appVersion: nil, osVersion: "26.6", secure: false, enabled: true, editable: nil, valueSettable: false, selectedTextSettable: false), "clipboard", "Retain the existing terminal adapter's input semantics")
    }

}
