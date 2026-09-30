import XCTest
import CryptoKit
@testable import AparteCore
final class ModelStoreTests: XCTestCase {
    func fixture(id: String = "base") throws -> (URL, URL, ModelManifest) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let source = root.appendingPathComponent("source")
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        let files = try ["tokenizer.json","tokenizer_config.json","AudioEncoder.mlmodelc/weights/weight.bin"].map { name -> AssetFile in
            let url = source.appendingPathComponent(name); try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = Data("synthetic test \(name)".utf8); try data.write(to: url)
            return .init(path: name, url: URL(string: "https://huggingface.co/test/resolve/" + String(repeating: "a", count: 40) + "/" + name)!, bytes: Int64(data.count), sha256: SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined())
        }
        return (root, source, .init(id: id, displayName: "Synthetic test", revision: String(repeating: "a", count: 40), tokenizerRevision: String(repeating: "b", count: 40), license: "test", files: files))
    }
    func testRealAtomicImportReplacementAndDeletion() async throws {
        let (root, source, manifest) = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let store = ModelStore(root: root.appendingPathComponent("models"))
        try await store.install(manifest, importing: source) { _ in }
        let installed = root.appendingPathComponent("models/base")
        try manifest.verify(directory: installed)
        try await store.install(manifest, importing: source) { _ in }; try manifest.verify(directory: installed)
        let children = try FileManager.default.contentsOfDirectory(atPath: root.appendingPathComponent("models").path)
        XCTAssertEqual(children, ["base"])
        try await store.delete("base"); XCTAssertFalse(FileManager.default.fileExists(atPath: installed.path))
    }
    func testEnglishOnlyModelCanBeDeleted() async throws {
        let (root, source, manifest) = try fixture(id: "base.en")
        defer { try? FileManager.default.removeItem(at: root) }
        let store = ModelStore(root: root.appendingPathComponent("models"))
        try await store.install(manifest, importing: source) { _ in }
        let installed = root.appendingPathComponent("models/base.en")
        try manifest.verify(directory: installed)
        try await store.delete("base.en")
        XCTAssertFalse(FileManager.default.fileExists(atPath: installed.path))
    }
    func testCorruptImportPreservesExistingInstallation() async throws {
        let (root, source, manifest) = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let store = ModelStore(root: root.appendingPathComponent("models"))
        try await store.install(manifest, importing: source) { _ in }
        try Data("corrupt".utf8).write(to: source.appendingPathComponent("tokenizer.json"))
        do { try await store.install(manifest, importing: source) { _ in }; XCTFail("must reject corrupt import") } catch {}
        try manifest.verify(directory: root.appendingPathComponent("models/base"))
    }
    func testCancelledImportAndStagingCleanup() async throws {
        let (root, source, manifest) = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let store = ModelStore(root: root.appendingPathComponent("models"))
        let task = Task { try Task.checkCancellation(); try await store.install(manifest, importing: source) { _ in } }; task.cancel()
        do { try await task.value; XCTFail("cancelled task cannot install") } catch {}
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("models/base").path))
        let partial = root.appendingPathComponent("models/.partial-test")
        try FileManager.default.createDirectory(at: partial, withIntermediateDirectories: true)
        try await store.cleanInterruptedStages(); XCTAssertFalse(FileManager.default.fileExists(atPath: partial.path))
    }
    func testSymlinkAndSameSizeCorruptionRejected() throws {
        let (root, source, manifest) = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let url = source.appendingPathComponent("tokenizer.json")
        let original = try Data(contentsOf: url)
        try Data(repeating: 65, count: original.count).write(to: url)
        XCTAssertThrowsError(try manifest.verify(directory: source))
        try original.write(to: root.appendingPathComponent("outside")); try FileManager.default.removeItem(at: url)
        try FileManager.default.createSymbolicLink(at: url, withDestinationURL: root.appendingPathComponent("outside"))
        XCTAssertThrowsError(try manifest.verify(directory: source))
    }
    func testInsufficientDiskFailsBeforeTouchingInstall() async throws {
        let (root, _, base) = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let files = base.files.map { AssetFile(path: $0.path, url: $0.url, bytes: 2_000_000_000_000, sha256: $0.sha256) }
        let huge = ModelManifest(id: base.id, displayName: base.displayName, revision: base.revision, tokenizerRevision: base.tokenizerRevision, license: base.license, files: files)
        do { try await ModelStore(root: root.appendingPathComponent("models")).install(huge) { _ in }; XCTFail("disk budget must refuse") }
        catch { XCTAssertEqual(error as? AparteError, .insufficientSpace) }
    }
}
