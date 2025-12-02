// FileSystemKit Core Library
// Chunk Storage Default Implementations
//
// This file provides default implementations for ChunkStorage convenience methods.
// These implementations use the organization and retrieval protocols.

import Foundation

/// Default implementations for `ChunkStorageComposable` convenience methods.
///
/// These default implementations use the `organization` and `retrieval` properties
/// to provide convenient methods that work with chunk identifiers directly,
/// rather than requiring clients to generate paths manually.
extension ChunkStorageComposable {
    /// Read chunk data by identifier using organization and retrieval.
    ///
    /// Default implementation that uses `organization` to generate the storage path,
    /// then `retrieval` to read the chunk data.
    ///
    /// - Parameter identifier: Chunk identifier
    /// - Returns: Chunk data, or nil if not found
    /// - Throws: Error if read fails
    public func readChunk(_ identifier: ChunkIdentifier) async throws -> Data? {
        let path = organization.storagePath(for: identifier)
        return try await retrieval.readChunk(at: path)
    }
    
    /// Write chunk data with identifier using organization and retrieval.
    ///
    /// Default implementation that uses `organization` to generate the storage path,
    /// then `retrieval` to write the chunk data.
    ///
    /// - Parameters:
    ///   - data: Chunk data to write
    ///   - identifier: Chunk identifier
    ///   - metadata: Optional chunk metadata
    /// - Returns: The chunk identifier (same as input, for consistency with existing API)
    /// - Throws: Error if write fails
    public func writeChunk(_ data: Data, identifier: ChunkIdentifier, metadata: ChunkMetadata?) async throws -> ChunkIdentifier {
        let path = organization.storagePath(for: identifier)
        try await retrieval.writeChunk(data, at: path, metadata: metadata)
        return identifier
    }
    
    /// Check if chunk exists by identifier.
    ///
    /// Default implementation that uses `existence` checker if available,
    /// otherwise falls back to `retrieval.chunkExists(at:)`.
    ///
    /// - Parameter identifier: Chunk identifier
    /// - Returns: True if chunk exists
    /// - Throws: Error if check fails (for compatibility with existing ChunkStorage protocol)
    public func chunkExists(_ identifier: ChunkIdentifier) async throws -> Bool {
        // Use existence checker if available, otherwise use retrieval
        if let existence = existence {
            return await existence.chunkExists(identifier: identifier)
        } else {
            let path = organization.storagePath(for: identifier)
            return await retrieval.chunkExists(at: path)
        }
    }
}

