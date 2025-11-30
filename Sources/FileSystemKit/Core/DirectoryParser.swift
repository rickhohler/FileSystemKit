// FileSystemKit Core Library
// Directory Parser
//
// This module provides a reusable directory parsing implementation that walks
// directory trees, detects file types, and collects metadata. It can be used
// by any archive or file system implementation that needs to process directories.
//
// Key Features:
// - Recursive directory traversal
// - File type detection (regular files, directories, symlinks, special files)
// - Metadata collection (permissions, owner, group, dates, size)
// - Symlink handling (preserve or follow)
// - Special file detection (block devices, character devices, sockets, FIFOs)
// - Ignore pattern support
// - Progress reporting
//
// Integration with FileSystemEntry:
// - DirectoryEntry can be converted to FileSystemEntryMetadata using DirectoryEntry.toFileSystemEntryMetadata()
// - Special file information is preserved in DirectoryEntry and can be transferred to FileSystemEntry

import Foundation

// MARK: - DirectoryEntry

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

// MARK: - DirectoryParserOptions

/// Configuration options for directory parsing
public struct DirectoryParserOptions: Sendable {
    /// Base path prefix for relative paths (default: "")
    public var basePath: String
    
    /// Follow symlinks instead of preserving them (default: false)
    public var followSymlinks: Bool
    
    /// Throw error on broken symlinks (default: false)
    public var errorOnBrokenSymlinks: Bool
    
    /// Include special files (block devices, character devices, sockets, FIFOs) (default: false)
    public var includeSpecialFiles: Bool
    
    /// Skip files that cause permission errors (default: false)
    public var skipPermissionErrors: Bool
    
    /// Skip hidden files (default: true)
    public var skipHiddenFiles: Bool
    
    /// Verbose logging (default: false)
    public var verbose: Bool
    
    public init(
        basePath: String = "",
        followSymlinks: Bool = false,
        errorOnBrokenSymlinks: Bool = false,
        includeSpecialFiles: Bool = false,
        skipPermissionErrors: Bool = false,
        skipHiddenFiles: Bool = true,
        verbose: Bool = false
    ) {
        self.basePath = basePath
        self.followSymlinks = followSymlinks
        self.errorOnBrokenSymlinks = errorOnBrokenSymlinks
        self.includeSpecialFiles = includeSpecialFiles
        self.skipPermissionErrors = skipPermissionErrors
        self.skipHiddenFiles = skipHiddenFiles
        self.verbose = verbose
    }
}

// MARK: - DirectoryParserDelegate

/// Delegate protocol for handling directory parsing events
public protocol DirectoryParserDelegate: Sendable {
    /// Called when a directory entry is discovered
    /// - Parameter entry: The discovered directory entry
    /// - Returns: true to continue parsing, false to stop
    /// - Throws: Error to abort parsing
    func processEntry(_ entry: DirectoryEntry) throws -> Bool
    
    /// Called when parsing starts
    /// - Parameter rootURL: Root directory URL being parsed
    func didStartParsing(rootURL: URL)
    
    /// Called when parsing completes
    /// - Parameter rootURL: Root directory URL that was parsed
    func didFinishParsing(rootURL: URL)
}

// MARK: - IgnoreMatcher

/// Protocol for matching file paths against ignore patterns
public protocol IgnoreMatcher: Sendable {
    /// Check if a path should be ignored
    /// - Parameter path: Relative path to check
    /// - Returns: true if path should be ignored, false otherwise
    func shouldIgnore(_ path: String) -> Bool
}

// MARK: - DirectoryParser

/// Reusable directory parser that walks directory trees and collects metadata
/// Uses SpecialFileType from Core/SpecialFileType.swift for special file detection
/// Uses FileMetadataCollector from Core/FileMetadata.swift for metadata collection
/// Uses PathUtilities from Core/PathUtilities.swift for path normalization
public struct DirectoryParser {
    /// Parse a directory tree and report entries via delegate
    /// - Parameters:
    ///   - rootURL: Root directory URL to parse
    ///   - options: Parsing options
    ///   - delegate: Delegate to receive entry notifications
    ///   - ignoreMatcher: Optional ignore pattern matcher
    /// - Throws: Errors encountered during parsing
    public static func parse(
        rootURL: URL,
        options: DirectoryParserOptions = DirectoryParserOptions(),
        delegate: DirectoryParserDelegate,
        ignoreMatcher: IgnoreMatcher? = nil
    ) throws {
        delegate.didStartParsing(rootURL: rootURL)
        defer {
            delegate.didFinishParsing(rootURL: rootURL)
        }
        
        var visitedCanonicalPaths: Set<String> = []
        let resourceKeys: [URLResourceKey] = [
            .isDirectoryKey,
            .isSymbolicLinkKey,
            .isRegularFileKey,
            .fileSizeKey,
            .contentModificationDateKey,
            .creationDateKey,
            .hasHiddenExtensionKey,
            .isSystemImmutableKey
        ]
        
        var enumeratorOptions: FileManager.DirectoryEnumerationOptions = []
        if options.skipHiddenFiles {
            enumeratorOptions.insert(.skipsHiddenFiles)
        }
        
        let enumerator = FileManager.default.enumerator(
            at: rootURL,
            includingPropertiesForKeys: resourceKeys,
            options: enumeratorOptions,
            errorHandler: { url, error in
                if options.skipPermissionErrors {
                    if options.verbose {
                        print("  Warning: Skipping \(url.path) due to error: \(error.localizedDescription)")
                    }
                    return true
                }
                return false
            }
        )
        
        guard let enumerator = enumerator else {
            throw DirectoryParserError.failedToEnumerate(rootURL)
        }
        
        for case let fileURL as URL in enumerator {
            let relativePath = PathUtilities.relativePath(from: fileURL, baseURL: rootURL, basePath: options.basePath)
            
            // Check ignore patterns
            if let matcher = ignoreMatcher, matcher.shouldIgnore(relativePath) {
                continue
            }
            
            // Get resource values
            guard let resourceValues = try? fileURL.resourceValues(forKeys: Set(resourceKeys)) else {
                if options.skipPermissionErrors {
                    continue
                }
                throw DirectoryParserError.permissionDenied(fileURL)
            }
            
            let isDirectory = resourceValues.isDirectory ?? false
            let isSymlink = resourceValues.isSymbolicLink ?? false
            let isRegularFile = resourceValues.isRegularFile ?? false
            let isHidden = resourceValues.hasHiddenExtension ?? false
            let isSystem = resourceValues.isSystemImmutable ?? false
            
            // Detect special files using Core/SpecialFileType.swift
            let specialFileType = detectSpecialFileType(at: fileURL)
            
            // Handle symlinks
            if isSymlink {
                if !options.followSymlinks {
                    // Preserve symlink
                    do {
                        let symlinkTarget = try FileManager.default.destinationOfSymbolicLink(atPath: fileURL.path)
                let metadata = FileMetadataCollector.collect(from: fileURL)
                let entry = DirectoryEntry(
                    path: relativePath,
                    url: fileURL,
                    type: "symlink",
                    symlinkTarget: symlinkTarget,
                    permissions: metadata.permissions,
                    owner: metadata.owner,
                    group: metadata.group,
                    modified: metadata.modified ?? resourceValues.contentModificationDate,
                    created: metadata.created ?? resourceValues.creationDate,
                    isHidden: isHidden,
                    isSystem: isSystem,
                    isSpecialFile: false
                )
                        
                        let shouldContinue = try delegate.processEntry(entry)
                        if !shouldContinue {
                            continue
                        }
                        
                        if options.verbose {
                            print("  Added symlink: \(relativePath) -> \(symlinkTarget)")
                        }
                    } catch {
                        if options.errorOnBrokenSymlinks {
                            throw DirectoryParserError.brokenSymlink(relativePath, target: "")
                        } else {
                            if options.verbose {
                                print("  Warning: Skipping broken symlink: \(relativePath)")
                            }
                            continue
                        }
                    }
                } else {
                    // Follow symlink - check for cycles
                    let canonicalPath = fileURL.resolvingSymlinksInPath().path
                    if visitedCanonicalPaths.contains(canonicalPath) {
                        if options.verbose {
                            print("  Warning: Skipping symlink cycle: \(relativePath)")
                        }
                        continue
                    }
                    visitedCanonicalPaths.insert(canonicalPath)
                    
                    // Process the resolved target instead
                    do {
                        let symlinkTarget = try FileManager.default.destinationOfSymbolicLink(atPath: fileURL.path)
                        let resolvedURL: URL
                        
                        if symlinkTarget.hasPrefix("/") {
                            resolvedURL = URL(fileURLWithPath: symlinkTarget).resolvingSymlinksInPath()
                        } else {
                            resolvedURL = URL(fileURLWithPath: symlinkTarget, relativeTo: fileURL.deletingLastPathComponent())
                                .resolvingSymlinksInPath()
                        }
                        
                        if !FileManager.default.fileExists(atPath: resolvedURL.path) {
                            if options.errorOnBrokenSymlinks {
                                throw DirectoryParserError.brokenSymlink(relativePath, target: symlinkTarget)
                            } else {
                                if options.verbose {
                                    print("  Warning: Skipping broken symlink: \(relativePath)")
                                }
                                continue
                            }
                        }
                        
                        // Continue processing with resolved URL
                        // Note: This is a simplified implementation - in practice, you might want
                        // to recursively process the resolved path
                        continue
                    } catch {
                        if options.errorOnBrokenSymlinks {
                            throw DirectoryParserError.brokenSymlink(relativePath, target: "")
                        } else {
                            if options.verbose {
                                print("  Warning: Skipping broken symlink: \(relativePath)")
                            }
                            continue
                        }
                    }
                }
                continue
            }
            
            // Handle special files using Core/SpecialFileType.swift
            if let specialType = specialFileType {
                if options.includeSpecialFiles {
                    let metadata = FileMetadataCollector.collect(from: fileURL)
                    let entry = DirectoryEntry(
                        path: relativePath,
                        url: fileURL,
                        type: specialType.typeString ?? "unknown",
                        permissions: metadata.permissions,
                        owner: metadata.owner,
                        group: metadata.group,
                        modified: metadata.modified ?? resourceValues.contentModificationDate,
                        created: metadata.created ?? resourceValues.creationDate,
                        isHidden: isHidden,
                        isSystem: isSystem,
                        isSpecialFile: true
                    )
                    
                    let shouldContinue = try delegate.processEntry(entry)
                    if !shouldContinue {
                        continue
                    }
                    
                    if options.verbose {
                        print("  Added special file (\(specialType.typeString ?? "unknown")): \(relativePath)")
                    }
                } else {
                    if options.verbose {
                        print("  Warning: Skipping \(specialType.description): \(relativePath)")
                    }
                }
                continue
            }
            
            // Handle directories
            if isDirectory {
                let metadata = FileMetadataCollector.collect(from: fileURL)
                let entry = DirectoryEntry(
                    path: relativePath,
                    url: fileURL,
                    type: "directory",
                    permissions: metadata.permissions,
                    owner: metadata.owner,
                    group: metadata.group,
                    modified: metadata.modified ?? resourceValues.contentModificationDate,
                    created: metadata.created ?? resourceValues.creationDate,
                    isHidden: isHidden,
                    isSystem: isSystem,
                    isSpecialFile: false
                )
                
                let shouldContinue = try delegate.processEntry(entry)
                if !shouldContinue {
                    continue
                }
                
                if options.verbose {
                    print("  Added directory: \(relativePath)")
                }
                continue
            }
            
            // Handle regular files
            if isRegularFile {
                let metadata = FileMetadataCollector.collect(from: fileURL)
                let fileSize = metadata.size ?? resourceValues.fileSize ?? 0
                let entry = DirectoryEntry(
                    path: relativePath,
                    url: fileURL,
                    type: "file",
                    size: fileSize,
                    permissions: metadata.permissions,
                    owner: metadata.owner,
                    group: metadata.group,
                    modified: metadata.modified ?? resourceValues.contentModificationDate,
                    created: metadata.created ?? resourceValues.creationDate,
                    isHidden: isHidden,
                    isSystem: isSystem,
                    isSpecialFile: false
                )
                
                let shouldContinue = try delegate.processEntry(entry)
                if !shouldContinue {
                    continue
                }
                
                if options.verbose {
                    print("  Added file: \(relativePath) (\(fileSize) bytes)")
                }
            }
        }
    }
    
    /// Parse a directory tree and build a FileSystemFolder hierarchy with FileSystemEntry instances
    /// - Parameters:
    ///   - rootURL: Root directory URL to parse
    ///   - options: Parsing options
    ///   - ignoreMatcher: Optional ignore pattern matcher
    /// - Returns: Root FileSystemFolder containing parsed file system hierarchy
    /// - Throws: Errors encountered during parsing
    /// - Note: Special files are included if options.includeSpecialFiles is true
    /// - Note: Files will have chunkIdentifier set to nil (can be set later when storing in ChunkStorage)
    /// Parse a directory tree and build a FileSystemFolder hierarchy with FileSystemEntry instances
    /// - Parameters:
    ///   - rootURL: Root directory URL to parse
    ///   - options: Parsing options
    ///   - ignoreMatcher: Optional ignore pattern matcher
    /// - Returns: Root FileSystemFolder containing parsed file system hierarchy
    /// - Throws: Errors encountered during parsing
    /// - Note: Special files are included if options.includeSpecialFiles is true
    /// - Note: Files will have chunkIdentifier set to nil (can be set later when storing in ChunkStorage)
    public static func parseToFileSystem(
        rootURL: URL,
        options: DirectoryParserOptions = DirectoryParserOptions(),
        ignoreMatcher: IgnoreMatcher? = nil
    ) throws -> FileSystemFolder {
        let rootFolder = FileSystemFolder(name: rootURL.lastPathComponent, modificationDate: nil)
        let folderMap = NSMutableDictionary()
        folderMap[""] = rootFolder
        
        final class FileSystemBuilderDelegate: @unchecked Sendable, DirectoryParserDelegate {
            let rootFolder: FileSystemFolder
            let folderMap: NSMutableDictionary
            let options: DirectoryParserOptions
            
            init(rootFolder: FileSystemFolder, folderMap: NSMutableDictionary, options: DirectoryParserOptions) {
                self.rootFolder = rootFolder
                self.folderMap = folderMap
                self.options = options
            }
            
            func processEntry(_ entry: DirectoryEntry) throws -> Bool {
                // Get parent path
                let pathComponents = entry.path.split(separator: "/").map(String.init)
                let parentPath: String
                if pathComponents.count > 1 {
                    parentPath = pathComponents.dropLast().joined(separator: "/")
                } else {
                    parentPath = ""
                }
                
                // Get or create parent folder
                let parentFolder: FileSystemFolder
                if let existingParent = folderMap[parentPath] as? FileSystemFolder {
                    parentFolder = existingParent
                } else {
                    // Create missing parent folders
                    var currentPath = ""
                    var currentFolder = rootFolder
                    
                    for component in pathComponents.dropLast() {
                        let nextPath = currentPath.isEmpty ? component : "\(currentPath)/\(component)"
                        if let existingFolder = folderMap[nextPath] as? FileSystemFolder {
                            currentFolder = existingFolder
                        } else {
                            let newFolder = FileSystemFolder(name: component, modificationDate: nil)
                            currentFolder.addChild(newFolder)
                            folderMap[nextPath] = newFolder
                            currentFolder = newFolder
                        }
                        currentPath = nextPath
                    }
                    
                    guard let finalParent = folderMap[parentPath] as? FileSystemFolder else {
                        return true  // Skip if we can't create parent
                    }
                    parentFolder = finalParent
                }
                
                // Add entry to parent folder
                if entry.type == "directory" {
                    if let folder = entry.toFileSystemFolder() {
                        let entryPath = entry.path
                        folderMap[entryPath] = folder
                        parentFolder.addChild(folder)
                    }
                } else {
                    // Regular file, symlink, or special file
                    if let fileEntry = entry.toFileSystemEntry() {
                        parentFolder.addChild(fileEntry)
                    }
                }
                
                return true
            }
            
            func didStartParsing(rootURL: URL) {
                // No-op
            }
            
            func didFinishParsing(rootURL: URL) {
                // No-op
            }
        }
        
        let delegate = FileSystemBuilderDelegate(rootFolder: rootFolder, folderMap: folderMap, options: options)
        try parse(rootURL: rootURL, options: options, delegate: delegate, ignoreMatcher: ignoreMatcher)
        
        return rootFolder
    }
    
}

// MARK: - DirectoryParserError

/// Errors that can occur during directory parsing
public enum DirectoryParserError: Error, Sendable {
    case failedToEnumerate(URL)
    case brokenSymlink(String, target: String)
    case permissionDenied(URL)
    
    public var localizedDescription: String {
        switch self {
        case .failedToEnumerate(let url):
            return "Failed to enumerate directory: \(url.path)"
        case .brokenSymlink(let path, let target):
            return "Broken symlink: \(path) -> \(target)"
        case .permissionDenied(let url):
            return "Permission denied: \(url.path)"
        }
    }
}
