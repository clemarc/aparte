import XCTest
@testable import AparteCore
final class AdversarialTests: XCTestCase {
    func testRapidSessionsIgnoreEveryStaleCompletion() {
        var machine = SessionMachine(); machine.prepared(true)
        for _ in 0..<100 {
            let id = machine.begin()!; XCTAssertTrue(machine.started(id)); XCTAssertTrue(machine.release(id))
            machine.invalidateTarget(); XCTAssertTrue(machine.invalidatedTarget)
            XCTAssertNil(machine.begin()); machine.cancel(); XCTAssertFalse(machine.decoded(id)); XCTAssertNil(machine.begin()); machine.unwind()
            let next = machine.begin()!; XCTAssertFalse(machine.started(id)); machine.cancel(); XCTAssertFalse(machine.decoded(next))
        }
    }
    func testEscapeMatchedAfterCancellation() {
        var gesture = GestureMatcher()
        XCTAssertEqual(gesture.key(53, down: true, flags: 0, active: true), .escape)
        XCTAssertEqual(gesture.key(53, down: false, flags: 0, active: false), .consume)
        XCTAssertEqual(gesture.key(53, down: true, flags: 0, active: false), .pass)
    }
    func testModifierReleaseOrdersAndMissedKeyupOwnership() {
        for flag in [Shortcut.control, Shortcut.option, 0] {
            var gesture = GestureMatcher()
            XCTAssertEqual(gesture.key(49, down: true, flags: Shortcut.standard.modifiers, active: false), .down)
            XCTAssertEqual(gesture.flags(flag), .up)
            XCTAssertEqual(gesture.flags(0), .pass)
            XCTAssertEqual(gesture.key(49, down: false, flags: 0, active: false), .consume)
        }
    }
    func testClipboardNewCopyNeverOwned() {
        XCTAssertTrue(ClipboardPolicy.owns(expectedCount: 2, actualCount: 2, expectedMarker: "a", actualMarker: "a", expectedText: "draft", actualText: "draft"))
        for count in [1,3,100] { XCTAssertFalse(ClipboardPolicy.owns(expectedCount: 2, actualCount: count, expectedMarker: "a", actualMarker: "a", expectedText: "draft", actualText: "draft")) }
        XCTAssertFalse(ClipboardPolicy.owns(expectedCount: 2, actualCount: 2, expectedMarker: "a", actualMarker: nil, expectedText: "draft", actualText: "draft"))
        XCTAssertFalse(ClipboardPolicy.owns(expectedCount: 2, actualCount: 2, expectedMarker: "a", actualMarker: "a", expectedText: "draft", actualText: "new"))
    }
    func testClipboardEmptyRichImageMultiItemAndBounds() throws {
        XCTAssertNoThrow(try ClipboardSnapshot(items: [], changeCount: 0))
        let items = [[ClipboardRepresentation(type: "public.utf8-plain-text", data: Data("é👩🏽‍💻".utf8)), ClipboardRepresentation(type: "public.rtf", data: Data([1,2]))], [ClipboardRepresentation(type: "public.png", data: Data([3,4]))]]
        let snapshot = try ClipboardSnapshot(items: items, changeCount: 8)
        XCTAssertEqual(snapshot.items, items)
        XCTAssertThrowsError(try ClipboardSnapshot(items: [[.init(type: "public.data", data: Data(count: 8*1024*1024+1))]], changeCount: 1))
        XCTAssertThrowsError(try ClipboardSnapshot(items: [[]], changeCount: 1))
        XCTAssertFalse(ClipboardPolicy.allowedType("com.apple.pasteboard.promised-file-url"))
        XCTAssertFalse(ClipboardPolicy.allowedType("custom.lazy"))
    }
    func testInvalidFloatAndBoundaryGate() {
        XCTAssertFalse(TranscriptPolicy.hasSpeechEnergy(Array(repeating: .nan, count: 8000)))
        XCTAssertFalse(TranscriptPolicy.hasSpeechEnergy(Array(repeating: .infinity, count: 8000)))
        XCTAssertFalse(TranscriptPolicy.hasSpeechEnergy(Array(repeating: 0.5, count: 3999)))
        XCTAssertTrue(TranscriptPolicy.hasSpeechEnergy(Array(repeating: 0.0011, count: 4000)))
    }
    func testNoReturnAndControlCodes() {
        let text = "echo hello\nrm -rf /\u{001b}[31m\t\u{0007}"
        let result = TranscriptPolicy.sanitize(text)
        XCTAssertFalse(result.unicodeScalars.contains { $0.properties.generalCategory == .control })
        XCTAssertEqual(result, "echo hello rm -rf /[31m")
    }
}
