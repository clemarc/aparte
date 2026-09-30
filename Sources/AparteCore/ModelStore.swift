import Foundation
import Darwin

private final class DownloadProgress: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    let update: @Sendable (Int64) -> Void
    init(_ update: @escaping @Sendable (Int64) -> Void) { self.update = update }
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {}
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(request.url?.scheme == "https" ? request : nil)
    }
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) { update(totalBytesWritten) }
}
public actor ModelStore {
    private let root: URL
    private var busy = false
    public init(root: URL) { self.root = root }
    public func install(_ manifest: ModelManifest, importing source: URL? = nil, progress: @escaping @Sendable (Double) -> Void) async throws {
        guard !busy else { throw AparteError.busy }; busy = true; defer { busy = false }
        try manifest.validate()
        let manager = FileManager.default
        try manager.createDirectory(at: root, withIntermediateDirectories: true)
        let capacity = try root.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]).volumeAvailableCapacityForImportantUsage ?? 0
        guard capacity > manifest.temporaryBytes else { throw AparteError.insufficientSpace }
        let stage = root.appendingPathComponent(".partial-" + UUID().uuidString, isDirectory: true)
        try manager.createDirectory(at: stage, withIntermediateDirectories: false)
        defer { try? manager.removeItem(at: stage) }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil; configuration.httpCookieStorage = nil; configuration.urlCredentialStorage = nil
        configuration.timeoutIntervalForRequest = 60; configuration.timeoutIntervalForResource = 600
        let session = URLSession(configuration: configuration); defer { session.invalidateAndCancel() }
        if let source { try manifest.verify(directory: source) }
        var completed: Int64 = 0
        for asset in manifest.files {
            try Task.checkCancellation()
            let destination = stage.appendingPathComponent(asset.path)
            try manager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            if let source { try manager.copyItem(at: source.appendingPathComponent(asset.path), to: destination) }
            else {
                let before = completed, total = manifest.installedBytes
                let delegate = DownloadProgress { count in progress(min(0.99, Double(before + count) / Double(total))) }
                let (temporary, response) = try await session.download(for: URLRequest(url: asset.url), delegate: delegate)
                defer { try? manager.removeItem(at: temporary) }
                guard let http = response as? HTTPURLResponse, http.statusCode == 200, response.url?.scheme == "https" else { throw AparteError.invalidAsset }
                try manager.moveItem(at: temporary, to: destination)
            }
            completed += asset.bytes; progress(min(0.99, Double(completed) / Double(manifest.installedBytes)))
        }
        try manifest.verify(directory: stage); try Task.checkCancellation()
        let destination = root.appendingPathComponent(manifest.id, isDirectory: true)
        if manager.fileExists(atPath: destination.path) {
            // Same-volume atomic exchange: failure leaves the existing installation intact.
            guard renameatx_np(AT_FDCWD, stage.path, AT_FDCWD, destination.path, UInt32(RENAME_SWAP)) == 0 else { throw AparteError.invalidAsset }
        } else { try manager.moveItem(at: stage, to: destination) }
        progress(1)
    }
    public func delete(_ id: String) throws {
        guard !busy, ["base", "small", "medium", "turbo", "base.en"].contains(id) else { throw AparteError.busy }
        try FileManager.default.removeItem(at: root.appendingPathComponent(id))
    }
    public func cleanInterruptedStages() throws {
        guard !busy, FileManager.default.fileExists(atPath: root.path) else { return }
        for url in try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) where url.lastPathComponent.hasPrefix(".partial-") {
            try FileManager.default.removeItem(at: url)
        }
    }
}
