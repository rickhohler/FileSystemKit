// FileSystemKit - SNUG Archive Creation
// Directory Processing Logic

import Foundation

/// Processes directories and files for SNUG archive creation
internal struct DirectoryProcessor {
    let hashAlgorithm: String
    let hashCache: FileHashCache
    let chunkStorage: any ChunkStorage
    let progressReporter: ProgressReporter
    
    /// Process directory and collect archive entries
    func processDirectory(
        at url: URL,
        basePath: String,
        entries: inout [ArchiveEntry],
        hashRegistry: inout [String: HashDefinition],
        processedHashes: inout Set<String>,
        totalSize: inout Int,
        embeddedFiles: inout [(hash: String, data: Data, path: String)],
        totalFileCount: Int,
        verbose: Bool,
        followExternalSymlinks: Bool = false,
        errorOnBrokenSymlinks: Bool = false,
        preserveSymlinks: Bool = false,
        embedSystemFiles: Bool = false,
        skipPermissionErrors: Bool = false,
        ignoreMatcher: SnugIgnoreMatcher? = nil
    ) async throws {
        let archiveRootURL = url.resolvingSymlinksInPath()
        var visitedCanonicalPaths: Set<String> = []
        
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
        
        // FileManager enumerator follows symlinks by default, but we need to handle them explicitly
        let enumeratorOptions: FileManager.DirectoryEnumerationOptions = preserveSymlinks
            ? [.skipsHiddenFiles]  // Don't follow symlinks when preserving
            : [.skipsHiddenFiles]   // Will follow symlinks, but we'll handle cycle detection
        
        let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: resourceKeys,
            options: enumeratorOptions,
            errorHandler: { @Sendable (url, error) -> Bool in
                if verbose {
                    print("  Warning: Error enumerating \(url.path): \(error.localizedDescription)")
                }
                return true  // Continue on error
            }
        )
        
        guard let enumerator = enumerator else {
            throw SnugError.storageError("Failed to enumerate directory", nil)
        }
        
        var filesProcessed = 0
        
        // Collect all URLs first (enumerator iteration not available in async context)
        var allURLs: [URL] = []
        while let fileURL = enumerator.nextObject() as? URL {
            allURLs.append(fileURL)
        }
        
        // Process collected URLs
        for fileURL in allURLs {
            // Normalize path to Unix-style (handle Windows paths)
            let relativePath = PathUtilities.relativePath(from: fileURL, baseURL: url, basePath: basePath)
            
            // Check ignore patterns
            if let matcher = ignoreMatcher, matcher.shouldIgnore(relativePath) {
                if verbose {
                    print("  Ignored: \(relativePath)")
                }
                continue
            }
            
            let resourceValues = try fileURL.resourceValues(forKeys: Set(resourceKeys))
            let isDirectory = resourceValues.isDirectory ?? false
            let isSymlink = resourceValues.isSymbolicLink ?? false
            let isRegularFile = resourceValues.isRegularFile ?? false
            let isHidden = resourceValues.hasHiddenExtension ?? false
            let isSystem = resourceValues.isSystemImmutable ?? false
            
            // Detect special files (block devices, character devices, sockets, FIFOs)
            // URLResourceValues doesn't provide these, so we use stat() system call
            let specialFileInfo = detectSpecialFileType(at: fileURL)
            
            // Handle symlinks
            if isSymlink {
                if preserveSymlinks {
                    // Preserve symlink mode: store symlink entry
                    do {
                        let symlinkTarget = try FileManager.default.destinationOfSymbolicLink(atPath: fileURL.path)
                        let entry = ArchiveEntry(
                            type: "symlink",
                            path: relativePath,
                            hash: nil,
                            size: nil,
                            target: symlinkTarget,
                            permissions: nil,
                            owner: nil,
                            group: nil,
                            modified: resourceValues.contentModificationDate,
                            created: resourceValues.creationDate,
                            embedded: false,
                            embeddedOffset: nil
                        )
                        entries.append(entry)
                        if verbose {
                            print("  Added symlink: \(relativePath) -> \(symlinkTarget)")
                        }
                        continue
                    } catch {
                        if errorOnBrokenSymlinks {
                            throw SnugError.brokenSymlink(relativePath, target: "")
                        } else {
                            if verbose {
                                print("  Warning: Skipping broken symlink: \(relativePath)")
                            }
                            continue
                        }
                    }
                } else {
                    // Follow symlink mode: resolve and process target
                    try await processSymlink(
                        fileURL: fileURL,
                        relativePath: relativePath,
                        archiveRootURL: archiveRootURL,
                        visitedCanonicalPaths: &visitedCanonicalPaths,
                        resourceKeys: resourceKeys,
                        entries: &entries,
                        hashRegistry: &hashRegistry,
                        processedHashes: &processedHashes,
                        totalSize: &totalSize,
                        filesProcessed: &filesProcessed,
                        totalFileCount: totalFileCount,
                        verbose: verbose,
                        followExternalSymlinks: followExternalSymlinks,
                        errorOnBrokenSymlinks: errorOnBrokenSymlinks
                    )
                    continue
                }
            }
            
            // Handle special files (devices, sockets, FIFOs)
            if let specialInfo = specialFileInfo {
                if embedSystemFiles {
                    // Store special file metadata entry
                    guard let specialType = specialInfo.typeString else {
                        // This shouldn't happen, but handle gracefully
                        if verbose {
                            print("  Warning: Unknown special file type: \(relativePath)")
                        }
                        continue
                    }
                    
                    let entry = ArchiveEntry(
                        type: specialType,
                        path: relativePath,
                        hash: nil,
                        size: nil,
                        target: nil,
                        permissions: nil,
                        owner: nil,
                        group: nil,
                        modified: resourceValues.contentModificationDate,
                        created: resourceValues.creationDate,
                        embedded: false,
                        embeddedOffset: nil
                    )
                    entries.append(entry)
                    
                    if verbose {
                        print("  Added special file (\(specialType)): \(relativePath)")
                    }
                } else {
                    // Skip special files with warning
                    if verbose {
                        print("  Warning: Skipping \(specialInfo.description): \(relativePath)")
                    }
                }
                continue
            }
            
            // Normal file/directory processing
            if isDirectory {
                // Directory entry
                let entry = ArchiveEntry(
                    type: "directory",
                    path: relativePath,
                    hash: nil,
                    size: nil,
                    target: nil,
                    permissions: nil,
                    owner: nil,
                    group: nil,
                    modified: resourceValues.contentModificationDate,
                    created: resourceValues.creationDate,
                    embedded: false,
                    embeddedOffset: nil
                )
                entries.append(entry)
            } else if isRegularFile {
                // Regular file entry - try to read
                try await processRegularFile(
                    fileURL: fileURL,
                    relativePath: relativePath,
                    resourceValues: resourceValues,
                    isSystem: isSystem,
                    isHidden: isHidden,
                    entries: &entries,
                    hashRegistry: &hashRegistry,
                    processedHashes: &processedHashes,
                    totalSize: &totalSize,
                    embeddedFiles: &embeddedFiles,
                    filesProcessed: &filesProcessed,
                    totalFileCount: totalFileCount,
                    verbose: verbose,
                    embedSystemFiles: embedSystemFiles,
                    skipPermissionErrors: skipPermissionErrors
                )
            }
        }
    }
    
    // MARK: - Private Helpers
    
    private func processSymlink(
        fileURL: URL,
        relativePath: String,
        archiveRootURL: URL,
        visitedCanonicalPaths: inout Set<String>,
        resourceKeys: [URLResourceKey],
        entries: inout [ArchiveEntry],
        hashRegistry: inout [String: HashDefinition],
        processedHashes: inout Set<String>,
        totalSize: inout Int,
        filesProcessed: inout Int,
        totalFileCount: Int,
        verbose: Bool,
        followExternalSymlinks: Bool,
        errorOnBrokenSymlinks: Bool
    ) async throws {
        do {
            let symlinkTarget = try FileManager.default.destinationOfSymbolicLink(atPath: fileURL.path)
            let resolvedURL: URL
            
            // Handle relative vs absolute symlink targets
            if symlinkTarget.hasPrefix("/") {
                resolvedURL = URL(fileURLWithPath: symlinkTarget).resolvingSymlinksInPath()
            } else {
                resolvedURL = URL(fileURLWithPath: symlinkTarget, relativeTo: fileURL.deletingLastPathComponent())
                    .resolvingSymlinksInPath()
            }
            
            // Check for broken symlink
            if !FileManager.default.fileExists(atPath: resolvedURL.path) {
                if errorOnBrokenSymlinks {
                    throw SnugError.brokenSymlink(relativePath, target: symlinkTarget)
                } else {
                    if verbose {
                        print("  Warning: Skipping broken symlink: \(relativePath) -> \(symlinkTarget)")
                    }
                    return
                }
            }
            
            // Check for cycle
            let canonicalPath = resolvedURL.path
            if visitedCanonicalPaths.contains(canonicalPath) {
                if verbose {
                    print("  Warning: Skipping symlink cycle: \(relativePath)")
                }
                return
            }
            
            // Check if symlink points outside archive root
            if !canonicalPath.hasPrefix(archiveRootURL.path) {
                if followExternalSymlinks {
                    visitedCanonicalPaths.insert(canonicalPath)
                    // Process external file - continue to file processing below
                    // Note: The enumerator may have already followed it
                } else {
                    if verbose {
                        print("  Warning: Skipping symlink pointing outside archive: \(relativePath)")
                    }
                    return
                }
            } else {
                visitedCanonicalPaths.insert(canonicalPath)
            }
            
            // Check if resolved path is a directory (will be handled by enumerator)
            let resolvedResourceValues = try resolvedURL.resourceValues(forKeys: Set(resourceKeys))
            if resolvedResourceValues.isDirectory ?? false {
                // Directory symlink - will be handled by enumerator, skip here
                return
            }
            
            // Process resolved file - use resolvedURL instead of fileURL
            // Note: We need to read from resolvedURL, but keep relativePath for entry
            let fileData = try Data(contentsOf: resolvedURL)
            totalSize += fileData.count
            let hash = try await hashCache.computeHash(for: resolvedURL, data: fileData, hashAlgorithm: hashAlgorithm)
            
            // Store file in chunk storage
            let identifier = ChunkIdentifier(id: hash)
            
            // Get file timestamps
            let createdDate = try? resolvedURL.resourceValues(forKeys: [.creationDateKey]).creationDate
            let modifiedDate = try? resolvedURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
            
            // Detect if this is a disk image file
            let typeInfo = FileTypeDetector.detect(for: resolvedURL, data: fileData)
            let chunkType = typeInfo.type
            let contentType = typeInfo.contentType
            
            let resolvedChunkMetadata = ChunkMetadata(
                size: fileData.count,
                contentHash: hash,
                hashAlgorithm: hashAlgorithm,
                contentType: contentType,
                chunkType: chunkType,
                originalFilename: resolvedURL.lastPathComponent,
                originalPaths: [relativePath],
                created: createdDate,
                modified: modifiedDate
            )
            
            // Write chunk (already in async context)
            _ = try await chunkStorage.writeChunk(fileData, identifier: identifier, metadata: resolvedChunkMetadata)
            
            // Add to hash registry if not already present
            if !processedHashes.contains(hash) {
                hashRegistry[hash] = HashDefinition(
                    hash: hash,
                    size: fileData.count,
                    algorithm: hashAlgorithm
                )
                processedHashes.insert(hash)
            }
            
            // File entry (from followed symlink)
            let entry = ArchiveEntry(
                type: "file",
                path: relativePath,
                hash: hash,
                size: fileData.count,
                target: nil,
                permissions: FileMetadataCollector.getPermissions(from: resolvedURL),
                owner: FileMetadataCollector.getOwnerAndGroup(from: resolvedURL).owner,
                group: FileMetadataCollector.getOwnerAndGroup(from: resolvedURL).group,
                modified: resolvedResourceValues.contentModificationDate,
                created: resolvedResourceValues.creationDate,
                embedded: false,
                embeddedOffset: nil
            )
            entries.append(entry)
            
            filesProcessed += 1
            progressReporter.report(
                filesProcessed: filesProcessed,
                totalFiles: totalFileCount,
                bytesProcessed: Int64(totalSize),
                totalBytes: nil,
                currentFile: relativePath,
                phase: .processing
            )
            
            if verbose {
                print("  Added (from symlink): \(relativePath) (\(hash.prefix(8))...)")
            }
        } catch let error as SnugError {
            throw error
        } catch {
            if errorOnBrokenSymlinks {
                throw SnugError.brokenSymlink(relativePath, target: "")
            } else {
                if verbose {
                    print("  Warning: Error resolving symlink \(relativePath): \(error.localizedDescription)")
                }
                return
            }
        }
    }
    
    private func processRegularFile(
        fileURL: URL,
        relativePath: String,
        resourceValues: URLResourceValues,
        isSystem: Bool,
        isHidden: Bool,
        entries: inout [ArchiveEntry],
        hashRegistry: inout [String: HashDefinition],
        processedHashes: inout Set<String>,
        totalSize: inout Int,
        embeddedFiles: inout [(hash: String, data: Data, path: String)],
        filesProcessed: inout Int,
        totalFileCount: Int,
        verbose: Bool,
        embedSystemFiles: Bool,
        skipPermissionErrors: Bool
    ) async throws {
        do {
            let fileData = try Data(contentsOf: fileURL)
            totalSize += fileData.count
            
            // Use hash cache if available
            let hash = try await hashCache.computeHash(for: fileURL, data: fileData, hashAlgorithm: hashAlgorithm)
            
            // Determine if this should be embedded (system files when embedSystemFiles is true)
            let shouldEmbed = embedSystemFiles && (isSystem || isHidden || PathUtilities.isSystemFile(relativePath))
            
            if shouldEmbed {
                // Embed file directly in archive
                embeddedFiles.append((hash: hash, data: fileData, path: relativePath))
                
                let metadata = FileMetadataCollector.collect(from: fileURL)
                let entry = ArchiveEntry(
                    type: "file",
                    path: relativePath,
                    hash: hash,
                    size: fileData.count,
                    target: nil,
                    permissions: metadata.permissions,
                    owner: metadata.owner,
                    group: metadata.group,
                    modified: metadata.modified ?? resourceValues.contentModificationDate,
                    created: metadata.created ?? resourceValues.creationDate,
                    embedded: true,
                    embeddedOffset: nil  // Will be set later
                )
                entries.append(entry)
                
                filesProcessed += 1
                progressReporter.report(
                    filesProcessed: filesProcessed,
                    totalFiles: totalFileCount,
                    bytesProcessed: Int64(totalSize),
                    totalBytes: nil,
                    currentFile: relativePath,
                    phase: .processing
                )
                
                if verbose {
                    print("  Added (embedded): \(relativePath) (\(hash.prefix(8))...)")
                }
            } else {
                // Store in hash storage (normal behavior)
                // Store file in chunk storage (properly async)
                let identifier = ChunkIdentifier(id: hash)
                
                // Get file timestamps
                let createdDate = try? fileURL.resourceValues(forKeys: [.creationDateKey]).creationDate
                let modifiedDate = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
                
                // Detect if this is a disk image file
                let typeInfo = FileTypeDetector.detect(for: fileURL, data: fileData)
                let chunkType = typeInfo.type
                let contentType = typeInfo.contentType
                
                let chunkMetadata = ChunkMetadata(
                    size: fileData.count,
                    contentHash: hash,
                    hashAlgorithm: hashAlgorithm,
                    contentType: contentType,
                    chunkType: chunkType,
                    originalFilename: fileURL.lastPathComponent,
                    originalPaths: [relativePath],
                    created: createdDate,
                    modified: modifiedDate
                )
                
                // Write chunk (already in async context)
                _ = try await chunkStorage.writeChunk(fileData, identifier: identifier, metadata: chunkMetadata)
                
                // Add to hash registry if not already present
                if !processedHashes.contains(hash) {
                    hashRegistry[hash] = HashDefinition(
                        hash: hash,
                        size: fileData.count,
                        algorithm: hashAlgorithm
                    )
                    processedHashes.insert(hash)
                }
                
                // File entry (hash storage)
                let fileMetadata = FileMetadataCollector.collect(from: fileURL)
                let entry = ArchiveEntry(
                    type: "file",
                    path: relativePath,
                    hash: hash,
                    size: fileData.count,
                    target: nil,
                    permissions: fileMetadata.permissions,
                    owner: fileMetadata.owner,
                    group: fileMetadata.group,
                    modified: fileMetadata.modified ?? resourceValues.contentModificationDate,
                    created: fileMetadata.created ?? resourceValues.creationDate,
                    embedded: false,
                    embeddedOffset: nil
                )
                entries.append(entry)
                
                filesProcessed += 1
                progressReporter.report(
                    filesProcessed: filesProcessed,
                    totalFiles: totalFileCount,
                    bytesProcessed: Int64(totalSize),
                    totalBytes: nil,
                    currentFile: relativePath,
                    phase: .processing
                )
                
                if verbose {
                    print("  Added: \(relativePath) (\(hash.prefix(8))...)")
                }
            }
        } catch CocoaError.fileReadNoPermission {
            // Permission denied - throw error by default (requires user permission/action)
            if skipPermissionErrors {
                // Skip with warning only if explicitly allowed
                if verbose {
                    print("  Warning: Permission denied, skipping: \(relativePath)")
                }
                return
            } else {
                // Default: throw error (user must grant permission or use --skip-permission-errors)
                throw SnugError.permissionDenied(relativePath)
            }
        } catch {
            // Other read errors - throw by default
            if skipPermissionErrors {
                // Skip with warning only if explicitly allowed
                if verbose {
                    print("  Warning: Error reading \(relativePath): \(error.localizedDescription)")
                }
                return
            } else {
                // Default: throw error
                throw error
            }
        }
    }
}

