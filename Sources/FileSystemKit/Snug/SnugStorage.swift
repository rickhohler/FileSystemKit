// FileSystemKit - SNUG Storage Management
// Handles storage directory setup and ChunkStorage creation for SNUG archives

import Foundation

/// SNUG storage helper functions
public struct SnugStorage {
    /// Get default storage directory
    /// Checks SNUG_STORAGE environment variable, defaults to ~/.snug
    public static func defaultStorageDirectory() -> String {
        if let envStorage = ProcessInfo.processInfo.environment["SNUG_STORAGE"] {
            return envStorage
        }
        
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(homeDir)/.snug"
    }
    
    /// Ensure storage directory exists
    public static func ensureStorageDirectory(at url: URL) throws {
        if !FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.createDirectory(
                at: url,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
    }
    
    /// Create ChunkStorage instance for SNUG
    public static func createChunkStorage(at url: URL) throws -> SnugFileSystemChunkStorage {
        try ensureStorageDirectory(at: url)
        return SnugFileSystemChunkStorage(baseURL: url)
    }
}

/// File system-based ChunkStorage implementation for SNUG
public struct SnugFileSystemChunkStorage: ChunkStorage, Sendable {
    public let baseURL: URL
    
    public init(baseURL: URL) {
        self.baseURL = baseURL
    }
    
    private func fileURL(for identifier: ChunkIdentifier) -> URL {
        // Store files by hash in a two-level directory structure
        // e.g., hash "abc123..." -> baseURL/ab/c1/abc123...
        let hash = identifier.id
        guard hash.count >= 4 else {
            return baseURL.appendingPathComponent(hash)
        }
        
        let prefix1 = String(hash.prefix(2))
        let prefix2 = String(hash.dropFirst(2).prefix(2))
        return baseURL
            .appendingPathComponent(prefix1)
            .appendingPathComponent(prefix2)
            .appendingPathComponent(hash)
    }
    
    public func writeChunk(_ data: Data, identifier: ChunkIdentifier, metadata: ChunkMetadata?) async throws -> ChunkIdentifier {
        let url = fileURL(for: identifier)
        
        // Create directory structure if needed
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        // Write file (only if it doesn't exist - deduplication)
        if !FileManager.default.fileExists(atPath: url.path) {
            try data.write(to: url)
        }
        
        return identifier
    }
    
    public func readChunk(_ identifier: ChunkIdentifier) async throws -> Data? {
        let url = fileURL(for: identifier)
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        return try Data(contentsOf: url)
    }
    
    public func readChunk(_ identifier: ChunkIdentifier, offset: Int, length: Int) async throws -> Data? {
        guard let fullData = try await readChunk(identifier) else {
            return nil
        }
        
        guard offset >= 0 && offset < fullData.count else {
            return nil
        }
        
        let endIndex = min(offset + length, fullData.count)
        return fullData.subdata(in: offset..<endIndex)
    }
    
    public func updateChunk(_ data: Data, identifier: ChunkIdentifier, metadata: ChunkMetadata?) async throws -> ChunkIdentifier {
        return try await writeChunk(data, identifier: identifier, metadata: metadata)
    }
    
    public func deleteChunk(_ identifier: ChunkIdentifier) async throws {
        let url = fileURL(for: identifier)
        try FileManager.default.removeItem(at: url)
    }
    
    public func chunkExists(_ identifier: ChunkIdentifier) async throws -> Bool {
        let url = fileURL(for: identifier)
        return FileManager.default.fileExists(atPath: url.path)
    }
    
    public func chunkSize(_ identifier: ChunkIdentifier) async throws -> Int? {
        let url = fileURL(for: identifier)
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? Int64 else {
            return nil
        }
        return Int(size)
    }
    
    public func chunkHandle(_ identifier: ChunkIdentifier) async throws -> ChunkHandle? {
        let url = fileURL(for: identifier)
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        return try SnugFileSystemChunkHandle(url: url)
    }
}

/// File system-based ChunkHandle implementation for SNUG
private final class SnugFileSystemChunkHandle: ChunkHandle, @unchecked Sendable {
    private let url: URL
    private var fileHandle: FileHandle?
    private var isClosed = false
    
    init(url: URL) throws {
        self.url = url
        self.fileHandle = try FileHandle(forReadingFrom: url)
    }
    
    func read(range: Range<Int>) async throws -> Data {
        guard !isClosed, let handle = fileHandle else {
            throw FileSystemError.storageUnavailable
        }
        
        handle.seek(toFileOffset: UInt64(range.lowerBound))
        guard let data = try handle.read(upToCount: range.upperBound - range.lowerBound) else {
            throw FileSystemError.readFailed
        }
        return data
    }
    
    var size: Int {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let fileSize = attributes[.size] as? Int64 else {
            return 0
        }
        return Int(fileSize)
    }
    
    func close() async throws {
        try fileHandle?.close()
        fileHandle = nil
        isClosed = true
    }
}

