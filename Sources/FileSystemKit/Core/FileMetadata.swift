// FileSystemKit Core Library
// File Metadata Collection
//
// This module provides utilities for collecting file system metadata
// (permissions, owner, group, dates, etc.) that can be reused across
// different archive and file system implementations.

import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

// MARK: - FileSystemMetadata

/// Represents file system metadata for a file or directory
/// Note: This is distinct from FileMetadata in FileSystemComponent which is for file content metadata
public struct FileSystemMetadata: Sendable {
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
    
    /// File size in bytes (nil for directories and special files)
    public let size: Int?
    
    /// True if file is executable
    public let isExecutable: Bool
    
    public init(
        permissions: String? = nil,
        owner: String? = nil,
        group: String? = nil,
        modified: Date? = nil,
        created: Date? = nil,
        size: Int? = nil,
        isExecutable: Bool = false
    ) {
        self.permissions = permissions
        self.owner = owner
        self.group = group
        self.modified = modified
        self.created = created
        self.size = size
        self.isExecutable = isExecutable
    }
}

// MARK: - FileMetadataCollector

/// Utility for collecting file system metadata
public struct FileMetadataCollector {
    /// Collect metadata for a file or directory
    /// - Parameter url: File URL to collect metadata from
    /// - Returns: FileSystemMetadata with collected information
    public static func collect(from url: URL) -> FileSystemMetadata {
        let permissions = getPermissions(from: url)
        let (owner, group) = getOwnerAndGroup(from: url)
        
        // Get resource values for dates and size
        let resourceKeys: [URLResourceKey] = [
            .contentModificationDateKey,
            .creationDateKey,
            .fileSizeKey,
            .isExecutableKey
        ]
        
        let resourceValues = try? url.resourceValues(forKeys: Set(resourceKeys))
        
        return FileSystemMetadata(
            permissions: permissions,
            owner: owner,
            group: group,
            modified: resourceValues?.contentModificationDate,
            created: resourceValues?.creationDate,
            size: resourceValues?.fileSize,
            isExecutable: resourceValues?.isExecutable ?? false
        )
    }
    
    /// Get file permissions as octal string
    /// - Parameter url: File URL
    /// - Returns: Permissions as octal string (e.g., "0644") or nil if unavailable
    public static func getPermissions(from url: URL) -> String? {
        // Try using stat() first (more reliable)
        var statInfo = stat()
        if stat(url.path, &statInfo) == 0 {
            let mode = statInfo.st_mode & 0o7777
            return String(format: "%04o", mode)
        }
        
        // Fallback to FileManager attributes
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            if let permissions = attributes[.posixPermissions] as? NSNumber {
                return String(format: "%04o", permissions.intValue)
            }
        } catch {
            // Ignore errors - permissions are optional
        }
        
        return nil
    }
    
    /// Get owner and group names for a file
    /// - Parameter url: File URL
    /// - Returns: Tuple of (owner, group) names, either may be nil
    public static func getOwnerAndGroup(from url: URL) -> (owner: String?, group: String?) {
        var owner: String? = nil
        var group: String? = nil
        
        // Try using stat() first (more reliable)
        var statInfo = stat()
        if stat(url.path, &statInfo) == 0 {
            #if canImport(Darwin)
            if let passwd = getpwuid(statInfo.st_uid) {
                owner = String(cString: passwd.pointee.pw_name)
            }
            if let grp = getgrgid(statInfo.st_gid) {
                group = String(cString: grp.pointee.gr_name)
            }
            #endif
        }
        
        // Fallback to FileManager attributes if stat() didn't provide names
        if owner == nil || group == nil {
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                if owner == nil, let ownerName = attributes[.ownerAccountName] as? String {
                    owner = ownerName
                }
                if group == nil, let groupName = attributes[.groupOwnerAccountName] as? String {
                    group = groupName
                }
            } catch {
                // Ignore errors - owner/group are optional
            }
        }
        
        return (owner, group)
    }
}

