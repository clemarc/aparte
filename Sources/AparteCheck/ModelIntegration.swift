import Foundation
import CryptoKit
import AparteCore
import AparteSpeech

func modelCommand(args: [String]) async throws {
    guard args.count >= 4 else { throw AparteError.invalidAsset }
    let catalog = try ModelCatalog.load(URL(fileURLWithPath: args[1]))
    guard let model = catalog.models.first(where: { $0.id == args[3] }) else { throw AparteError.unavailableModel }
    let root = URL(fileURLWithPath: args[2]); let store = ModelStore(root: root)
    if args[0] == "cancel-install" {
        try model.verify(directory: root.appendingPathComponent(model.id))
        let task = Task { try await store.install(model) { _ in } }
        try await Task.sleep(for: .milliseconds(100)); task.cancel()
        var cancelled = false
        do { try await task.value } catch { cancelled = error is CancellationError || (error as? URLError)?.code == .cancelled }
        guard cancelled else { throw AparteError.inference }
        try model.verify(directory: root.appendingPathComponent(model.id))
        let names = try FileManager.default.contentsOfDirectory(atPath: root.path)
        guard !names.contains(where: { $0.hasPrefix(".partial-") }) else { throw AparteError.invalidAsset }
        try emit(["phase":"cancel-download", "cancelled":true, "previousInstallPreserved":true, "partialRemoved":true]); return
    }
    if args[0] == "install" {
        try await store.install(model, importing: args.count > 4 ? URL(fileURLWithPath: args[4]) : nil) { _ in }
        try emit(["phase":"install", "model":model.id, "verified":true, "bytes":model.installedBytes]); return
    }
    guard args[0] == "model-lifecycle", args.count == 6, let other = catalog.models.first(where: { $0.id != model.id }) else { throw AparteError.invalidAsset }
    let sourceRoot = URL(fileURLWithPath: args[4]); let fixture = try AudioConversion.readFixture(URL(fileURLWithPath: args[5]))
    try await store.install(model, importing: sourceRoot.appendingPathComponent(model.id)) { _ in }
    let engine = Transcriber()
    try await engine.load(directory: root.appendingPathComponent(model.id), manifest: model)
    let first = try await engine.transcribe(fixture); guard !first.text.isEmpty else { throw AparteError.inference }
    // Reject missing tokenizer locally without falling through to any remote source.
    let tokenizer = root.appendingPathComponent(model.id + "/tokenizer.json")
    let saved = root.appendingPathComponent("tokenizer.saved")
    try FileManager.default.moveItem(at: tokenizer, to: saved)
    var rejected = false
    do { try await engine.load(directory: root.appendingPathComponent(model.id), manifest: model) } catch { rejected = true }
    try FileManager.default.moveItem(at: saved, to: tokenizer)
    guard rejected, await engine.activeModelID == model.id else { throw AparteError.inference }
    let preserved = try await engine.transcribe(fixture); guard preserved.text == first.text else { throw AparteError.inference }
    try await store.install(other, importing: sourceRoot.appendingPathComponent(other.id)) { _ in }
    try await engine.load(directory: root.appendingPathComponent(other.id), manifest: other)
    guard await engine.activeModelID == other.id, !(try await engine.transcribe(fixture)).text.isEmpty else { throw AparteError.inference }
    // Deliberately invalid Core ML fixture with its own test-only hash manifest:
    // forces a real loader error AFTER integrity checks, exercising actual rollback.
    let broken = root.appendingPathComponent("broken-coreml-fixture")
    if FileManager.default.fileExists(atPath: broken.path) { try FileManager.default.removeItem(at: broken) }
    try FileManager.default.copyItem(at: root.appendingPathComponent(model.id), to: broken)
    defer { try? FileManager.default.removeItem(at: broken) }
    let relative = "MelSpectrogram.mlmodelc/model.mil"
    let invalid = Data("deliberately invalid synthetic Core ML test fixture".utf8)
    try invalid.write(to: broken.appendingPathComponent(relative))
    var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(model)) as! [String: Any]
    var files = json["files"] as! [[String: Any]]
    guard let index = files.firstIndex(where: { $0["path"] as? String == relative }) else { throw AparteError.invalidAsset }
    files[index]["bytes"] = invalid.count
    files[index]["sha256"] = SHA256.hash(data: invalid).map { String(format: "%02x", $0) }.joined()
    json["files"] = files
    let invalidManifest = try JSONDecoder().decode(ModelManifest.self, from: JSONSerialization.data(withJSONObject: json))
    var loadFailed = false
    do { try await engine.load(directory: broken, manifest: invalidManifest) } catch { loadFailed = true }
    guard loadFailed, await engine.activeModelID == other.id, !(try await engine.transcribe(fixture)).text.isEmpty else { throw AparteError.inference }
    try await engine.load(directory: root.appendingPathComponent(model.id), manifest: model)
    let long = try AudioConversion.readFixture(URL(fileURLWithPath: "artifacts/fixtures/boundary-59.wav"))
    let decoding = Task { try await engine.transcribe(long) }
    try await Task.sleep(for: .milliseconds(10)); decoding.cancel()
    var cancelledDecode = false
    do { _ = try await decoding.value } catch is CancellationError { cancelledDecode = true }
    guard cancelledDecode, !(try await engine.transcribe(fixture)).text.isEmpty else { throw AparteError.inference }
    try await engine.unload()
    try await store.delete(other.id)
    try emit(["phase":"model-lifecycle", "verifiedImport":true, "missingTokenizerRefused":true, "workingEnginePreserved":true, "realSwitchBackAndForth":true, "inactiveDeletion":true, "realInferenceCancellationAndRetry":true, "coreMLLoadFailureRollback":true, "outboundURLRequests":NetworkAudit.count])
}
