import Foundation
import AparteCore
import AparteSpeech

func modelCommand(args: [String]) async throws {
    guard args.count >= 4 else { throw AparteError.invalidAsset }
    let catalog = try ModelCatalog.load(URL(fileURLWithPath: args[1]))
    guard let model = catalog.models.first(where: { $0.id == args[3] }) else { throw AparteError.unavailableModel }
    let root = URL(fileURLWithPath: args[2]); let store = ModelStore(root: root)
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
    try await engine.load(directory: root.appendingPathComponent(model.id), manifest: model)
    try await engine.unload()
    try await store.delete(other.id)
    try emit(["phase":"model-lifecycle", "verifiedImport":true, "missingTokenizerRefused":true, "workingEnginePreserved":true, "realSwitchBackAndForth":true, "inactiveDeletion":true, "outboundURLRequests":NetworkAudit.count])
}
