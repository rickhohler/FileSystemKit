// FileSystemKit Core Library
// Metadata Storage Protocol
//
// This file implements the MetadataStorage protocol for storing and retrieving metadata.

import Foundation

/// Protocol for metadata storage operations
///
/// This protocol defines the interface for storing and retrieving metadata about digital assets.
public protocol MetadataStorage: Sendable {
    /// Write/store metadata
    ///
    /// - Parameters:
    ///   - metadata: Metadata to store
    ///   - hash: Hash identifier for the metadata
    /// - Throws: Error if storage fails
    func writeMetadata(_ metadata: DiskImageMetadata, for hash: DiskImageHash) async throws
    
    /// Read/fetch metadata
    ///
    /// - Parameter hash: Hash identifier
    /// - Returns: Metadata, or nil if not found
    /// - Throws: Error if read fails
    func readMetadata(for hash: DiskImageHash) async throws -> DiskImageMetadata?
    
    /// Update metadata
    ///
    /// - Parameters:
    ///   - metadata: Updated metadata
    ///   - hash: Hash identifier
    /// - Throws: Error if update fails
    func updateMetadata(_ metadata: DiskImageMetadata, for hash: DiskImageHash) async throws
    
    /// Delete metadata
    ///
    /// - Parameter hash: Hash identifier
    /// - Throws: Error if deletion fails
    func deleteMetadata(for hash: DiskImageHash) async throws
    
    /// Check if metadata exists
    ///
    /// - Parameter hash: Hash identifier
    /// - Returns: True if metadata exists
    /// - Throws: Error if check fails
    func metadataExists(for hash: DiskImageHash) async throws -> Bool
    
    /// Search metadata by criteria
    ///
    /// - Parameter criteria: Search criteria
    /// - Returns: Array of matching hash identifiers
    /// - Throws: Error if search fails
    func searchMetadata(criteria: DiskImageSearchCriteria) async throws -> [DiskImageHash]
}

// MARK: - Supporting Types

/// Search criteria for disk images
/// Used by MetadataStorage implementations to filter disk images
public struct DiskImageSearchCriteria: Sendable {
    /// Exact hash match
    public let hash: DiskImageHash?
    
    /// Exact filename match
    public let exactFilename: String?
    
    /// Filename contains (partial match)
    public let filenameContains: String?
    
    /// Alternative name match
    public let alternativeName: String?
    
    /// Alternative name contains (partial match)
    public let alternativeNameContains: String?
    
    /// All tags must match (AND operation)
    public let allTags: [String]?
    
    /// Any tag must match (OR operation)
    public let anyTag: [String]?
    
    /// Exact length match
    public let exactLength: Int?
    
    /// Minimum length
    public let minLength: Int?
    
    /// Maximum length
    public let maxLength: Int?
    
    /// Title contains (partial match)
    public let titleContains: String?
    
    /// Publisher match
    public let publisher: String?
    
    /// Developer match
    public let developer: String?
    
    public init(
        hash: DiskImageHash? = nil,
        exactFilename: String? = nil,
        filenameContains: String? = nil,
        alternativeName: String? = nil,
        alternativeNameContains: String? = nil,
        allTags: [String]? = nil,
        anyTag: [String]? = nil,
        exactLength: Int? = nil,
        minLength: Int? = nil,
        maxLength: Int? = nil,
        titleContains: String? = nil,
        publisher: String? = nil,
        developer: String? = nil
    ) {
        self.hash = hash
        self.exactFilename = exactFilename
        self.filenameContains = filenameContains
        self.alternativeName = alternativeName
        self.alternativeNameContains = alternativeNameContains
        self.allTags = allTags
        self.anyTag = anyTag
        self.exactLength = exactLength
        self.minLength = minLength
        self.maxLength = maxLength
        self.titleContains = titleContains
        self.publisher = publisher
        self.developer = developer
    }
}

