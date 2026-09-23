import AppKit
import ApplicationServices

private final class SnapshotRace: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<ClipboardSnapshot, Error>?
    init(_ c: CheckedContinuation<ClipboardSnapshot, Error>) { continuation = c }
    public func finish(_ result: Result<ClipboardSnapshot, Error>) {
        lock.lock(); let c = continuation; continuation = nil; lock.unlock(); c?.resume(with: result)
    }
}
@MainActor public final class ClipboardService {
    public static let markerType = NSPasteboard.PasteboardType("dev.aparte.transaction")
    private let boardName: NSPasteboard.Name
    public init(boardName: NSPasteboard.Name = .general) { self.boardName = boardName }
    private var snapshotTaskBusy = false
    private var provenEagerChangeCount: Int?
    private var pending: (snapshot: ClipboardSnapshot, count: Int, marker: String, text: String)?
    private var restoration: Task<Void, Never>?
    public func snapshot() async throws -> ClipboardSnapshot {
        guard !snapshotTaskBusy else { throw AparteError.clipboardUnavailable }
        snapshotTaskBusy = true
        return try await withCheckedThrowingContinuation { continuation in
            let race = SnapshotRace(continuation)
            let name = boardName
            let eagerReceipt = provenEagerChangeCount
            DispatchQueue.global(qos: .userInitiated).async {
                let result: Result<ClipboardSnapshot, Error>
                do {
                    let start = ContinuousClock.now
                    let board = NSPasteboard(name: name); let count = board.changeCount
                    var items: [[ClipboardRepresentation]] = []; var size = 0
                    var legacy: Pasteboard?
                    guard PasteboardCreate(name.rawValue as CFString, &legacy) == noErr, let legacy else { throw AparteError.clipboardUnavailable }
                    PasteboardSynchronize(legacy)
                    var itemCount = 0
                    guard PasteboardGetItemCount(legacy, &itemCount) == noErr else { throw AparteError.clipboardUnavailable }
                    // macOS 26.6 reports flags=0 for lazy AppKit providers. Only an
                    // empty board or a still-owned eager write by this adapter is provable.
                    // Unknown nonempty clipboards use Recovery without fetching any data.
                    guard itemCount == 0 || eagerReceipt == count else { throw AparteError.clipboardUnavailable }
                    for index in 0..<Int(itemCount) {
                        var itemID: PasteboardItemID?
                        guard PasteboardGetItemIdentifier(legacy, CFIndex(index + 1), &itemID) == noErr, let itemID else { throw AparteError.clipboardUnavailable }
                        var flavors: CFArray?
                        guard PasteboardCopyItemFlavors(legacy, itemID, &flavors) == noErr, let types = flavors as? [String], !types.isEmpty else { throw AparteError.clipboardUnavailable }
                        var reps: [ClipboardRepresentation] = []
                        for type in types {
                            var flags: PasteboardFlavorFlags = []
                            let flagStatus = PasteboardGetItemFlavorFlags(legacy, itemID, type as CFString, &flags)
                            guard flagStatus == noErr else { throw AparteError.clipboardUnavailable }
                            // Ignore implicit OS translations, not representations supplied by
                            // the clipboard owner. Never ask AppKit for pasteboardItems here:
                            // that accessor can eagerly resolve foreign promises.
                            if flags.rawValue & (1 << 8) != 0 { continue } // kPasteboardFlavorSystemTranslated
                            guard flags.rawValue & (1 << 9) == 0 else { throw AparteError.clipboardUnavailable } // kPasteboardFlavorPromised
                            guard ClipboardPolicy.allowedType(type), start.duration(to: .now) < .milliseconds(500) else { throw AparteError.clipboardUnavailable }
                            var copied: CFData?
                            let copyStatus = PasteboardCopyItemFlavorData(legacy, itemID, type as CFString, &copied)
                            guard copyStatus == noErr, let copied else { throw AparteError.clipboardUnavailable }
                            let data = copied as Data
                            size += data.count
                            guard size <= 8 * 1024 * 1024 else { throw AparteError.clipboardUnavailable }
                            reps.append(.init(type: type, data: data))
                        }
                        items.append(reps)
                    }
                    guard board.changeCount == count, start.duration(to: .now) < .milliseconds(500) else { throw AparteError.clipboardUnavailable }
                    result = .success(try ClipboardSnapshot(items: items, changeCount: count))
                } catch { result = .failure(AparteError.clipboardUnavailable) }
                Task { @MainActor in self.snapshotTaskBusy = false; race.finish(result) }
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) { race.finish(.failure(AparteError.clipboardUnavailable)) }
        }
    }
    public func write(_ text: String, snapshot: ClipboardSnapshot) throws {
        restore()
        let board = NSPasteboard(name: boardName)
        guard board.changeCount == snapshot.changeCount else { throw AparteError.clipboardUnavailable }
        let marker = UUID().uuidString; let item = NSPasteboardItem()
        item.setString(text, forType: .string); item.setString(marker, forType: Self.markerType)
        let clearedCount = board.clearContents()
        guard board.writeObjects([item]) else {
            // Failure after clear must not strand the prior clipboard. Restore only if
            // no newer writer is observable; a general atomic CAS is unavailable.
            if board.changeCount == clearedCount && (board.pasteboardItems ?? []).isEmpty {
                restoreItems(snapshot, to: board)
            }
            throw AparteError.clipboardUnavailable
        }
        provenEagerChangeCount = board.changeCount
        pending = (snapshot, board.changeCount, marker, text)
    }
    public func dispatchPaste() -> Bool {
        guard owns(), CGPreflightPostEventAccess(), let source = CGEventSource(stateID: .privateState),
              let down = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) else { restore(); return false }
        for event in [down, up] { event.flags = .maskCommand; event.setIntegerValueField(.eventSourceUserData, value: EventIdentity.marker); event.post(tap: .cghidEventTap) }
        restoration?.cancel()
        restoration = Task { try? await Task.sleep(for: .seconds(1)); guard !Task.isCancelled else { return }; self.restore() }
        return true
    }
    private func owns() -> Bool {
        guard let pending else { return false }; let board = NSPasteboard(name: boardName)
        return ClipboardPolicy.owns(expectedCount: pending.count, actualCount: board.changeCount, expectedMarker: pending.marker, actualMarker: board.string(forType: Self.markerType), expectedText: pending.text, actualText: board.string(forType: .string))
    }
    public func restore() {
        restoration?.cancel(); restoration = nil
        defer { pending = nil }
        guard let pending, owns() else { return }
        let board = NSPasteboard(name: boardName)
        guard owns() else { return }
        restoreItems(pending.snapshot, to: board)
    }
    private func restoreItems(_ snapshot: ClipboardSnapshot, to board: NSPasteboard) {
        let items = snapshot.items.map { reps -> NSPasteboardItem in
            let item = NSPasteboardItem(); for rep in reps { item.setData(rep.data, forType: .init(rep.type)) }; return item
        }
        if pending != nil && !owns() { return }
        board.clearContents(); if !items.isEmpty { board.writeObjects(items) }
        provenEagerChangeCount = board.changeCount
    }
    /// Explicit replacement is used for user-requested Copy and known eager restoration.
    public func replaceContentsExplicitly(_ items: [[ClipboardRepresentation]]) throws {
        let snapshot = try ClipboardSnapshot(items: items, changeCount: 0)
        restore(); restoreItems(snapshot, to: NSPasteboard(name: boardName))
    }
    public func copyExplicit(_ text: String) {
        try? replaceContentsExplicitly([[.init(type: NSPasteboard.PasteboardType.string.rawValue, data: Data(text.utf8))]])
    }
}
