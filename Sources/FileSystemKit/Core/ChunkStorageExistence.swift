// FileSystemKit Core Library
// Chunk Storage Existence Protocol
//
// This file defines the protocol for efficiently checking chunk existence.
// Optional - can be implemented separately for optimized existence checks.

import Foundation

/// Protocol for efficiently checking chunk existence.
///
/// `ChunkStorageExistence` provides optimized existence checking that may be more
/// efficient than reading chunk data just to check if it exists. Some backends may
/// implement this with optimized queries (e.g., database index lookup, file system
/// metadata checks).
///
/// ## Overview
///
/// This protocol is **optional** - if not provided, existence checks will fall back
/// to using `ChunkStorageRetrieval.chunkExists(at:)`. However, implementing this
/// protocol separately allows for:
/// - **Optimized Queries**: Database index lookups instead of file reads
/// - **Batch Operations**: Efficient batch existence checks
/// - **Performance**: Faster existence checks for large storage backends
///
/// ## Usage
///
/// Check if chunk exists:
/// ```swift
/// let existence = FileSystemExistence(organization: organization, baseURL: baseURL)
/// let identifier = ChunkIdentifier(id: "a1b2c3d4...")
///
/// if await existence.chunkExists(identifier: identifier) {
///     print("Chunk exists")
/// }
/// ```
///
/// Batch existence check:
/// ```swift
/// let identifiers = [identifier1, identifier2, identifier3]
/// let results = await existence.chunkExists(identifiers: identifiers)
///
/// for (identifier, exists) in results {
///     if exists {
///         print("\(identifier.id) exists")
///     }
/// }
/// ```
///
/// ## Implementation Notes
///
/// - **File System**: Use `FileManager.fileExists(atPath:)` for fast checks
/// - **Database**: Use index lookups instead of full record reads
/// - **Cloud Storage**: Use metadata queries instead of full object reads
/// - **Batch Operations**: Implement parallel checks for better performance
///
/// ## See Also
///
/// - ``ChunkStorageOrganization`` - Organization protocol
/// - ``ChunkStorageRetrieval`` - Retrieval protocol (fallback for existence checks)
/// - ``ChunkStorage`` - Composed storage protocol
/// - ``FileSystemExistence`` - File system existence implementation
public protocol ChunkStorageExistence: Sendable {
    /// Check if chunk exists by identifier.
    ///
    /// More efficient than reading chunk data just to check existence.
    /// Some backends may implement this with optimized queries (e.g., database index lookup).
    ///
    /// - Parameter identifier: Chunk identifier
    /// - Returns: True if chunk exists
    func chunkExists(identifier: ChunkIdentifier) async -> Bool
    
    /// Batch check existence for multiple chunks.
    ///
    /// Optional - allows backends to optimize batch existence checks.
    /// Implementations may use parallel queries or batch database operations.
    ///
    /// - Parameter identifiers: Array of chunk identifiers
    /// - Returns: Dictionary mapping identifiers to existence status
    func chunkExists(identifiers: [ChunkIdentifier]) async -> [ChunkIdentifier: Bool]
}

