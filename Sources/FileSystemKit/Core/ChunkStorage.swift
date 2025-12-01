// FileSystemKit Core Library
// Chunk Storage Protocol
//
// This file implements the ChunkStorage protocol for storing and retrieving binary chunks.

import Foundation

/// Content-addressable identifier for a binary chunk.
///
/// `ChunkIdentifier` uniquely identifies a chunk of binary data, typically using
/// a cryptographic hash of the content. This enables deduplication and integrity
/// verification.
///
/// ## Usage
///
/// Create identifier from hash:
/// ```swift
/// let hash = computeSHA256(data)
/// let identifier = ChunkIdentifier(id: hash.hexString)
/// ```
///
/// Create with metadata:
/// ```swift
/// let identifier = ChunkIdentifier(
///     id: hash.hexString,
///     metadata: ChunkMetadata(
///         size: data.count,
///         contentType: "application/octet-stream"
///     )
/// )
/// ```
///
/// Use as dictionary key (Hashable):
/// ```swift
/// var chunkCache: [ChunkIdentifier: Data] = [:]
/// chunkCache[identifier] = data
/// ```
///
/// ## Properties
///
/// - `id` - Unique identifier (typically hash hex string)
/// - `metadata` - Optional metadata about the chunk
///
/// ## See Also
///
/// - ``ChunkStorage`` - Storage protocol
/// - ``ChunkMetadata`` - Chunk metadata
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

/// Metadata describing a binary chunk.
///
/// `ChunkMetadata` provides information about a chunk including size, content type,
/// timestamps, and compression information. This metadata helps with chunk management
/// and optimization.
///
/// ## Usage
///
/// Create metadata for a file chunk:
/// ```swift
/// let metadata = ChunkMetadata(
///     size: fileData.count,
///     contentHash: hash.hexString,
///     hashAlgorithm: "sha256",
///     contentType: "application/pdf",
///     chunkType: "file",
///     originalFilename: "document.pdf",
///     created: Date(),
///     modified: Date()
/// )
/// ```
///
/// Create minimal metadata:
/// ```swift
/// let metadata = ChunkMetadata(size: data.count)
/// ```
///
/// Include compression information:
/// ```swift
/// let metadata = ChunkMetadata(
///     size: compressedData.count,
///     compression: CompressionInfo(
///         algorithm: "gzip",
///         uncompressedSize: originalSize,
///         compressedSize: compressedData.count
///     )
/// )
/// ```
///
/// ## Properties
///
/// - `size` - Size of the chunk in bytes
/// - `contentHash` - Content hash for verification
/// - `hashAlgorithm` - Hash algorithm used
/// - `contentType` - MIME type (e.g., "application/pdf")
/// - `chunkType` - Type of chunk ("disk-image", "file", "stream")
/// - `originalFilename` - Original filename if applicable
/// - `originalPaths` - Original file paths (for deduplication tracking)
/// - `created` - Creation timestamp
/// - `modified` - Modification timestamp
/// - `compression` - Compression information if applicable
///
/// ## See Also
///
/// - ``ChunkIdentifier`` - Chunk identifier
/// - ``CompressionInfo`` - Compression details
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

/// Compression information for a chunk.
///
/// `CompressionInfo` describes how a chunk was compressed, including the algorithm
/// used and the size difference between compressed and uncompressed data.
///
/// ## See Also
///
/// - ``ChunkMetadata`` - Chunk metadata container
/// - [Data Compression (Wikipedia)](https://en.wikipedia.org/wiki/Data_compression) - Overview of compression techniques
/// - [Gzip (Wikipedia)](https://en.wikipedia.org/wiki/Gzip) - Gzip compression format
/// - [ZIP (file format) (Wikipedia)](https://en.wikipedia.org/wiki/ZIP_(file_format)) - ZIP compression format
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

/// Protocol for content-addressable binary data storage.
///
/// `ChunkStorage` defines the interface for storing and retrieving binary chunks
/// using content-addressable identifiers (typically hash-based). This enables
/// deduplication, efficient storage, and integrity verification.
///
/// ## Overview
///
/// Chunk storage provides:
/// - **Content-Addressable Storage**: Files identified by their content hash
/// - **Deduplication**: Identical content stored only once
/// - **Efficient Access**: Lazy loading and partial reads
/// - **Multiple Backends**: File system, cloud storage, memory, etc.
///
/// ## Usage
///
/// Store a chunk:
/// ```swift
/// let data = "Hello, World!".data(using: .utf8)!
/// let hash = computeSHA256(data)
/// let identifier = ChunkIdentifier(id: hash.hexString)
///
/// let storedIdentifier = try await chunkStorage.writeChunk(
///     data,
///     identifier: identifier,
///     metadata: ChunkMetadata(size: data.count)
/// )
/// ```
///
/// Read a chunk:
/// ```swift
/// let identifier = ChunkIdentifier(id: "abc123...")
///
/// if let data = try await chunkStorage.readChunk(identifier) {
///     print("Read \(data.count) bytes")
/// }
/// ```
///
/// Read partial chunk (efficient for large files):
/// ```swift
/// let identifier = ChunkIdentifier(id: "abc123...")
///
/// // Read first 1KB
/// let header = try await chunkStorage.readChunk(
///     identifier,
///     offset: 0,
///     length: 1024
/// )
/// ```
///
/// Check if chunk exists:
/// ```swift
/// let identifier = ChunkIdentifier(id: "abc123...")
///
/// if try await chunkStorage.chunkExists(identifier) {
///     print("Chunk exists")
/// }
/// ```
///
/// Get chunk size without loading:
/// ```swift
/// if let size = try await chunkStorage.chunkSize(identifier) {
///     print("Chunk size: \(size) bytes")
/// }
/// ```
///
/// Use chunk handle for random access:
/// ```swift
/// if let handle = try await chunkStorage.chunkHandle(identifier) {
///     // Read specific range
///     let data = try await handle.read(range: 0..<1024)
///     // ... use data ...
///     try await handle.close()
/// }
/// ```
///
/// ## Memory Optimization
///
/// The protocol supports efficient memory usage:
/// - **Lazy Loading**: Chunks loaded only when accessed
/// - **Partial Reads**: Read only needed portions of large files
/// - **Handle-Based Access**: Random access without loading entire chunk
///
/// ## Implementations
///
/// Common implementations include:
/// - `FileSystemChunkStorage` - File system-based storage
/// - `MemoryChunkStorage` - In-memory storage (for testing)
/// - `CloudChunkStorage` - Cloud storage backends
///
/// ## See Also
///
/// - ``ChunkIdentifier`` - Content-addressable identifier
/// - ``ChunkMetadata`` - Chunk metadata
/// - ``ChunkHandle`` - Handle for random access
/// - [Content-Addressable Storage (Wikipedia)](https://en.wikipedia.org/wiki/Content-addressable_storage) - Overview of content-addressable storage systems
/// - [Data Deduplication (Wikipedia)](https://en.wikipedia.org/wiki/Data_deduplication) - Techniques for eliminating duplicate data
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

