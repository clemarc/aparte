import XCTest
import AVFoundation
@testable import AparteCore
final class PolicyTests: XCTestCase {
    func testSanitization() {
        XCTAssertEqual(TranscriptPolicy.sanitize("  élève 👩🏽‍💻\tA\r\nB\u{2028}C\u{001b}\0  "), "élève 👩🏽‍💻 A  B C")
        XCTAssertEqual(TranscriptPolicy.sanitize("foo_bar(a);"), "foo_bar(a);")
    }
    func testGate() {
        XCTAssertFalse(TranscriptPolicy.hasSpeechEnergy(Array(repeating: 0, count: 16000)))
        XCTAssertFalse(TranscriptPolicy.hasSpeechEnergy(Array(repeating: 0.3, count: 3999)))
        XCTAssertTrue(TranscriptPolicy.hasSpeechEnergy(Array(repeating: 0.002, count: 4000)))
        XCTAssertTrue(TranscriptPolicy.isRepetitive(Array(repeating: "thank you now", count: 4).joined(separator: " ")))
        XCTAssertFalse(TranscriptPolicy.isRepetitive("A legitimate short sentence."))
    }
    func testStartupCancelAndStaleCallback() {
        var s = SessionMachine(); s.prepared(true); let id = s.begin()!
        XCTAssertFalse(s.release(id)); XCTAssertFalse(s.started(id)); XCTAssertNil(s.id)
        let next = s.begin()!; XCTAssertFalse(s.started(id)); XCTAssertTrue(s.started(next))
    }
    func testLeaseSurvivesCancellation() {
        var s = SessionMachine(); s.prepared(true); let id = s.begin()!; XCTAssertTrue(s.started(id)); XCTAssertTrue(s.release(id))
        s.cancel(); XCTAssertNil(s.begin()); XCTAssertFalse(s.decoded(id)); s.unwind(); XCTAssertNotNil(s.begin())
    }
    func testFailureRemainsVisibleUntilExplicitRetry() {
        var s = SessionMachine(); s.prepared(true); let id = s.begin()!
        XCTAssertTrue(s.started(id)); XCTAssertTrue(s.release(id))
        s.fail(); XCTAssertNil(s.begin()); XCTAssertFalse(s.decoded(id))
        s.unwind(); s.prepared(true)
        XCTAssertEqual(s.state, .error); XCTAssertNil(s.begin())
        s.prepared(true, clearError: true); XCTAssertNotNil(s.begin())
        s.fail(); s.unwind(); s.prepared(false)
        XCTAssertEqual(s.state, .needsSetup, "missing capabilities must still take precedence")
    }
    func testOwnedKeyupAndModifiers() {
        var m = GestureMatcher()
        XCTAssertEqual(m.key(49, down: true, flags: Shortcut.standard.modifiers, active: false), .down)
        XCTAssertEqual(m.key(49, down: true, flags: Shortcut.standard.modifiers, repeated: true, active: true), .consume)
        XCTAssertEqual(m.flags(Shortcut.control), .up)
        m.binding = Shortcut(key: 0, modifiers: Shortcut.control)
        XCTAssertEqual(m.key(49, down: false, flags: 0, active: false), .consume)
        XCTAssertEqual(m.key(8, down: true, flags: Shortcut.command, active: true), .interaction)
        XCTAssertEqual(m.key(9, down: true, flags: Shortcut.command, active: true, ownEvent: true), .pass)
    }
    func testHoldAndDoubleTapShareOneShortcut() {
        var gesture = ShortcutGesture()
        XCTAssertEqual(gesture.press(at: 1), .none)
        XCTAssertEqual(gesture.held(at: 1.05), .none)
        XCTAssertEqual(gesture.release(at: 1.08), .firstTap)
        XCTAssertEqual(gesture.press(at: 1.43), .none) // 350 ms inclusive
        XCTAssertEqual(gesture.release(at: 1.48), .startToggle)
        XCTAssertTrue(gesture.isToggled)
        XCTAssertEqual(gesture.press(at: 5), .stopToggle)
        XCTAssertEqual(gesture.release(at: 5.05), .none)
        XCTAssertEqual(gesture.press(at: 6), .none)
        XCTAssertEqual(gesture.held(at: 6.19), .startHold)
        XCTAssertEqual(gesture.release(at: 7.1), .stopHold)
        XCTAssertEqual(gesture.press(at: 7.2), .none)
        XCTAssertEqual(gesture.release(at: 7.28), .firstTap)
        XCTAssertEqual(gesture.press(at: 7.4), .none)
        XCTAssertEqual(gesture.held(at: 7.59), .startHold) // A second press held down is a hold.
        XCTAssertEqual(gesture.release(at: 8), .stopHold)
        XCTAssertEqual(gesture.press(at: 9), .none)
        XCTAssertEqual(gesture.release(at: 9.08), .firstTap)
        XCTAssertEqual(gesture.press(at: 9.44), .none) // Outside the 350 ms window.
        XCTAssertEqual(gesture.release(at: 9.5), .firstTap)
        gesture.reset()
        XCTAssertEqual(gesture.press(at: 9.6), .none)
        XCTAssertEqual(gesture.release(at: 9.68), .firstTap)
        XCTAssertEqual(gesture.press(at: 10), .none)
        XCTAssertEqual(gesture.release(at: 10.25), .none) // A long press is not a tap.
        XCTAssertEqual(gesture.press(at: 10.3), .none)
        XCTAssertEqual(gesture.release(at: 10.38), .firstTap)
    }
    func testPreferencesFailSafely() {
        XCTAssertEqual(Preferences.decode(Data("bad".utf8)).shortcut, .standard)
        var turbo = Preferences(); turbo.model = "turbo"
        XCTAssertEqual(Preferences.decode(try? JSONEncoder().encode(turbo)).model, "turbo")
        turbo.model = "medium"
        XCTAssertEqual(Preferences.decode(try? JSONEncoder().encode(turbo)).model, "medium")
        XCTAssertFalse(Shortcut(key: 36, modifiers: Shortcut.control).isValid)
        XCTAssertTrue(Shortcut(key: 0, modifiers: 0).isValid)
        XCTAssertTrue(Shortcut.standard.isValid)
        turbo.language = "de"; XCTAssertEqual(Preferences.decode(try? JSONEncoder().encode(turbo)).language, "de")
        turbo.language = "zz"; XCTAssertEqual(Preferences.decode(try? JSONEncoder().encode(turbo)).language, "auto")
        turbo.model = "base.en"; turbo.language = "fr"
        let decoded = Preferences.decode(try? JSONEncoder().encode(turbo))
        XCTAssertEqual(decoded.model, "base.en"); XCTAssertEqual(decoded.language, "auto")
        for oldMode in ["hold", "doubleTap"] {
            let legacy = Data("{\"schema\":1,\"shortcut\":{\"key\":65535,\"modifiers\":262144},\"language\":\"en\",\"model\":\"medium\",\"gesture\":\"\(oldMode)\"}".utf8)
            let migrated = Preferences.decode(legacy)
            XCTAssertEqual(migrated.shortcut, Shortcut(key: Shortcut.modifierOnlyKey, modifiers: Shortcut.control))
            XCTAssertEqual(migrated.language, "en")
            let encoded = try? JSONEncoder().encode(migrated)
            XCTAssertFalse(String(decoding: encoded ?? Data(), as: UTF8.self).contains("gesture"))
        }
    }
    func testSampleRateAndStereoConversion() throws {
        for rate in [44100.0, 48000.0] {
            let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: rate, channels: 2, interleaved: false)!
            let input = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(rate))!
            input.frameLength = input.frameCapacity
            for i in 0..<Int(input.frameLength) { input.floatChannelData![0][i] = 0.2; input.floatChannelData![1][i] = 0.4 }
            let result = try AudioConversion.mono16k(input)
            XCTAssertEqual(result.count, 16000, accuracy: 2)
            XCTAssertEqual(result[8000], 0.3, accuracy: 0.01)
        }
    }
    func testPathTraversal() {
        let url = URL(string: "https://huggingface.co/model")!
        for path in ["../evil", "/evil", "ok/../../evil", "ok//evil", "ok/./evil"] {
            XCTAssertFalse(AssetFile(path: path, url: url, bytes: 1, sha256: String(repeating: "0", count: 64)).isSafe)
        }
    }
}
