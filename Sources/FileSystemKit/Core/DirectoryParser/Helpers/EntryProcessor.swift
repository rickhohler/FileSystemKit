// FileSystemKit Core Library
// EntryProcessor
//
// Helper methods for processing different types of directory entries.

import Foundation

/// Helper methods for processing directory entries
internal enum EntryProcessor {
    /// Process a symlink entry
    /// - Parameters:
    ///   - fileURL: File URL of the symlink
    ///   - relativePath: Relative path from root
    ///   - resourceValues: Resource values for the symlink
    ///   - options: Parser options
    ///   - visitedCanonicalPaths: Set of visited canonical paths (for cycle detection)
    ///   - delegate: Delegate to receive entry notifications
    /// - Throws: DirectoryParserError if processing fails
    /// - Returns: true if processing should continue, false to stop
    static func processSymlink(
        fileURL: URL,
        relativePath: String,
        resourceValues: URLResourceValues,
        options: DirectoryParserOptions,
        visitedCanonicalPaths: inout Set<String>,
        delegate: DirectoryParserDelegate
    ) throws -> Bool {
        if !options.followSymlinks {
            // Preserve symlink
            do {
                let symlinkTarget = try FileManager.default.destinationOfSymbolicLink(atPath: fileURL.path)
                let metadata = FileMetadataCollector.collect(from: fileURL)
                let isHidden = resourceValues.hasHiddenExtension ?? false
                let isSystem = resourceValues.isSystemImmutable ?? false
                
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
                    return false
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
                    return true
                }
            }
        } else {
            // Follow symlink - check for cycles
            let canonicalPath = fileURL.resolvingSymlinksInPath().path
            if visitedCanonicalPaths.contains(canonicalPath) {
                if options.verbose {
                    print("  Warning: Skipping symlink cycle: \(relativePath)")
                }
                return true
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
                        return true
                    }
                }
                
                // Continue processing with resolved URL
                // Note: This is a simplified implementation - in practice, you might want
                // to recursively process the resolved path
            } catch {
                if options.errorOnBrokenSymlinks {
                    throw DirectoryParserError.brokenSymlink(relativePath, target: "")
                } else {
                    if options.verbose {
                        print("  Warning: Skipping broken symlink: \(relativePath)")
                    }
                    return true
                }
            }
        }
        
        return true
    }
    
    /// Process a special file entry
    /// - Parameters:
    ///   - fileURL: File URL of the special file
    ///   - relativePath: Relative path from root
    ///   - resourceValues: Resource values for the file
    ///   - specialType: Detected special file type
    ///   - options: Parser options
    ///   - delegate: Delegate to receive entry notifications
    /// - Throws: DirectoryParserError if processing fails
    /// - Returns: true if processing should continue, false to stop
    static func processSpecialFile(
        fileURL: URL,
        relativePath: String,
        resourceValues: URLResourceValues,
        specialType: SpecialFileType,
        options: DirectoryParserOptions,
        delegate: DirectoryParserDelegate
    ) throws -> Bool {
        if options.includeSpecialFiles {
            let metadata = FileMetadataCollector.collect(from: fileURL)
            let isHidden = resourceValues.hasHiddenExtension ?? false
            let isSystem = resourceValues.isSystemImmutable ?? false
            
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
                return false
            }
            
            if options.verbose {
                print("  Added special file (\(specialType.typeString ?? "unknown")): \(relativePath)")
            }
        } else {
            if options.verbose {
                print("  Warning: Skipping \(specialType.description): \(relativePath)")
            }
        }
        
        return true
    }
    
    /// Process a directory entry
    /// - Parameters:
    ///   - fileURL: File URL of the directory
    ///   - relativePath: Relative path from root
    ///   - resourceValues: Resource values for the directory
    ///   - options: Parser options
    ///   - delegate: Delegate to receive entry notifications
    /// - Throws: DirectoryParserError if processing fails
    /// - Returns: true if processing should continue, false to stop
    static func processDirectory(
        fileURL: URL,
        relativePath: String,
        resourceValues: URLResourceValues,
        options: DirectoryParserOptions,
        delegate: DirectoryParserDelegate
    ) throws -> Bool {
        let metadata = FileMetadataCollector.collect(from: fileURL)
        let isHidden = resourceValues.hasHiddenExtension ?? false
        let isSystem = resourceValues.isSystemImmutable ?? false
        
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
            return false
        }
        
        if options.verbose {
            print("  Added directory: \(relativePath)")
        }
        
        return true
    }
    
    /// Process a regular file entry
    /// - Parameters:
    ///   - fileURL: File URL of the file
    ///   - relativePath: Relative path from root
    ///   - resourceValues: Resource values for the file
    ///   - options: Parser options
    ///   - delegate: Delegate to receive entry notifications
    /// - Throws: DirectoryParserError if processing fails
    /// - Returns: true if processing should continue, false to stop
    static func processRegularFile(
        fileURL: URL,
        relativePath: String,
        resourceValues: URLResourceValues,
        options: DirectoryParserOptions,
        delegate: DirectoryParserDelegate
    ) throws -> Bool {
        let metadata = FileMetadataCollector.collect(from: fileURL)
        let fileSize = metadata.size ?? resourceValues.fileSize ?? 0
        let isHidden = resourceValues.hasHiddenExtension ?? false
        let isSystem = resourceValues.isSystemImmutable ?? false
        
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
            return false
        }
        
        if options.verbose {
            print("  Added file: \(relativePath) (\(fileSize) bytes)")
        }
        
        return true
    }
}

