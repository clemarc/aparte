import AVFoundation
import XCTest
@testable import AparteCore

final class CaptureConfigurationTests: XCTestCase {
    private final class Changes: @unchecked Sendable {
        private let lock = NSLock()
        private var value = 0
        func record() { lock.lock(); value += 1; lock.unlock() }
        var count: Int { lock.lock(); defer { lock.unlock() }; return value }
    }

    func testOnlyCurrentCaptureEngineNotifiesAndOnlyOnce() {
        let center = NotificationCenter()
        let current = AVAudioEngine(), unrelated = AVAudioEngine()
        let changes = Changes()
        let observer = CaptureConfigurationObserver(engine: current, center: center) { changes.record() }
        defer { observer.invalidate() }
        center.post(name: .AVAudioEngineConfigurationChange, object: unrelated)
        center.post(name: .AVAudioEngineConfigurationChange, object: nil)
        XCTAssertEqual(changes.count, 0)
        center.post(name: .AVAudioEngineConfigurationChange, object: current)
        center.post(name: .AVAudioEngineConfigurationChange, object: current)
        XCTAssertEqual(changes.count, 1)
    }

    func testStoppedEngineCannotInterruptNextCapture() {
        let center = NotificationCenter()
        let old = AVAudioEngine(), next = AVAudioEngine()
        let changes = Changes()
        var observer: CaptureConfigurationObserver? = CaptureConfigurationObserver(engine: old, center: center) { changes.record() }
        observer?.invalidate()
        center.post(name: .AVAudioEngineConfigurationChange, object: old)
        XCTAssertEqual(changes.count, 0)
        observer = nil
        let nextObserver = CaptureConfigurationObserver(engine: next, center: center) { changes.record() }
        defer { nextObserver.invalidate() }
        center.post(name: .AVAudioEngineConfigurationChange, object: old)
        XCTAssertEqual(changes.count, 0)
        center.post(name: .AVAudioEngineConfigurationChange, object: next)
        XCTAssertEqual(changes.count, 1)
    }

    func testDelayedChangeCannotCancelFrozenAudioOrNewSession() {
        var machine = SessionMachine()
        machine.prepared(true)
        let old = machine.begin()!
        XCTAssertTrue(machine.isCapturing(old), "Route changes must still cancel startup")
        XCTAssertTrue(machine.started(old))
        XCTAssertTrue(machine.isCapturing(old), "Route changes must still cancel recording")
        XCTAssertTrue(machine.release(old))
        XCTAssertFalse(machine.isCapturing(old), "Frozen audio must survive a delayed notification")
        XCTAssertTrue(machine.decoded(old))
        XCTAssertFalse(machine.isCapturing(old), "Insertion must not be interrupted by capture teardown")
        machine.finish(old)
        let next = machine.begin()!
        XCTAssertFalse(machine.isCapturing(old), "An old callback must not cancel a rapid next hold")
        XCTAssertTrue(machine.isCapturing(next))
        machine.cancel()
        XCTAssertFalse(machine.isCapturing(next))
    }
}
