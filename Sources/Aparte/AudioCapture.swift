import AVFoundation
import AparteCore
import Accelerate
import CoreAudio

final class CaptureTicket: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false
    func cancel() { lock.lock(); cancelled = true; lock.unlock() }
    var isCancelled: Bool { lock.lock(); defer { lock.unlock() }; return cancelled }
}

/// All engine lifecycle operations run on one queue; the tap only copies to a preallocated buffer.
final class AudioCapture: @unchecked Sendable {
    private let queue = DispatchQueue(label: "dev.aparte.audio", qos: .userInitiated)
    private var engine: AVAudioEngine?
    private var configurationObserver: CaptureConfigurationObserver?
    private var storage: AVAudioPCMBuffer?
    private let lock = NSLock()
    private var frames = 0
    private var first = false
    private var reachedLimit = false
    private var ticket: CaptureTicket?
    private var inputName = "System default input"
    private var sampleRate = 0.0
    private var level: Float = 0
    var limitReached: Bool { lock.lock(); defer { lock.unlock() }; return reachedLimit }
    var status: (name: String, seconds: Double, level: Double) {
        lock.lock(); defer { lock.unlock() }
        return (inputName, sampleRate > 0 ? Double(frames) / sampleRate : 0,
                level > 0 ? max(0, min(1, (20 * log10(Double(level)) + 60) / 60)) : 0)
    }

    func start(ticket: CaptureTicket, onConfigurationChange: @escaping @Sendable () -> Void,
               onLive: @escaping @Sendable () -> Void) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                do {
                    guard !ticket.isCancelled else { throw AparteError.cancelled }
                    let engine = AVAudioEngine()
                    let input = engine.inputNode
                    let format = input.outputFormat(forBus: 0)
                    guard format.sampleRate > 0, format.sampleRate <= 192_000, format.channelCount > 0, format.channelCount <= 8,
                          format.commonFormat == .pcmFormatFloat32, !format.isInterleaved,
                          let storage = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(format.sampleRate * 60)) else { throw AparteError.unavailableDevice }
                    let name = Self.deviceName(input)
                    self.lock.lock(); self.frames = 0; self.first = false; self.reachedLimit = false
                    self.inputName = name; self.sampleRate = format.sampleRate; self.level = 0; self.lock.unlock()
                    self.storage = storage; self.engine = engine; self.ticket = ticket
                    self.configurationObserver = CaptureConfigurationObserver(engine: engine, onChange: onConfigurationChange)
                    input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
                        guard let self, !ticket.isCancelled, let source = buffer.floatChannelData, let dest = storage.floatChannelData else { return }
                        self.lock.lock()
                        let count = min(Int(buffer.frameLength), Int(storage.frameCapacity) - self.frames)
                        if count > 0 {
                            var peak: Float = 0
                            for channel in 0..<Int(format.channelCount) {
                                dest[channel].advanced(by: self.frames).update(from: source[channel], count: count)
                                var channelPeak: Float = 0
                                vDSP_maxmgv(source[channel], 1, &channelPeak, vDSP_Length(count))
                                if channelPeak.isFinite { peak = max(peak, channelPeak) }
                            }
                            self.level = peak
                            self.frames += count
                        }
                        self.reachedLimit = self.frames >= Int(storage.frameCapacity)
                        let notify = !self.first && count > 0
                        self.first = self.first || notify
                        self.lock.unlock()
                        if notify { onLive() }
                    }
                    guard !ticket.isCancelled else { self.teardown(); throw AparteError.cancelled }
                    engine.prepare(); try engine.start()
                    if ticket.isCancelled { self.teardown(); throw AparteError.cancelled }
                    continuation.resume()
                } catch { self.teardown(); continuation.resume(throwing: error) }
            }
        }
    }
    func stop(discard: Bool) async throws -> [Float] {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                self.configurationObserver?.invalidate(); self.configurationObserver = nil
                self.engine?.inputNode.removeTap(onBus: 0); self.engine?.stop(); self.engine = nil
                let storage = self.storage
                self.lock.lock(); let count = self.frames; let limit = self.reachedLimit; self.frames = 0; self.lock.unlock()
                self.storage = nil; self.ticket = nil
                guard !discard, !limit, let storage, count > 0 else { continuation.resume(returning: []); return }
                storage.frameLength = AVAudioFrameCount(count)
                do { continuation.resume(returning: try AudioConversion.mono16k(storage)) }
                catch { continuation.resume(throwing: error) }
            }
        }
    }
    private func teardown() {
        configurationObserver?.invalidate(); configurationObserver = nil
        engine?.inputNode.removeTap(onBus: 0); engine?.stop(); engine = nil; storage = nil; ticket = nil
    }
    private static func deviceName(_ input: AVAudioInputNode) -> String {
        guard let unit = input.audioUnit else { return "System default input" }
        var device = AudioDeviceID(0); var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        guard AudioUnitGetProperty(unit, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, 0, &device, &size) == noErr else { return "System default input" }
        var address = AudioObjectPropertyAddress(mSelector: kAudioObjectPropertyName, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var name: Unmanaged<CFString>?; size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &name) == noErr else { return "System default input" }
        return name?.takeRetainedValue() as String? ?? "System default input"
    }
}
