// FileSystemKit Core Library
// File System Existence Implementation
//
// This file implements ChunkStorageExistence using the local file system.

import Foundation

/// File system-based existence checking implementation.
///
/// `FileSystemExistence` provides optimized existence checks using file system APIs.
/// This is more efficient than reading chunk data just to check if it exists.
///
/// ## Overview
///
/// The existence implementation:
/// - Uses `FileManager.fileExists(atPath:)` for fast checks
/// - Supports batch existence checks
/// - More efficient than reading chunk data
///
/// ## Usage
///
/// Create existence checker:
/// ```swift
/// let organization = GitStyleOrganization()
/// let baseURL = URL(fileURLWithPath: "/path/to/storage")
/// let existence = FileSystemExistence(organization: organization, baseURL: baseURL)
///
/// let identifier = ChunkIdentifier(id: "a1b2c3d4...")
/// if await existence.chunkExists(identifier: identifier) {
///     print("Chunk exists")
/// }
/// ```
///
/// Batch existence check:
/// ```swift
/// let identifiers = [id1, id2, id3]
/// let results = await existence.chunkExists(identifiers: identifiers)
/// for (identifier, exists) in results {
///     print("\(identifier.id): \(exists)")
/// }
/// ```
///
/// ## See Also
///
/// - ``ChunkStorageExistence`` - Existence protocol
/// - ``ChunkStorageOrganization`` - Organization protocol
/// - ``FileSystemRetrieval`` - File system retrieval implementation
public struct FileSystemExistence: ChunkStorageExistence {
    /// Organization strategy for path generation.
    private let organization: ChunkStorageOrganization
    
    /// Base URL for chunk storage.
    private let baseURL: URL
    
    /// Create file system existence checker.
    ///
    /// - Parameters:
    ///   - organization: Organization strategy for path generation
    ///   - baseURL: Base directory for chunk storage
    public init(organization: ChunkStorageOrganization, baseURL: URL) {
        self.organization = organization
        self.baseURL = baseURL
    }
    
    /// Check if chunk exists by identifier.
    ///
    /// Uses file system APIs for efficient existence check.
    ///
    /// - Parameter identifier: Chunk identifier
    /// - Returns: True if chunk exists
    public func chunkExists(identifier: ChunkIdentifier) async -> Bool {
        let path = organization.storagePath(for: identifier)
        let fileURL = baseURL.appendingPathComponent(path)
        return FileManager.default.fileExists(atPath: fileURL.path)
    }
    
    /// Batch check existence for multiple chunks.
    ///
    /// Checks existence for multiple chunks efficiently.
    ///
    /// - Parameter identifiers: Array of chunk identifiers
    /// - Returns: Dictionary mapping identifiers to existence status
    public func chunkExists(identifiers: [ChunkIdentifier]) async -> [ChunkIdentifier: Bool] {
        var results: [ChunkIdentifier: Bool] = [:]
        
        for identifier in identifiers {
            let path = organization.storagePath(for: identifier)
            let fileURL = baseURL.appendingPathComponent(path)
            results[identifier] = FileManager.default.fileExists(atPath: fileURL.path)
        }
        
        return results
    }
}

