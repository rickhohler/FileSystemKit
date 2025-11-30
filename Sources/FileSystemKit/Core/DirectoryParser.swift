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

import Foundation

// MARK: - DirectoryEntry

/// Represents a file system entry discovered during directory parsing
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

/// Delegate protocol for processing directory entries during parsing
public protocol DirectoryParserDelegate: Sendable {
    /// Called when a directory entry is discovered
    /// - Parameter entry: The discovered directory entry
    /// - Returns: True to continue parsing, false to skip this entry
    func processEntry(_ entry: DirectoryEntry) throws -> Bool
    
    /// Called when an error occurs during parsing
    /// - Parameters:
    ///   - url: The URL that caused the error
    ///   - error: The error that occurred
    /// - Returns: True to continue parsing, false to stop
    func handleError(url: URL, error: Error) -> Bool
}

// MARK: - IgnoreMatcher

/// Protocol for matching paths against ignore patterns
public protocol IgnoreMatcher: Sendable {
    /// Check if a path should be ignored
    /// - Parameter path: Relative path to check
    /// - Returns: True if the path should be ignored
    func shouldIgnore(_ path: String) -> Bool
}

// MARK: - DirectoryParser

/// Parses directories and discovers file system entries with metadata
public class DirectoryParser {
    private let options: DirectoryParserOptions
    private let delegate: DirectoryParserDelegate
    private let ignoreMatcher: IgnoreMatcher?
    
    /// Initialize a directory parser
    /// - Parameters:
    ///   - options: Parsing options
    ///   - delegate: Delegate to process discovered entries
    ///   - ignoreMatcher: Optional ignore pattern matcher
    public init(
        options: DirectoryParserOptions,
        delegate: DirectoryParserDelegate,
        ignoreMatcher: IgnoreMatcher? = nil
    ) {
        self.options = options
        self.delegate = delegate
        self.ignoreMatcher = ignoreMatcher
    }
    
    /// Parse a directory tree
    /// - Parameter rootURL: Root directory URL to parse
    /// - Throws: Errors encountered during parsing (if not handled by delegate)
    public func parse(_ rootURL: URL) throws {
        let resourceKeys: [URLResourceKey] = [
            .isDirectoryKey,
            .isSymbolicLinkKey,
            .isRegularFileKey,
            .hasHiddenExtensionKey,
            .isUserImmutableKey,
            .isSystemImmutableKey,
            .fileSizeKey,
            .contentModificationDateKey,
            .creationDateKey,
            .isExecutableKey
        ]
        
        var enumeratorOptions: FileManager.DirectoryEnumerationOptions = []
        if options.skipHiddenFiles {
            enumeratorOptions.insert(.skipsHiddenFiles)
        }
        
        let enumerator = FileManager.default.enumerator(
            at: rootURL,
            includingPropertiesForKeys: resourceKeys,
            options: enumeratorOptions,
            errorHandler: { [weak self] (url, error) -> Bool in
                guard let self = self else { return false }
                return self.delegate.handleError(url: url, error: error)
            }
        )
        
        guard let enumerator = enumerator else {
            throw DirectoryParserError.failedToEnumerate(rootURL)
        }
        
        var visitedCanonicalPaths: Set<String> = []
        
        for case let fileURL as URL in enumerator {
            // Normalize path
            var relativePath = fileURL.path.replacingOccurrences(of: rootURL.path, with: options.basePath)
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            relativePath = normalizePath(relativePath)
            
            // Check ignore patterns
            if let matcher = ignoreMatcher, matcher.shouldIgnore(relativePath) {
                if options.verbose {
                    print("  Ignored: \(relativePath)")
                }
                continue
            }
            
            // Get resource values
            let resourceValues: URLResourceValues
            do {
                resourceValues = try fileURL.resourceValues(forKeys: Set(resourceKeys))
            } catch {
                if options.skipPermissionErrors {
                    if options.verbose {
                        print("  Warning: Skipping \(relativePath) due to permission error: \(error.localizedDescription)")
                    }
                    continue
                }
                throw error
            }
            
            let isDirectory = resourceValues.isDirectory ?? false
            let isSymlink = resourceValues.isSymbolicLink ?? false
            let isRegularFile = resourceValues.isRegularFile ?? false
            let isHidden = resourceValues.hasHiddenExtension ?? false
            let isSystem = resourceValues.isSystemImmutable ?? false
            
            // Detect special files
            let specialFileType = detectSpecialFileType(at: fileURL)
            
            // Handle symlinks
            if isSymlink {
                if !options.followSymlinks {
                    // Preserve symlink
                    do {
                        let symlinkTarget = try FileManager.default.destinationOfSymbolicLink(atPath: fileURL.path)
                        let entry = DirectoryEntry(
                            path: relativePath,
                            url: fileURL,
                            type: "symlink",
                            symlinkTarget: symlinkTarget,
                            permissions: getPermissions(from: fileURL),
                            owner: getOwner(from: fileURL),
                            group: getGroup(from: fileURL),
                            modified: resourceValues.contentModificationDate,
                            created: resourceValues.creationDate,
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
            
            // Handle special files
            if let specialType = specialFileType {
                if options.includeSpecialFiles {
                    let entry = DirectoryEntry(
                        path: relativePath,
                        url: fileURL,
                        type: specialType.typeString ?? "unknown",
                        permissions: getPermissions(from: fileURL),
                        owner: getOwner(from: fileURL),
                        group: getGroup(from: fileURL),
                        modified: resourceValues.contentModificationDate,
                        created: resourceValues.creationDate,
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
                let entry = DirectoryEntry(
                    path: relativePath,
                    url: fileURL,
                    type: "directory",
                    permissions: getPermissions(from: fileURL),
                    owner: getOwner(from: fileURL),
                    group: getGroup(from: fileURL),
                    modified: resourceValues.contentModificationDate,
                    created: resourceValues.creationDate,
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
                let fileSize = resourceValues.fileSize ?? 0
                let entry = DirectoryEntry(
                    path: relativePath,
                    url: fileURL,
                    type: "file",
                    size: fileSize,
                    permissions: getPermissions(from: fileURL),
                    owner: getOwner(from: fileURL),
                    group: getGroup(from: fileURL),
                    modified: resourceValues.contentModificationDate,
                    created: resourceValues.creationDate,
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
    
    // MARK: - Helper Methods
    
    private func normalizePath(_ path: String) -> String {
        // Normalize path separators to forward slashes
        return path.replacingOccurrences(of: "\\", with: "/")
    }
    
    private func getPermissions(from url: URL) -> String? {
        // Get file permissions using stat()
        var statInfo = stat()
        guard stat(url.path, &statInfo) == 0 else {
            return nil
        }
        
        // Convert to octal string
        let mode = statInfo.st_mode & 0o7777
        return String(format: "%04o", mode)
    }
    
    private func getOwner(from url: URL) -> String? {
        var statInfo = stat()
        guard stat(url.path, &statInfo) == 0 else {
            return nil
        }
        
        // Get owner name (simplified - in production you might want to use getpwuid)
        #if canImport(Darwin)
        if let passwd = getpwuid(statInfo.st_uid) {
            return String(cString: passwd.pointee.pw_name)
        }
        #endif
        return nil
    }
    
    private func getGroup(from url: URL) -> String? {
        var statInfo = stat()
        guard stat(url.path, &statInfo) == 0 else {
            return nil
        }
        
        // Get group name (simplified - in production you might want to use getgrgid)
        #if canImport(Darwin)
        if let group = getgrgid(statInfo.st_gid) {
            return String(cString: group.pointee.gr_name)
        }
        #endif
        return nil
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

