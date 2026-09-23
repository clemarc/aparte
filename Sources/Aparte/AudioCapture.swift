import AVFoundation
import AparteCore

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
    private var storage: AVAudioPCMBuffer?
    private let lock = NSLock()
    private var frames = 0
    private var first = false
    private var reachedLimit = false
    private var ticket: CaptureTicket?
    var limitReached: Bool { lock.lock(); defer { lock.unlock() }; return reachedLimit }

    func start(ticket: CaptureTicket, onLive: @escaping @Sendable () -> Void) async throws {
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
                    self.lock.lock(); self.frames = 0; self.first = false; self.reachedLimit = false; self.lock.unlock()
                    self.storage = storage; self.engine = engine; self.ticket = ticket
                    input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
                        guard let self, !ticket.isCancelled, let source = buffer.floatChannelData, let dest = storage.floatChannelData else { return }
                        self.lock.lock()
                        let count = min(Int(buffer.frameLength), Int(storage.frameCapacity) - self.frames)
                        if count > 0 {
                            for channel in 0..<Int(format.channelCount) {
                                dest[channel].advanced(by: self.frames).update(from: source[channel], count: count)
                            }
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
        engine?.inputNode.removeTap(onBus: 0); engine?.stop(); engine = nil; storage = nil; ticket = nil
    }
}
