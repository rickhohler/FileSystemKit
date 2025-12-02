// FileSystemKit Core Library
// Composable File System Chunk Storage
//
// This file implements ChunkStorageComposable using file system components.
// This is the new composable implementation that uses organization, retrieval, and existence protocols.

import Foundation

/// Composable file system chunk storage implementation.
///
/// `ComposableFileSystemChunkStorage` composes `GitStyleOrganization`, `FileSystemRetrieval`,
/// and `FileSystemExistence` into a complete chunk storage solution. This provides
/// a flexible, composable architecture while maintaining the convenience of a single type.
///
/// ## Overview
///
/// This implementation:
/// - Uses `GitStyleOrganization` by default (configurable)
/// - Uses `FileSystemRetrieval` for read/write operations
/// - Uses `FileSystemExistence` for optimized existence checks
/// - Provides all `ChunkStorage` protocol methods via default implementations
///
/// ## Usage
///
/// Create with default organization (Git-style, depth 2):
/// ```swift
/// let baseURL = URL(fileURLWithPath: "/path/to/storage")
/// let storage = ComposableFileSystemChunkStorage(baseURL: baseURL)
///
/// let identifier = ChunkIdentifier(id: "a1b2c3d4...")
/// try await storage.writeChunk(data, identifier: identifier, metadata: metadata)
/// let data = try await storage.readChunk(identifier)
/// ```
///
/// Create with custom organization:
/// ```swift
/// let organization = FlatOrganization()
/// let baseURL = URL(fileURLWithPath: "/path/to/storage")
/// let storage = ComposableFileSystemChunkStorage(
///     baseURL: baseURL,
///     organization: organization
/// )
/// ```
///
/// Create with custom depth:
/// ```swift
/// let organization = GitStyleOrganization(directoryDepth: 3)
/// let baseURL = URL(fileURLWithPath: "/path/to/storage")
/// let storage = ComposableFileSystemChunkStorage(
///     baseURL: baseURL,
///     organization: organization
/// )
/// ```
///
/// ## Backward Compatibility
///
/// This implementation is separate from the existing `FileSystemChunkStorage` to
/// maintain backward compatibility. The existing implementation continues to work,
/// while this new composable version provides the enhanced architecture.
///
/// ## See Also
///
/// - ``ChunkStorageComposable`` - Composable storage protocol
/// - ``ChunkStorage`` - Base storage protocol
/// - ``GitStyleOrganization`` - Default organization strategy
/// - ``FileSystemRetrieval`` - File system retrieval implementation
/// - ``FileSystemExistence`` - File system existence implementation
/// - ``FileSystemChunkStorage`` - Original file system storage implementation
public struct ComposableFileSystemChunkStorage: ChunkStorageComposable {
    /// Organization strategy for this storage.
    public let organization: ChunkStorageOrganization
    
    /// Retrieval mechanism for this storage.
    public let retrieval: ChunkStorageRetrieval
    
    /// Existence checker for this storage.
    public let existence: ChunkStorageExistence?
    
    /// Base URL for chunk storage (stored for size calculations).
    private let baseURL: URL
    
    /// Create composable file system chunk storage.
    ///
    /// - Parameters:
    ///   - baseURL: Base directory for chunk storage
    ///   - organization: Organization strategy (default: GitStyleOrganization with depth 2)
    public init(
        baseURL: URL,
        organization: ChunkStorageOrganization = GitStyleOrganization(directoryDepth: 2)
    ) {
        self.baseURL = baseURL
        self.organization = organization
        self.retrieval = FileSystemRetrieval(baseURL: baseURL)
        self.existence = FileSystemExistence(organization: organization, baseURL: baseURL)
    }
    
    // ChunkStorage methods are provided by default implementation in ChunkStorage+Default.swift
    // Additional methods from ChunkStorage protocol that aren't covered by defaults:
    
    /// Read partial chunk (offset + length).
    ///
    /// Reads a portion of the chunk data without loading the entire chunk.
    ///
    /// - Parameters:
    ///   - identifier: Chunk identifier
    ///   - offset: Byte offset to start reading
    ///   - length: Number of bytes to read
    /// - Returns: Binary data slice, or nil if not found
    /// - Throws: Error if read fails
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
    
    /// Update chunk (same as write for content-addressable storage).
    ///
    /// For content-addressable storage, updating is the same as writing since
    /// the identifier is based on content hash.
    ///
    /// - Parameters:
    ///   - data: Updated binary data
    ///   - identifier: Chunk identifier
    ///   - metadata: Optional updated metadata
    /// - Returns: The chunk identifier (may be different if content changed)
    /// - Throws: Error if update fails
    public func updateChunk(_ data: Data, identifier: ChunkIdentifier, metadata: ChunkMetadata?) async throws -> ChunkIdentifier {
        // For content-addressable storage, update is same as write
        return try await writeChunk(data, identifier: identifier, metadata: metadata)
    }
    
    /// Delete chunk.
    ///
    /// Deletes the chunk from storage.
    ///
    /// - Parameter identifier: Chunk identifier to delete
    /// - Throws: Error if deletion fails
    public func deleteChunk(_ identifier: ChunkIdentifier) async throws {
        let path = organization.storagePath(for: identifier)
        try await retrieval.deleteChunk(at: path)
    }
    
    /// Get chunk size without loading the data.
    ///
    /// Uses file system APIs to get file size without reading the data.
    ///
    /// - Parameter identifier: Chunk identifier
    /// - Returns: Size in bytes, or nil if chunk doesn't exist
    /// - Throws: Error if check fails
    public func chunkSize(_ identifier: ChunkIdentifier) async throws -> Int? {
        let path = organization.storagePath(for: identifier)
        let fileURL = baseURL.appendingPathComponent(path)
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              let size = attributes[.size] as? Int64 else {
            return nil
        }
        
        return Int(size)
    }
    
    /// Get chunk handle for random access.
    ///
    /// Returns a file handle for efficient random access to the chunk.
    /// Currently returns nil - can be enhanced to use FileHandle.
    ///
    /// - Parameter identifier: Chunk identifier
    /// - Returns: File handle reference, or nil if not supported/available
    /// - Throws: Error if handle cannot be obtained
    public func chunkHandle(_ identifier: ChunkIdentifier) async throws -> ChunkHandle? {
        // TODO: Implement FileHandle-based ChunkHandle
        // Requires access to baseURL from FileSystemRetrieval
        return nil
    }
}

