import XCTest
@testable import AparteCore

final class SetupTests: XCTestCase {
    func testShortcutRejectionsExplainTheActualConstraint() {
        XCTAssertNil(Shortcut.standard.validationMessage)
        XCTAssertTrue(Shortcut(key: 49, modifiers: Shortcut.control).validationMessage!.contains("reserved"))
        XCTAssertTrue(Shortcut(key: 12, modifiers: Shortcut.command).validationMessage!.contains("reserved"))
        XCTAssertTrue(Shortcut(key: 0, modifiers: Shortcut.shift).isValid)
        XCTAssertTrue(Shortcut(key: 0, modifiers: 0).isValid)
        XCTAssertTrue(Shortcut(key: Shortcut.modifierOnlyKey, modifiers: Shortcut.function).isValid)
        XCTAssertFalse(Shortcut(key: Shortcut.modifierOnlyKey, modifiers: Shortcut.control | Shortcut.shift).isValid)
        XCTAssertTrue(Shortcut(key: 49, modifiers: Shortcut.control | Shortcut.function).isValid)
        XCTAssertTrue(Shortcut(key: 36, modifiers: Shortcut.control).validationMessage!.contains("Use a letter"))
        XCTAssertTrue(Shortcut(key: 49, modifiers: Shortcut.function).validationMessage!.contains("reserved"))
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
    func testModifierOnlyAndBareKeyOwnership() {
        var matcher = GestureMatcher()
        matcher.binding = Shortcut(key: Shortcut.modifierOnlyKey, modifiers: Shortcut.function)
        XCTAssertEqual(matcher.flags(Shortcut.function), .down)
        XCTAssertEqual(matcher.flags(0), .up)
        XCTAssertEqual(matcher.flags(Shortcut.function), .down)
        XCTAssertEqual(matcher.key(0, down: true, flags: Shortcut.function, active: false), .up)
        XCTAssertEqual(matcher.flags(Shortcut.function | Shortcut.shift), .pass)
        XCTAssertEqual(matcher.flags(Shortcut.function), .pass)
        XCTAssertEqual(matcher.flags(0), .pass)
        XCTAssertEqual(matcher.flags(Shortcut.function), .down)
        XCTAssertEqual(matcher.flags(Shortcut.function | Shortcut.shift), .up)
        XCTAssertEqual(matcher.flags(Shortcut.function), .pass)
        XCTAssertEqual(matcher.flags(0), .pass)
        matcher.binding = Shortcut(key: 0, modifiers: 0)
        XCTAssertEqual(matcher.key(0, down: true, flags: 0, repeated: true, active: false), .pass)
        XCTAssertEqual(matcher.key(0, down: true, flags: 0, active: false), .down)
        XCTAssertEqual(matcher.key(0, down: false, flags: 0, active: true), .up)
    }
    func testModifierKeyEventsDoNotInterruptEitherGesture() {
        for (key, flag) in [(UInt16(63), Shortcut.function), (UInt16(59), Shortcut.control), (UInt16(62), Shortcut.control)] {
            XCTAssertTrue(Shortcut.isModifierKeyCode(key))
            var matcher = GestureMatcher()
            matcher.binding = Shortcut(key: Shortcut.modifierOnlyKey, modifiers: flag)
            var gesture = ShortcutGesture()
            for (downTime, upTime, expectedPress, expectedRelease) in [
                (1.0, 1.08, ShortcutGesture.Action.none, ShortcutGesture.Action.firstTap),
                (1.2, 1.28, .none, .startToggle),
                (2.0, 2.08, .stopToggle, .none)
            ] {
                XCTAssertEqual(matcher.flags(flag), .down)
                XCTAssertEqual(gesture.press(at: downTime), expectedPress)
                XCTAssertEqual(matcher.key(key, down: true, flags: flag, active: expectedRelease == .startToggle), .pass)
                XCTAssertEqual(matcher.key(key, down: false, flags: flag, active: expectedRelease == .startToggle), .pass)
                XCTAssertEqual(matcher.flags(0), .up)
                XCTAssertEqual(gesture.release(at: upTime), expectedRelease)
            }
            XCTAssertEqual(matcher.flags(flag), .down)
            XCTAssertEqual(gesture.press(at: 3), .none)
            XCTAssertEqual(matcher.key(key, down: true, flags: flag, active: true), .pass)
            XCTAssertEqual(gesture.held(at: 3.19), .startHold)
            XCTAssertEqual(matcher.flags(0), .up)
            XCTAssertEqual(gesture.release(at: 3.5), .stopHold)
        }
    }
    func testModelSpecificLanguages() {
        XCTAssertTrue(SpeechLanguages.supports("yue", model: "turbo"))
        XCTAssertFalse(SpeechLanguages.supports("yue", model: "small"))
        XCTAssertTrue(SpeechLanguages.supports("en", model: "base.en"))
        XCTAssertFalse(SpeechLanguages.supports("fr", model: "base.en"))
        XCTAssertEqual(SpeechLanguages.codes.count, 100)
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
