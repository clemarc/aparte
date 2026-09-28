import XCTest
@testable import AparteCore

final class SetupTests: XCTestCase {
    func testShortcutRejectionsExplainTheActualConstraint() {
        XCTAssertNil(Shortcut.standard.validationMessage)
        XCTAssertTrue(Shortcut(key: 49, modifiers: Shortcut.control).validationMessage!.contains("reserved"))
        XCTAssertTrue(Shortcut(key: 12, modifiers: Shortcut.command).validationMessage!.contains("reserved"))
        XCTAssertTrue(Shortcut(key: 0, modifiers: Shortcut.shift).validationMessage!.contains("Add Control"))
        XCTAssertTrue(Shortcut(key: 36, modifiers: Shortcut.control).validationMessage!.contains("Function keys"))
        let fn = Shortcut(key: 49, modifiers: Shortcut.control | Shortcut.option | (1 << 23))
        XCTAssertFalse(fn.isValid)
        XCTAssertTrue(fn.validationMessage!.contains("Fn / Globe"))
        // Extra modifiers must not turn an unsupported Fn chord into the saved chord.
        XCTAssertTrue(Shortcut(key: 0, modifiers: Shortcut.control | Shortcut.shift).isValid)
    }
    func testMicrophoneTestDoesNotRequireCrossAppAccess() {
        let local = SetupReadiness(microphone: true, accessibility: false, model: true, shortcut: false)
        XCTAssertTrue(local.canTestMicrophone)
        XCTAssertFalse(local.canDictate)
        XCTAssertEqual(local.blockers.count, 1)
        XCTAssertFalse(SetupReadiness(microphone: false, accessibility: true, model: true, shortcut: true).canTestMicrophone)
    }
    func testReadinessExplainsMissingModelAndRealTap() {
        let incomplete = SetupReadiness(microphone: true, accessibility: true, model: false, shortcut: false)
        XCTAssertEqual(incomplete.blockers.count, 2)
        XCTAssertFalse(incomplete.canDictate)
        let ready = SetupReadiness(microphone: true, accessibility: true, model: true, shortcut: true)
        XCTAssertTrue(ready.canDictate); XCTAssertTrue(ready.blockers.isEmpty)
    }
    func testRecorderAllowsCurrentBindingButStillOwnsExistingKeyup() {
        var matcher = GestureMatcher()
        let chord = Shortcut.standard
        XCTAssertEqual(matcher.key(chord.key, down: true, flags: chord.modifiers, active: false, allowNewBinding: false), .pass)
        XCTAssertFalse(matcher.ownsGesture)
        XCTAssertEqual(matcher.key(chord.key, down: true, flags: chord.modifiers, active: false), .down)
        XCTAssertTrue(matcher.ownsGesture)
        XCTAssertEqual(matcher.key(chord.key, down: false, flags: 0, active: false, allowNewBinding: false), .up)
        XCTAssertFalse(matcher.ownsGesture)
    }
    func testTestFieldRejectsChangedContextAndInvalidRanges() {
        let text = "élève 👩🏽‍💻 fin" as NSString
        let selection = text.range(of: "👩🏽‍💻")
        let receipt = TestInsertionReceipt(revision: 7, selection: selection)
        XCTAssertTrue(receipt.matches(revision: 7, selection: selection, isFocused: true, textLength: text.length))
        XCTAssertFalse(receipt.matches(revision: 8, selection: selection, isFocused: true, textLength: text.length))
        XCTAssertFalse(receipt.matches(revision: 7, selection: selection, isFocused: false, textLength: text.length))
        XCTAssertFalse(receipt.matches(revision: 7, selection: NSRange(location: 0, length: 0), isFocused: true, textLength: text.length))
        XCTAssertFalse(receipt.matches(revision: 7, selection: selection, isFocused: true, textLength: 1))
        let invalid = TestInsertionReceipt(revision: 1, selection: NSRange(location: NSNotFound, length: 0))
        XCTAssertFalse(invalid.matches(revision: 1, selection: NSRange(location: NSNotFound, length: 0), isFocused: true, textLength: text.length))
    }
}
