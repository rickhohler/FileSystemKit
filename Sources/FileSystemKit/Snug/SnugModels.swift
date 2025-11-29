// FileSystemKit - SNUG Archive Data Models
// YAML structure definitions for SNUG archives

import Foundation

/// SNUG archive structure
public struct SnugArchive: Codable, Sendable {
    public let format: String
    public let version: Int
    public let hashAlgorithm: String
    public let hashes: [String: HashDefinition]?
    public let metadata: MetadataTemplate?
    public let entries: [ArchiveEntry]
    
    public init(format: String, version: Int, hashAlgorithm: String, hashes: [String: HashDefinition]?, metadata: MetadataTemplate?, entries: [ArchiveEntry]) {
        self.format = format
        self.version = version
        self.hashAlgorithm = hashAlgorithm
        self.hashes = hashes
        self.metadata = metadata
        self.entries = entries
    }
}

/// Hash definition for SNUG archive
public struct HashDefinition: Codable, Sendable {
    public let hash: String
    public let size: Int
    public let algorithm: String?
    
    public init(hash: String, size: Int, algorithm: String?) {
        self.hash = hash
        self.size = size
        self.algorithm = algorithm
    }
}

/// Metadata template for SNUG archive
public struct MetadataTemplate: Codable, Sendable {
    public let owner: String?
    public let group: String?
    public let filePerms: String?
    public let dirPerms: String?
    
    public init(owner: String?, group: String?, filePerms: String?, dirPerms: String?) {
        self.owner = owner
        self.group = group
        self.filePerms = filePerms
        self.dirPerms = dirPerms
    }
}

/// Archive entry for SNUG archive
public struct ArchiveEntry: Codable, Sendable {
    public let type: String  // "file", "directory", "symlink"
    public let path: String
    public let hash: String?
    public let size: Int?
    public let permissions: String?
    public let owner: String?
    public let group: String?
    public let modified: Date?
    public let created: Date?
    
    public init(type: String, path: String, hash: String?, size: Int?, permissions: String?, owner: String?, group: String?, modified: Date?, created: Date?) {
        self.type = type
        self.path = path
        self.hash = hash
        self.size = size
        self.permissions = permissions
        self.owner = owner
        self.group = group
        self.modified = modified
        self.created = created
    }
}

