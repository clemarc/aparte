import Foundation

/// Transient summary of the converted capture. No audio is retained here.
public struct AudioDiagnostics {
    public let seconds: Double
    public let rms: Double
    public let finite: Bool
    public init(_ samples: [Float]) {
        seconds = Double(samples.count) / 16_000
        finite = samples.allSatisfy(\.isFinite)
        rms = !samples.isEmpty && finite ? sqrt(samples.reduce(0.0) { $0 + Double($1) * Double($1) } / Double(samples.count)) : 0
    }
    public var problem: String? {
        if seconds == 0 { return "No audio frames arrived from the input device. Check Sound → Input and try again." }
        if !finite { return "The input device supplied invalid audio. Check Sound → Input and try again." }
        if seconds < 0.25 { return "Recording was too short. Speak for at least a second before stopping." }
        if rms == 0 { return "The input device delivered silence. Check its mute, input volume and Sound → Input selection." }
        if rms < 0.001 { return "Audio arrived but was too quiet to transcribe. Check input volume or move closer to the microphone." }
        return nil
    }
    public var summary: String {
        let level = rms > 0 ? String(format: "%.0f dBFS", 20 * log10(rms)) : "silent"
        return String(format: "Captured %.1f s · %@", seconds, level)
    }
}
