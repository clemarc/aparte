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
    func testPreferencesFailSafely() {
        XCTAssertEqual(Preferences.decode(Data("bad".utf8)).shortcut, .standard)
        XCTAssertFalse(Shortcut(key: 36, modifiers: Shortcut.control).isValid)
        XCTAssertFalse(Shortcut(key: 0, modifiers: 0).isValid)
        XCTAssertTrue(Shortcut.standard.isValid)
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
