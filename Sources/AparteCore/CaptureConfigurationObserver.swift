import AVFoundation
import Foundation

/// One capture's configuration notifications. Teardown must happen outside the
/// notification callback: AVAudioEngine delivers it on an internal queue.
public final class CaptureConfigurationObserver: @unchecked Sendable {
    private let center: NotificationCenter
    private let lock = NSLock()
    private var active = true
    private var observer: NSObjectProtocol?
    private let onChange: @Sendable () -> Void

    public init(engine: AVAudioEngine, center: NotificationCenter = .default,
                onChange: @escaping @Sendable () -> Void) {
        self.center = center
        self.onChange = onChange
        observer = center.addObserver(forName: .AVAudioEngineConfigurationChange,
                                      object: engine, queue: nil) { [weak self] _ in
            self?.changed()
        }
    }

    private func changed() {
        lock.lock()
        let notify = active
        active = false
        lock.unlock()
        if notify { onChange() }
    }

    public func invalidate() {
        lock.lock()
        active = false
        let old = observer
        observer = nil
        lock.unlock()
        if let old { center.removeObserver(old) }
    }

    deinit { invalidate() }
}
