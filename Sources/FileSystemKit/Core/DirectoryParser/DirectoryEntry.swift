// FileSystemKit Core Library
// DirectoryEntry
//
// Represents a file system entry discovered during directory parsing.
// Can be converted to FileSystemEntryMetadata for use with FileSystemEntry.

import Foundation

/// Represents a file system entry discovered during directory parsing
/// Can be converted to FileSystemEntryMetadata for use with FileSystemEntry
public struct DirectoryEntry: Sendable {
    /// Relative path from the root directory
    public let path: String
    
    /// Absolute file URL
    public let url: URL
    
    /// File type: "file", "directory", "symlink", "block-device", "character-device", "socket", "fifo"
    public let type: String
    
    /// File size in bytes (nil for directories and special files)
    public let size: Int?
    
    /// Symlink target path (only for symlinks)
    public let symlinkTarget: String?
    
    /// File permissions as octal string (e.g., "0644")
    public let permissions: String?
    
    /// File owner name
    public let owner: String?
    
    /// File group name
    public let group: String?
    
    /// Modification date
    public let modified: Date?
    
    /// Creation date
    public let created: Date?
    
    /// True if this is a hidden file
    public let isHidden: Bool
    
    /// True if this is a system file
    public let isSystem: Bool
    
    /// True if this is a special file (block device, character device, socket, FIFO)
    public let isSpecialFile: Bool
    
    public init(
        path: String,
        url: URL,
        type: String,
        size: Int? = nil,
        symlinkTarget: String? = nil,
        permissions: String? = nil,
        owner: String? = nil,
        group: String? = nil,
        modified: Date? = nil,
        created: Date? = nil,
        isHidden: Bool = false,
        isSystem: Bool = false,
        isSpecialFile: Bool = false
    ) {
        self.path = path
        self.url = url
        self.type = type
        self.size = size
        self.symlinkTarget = symlinkTarget
        self.permissions = permissions
        self.owner = owner
        self.group = group
        self.modified = modified
        self.created = created
        self.isHidden = isHidden
        self.isSystem = isSystem
        self.isSpecialFile = isSpecialFile
    }
    
    /// Convert this DirectoryEntry to FileSystemEntryMetadata for use with FileSystemEntry
    /// - Returns: FileSystemEntryMetadata with information from this DirectoryEntry
    /// - Note: Special file information is preserved in the specialFileType property
    public func toFileSystemEntryMetadata() -> FileSystemEntryMetadata {
        // Extract filename from path
        let fileName = (path as NSString).lastPathComponent
        
        // Determine special file type string if this is a special file
        let specialFileType: String?
        if isSpecialFile {
            // Map DirectoryEntry type to special file type string
            switch type {
            case "block-device":
                specialFileType = "block-device"
            case "character-device":
                specialFileType = "character-device"
            case "socket":
                specialFileType = "socket"
            case "fifo":
                specialFileType = "fifo"
            default:
                specialFileType = type  // Use type as-is if it's already a special file type string
            }
        } else {
            specialFileType = nil
        }
        
        // Build attributes dictionary with additional metadata
        var attributes: [String: Any] = [:]
        if let permissions = permissions {
            attributes["permissions"] = permissions
        }
        if let owner = owner {
            attributes["owner"] = owner
        }
        if let group = group {
            attributes["group"] = group
        }
        if let created = created {
            attributes["created"] = created
        }
        if isHidden {
            attributes["isHidden"] = true
        }
        if isSystem {
            attributes["isSystem"] = true
        }
        if let symlinkTarget = symlinkTarget {
            attributes["symlinkTarget"] = symlinkTarget
        }
        
        return FileSystemEntryMetadata(
            name: fileName,
            size: size ?? 0,
            modificationDate: modified,
            fileType: nil,  // FileTypeCategory can be determined separately if needed
            specialFileType: specialFileType,
            attributes: attributes,
            location: nil,  // DirectoryEntry doesn't have disk image location
            hashes: [:]
        )
    }
    
    /// Convert this DirectoryEntry to a FileSystemEntry instance
    /// - Parameter chunkIdentifier: Optional chunk identifier if file data is stored in ChunkStorage
    /// - Returns: FileSystemEntry instance with metadata from this DirectoryEntry
    /// - Note: For directories, this returns nil (use FileSystemFolder instead)
    /// - Note: Special files are supported and will have specialFileType set in metadata
    public func toFileSystemEntry(chunkIdentifier: ChunkIdentifier? = nil) -> FileSystemEntry? {
        // Directories should use FileSystemFolder, not FileSystemEntry
        guard type != "directory" else {
            return nil
        }
        
        let metadata = toFileSystemEntryMetadata()
        return FileSystemEntry(metadata: metadata, chunkIdentifier: chunkIdentifier)
    }
    
    /// Convert this DirectoryEntry to a FileSystemFolder instance
    /// - Returns: FileSystemFolder instance if this is a directory, nil otherwise
    public func toFileSystemFolder() -> FileSystemFolder? {
        guard type == "directory" else {
            return nil
        }
        
        return FileSystemFolder(name: (path as NSString).lastPathComponent, modificationDate: modified)
    }
}

