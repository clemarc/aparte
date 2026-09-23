import AVFoundation

public enum AudioConversion {
    /// Uses the input-block overload, which performs real sample-rate conversion.
    public static func mono16k(_ input: AVAudioPCMBuffer) throws -> [Float] {
        guard input.format.sampleRate > 0, input.format.channelCount > 0,
              let outputFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16_000, channels: 1, interleaved: false),
              let converter = AVAudioConverter(from: input.format, to: outputFormat) else { throw AparteError.invalidAudio }
        converter.downmix = true
        let capacity = AVAudioFrameCount(ceil(Double(input.frameLength) * 16_000 / input.format.sampleRate) + 64)
        guard let output = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: capacity) else { throw AparteError.invalidAudio }
        var supplied = false
        var error: NSError?
        let status = converter.convert(to: output, error: &error) { _, state in
            if supplied { state.pointee = .endOfStream; return nil }
            supplied = true; state.pointee = .haveData; return input
        }
        guard status != .error, error == nil, let data = output.floatChannelData else { throw AparteError.invalidAudio }
        return Array(UnsafeBufferPointer(start: data[0], count: Int(output.frameLength)))
    }
    public static func readFixture(_ url: URL) throws -> [Float] {
        let file = try AVAudioFile(forReading: url)
        guard file.length > 0, Double(file.length) / file.processingFormat.sampleRate <= 60.1,
              let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)) else { throw AparteError.invalidAudio }
        try file.read(into: buffer); return try mono16k(buffer)
    }
}
