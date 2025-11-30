// FileSystemKit Core Library
// File System Chunk Storage Implementation
//
// Concrete implementation of ChunkStorage using the local file system.
// Used for unit tests and local storage scenarios.

import Foundation

/// File system-based ChunkStorage implementation
/// Reads/writes chunks directly from/to the file system
/// Used for batch processing and file system operations
public struct FileSystemChunkStorage: ChunkStorage, Sendable {
    /// Base directory for storing chunks
    public let baseURL: URL
    
    public init(baseURL: URL) {
        self.baseURL = baseURL
    }
    
    /// Get file URL for a chunk identifier
    private func fileURL(for identifier: ChunkIdentifier) -> URL {
        baseURL.appendingPathComponent(identifier.id)
    }
    
    public func writeChunk(_ data: Data, identifier: ChunkIdentifier, metadata: ChunkMetadata?) async throws -> ChunkIdentifier {
        let url = fileURL(for: identifier)
        
        // Ensure directory exists
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        try data.write(to: url)
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
        return try FileSystemChunkHandle(url: url)
    }
}

/// File system-based ChunkHandle implementation
private final class FileSystemChunkHandle: ChunkHandle, @unchecked Sendable {
    private let url: URL
    private var fileHandle: FileHandle?
    private var isClosed = false
    
    init(url: URL) throws {
        self.url = url
        self.fileHandle = try FileHandle(forReadingFrom: url)
    }
    
    func read(range: Range<Int>) async throws -> Data {
        guard !isClosed, let handle = fileHandle else {
            throw FileSystemError.storageUnavailable(reason: "File handle is closed or unavailable")
        }
        
        handle.seek(toFileOffset: UInt64(range.lowerBound))
        guard let data = try handle.read(upToCount: range.upperBound - range.lowerBound) else {
            throw FileSystemError.readFailed(path: url.path, underlyingError: nil)
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

