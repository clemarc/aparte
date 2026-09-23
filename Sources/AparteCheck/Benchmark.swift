import Foundation
import CryptoKit
import Darwin
import AparteCore
import AparteSpeech

struct FixtureManifest: Decodable {
    struct Clip: Decodable {
        let id: String
        let language: String
        let reference: String
        let path: String
        let sha256: String
        let duration: Double
        let kind: String
        let split: String
        let warmGroup: Int?
        let technicalTerms: [String]
    }
    let clips: [Clip]
}
final class NetworkAudit: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    private static var attempts = 0
    static var count: Int { lock.lock(); defer { lock.unlock() }; return attempts }
    override class func canInit(with request: URLRequest) -> Bool {
        guard ["http","https"].contains(request.url?.scheme ?? "") else { return false }
        lock.lock(); attempts += 1; lock.unlock(); return true
    }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() { client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet)) }
    override func stopLoading() {}
}
func words(_ s: String) -> [String] {
    String(s.precomposedStringWithCanonicalMapping.lowercased().unicodeScalars.map { CharacterSet.alphanumerics.contains($0) || CharacterSet.nonBaseCharacters.contains($0) ? Character($0) : " " }).split(whereSeparator: \.isWhitespace).map(String.init)
}
func distance(_ a: [String], _ b: [String]) -> Int {
    var row = Array(0...b.count)
    for (i, x) in a.enumerated() {
        var next = [i+1] + Array(repeating: 0, count: b.count)
        for (j,y) in b.enumerated() { next[j+1] = min(next[j]+1, row[j+1]+1, row[j]+(x == y ? 0 : 1)) }
        row = next
    }
    return row[b.count]
}
func residentBytes() -> UInt64 {
    var info = mach_task_basic_info(); var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size)
    let status = withUnsafeMutablePointer(to: &info) { $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count) } }
    return status == KERN_SUCCESS ? info.resident_size : 0
}
func emit(_ record: [String: Any]) throws { print(String(data: try JSONSerialization.data(withJSONObject: record, options: [.sortedKeys]), encoding: .utf8)!); fflush(stdout) }

func benchmark(args: [String]) async throws {
    guard args.count == 5 else { throw AparteError.invalidAsset }
    let catalog = try ModelCatalog.load(URL(fileURLWithPath: args[1]))
    guard let model = catalog.models.first(where: { $0.id == args[4] }) else { throw AparteError.unavailableModel }
    let fixtures = try JSONDecoder().decode(FixtureManifest.self, from: Data(contentsOf: URL(fileURLWithPath: args[3])))
    guard fixtures.clips.filter({ $0.kind == "speech" && $0.language == "en" }).count >= 20,
          fixtures.clips.filter({ $0.kind == "speech" && $0.language == "fr" }).count >= 20,
          fixtures.clips.filter({ $0.kind == "noSpeech" }).count >= 10,
          fixtures.clips.filter({ $0.kind == "quiet" }).count >= 5 else { throw AparteError.invalidAsset }
    for clip in fixtures.clips {
        let data = try Data(contentsOf: URL(fileURLWithPath: clip.path))
        guard SHA256.hash(data: data).map({ String(format: "%02x", $0) }).joined() == clip.sha256 else { throw AparteError.invalidAsset }
    }
    URLProtocol.registerClass(NetworkAudit.self)
    let engine = Transcriber(); let start = Date()
    try await engine.load(directory: URL(fileURLWithPath: args[2]), manifest: model)
    try emit(["phase":"prepare", "model":model.id, "seconds":Date().timeIntervalSince(start), "residentBytes":residentBytes(), "installedBytes":model.installedBytes])
    let first = try AudioConversion.readFixture(URL(fileURLWithPath: fixtures.clips[0].path))
    _ = try await engine.transcribe(first)
    for clip in fixtures.clips {
        let audio = try AudioConversion.readFixture(URL(fileURLWithPath: clip.path))
        let result = try await engine.transcribe(audio) // Same default Auto policy as production.
        let reference = words(clip.reference), actual = words(result.text)
        let preserved = clip.technicalTerms.filter { words(result.text).joined(separator: " ").contains(words($0).joined(separator: " ")) }.count
        try emit(["phase":"quality", "model":model.id, "id":clip.id, "language":clip.language, "kind":clip.kind, "split":clip.split, "referenceWords":reference.count, "wordErrors":distance(reference,actual), "termCount":clip.technicalTerms.count, "termsPreserved":preserved, "noSpeech":result.noSpeech, "text":result.text, "seconds":result.seconds, "rms":sqrt(audio.reduce(0.0) { $0 + Double($1)*Double($1) } / Double(audio.count))])
    }
    for clip in fixtures.clips where clip.warmGroup != nil {
        let audio = try AudioConversion.readFixture(URL(fileURLWithPath: clip.path)); let result = try await engine.transcribe(audio)
        try emit(["phase":"warm", "model":model.id, "id":clip.id, "group":clip.warmGroup!, "audioSeconds":Double(audio.count)/16000, "decodeSeconds":result.seconds])
    }
    for i in 0..<100 {
        _ = try await engine.transcribe(first)
        try emit(["phase":"memory", "session":i+1, "residentBytes":residentBytes()])
    }
    let boundary = URL(fileURLWithPath: "artifacts/fixtures/boundary-59.wav")
    if FileManager.default.fileExists(atPath: boundary.path) {
        let result = try await engine.transcribe(AudioConversion.readFixture(boundary))
        try emit(["phase":"boundary59", "seconds":result.seconds, "completed":true])
    } else { try emit(["phase":"boundary59", "status":"BLOCKED", "reason":"Missing synthetic 59-second fixture"]) }
    var rejected60 = false
    do { _ = try await engine.transcribe(Array(repeating: 0.2, count: 960000)) }
    catch AparteError.invalidAudio { rejected60 = true }
    guard rejected60 else { throw AparteError.inference }
    try emit(["phase":"boundary60", "rejected":true])
    var usage = rusage(); getrusage(RUSAGE_SELF, &usage)
    try emit(["phase":"summary", "outboundURLRequests":NetworkAudit.count, "peakResidentBytes":usage.ru_maxrss])
    guard NetworkAudit.count == 0 else { throw AparteError.inference }
}
