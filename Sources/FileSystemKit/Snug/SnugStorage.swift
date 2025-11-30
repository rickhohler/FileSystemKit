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
        let isNewFile = !FileManager.default.fileExists(atPath: url.path)
        if isNewFile {
            try data.write(to: url)
        }
        
        // Write or update metadata file (always update to track all original paths)
        if let metadata = metadata {
            let metadataURL = url.appendingPathExtension("meta")
            try writeMetadata(metadata, to: metadataURL, identifier: identifier)
        }
        
        return identifier
    }
    
    /// Write metadata to file (JSON format)
    private func writeMetadata(_ metadata: ChunkMetadata, to url: URL, identifier: ChunkIdentifier) throws {
        // If metadata file exists, read existing metadata to merge original paths
        var finalMetadata = metadata
        
        // Always try to read existing metadata if file exists (for merging)
        let fileExists = FileManager.default.fileExists(atPath: url.path)
        if fileExists {
            do {
                let existingData = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let existingMetadata = try decoder.decode(ChunkMetadata.self, from: existingData)
                // Merge original paths
                var mergedPaths = Set(existingMetadata.originalPaths ?? [])
                if let originalFilename = existingMetadata.originalFilename {
                    mergedPaths.insert(originalFilename)
                }
                if let paths = metadata.originalPaths {
                    mergedPaths.formUnion(paths)
                }
                if let originalFilename = metadata.originalFilename {
                    mergedPaths.insert(originalFilename)
                }
                
                // Use earliest created date, latest modified date
                let earliestCreated = [existingMetadata.created, metadata.created].compactMap { $0 }.min()
                let latestModified = [existingMetadata.modified, metadata.modified].compactMap { $0 }.max()
                
                finalMetadata = ChunkMetadata(
                    size: metadata.size,
                    contentHash: metadata.contentHash ?? existingMetadata.contentHash,
                    hashAlgorithm: metadata.hashAlgorithm ?? existingMetadata.hashAlgorithm,
                    contentType: existingMetadata.contentType ?? metadata.contentType,  // Prefer existing (first write)
                    chunkType: metadata.chunkType ?? existingMetadata.chunkType,
                    originalFilename: existingMetadata.originalFilename ?? metadata.originalFilename,  // Prefer existing (first write)
                    originalPaths: Array(mergedPaths).sorted(),
                    created: earliestCreated ?? existingMetadata.created ?? metadata.created,
                    modified: latestModified ?? existingMetadata.modified ?? metadata.modified,
                    compression: existingMetadata.compression ?? metadata.compression  // Prefer existing (first write)
                )
            } catch {
                // If we can't read/decode existing metadata, just use new metadata
                // This shouldn't happen in normal operation, but handle gracefully
            }
        }
        
        // Write metadata as JSON (atomically to ensure file is fully written)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let metadataData = try encoder.encode(finalMetadata)
        try metadataData.write(to: url, options: [.atomic])
    }
    
    /// Read metadata from file
    public func readMetadata(_ identifier: ChunkIdentifier) throws -> ChunkMetadata? {
        let url = fileURL(for: identifier)
        let metadataURL = url.appendingPathExtension("meta")
        
        guard FileManager.default.fileExists(atPath: metadataURL.path) else {
            return nil
        }
        
        let data = try Data(contentsOf: metadataURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ChunkMetadata.self, from: data)
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
        let metadataURL = url.appendingPathExtension("meta")
        
        // Delete data file
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        
        // Delete metadata file
        if FileManager.default.fileExists(atPath: metadataURL.path) {
            try FileManager.default.removeItem(at: metadataURL)
        }
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

