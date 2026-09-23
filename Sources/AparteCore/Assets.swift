import Foundation
import CryptoKit

public struct AssetFile: Codable, Sendable {
    public let path: String
    public let url: URL
    public let bytes: Int64
    public let sha256: String
    public init(path: String, url: URL, bytes: Int64, sha256: String) { self.path = path; self.url = url; self.bytes = bytes; self.sha256 = sha256 }
    public var isSafe: Bool {
        !path.isEmpty && !path.hasPrefix("/") && !path.contains("\\") && !path.split(separator: "/", omittingEmptySubsequences: false).contains(where: { $0 == ".." || $0 == "." || $0.isEmpty }) && url.scheme == "https" && url.host == "huggingface.co" && bytes > 0 && sha256.count == 64 && sha256.allSatisfy(\.isHexDigit)
    }
}
public struct ModelManifest: Codable, Sendable, Identifiable {
    public let id: String
    public let displayName: String
    public let revision: String
    public let tokenizerRevision: String
    public let license: String
    public let files: [AssetFile]
    public var installedBytes: Int64 { files.reduce(0) { $0 + $1.bytes } }
    public var temporaryBytes: Int64 { installedBytes * 2 + 256 * 1_024 * 1_024 }
    public func validate() throws {
        guard ["base", "small"].contains(id), revision.count == 40, tokenizerRevision.count == 40,
              !files.isEmpty, Set(files.map(\.path)).count == files.count, files.allSatisfy(\.isSafe),
              ["tokenizer.json", "tokenizer_config.json"].allSatisfy({ name in files.contains { $0.path == name } }) else { throw AparteError.invalidAsset }
    }
    public func verify(directory: URL) throws {
        try validate()
        for file in files {
            try Task.checkCancellation()
            var ancestor = directory
            for part in file.path.split(separator: "/") {
                ancestor.appendPathComponent(String(part))
                let values = try ancestor.resourceValues(forKeys: [.isSymbolicLinkKey])
                guard values.isSymbolicLink != true else { throw AparteError.invalidAsset }
            }
            let url = directory.appendingPathComponent(file.path)
            let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
            guard values.isRegularFile == true, Int64(values.fileSize ?? -1) == file.bytes else { throw AparteError.invalidAsset }
            let handle = try FileHandle(forReadingFrom: url); defer { try? handle.close() }
            var hash = SHA256()
            while let chunk = try handle.read(upToCount: 1_048_576), !chunk.isEmpty { try Task.checkCancellation(); hash.update(data: chunk) }
            guard hash.finalize().map({ String(format: "%02x", $0) }).joined() == file.sha256 else { throw AparteError.invalidAsset }
        }
    }
}
public struct ModelCatalog: Codable, Sendable {
    public let schema: Int
    public let models: [ModelManifest]
    public static func load(_ url: URL) throws -> ModelCatalog {
        let catalog = try JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
        guard catalog.schema == 1 else { throw AparteError.invalidAsset }
        try catalog.models.forEach { try $0.validate() }; return catalog
    }
}
