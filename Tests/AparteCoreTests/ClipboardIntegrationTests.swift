import XCTest
import AppKit
@testable import AparteCore

/// Real NSPasteboard service against a private named board; never reads/writes the user's clipboard.
@MainActor final class ClipboardIntegrationTests: XCTestCase {
    private func board() -> NSPasteboard { NSPasteboard(name: .init("dev.aparte.tests." + UUID().uuidString)) }
    func testRealRichImageMultiItemRestoration() async throws {
        let board = board(); defer { board.releaseGlobally() }
        let process = Process(); let output = Pipe()
        process.executableURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("artifacts/lazy-clipboard-owner")
        process.arguments = [board.name.rawValue, "rich"]; process.standardOutput = output
        try process.run(); defer { if process.isRunning { process.terminate() } }
        XCTAssertEqual(String(data: output.fileHandleForReading.availableData, encoding: .utf8), "READY\n")
        let service = ClipboardService(boardName: board.name)
        let before = try await service.snapshot()
        XCTAssertEqual(before.items.count, 2)
        // AppKit also advertises legacy text encodings across processes. Preserve those too.
        XCTAssertTrue(Set([NSPasteboard.PasteboardType.string.rawValue, NSPasteboard.PasteboardType.rtf.rawValue]).isSubset(of: Set(before.items[0].map(\.type))))
        XCTAssertEqual(before.items[0].first { $0.type == NSPasteboard.PasteboardType.rtf.rawValue }?.data, Data("{\\rtf1 rich}".utf8))
        XCTAssertEqual(before.items[1].first { $0.type == NSPasteboard.PasteboardType.png.rawValue }?.data, Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="))
        XCTAssertEqual(before.items[0].first { $0.type == NSPasteboard.PasteboardType.string.rawValue }?.data, Data("original é👩🏽‍💻".utf8))
        process.terminate(); process.waitUntilExit()
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
    func testRecoveryKeepsTranscriptAfterAttemptedPasteWithoutRestoringOldClipboard() async throws {
        let board = board(); defer { board.releaseGlobally() }
        let service = ClipboardService(boardName: board.name)
        service.copyExplicit("old")
        try service.write("dictation", snapshot: await service.snapshot())
        XCTAssertTrue(service.copyRecovery("dictation"))
        service.restore()
        XCTAssertEqual(board.string(forType: .string), "dictation")
    }
    func testRecoveryDoesNotOverwriteNewerClipboardOwner() async throws {
        let board = board(); defer { board.releaseGlobally() }
        let service = ClipboardService(boardName: board.name)
        service.copyExplicit("old")
        try service.write("dictation", snapshot: await service.snapshot())
        board.clearContents(); board.setString("new user copy", forType: .string)
        XCTAssertFalse(service.copyRecovery("dictation"))
        XCTAssertEqual(board.string(forType: .string), "new user copy")
    }
    func testRealPromisedAndOversizedClipboardAborts() async throws {
        let board = board(); defer { board.releaseGlobally() }
        board.setData(Data([1]), forType: .init("com.apple.pasteboard.promised-file-url"))
        let service = ClipboardService(boardName: board.name)
        do { _ = try await service.snapshot(); XCTFail("promised type must refuse") } catch { XCTAssertEqual(error as? ClipboardFailure, .unsupportedType) }
        board.clearContents(); board.setData(Data(count: 8*1024*1024+1), forType: .init("public.data"))
        do { _ = try await service.snapshot(); XCTFail("oversized data must refuse") } catch { XCTAssertEqual(error as? ClipboardFailure, .tooLarge) }
        XCTAssertEqual(board.data(forType: .init("public.data"))?.count, 8*1024*1024+1)
    }
}

extension ClipboardIntegrationTests {
    func testNewLazyOwnerIsNotReadDuringRestoration() async throws {
        let board = board(); defer { board.releaseGlobally() }
        let service = ClipboardService(boardName: board.name)
        service.copyExplicit("original")
        try service.write("dictation", snapshot: await service.snapshot())
        let process = Process(); let output = Pipe()
        process.executableURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("artifacts/lazy-clipboard-owner")
        process.arguments = [board.name.rawValue]; process.standardOutput = output
        try process.run(); defer { if process.isRunning { process.terminate() } }
        XCTAssertEqual(String(data: output.fileHandleForReading.availableData, encoding: .utf8), "READY\n")
        let foreignCount = board.changeCount
        service.restore()
        XCTAssertEqual(board.changeCount, foreignCount)
        process.terminate(); process.waitUntilExit()
        let rest = output.fileHandleForReading.readDataToEndOfFile()
        XCTAssertFalse(String(data: rest, encoding: .utf8)!.contains("REQUESTED"), "restoration must not read a newer lazy owner's data")
    }

    func testActualFastLazyProviderMaterializesAndRestores() async throws {
        let name = "dev.aparte.tests." + UUID().uuidString
        let board = NSPasteboard(name: .init(name)); defer { board.releaseGlobally() }
        let process = Process(); let output = Pipe()
        process.executableURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("artifacts/lazy-clipboard-owner")
        process.arguments = [name]; process.standardOutput = output
        try process.run(); defer { if process.isRunning { process.terminate() } }
        let ready = output.fileHandleForReading.availableData
        XCTAssertEqual(String(data: ready, encoding: .utf8), "READY\n")
        let service = ClipboardService(boardName: board.name)
        let snapshot = try await service.snapshot()
        try service.write("dictation", snapshot: snapshot)
        service.restore()
        XCTAssertEqual(board.string(forType: .string), "synthetic lazy content")
        process.terminate(); process.waitUntilExit()
        let rest = output.fileHandleForReading.readDataToEndOfFile()
        XCTAssertTrue(String(data: rest, encoding: .utf8)!.contains("REQUESTED"), "D013 permits bounded materialization of ordinary data")
    }
}

extension ClipboardIntegrationTests {
    func testForeignNonemptyClipboardCanBePreserved() async throws {
        let board = NSPasteboard(name: .init("dev.aparte.tests." + UUID().uuidString)); defer { board.releaseGlobally() }
        board.setString("unproven external content", forType: .string)
        let count = board.changeCount
        let service = ClipboardService(boardName: board.name)
        let snapshot = try await service.snapshot()
        XCTAssertEqual(board.changeCount, count)
        try service.write("dictation", snapshot: snapshot)
        service.restore()
        XCTAssertEqual(board.string(forType: .string), "unproven external content")
    }
}


extension ClipboardIntegrationTests {
    func testSlowForeignProviderTimesOutWithoutLateMutation() async throws {
        let board = board(); defer { board.releaseGlobally() }
        let process = Process(); let output = Pipe()
        process.executableURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("artifacts/lazy-clipboard-owner")
        process.arguments = [board.name.rawValue, "1.5"]; process.standardOutput = output
        try process.run(); defer { if process.isRunning { process.terminate() } }
        XCTAssertEqual(String(data: output.fileHandleForReading.availableData, encoding: .utf8), "READY\n")
        let service = ClipboardService(boardName: board.name)
        let count = board.changeCount; let start = ContinuousClock.now
        do { _ = try await service.snapshot(); XCTFail("slow provider must time out") }
        catch { XCTAssertEqual(error as? ClipboardFailure, .timeout) }
        XCTAssertLessThan(start.duration(to: .now), .seconds(1.2))
        XCTAssertEqual(board.changeCount, count, "timeout must not write anything")
        do { _ = try await service.snapshot(); XCTFail("one worker only until native read unwinds") }
        catch { XCTAssertEqual(error as? ClipboardFailure, .busy) }
        board.clearContents(); board.setString("new user copy", forType: .string)
        try await Task.sleep(for: .seconds(1.8))
        XCTAssertEqual(board.string(forType: .string), "new user copy", "late snapshot completion must never write")
        let fresh = try await service.snapshot()
        XCTAssertEqual(fresh.items.flatMap { $0 }.first { $0.type == NSPasteboard.PasteboardType.string.rawValue }?.data, Data("new user copy".utf8))
    }
}
