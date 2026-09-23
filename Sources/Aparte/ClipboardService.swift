import AppKit
import AparteCore

private final class SnapshotRace: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<ClipboardSnapshot, Error>?
    init(_ c: CheckedContinuation<ClipboardSnapshot, Error>) { continuation = c }
    func finish(_ result: Result<ClipboardSnapshot, Error>) {
        lock.lock(); let c = continuation; continuation = nil; lock.unlock(); c?.resume(with: result)
    }
}
@MainActor final class ClipboardService {
    static let markerType = NSPasteboard.PasteboardType("dev.aparte.transaction")
    private var snapshotTaskBusy = false
    private var pending: (snapshot: ClipboardSnapshot, count: Int, marker: String, text: String)?
    private var restoration: Task<Void, Never>?
    func snapshot() async throws -> ClipboardSnapshot {
        guard !snapshotTaskBusy else { throw AparteError.clipboardUnavailable }
        snapshotTaskBusy = true
        return try await withCheckedThrowingContinuation { continuation in
            let race = SnapshotRace(continuation)
            DispatchQueue.global(qos: .userInitiated).async {
                defer { Task { @MainActor in self.snapshotTaskBusy = false } }
                do {
                    let start = ContinuousClock.now
                    let board = NSPasteboard.general; let count = board.changeCount
                    var items: [[ClipboardRepresentation]] = []; var size = 0
                    for item in board.pasteboardItems ?? [] {
                        var reps: [ClipboardRepresentation] = []
                        for type in item.types {
                            guard ClipboardPolicy.allowedType(type.rawValue), start.duration(to: .now) < .milliseconds(500), let data = item.data(forType: type) else { throw AparteError.clipboardUnavailable }
                            size += data.count
                            guard size <= 8 * 1024 * 1024 else { throw AparteError.clipboardUnavailable }
                            reps.append(.init(type: type.rawValue, data: data))
                        }
                        items.append(reps)
                    }
                    guard board.changeCount == count, start.duration(to: .now) < .milliseconds(500) else { throw AparteError.clipboardUnavailable }
                    race.finish(.success(try ClipboardSnapshot(items: items, changeCount: count)))
                } catch { race.finish(.failure(AparteError.clipboardUnavailable)) }
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) { race.finish(.failure(AparteError.clipboardUnavailable)) }
        }
    }
    func write(_ text: String, snapshot: ClipboardSnapshot) throws {
        restore()
        let board = NSPasteboard.general
        guard board.changeCount == snapshot.changeCount else { throw AparteError.clipboardUnavailable }
        let marker = UUID().uuidString; let item = NSPasteboardItem()
        item.setString(text, forType: .string); item.setString(marker, forType: Self.markerType)
        board.clearContents()
        guard board.writeObjects([item]) else { throw AparteError.clipboardUnavailable }
        pending = (snapshot, board.changeCount, marker, text)
    }
    func dispatchPaste() -> Bool {
        guard owns(), CGPreflightPostEventAccess(), let source = CGEventSource(stateID: .privateState),
              let down = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) else { restore(); return false }
        for event in [down, up] { event.flags = .maskCommand; event.setIntegerValueField(.eventSourceUserData, value: HotkeyService.eventMarker); event.post(tap: .cghidEventTap) }
        restoration?.cancel()
        restoration = Task { try? await Task.sleep(for: .seconds(1)); guard !Task.isCancelled else { return }; self.restore() }
        return true
    }
    private func owns() -> Bool {
        guard let pending else { return false }; let board = NSPasteboard.general
        return ClipboardPolicy.owns(expectedCount: pending.count, actualCount: board.changeCount, expectedMarker: pending.marker, actualMarker: board.string(forType: Self.markerType), expectedText: pending.text, actualText: board.string(forType: .string))
    }
    func restore() {
        restoration?.cancel(); restoration = nil
        defer { pending = nil }
        guard let pending, owns() else { return }
        let items = pending.snapshot.items.map { reps -> NSPasteboardItem in
            let item = NSPasteboardItem(); for rep in reps { item.setData(rep.data, forType: .init(rep.type)) }; return item
        }
        let board = NSPasteboard.general
        // Recheck after constructing objects. The OS offers no atomic compare-and-swap.
        guard owns() else { return }
        board.clearContents(); if !items.isEmpty { board.writeObjects(items) }
    }
    func copyExplicit(_ text: String) {
        restore(); let board = NSPasteboard.general; board.clearContents(); board.setString(text, forType: .string)
    }
}
