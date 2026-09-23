import XCTest
import AppKit
@testable import AparteCore

/// Real NSPasteboard service against a private named board; never reads/writes the user's clipboard.
@MainActor final class ClipboardIntegrationTests: XCTestCase {
    private func board() -> NSPasteboard { NSPasteboard(name: .init("dev.aparte.tests." + UUID().uuidString)) }
    func testRealRichImageMultiItemRestoration() async throws {
        let board = board(); defer { board.releaseGlobally() }
        let text = NSPasteboardItem(); text.setString("original é👩🏽‍💻", forType: .string)
        text.setData(Data("{\\rtf1 rich}".utf8), forType: .rtf)
        let image = NSPasteboardItem(); image.setData(Data([137,80,78,71,1,2,3]), forType: .png)
        let service = ClipboardService(boardName: board.name)
        try service.replaceContentsExplicitly([[.init(type: NSPasteboard.PasteboardType.string.rawValue, data: Data("original é👩🏽‍💻".utf8)), .init(type: NSPasteboard.PasteboardType.rtf.rawValue, data: text.data(forType: .rtf)!)], [.init(type: NSPasteboard.PasteboardType.png.rawValue, data: image.data(forType: .png)!)]])
        let before = try await service.snapshot()
        try service.write("dictation", snapshot: before)
        XCTAssertEqual(board.string(forType: .string), "dictation")
        service.restore()
        let after = try await service.snapshot()
        XCTAssertEqual(after.items, before.items)
    }
    func testRealConcurrentCopyIsPreserved() async throws {
        let board = board(); defer { board.releaseGlobally() }
        let service = ClipboardService(boardName: board.name); service.copyExplicit("old")
        try service.write("dictation", snapshot: await service.snapshot())
        board.clearContents(); board.setString("new user copy", forType: .string)
        service.restore(); XCTAssertEqual(board.string(forType: .string), "new user copy")
    }
    func testRealEmptyRestorationAndExplicitCopy() async throws {
        let board = board(); defer { board.releaseGlobally() }
        board.clearContents(); let service = ClipboardService(boardName: board.name)
        let empty = try await service.snapshot(); XCTAssertTrue(empty.items.isEmpty)
        try service.write("dictation", snapshot: empty); service.restore()
        XCTAssertTrue((board.pasteboardItems ?? []).isEmpty)
        service.copyExplicit("explicit"); service.restore(); XCTAssertEqual(board.string(forType: .string), "explicit")
    }
    func testRealNewCopyBetweenSnapshotAndWriteAborts() async throws {
        let board = board(); defer { board.releaseGlobally() }
        let service = ClipboardService(boardName: board.name); service.copyExplicit("old")
        let old = try await service.snapshot()
        board.clearContents(); board.setString("new", forType: .string)
        XCTAssertThrowsError(try service.write("must not paste", snapshot: old))
        XCTAssertEqual(board.string(forType: .string), "new")
    }
    func testRealPromisedAndOversizedClipboardAborts() async throws {
        let board = board(); defer { board.releaseGlobally() }
        board.setData(Data([1]), forType: .init("com.apple.pasteboard.promised-file-url"))
        let service = ClipboardService(boardName: board.name)
        do { _ = try await service.snapshot(); XCTFail("promised type must refuse") } catch {}
        board.clearContents(); board.setData(Data(count: 8*1024*1024+1), forType: .init("public.data"))
        do { _ = try await service.snapshot(); XCTFail("oversized data must refuse") } catch {}
        XCTAssertEqual(board.data(forType: .init("public.data"))?.count, 8*1024*1024+1)
    }
}

extension ClipboardIntegrationTests {
    func testActualLazyProviderRefusedWithoutMaterializing() async throws {
        let name = "dev.aparte.tests." + UUID().uuidString
        let board = NSPasteboard(name: .init(name)); defer { board.releaseGlobally() }
        let process = Process(); let output = Pipe()
        process.executableURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("artifacts/lazy-clipboard-owner")
        process.arguments = [name]; process.standardOutput = output
        try process.run(); defer { process.terminate() }
        let ready = output.fileHandleForReading.availableData
        XCTAssertEqual(String(data: ready, encoding: .utf8), "READY\n")
        let service = ClipboardService(boardName: board.name)
        do { _ = try await service.snapshot(); XCTFail("lazy provider must be rejected") } catch {}
        process.terminate(); process.waitUntilExit()
        let rest = output.fileHandleForReading.readDataToEndOfFile()
        XCTAssertFalse(String(data: rest, encoding: .utf8)!.contains("REQUESTED"), "snapshot must not materialize a foreign promise")
    }
}

extension ClipboardIntegrationTests {
    func testUnprovenNonemptyClipboardRefusesWithoutMutation() async throws {
        let board = NSPasteboard(name: .init("dev.aparte.tests." + UUID().uuidString)); defer { board.releaseGlobally() }
        board.setString("unproven external content", forType: .string)
        let count = board.changeCount
        do { _ = try await ClipboardService(boardName: board.name).snapshot(); XCTFail("unknown eager/lazy provenance must refuse") } catch {}
        XCTAssertEqual(board.changeCount, count)
        XCTAssertEqual(board.string(forType: .string), "unproven external content")
    }
}
