import Foundation
import AparteCore
import AparteSpeech
import ApplicationServices
import AVFoundation

@main struct AparteCheck {
    static func main() async {
        do {
            let args = Array(CommandLine.arguments.dropFirst())
            if args.first == "permissions" {
                print("microphone=\(AVCaptureDevice.authorizationStatus(for: .audio).rawValue) accessibility=\(AXIsProcessTrusted()) listen=\(CGPreflightListenEventAccess()) post=\(CGPreflightPostEventAccess())")
                return
            }
            guard args.count >= 4, args[0] == "transcribe" else {
                fputs("Usage: aparte-check transcribe CATALOG MODEL_DIRECTORY FIXTURE [base|small] [auto|en|fr]\n", stderr); exit(64)
            }
            let catalog = try ModelCatalog.load(URL(fileURLWithPath: args[1]))
            let modelID = args.count > 4 ? args[4] : "base"
            guard let manifest = catalog.models.first(where: { $0.id == modelID }) else { throw AparteError.unavailableModel }
            let engine = Transcriber(); let start = Date()
            try await engine.load(directory: URL(fileURLWithPath: args[2]), manifest: manifest)
            let prepared = Date().timeIntervalSince(start)
            let audio = try AudioConversion.readFixture(URL(fileURLWithPath: args[3]))
            let result = try await engine.transcribe(audio, language: args.count > 5 ? args[5] : "auto")
            // Only this explicit fixture tool emits synthetic/public fixture output, never production logs.
            let payload: [String: Any] = ["model": modelID, "prepareSeconds": prepared, "audioSeconds": Double(audio.count)/16000, "decodeSeconds": result.seconds, "text": result.text, "noSpeech": result.noSpeech]
            print(String(data: try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]), encoding: .utf8)!)
        } catch {
            fputs("FAILED: \((error as? AparteError)?.rawValue ?? "fixture-or-model-error")\n", stderr); exit(1)
        }
    }
}
