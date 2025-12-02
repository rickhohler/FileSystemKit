// FileSystemKit Core Library
// Chunk Storage Composable Protocol Extension
//
// This file extends the existing ChunkStorage protocol to support the composable design.
// This allows backward compatibility while adding the new flexible architecture.

import Foundation

/// Composable chunk storage protocol that extends the existing `ChunkStorage` protocol.
///
/// This protocol composes organization, retrieval, and existence protocols into a
/// complete storage solution. It extends the existing `ChunkStorage` protocol to
/// maintain backward compatibility while adding the new composable architecture.
///
/// ## Overview
///
/// The composable design allows clients to:
/// - Mix and match different organization strategies
/// - Use different retrieval implementations
/// - Add optional existence checking
/// - Wrap retrieval implementations with compression, caching, etc.
///
/// ## Usage
///
/// Create storage with composable components:
/// ```swift
/// let organization = GitStyleOrganization(directoryDepth: 2)
/// let retrieval = FileSystemRetrieval(baseURL: storageURL)
/// let existence = FileSystemExistence(organization: organization, baseURL: storageURL)
///
/// struct MyChunkStorage: ChunkStorageComposable {
///     let organization: ChunkStorageOrganization
///     let retrieval: ChunkStorageRetrieval
///     let existence: ChunkStorageExistence?
/// }
///
/// let storage = MyChunkStorage(
///     organization: organization,
///     retrieval: retrieval,
///     existence: existence
/// )
/// ```
///
/// ## See Also
///
/// - ``ChunkStorage`` - Base chunk storage protocol
/// - ``ChunkStorageOrganization`` - Organization protocol
/// - ``ChunkStorageRetrieval`` - Retrieval protocol
/// - ``ChunkStorageExistence`` - Existence checking protocol
public protocol ChunkStorageComposable: ChunkStorage {
    /// Organization strategy for this storage.
    ///
    /// Defines how chunks are organized in the storage backend.
    var organization: ChunkStorageOrganization { get }
    
    /// Retrieval mechanism for this storage.
    ///
    /// Defines how chunks are read and written.
    var retrieval: ChunkStorageRetrieval { get }
    
    /// Optional existence checker for this storage.
    ///
    /// If provided, used for optimized existence checks.
    /// If nil, falls back to `retrieval.chunkExists(at:)`.
    var existence: ChunkStorageExistence? { get }
}

