import XCTest
@testable import AparteCore

final class AudioDiagnosticsTests: XCTestCase {
    func testDiagnosticsPreserveExistingEnergyGate() {
        // The new explanation must not silently lower or raise ASR eligibility.
        for count in [0, 1, 3_999, 4_000, 16_000] {
            for level: Float in [0, 0.0001, 0.00099, 0.001, 0.2, .nan, .infinity] {
                let samples = [Float](repeating: level, count: count)
                XCTAssertEqual(AudioDiagnostics(samples).problem == nil, TranscriptPolicy.hasSpeechEnergy(samples), "count=\(count), level=\(level)")
            }
        }
    }
    func testNoFramesSilenceQuietAndSpeechAreDistinguishable() {
        XCTAssertTrue(AudioDiagnostics([]).problem!.contains("No audio frames"))
        XCTAssertTrue(AudioDiagnostics([Float](repeating: 0, count: 16_000)).problem!.contains("silence"))
        XCTAssertTrue(AudioDiagnostics([Float](repeating: 0.0001, count: 16_000)).problem!.contains("too quiet"))
        let voiced = AudioDiagnostics([Float](repeating: 0.1, count: 32_000))
        XCTAssertNil(voiced.problem)
        XCTAssertEqual(voiced.seconds, 2)
        XCTAssertEqual(voiced.rms, 0.1, accuracy: 0.00001)
    }
}
