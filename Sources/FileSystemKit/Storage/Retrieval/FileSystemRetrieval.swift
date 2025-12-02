// FileSystemKit Core Library
// File System Retrieval Implementation
//
// This file implements ChunkStorageRetrieval using the local file system.

import Foundation

/// File system-based chunk retrieval implementation.
///
/// `FileSystemRetrieval` reads and writes chunks to the local file system.
/// This is the default retrieval implementation for file system-based storage.
///
/// ## Overview
///
/// The retrieval implementation:
/// - Reads chunks from file system using paths
/// - Writes chunks to file system, creating directories as needed
/// - Checks existence using file system APIs
/// - Deletes chunks and associated metadata files
///
/// ## Usage
///
/// Create retrieval with base URL:
/// ```swift
/// let baseURL = URL(fileURLWithPath: "/path/to/storage")
/// let retrieval = FileSystemRetrieval(baseURL: baseURL)
///
/// let path = "a1/b2/a1b2c3d4..."
/// try await retrieval.writeChunk(data, at: path, metadata: metadata)
/// let data = try await retrieval.readChunk(at: path)
/// ```
///
/// Wrap with compression:
/// ```swift
/// let baseRetrieval = FileSystemRetrieval(baseURL: baseURL)
/// let compressedRetrieval = CompressedRetrieval(wrapped: baseRetrieval)
/// ```
///
/// ## Metadata Storage
///
/// When metadata is provided, it's stored in a separate `.meta` file alongside
/// the chunk data. This allows metadata to be read without loading the full chunk.
///
/// ## See Also
///
/// - ``ChunkStorageRetrieval`` - Retrieval protocol
/// - ``ChunkStorageOrganization`` - Organization protocol
/// - ``ChunkStorage`` - Composed storage protocol
public struct FileSystemRetrieval: ChunkStorageRetrieval {
    /// Base URL for chunk storage.
    private let baseURL: URL
    
    /// Create file system retrieval with base URL.
    ///
    /// - Parameter baseURL: Base directory for chunk storage
    public init(baseURL: URL) {
        self.baseURL = baseURL
    }
    
    /// Read chunk data from storage.
    ///
    /// Reads chunk data from the file system at the specified path.
    ///
    /// - Parameter path: Storage path (from organization strategy)
    /// - Returns: Chunk data, or nil if not found
    /// - Throws: Error if read fails
    public func readChunk(at path: String) async throws -> Data? {
        let fileURL = baseURL.appendingPathComponent(path)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        return try Data(contentsOf: fileURL)
    }
    
    /// Write chunk data to storage.
    ///
    /// Writes chunk data to the file system at the specified path.
    /// Creates directory structure if needed.
    ///
    /// - Parameters:
    ///   - data: Chunk data to write
    ///   - path: Storage path (from organization strategy)
    ///   - metadata: Optional chunk metadata (stored in separate .meta file)
    /// - Throws: Error if write fails
    public func writeChunk(_ data: Data, at path: String, metadata: ChunkMetadata?) async throws {
        let fileURL = baseURL.appendingPathComponent(path)
        
        // Create directory structure if needed
        let directoryURL = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        
        // Write chunk data
        try data.write(to: fileURL)
        
        // Write metadata if provided (optional)
        if let metadata = metadata {
            let metadataURL = fileURL.appendingPathExtension("meta")
            let encoder = JSONEncoder()
            let metadataData = try encoder.encode(metadata)
            try metadataData.write(to: metadataURL)
        }
    }
    
    /// Check if chunk exists at path.
    ///
    /// Uses file system APIs for efficient existence check.
    ///
    /// - Parameter path: Storage path (from organization strategy)
    /// - Returns: True if chunk exists
    public func chunkExists(at path: String) async -> Bool {
        let fileURL = baseURL.appendingPathComponent(path)
        return FileManager.default.fileExists(atPath: fileURL.path)
    }
    
    /// Delete chunk at path.
    ///
    /// Deletes both the chunk data file and associated metadata file (if present).
    ///
    /// - Parameter path: Storage path (from organization strategy)
    /// - Throws: Error if deletion fails
    public func deleteChunk(at path: String) async throws {
        let fileURL = baseURL.appendingPathComponent(path)
        try FileManager.default.removeItem(at: fileURL)
        
        // Also delete metadata if it exists
        let metadataURL = fileURL.appendingPathExtension("meta")
        try? FileManager.default.removeItem(at: metadataURL)
    }
}

