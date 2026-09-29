import Foundation
import WhisperKit
import AparteCore

/// Local-only tokenizer adapter. Never calls the upstream Hub fallback.
private final class LocalTokenizer: WhisperTokenizer {
    let underlying: TokenizerWrapper
    let specialTokens: SpecialTokens
    let allLanguageTokens: Set<Int>
    init(folder: URL) async throws {
        let local = try await AutoTokenizerWrapper.from(modelFolder: folder, hubApi: HubApiWrapper(downloadBase: folder, hfToken: "", endpoint: "https://huggingface.co"))
        underlying = local
        func token(_ s: String) throws -> Int { guard let id = local.convertTokenToId(s) else { throw AparteError.invalidAsset }; return id }
        specialTokens = try SpecialTokens(endToken: token("<|endoftext|>"), englishToken: token("<|en|>"), noSpeechToken: token("<|nospeech|>"), noTimestampsToken: token("<|notimestamps|>"), specialTokenBegin: token("<|endoftext|>"), startOfPreviousToken: token("<|startofprev|>"), startOfTranscriptToken: token("<|startoftranscript|>"), timeTokenBegin: token("<|0.00|>"), transcribeToken: token("<|transcribe|>"), translateToken: token("<|translate|>"), whitespaceToken: local.encode(text: " ").first ?? 220)
        allLanguageTokens = Set(Constants.languages.values.compactMap { local.convertTokenToId("<|\($0)|>") })
    }
    func encode(text: String) -> [Int] { underlying.encode(text: text) }
    func decode(tokens: [Int]) -> String { underlying.decode(tokens: tokens) }
    func convertTokenToId(_ token: String) -> Int? { underlying.convertTokenToId(token) }
    func convertIdToToken(_ id: Int) -> String? { underlying.convertIdToToken(id) }
    // Word timestamps are disabled in Aparté; grouping preserves every token if queried.
    func splitToWordTokens(tokenIds: [Int]) -> (words: [String], wordTokens: [[Int]]) { ([decode(tokens: tokenIds)], [tokenIds]) }
}
private final class LocalWhisperKit: WhisperKit {
    override func loadTokenizerIfNeeded() async throws {
        guard tokenizer == nil else { return }
        guard let folder = tokenizerFolder else { throw AparteError.unavailableModel }
        guard let logits = textDecoder.logitsSize, [51864, 51865, 51866].contains(logits) else { throw AparteError.invalidAsset }
        textDecoder.isModelMultilingual = logits != 51864
        tokenizer = try await LocalTokenizer(folder: folder)
    }
}

public struct SpeechResult: Sendable {
    public let text: String
    public let seconds: Double
    public let noSpeech: Bool
}

/// One owner. A busy lease remains held across all suspension points and cancellation.
public actor Transcriber {
    private var engine: LocalWhisperKit?
    private var busy = false
    private var selected: (URL, ModelManifest)?
    public var activeModelID: String? { selected?.1.id }
    public init() {}
    public func load(directory: URL, manifest: ModelManifest) async throws {
        guard !busy else { throw AparteError.busy }; busy = true; defer { busy = false }
        // Verify before unloading the working model; corrupt switches leave it usable.
        try manifest.verify(directory: directory)
        let previous = selected
        if let engine { await engine.unloadModels() }; engine = nil; selected = nil
        do {
            engine = try await makeEngine(directory: directory)
            try Task.checkCancellation(); selected = (directory, manifest)
        } catch {
            if let engine { await engine.unloadModels() }; engine = nil
            if let (oldDirectory, oldManifest) = previous, !Task.isCancelled {
                engine = try? await makeEngine(directory: oldDirectory)
                if engine != nil { selected = (oldDirectory, oldManifest) }
            }
            throw error
        }
    }
    private func makeEngine(directory: URL) async throws -> LocalWhisperKit {
        Logging.updateLogLevel(.none); Logging.updateCallback(nil)
        let configuration = WhisperKitConfig(modelFolder: directory.path, tokenizerFolder: directory, verbose: false, logLevel: .none, prewarm: true, load: true, download: false)
        return try await LocalWhisperKit(configuration)
    }
    public func unload() async throws {
        guard !busy else { throw AparteError.busy }; busy = true; defer { busy = false }
        if let engine { await engine.unloadModels() }; engine = nil; selected = nil
    }
    public func transcribe(_ samples: [Float], language: String = "auto") async throws -> SpeechResult {
        guard !busy else { throw AparteError.busy }; guard let engine else { throw AparteError.unavailableModel }
        guard samples.count < 960_000 else { throw AparteError.invalidAudio }
        guard TranscriptPolicy.hasSpeechEnergy(samples) else { return SpeechResult(text: "", seconds: 0, noSpeech: true) }
        busy = true; defer { busy = false }
        let started = ContinuousClock.now
        guard let model = selected?.1.id, SpeechLanguages.supports(language, model: model) else { throw AparteError.unsupportedLanguage }
        let englishOnly = model.hasSuffix(".en")
        if language != "auto" && !englishOnly {
            guard let token = engine.tokenizer?.convertTokenToId("<|\(language)|>"), token < (engine.textDecoder.logitsSize ?? 0) else { throw AparteError.unsupportedLanguage }
        }
        let options = DecodingOptions(verbose: false, task: .transcribe, language: englishOnly ? "en" : (language == "auto" ? nil : language), temperatureFallbackCount: 2, detectLanguage: !englishOnly && language == "auto", skipSpecialTokens: true, withoutTimestamps: true, wordTimestamps: false, suppressBlank: true, compressionRatioThreshold: 2.4, logProbThreshold: -1, noSpeechThreshold: 0.6, concurrentWorkerCount: 1)
        let results = try await engine.transcribe(audioArray: samples, decodeOptions: options, callback: { _ in
            if Task.isCancelled || started.duration(to: .now) > .seconds(30) { return false }; return nil
        })
        try Task.checkCancellation()
        let seconds = Double(started.duration(to: .now).components.seconds) + Double(started.duration(to: .now).components.attoseconds) / 1e18
        guard seconds <= 30 else { throw AparteError.timeout }
        let segments = results.flatMap(\.segments)
        let silent = !segments.isEmpty && segments.allSatisfy { $0.noSpeechProb > 0.6 && $0.avgLogprob < -1 }
        let text = TranscriptPolicy.sanitize(results.map(\.text).joined(separator: " "))
        let rejected = silent || text.isEmpty || TranscriptPolicy.isRepetitive(text) || segments.contains { $0.compressionRatio > 2.4 }
        return SpeechResult(text: rejected ? "" : text, seconds: seconds, noSpeech: rejected)
    }
}
