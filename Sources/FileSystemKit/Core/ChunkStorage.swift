// FileSystemKit Core Library
// Chunk Storage Protocol
//
// This file implements the ChunkStorage protocol for storing and retrieving binary chunks.

import Foundation

/// Content-addressable identifier for a binary chunk
/// Typically hash-based for deduplication
public struct ChunkIdentifier: Sendable, Hashable, Codable {
    /// Unique identifier (typically hash hex string)
    public let id: String
    
    /// Optional metadata about the chunk
    public let metadata: ChunkMetadata?
    
    public init(id: String, metadata: ChunkMetadata? = nil) {
        self.id = id
        self.metadata = metadata
    }
}

/// Metadata associated with a binary chunk
public struct ChunkMetadata: Sendable, Codable, Equatable, Hashable {
    /// Size of the chunk in bytes
    public let size: Int
    
    /// Content hash (for verification)
    public let contentHash: String?
    
    /// Hash algorithm used (e.g., "sha256")
    public let hashAlgorithm: String?
    
    /// Content type/MIME type (e.g., "application/octet-stream")
    public let contentType: String?
    
    /// Type of chunk (e.g., "disk-image", "file", "stream")
    public let chunkType: String?
    
    /// Original filename (if applicable)
    public let originalFilename: String?
    
    /// Original file paths (multiple if same content appears in different locations)
    public let originalPaths: [String]?
    
    /// Creation timestamp (when file was originally created)
    public let created: Date?
    
    /// Modification timestamp (when file was last modified)
    public let modified: Date?
    
    /// Compression information (if applicable)
    public let compression: CompressionInfo?
    
    public init(
        size: Int,
        contentHash: String? = nil,
        hashAlgorithm: String? = nil,
        contentType: String? = nil,
        chunkType: String? = nil,
        originalFilename: String? = nil,
        originalPaths: [String]? = nil,
        created: Date? = nil,
        modified: Date? = nil,
        compression: CompressionInfo? = nil
    ) {
        self.size = size
        self.contentHash = contentHash
        self.hashAlgorithm = hashAlgorithm
        self.contentType = contentType
        self.chunkType = chunkType
        self.originalFilename = originalFilename
        self.originalPaths = originalPaths
        self.created = created
        self.modified = modified
        self.compression = compression
    }
}

/// Compression information for a chunk
public struct CompressionInfo: Sendable, Codable, Equatable, Hashable {
    /// Compression algorithm (e.g., "gzip", "zip", "deflate")
    public let algorithm: String
    
    /// Uncompressed size
    public let uncompressedSize: Int
    
    /// Compressed size
    public let compressedSize: Int
    
    public init(algorithm: String, uncompressedSize: Int, compressedSize: Int) {
        self.algorithm = algorithm
        self.uncompressedSize = uncompressedSize
        self.compressedSize = compressedSize
    }
}

/// Protocol for chunk/binary data storage operations
///
/// This protocol defines the interface for storing and retrieving binary chunks.
/// Implementations can use various storage backends (file system, cloud storage, etc.).
///
/// **Memory Optimization**: The protocol supports lazy loading and partial reads.
public protocol ChunkStorage: Sendable {
    /// Write/store binary chunk
    ///
    /// - Parameters:
    ///   - data: Binary data to store
    ///   - identifier: Content-addressable identifier (typically hash-based)
    ///   - metadata: Optional metadata about the chunk
    /// - Returns: The chunk identifier (may be different if deduplication occurred)
    /// - Throws: Error if storage fails
    func writeChunk(_ data: Data, identifier: ChunkIdentifier, metadata: ChunkMetadata?) async throws -> ChunkIdentifier
    
    /// Read/fetch full binary chunk
    ///
    /// - Parameter identifier: Chunk identifier
    /// - Returns: Binary data, or nil if not found
    /// - Throws: Error if read fails
    func readChunk(_ identifier: ChunkIdentifier) async throws -> Data?
    
    /// Read/fetch partial binary chunk (offset + length)
    ///
    /// - Parameters:
    ///   - identifier: Chunk identifier
    ///   - offset: Byte offset to start reading
    ///   - length: Number of bytes to read
    /// - Returns: Binary data slice, or nil if not found
    /// - Throws: Error if read fails
    func readChunk(_ identifier: ChunkIdentifier, offset: Int, length: Int) async throws -> Data?
    
    /// Update binary chunk
    ///
    /// - Parameters:
    ///   - data: Updated binary data
    ///   - identifier: Chunk identifier
    ///   - metadata: Optional updated metadata
    /// - Returns: The chunk identifier (may be different if content changed)
    /// - Throws: Error if update fails
    func updateChunk(_ data: Data, identifier: ChunkIdentifier, metadata: ChunkMetadata?) async throws -> ChunkIdentifier
    
    /// Delete chunk
    ///
    /// - Parameter identifier: Chunk identifier to delete
    /// - Throws: Error if deletion fails
    func deleteChunk(_ identifier: ChunkIdentifier) async throws
    
    /// Check if chunk exists
    ///
    /// - Parameter identifier: Chunk identifier
    /// - Returns: True if chunk exists
    /// - Throws: Error if check fails
    func chunkExists(_ identifier: ChunkIdentifier) async throws -> Bool
    
    /// Get chunk size without loading the data
    /// Useful for determining how much to read
    ///
    /// - Parameter identifier: Chunk identifier
    /// - Returns: Size in bytes, or nil if chunk doesn't exist
    /// - Throws: Error if check fails
    func chunkSize(_ identifier: ChunkIdentifier) async throws -> Int?
    
    /// Get a file handle/reference to the underlying chunk
    /// Allows for efficient random access without loading entire file
    ///
    /// - Parameter identifier: Chunk identifier
    /// - Returns: File handle reference, or nil if not supported/available
    /// - Throws: Error if handle cannot be obtained
    func chunkHandle(_ identifier: ChunkIdentifier) async throws -> ChunkHandle?
}

// MARK: - Chunk Handle

/// Reference to underlying chunk storage for efficient random access
/// Allows implementations to provide file handles, stream references, etc.
public protocol ChunkHandle: Sendable {
    /// Read data from a specific range
    /// - Parameter range: Byte range to read
    /// - Returns: Data from the range
    /// - Throws: Error if read fails
    func read(range: Range<Int>) async throws -> Data
    
    /// Get total size of the chunk
    var size: Int { get }
    
    /// Close/release the handle
    func close() async throws
}

