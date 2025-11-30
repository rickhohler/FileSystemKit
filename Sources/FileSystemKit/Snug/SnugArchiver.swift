// FileSystemKit - SNUG Archive Creation
// Creates .snug archives from directories

import Foundation
import Yams
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif
#if canImport(Compression)
import Compression
#endif
#if canImport(CommonCrypto)
import CommonCrypto
#endif
#if canImport(CryptoKit)
import CryptoKit
#endif

/// Creates SNUG archives from directory structures
public class SnugArchiver {
    let storageURL: URL
    let hashAlgorithm: String
    let chunkStorage: any ChunkStorage
    var progressCallback: SnugProgressCallback?
    let hashCache: FileHashCache
    
    /// Initialize with storage URL (uses default file system storage or config-based provider)
    /// - Parameters:
    ///   - storageURL: URL for storage directory (used if no custom provider configured)
    ///   - hashAlgorithm: Hash algorithm to use
    ///   - enableHashCache: Whether to enable hash caching
    /// - Throws: Error if storage cannot be created
    /// 
    /// **Note**: If `SnugConfig` specifies a `storageProviderIdentifier`, that provider will be used
    /// instead of file system storage. Otherwise, uses file system storage at `storageURL`.
    /// 
    /// **CLI Usage**: The `snug` CLI tool uses this initializer with local file system storage.
    /// For cloud storage, use the `storageProvider` or `providerIdentifier` initializers instead.
    public init(storageURL: URL, hashAlgorithm: String, enableHashCache: Bool = true) async throws {
        self.storageURL = storageURL
        self.hashAlgorithm = hashAlgorithm
        
        // Initialize hash cache (persist to storage directory)
        let cacheURL = enableHashCache ? storageURL.appendingPathComponent(".hashcache.json") : nil
        self.hashCache = FileHashCache(cacheFileURL: cacheURL, hashAlgorithm: hashAlgorithm)
        
        // Check configuration for custom storage provider
        if let config = try? SnugConfigManager.load(),
           let providerID = config.storageProviderIdentifier {
            // Use custom storage provider from config
            let providerConfig = config.storageProviderConfiguration?.mapValues { $0 as Any }
            self.chunkStorage = try await SnugStorage.createChunkStorage(
                providerIdentifier: providerID,
                configuration: providerConfig
            )
        } else {
            // Check if mirroring is enabled or glacier volumes exist in config
            if let config = try? SnugConfigManager.load() {
                let hasGlacierVolumes = config.storageLocations.contains { $0.volumeType == .glacier }
                let hasMirrorVolumes = config.storageLocations.contains { $0.volumeType == .mirror || $0.volumeType == .secondary }
                
                if config.enableMirroring || hasGlacierVolumes || hasMirrorVolumes {
                    self.chunkStorage = try SnugStorage.createMirroredChunkStorage(from: config)
                } else {
                    self.chunkStorage = try SnugStorage.createChunkStorage(at: storageURL)
                }
            } else {
                self.chunkStorage = try SnugStorage.createChunkStorage(at: storageURL)
            }
        }
    }
    
    /// Initialize with explicit chunk storage (for testing or custom storage)
    public init(chunkStorage: any ChunkStorage, hashAlgorithm: String, enableHashCache: Bool = true) {
        self.storageURL = URL(fileURLWithPath: "/")
        self.hashAlgorithm = hashAlgorithm
        self.chunkStorage = chunkStorage
        
        // Initialize hash cache (in-memory only for testing)
        let cacheURL: URL? = enableHashCache ? nil : nil // In-memory cache for testing
        self.hashCache = FileHashCache(cacheFileURL: cacheURL, hashAlgorithm: hashAlgorithm)
    }
    
    /// Set progress callback for archive operations
    public func setProgressCallback(_ callback: @escaping SnugProgressCallback) {
        self.progressCallback = callback
    }
    
    public func createArchive(
        from sourceURL: URL,
        outputURL: URL,
        verbose: Bool,
        followExternalSymlinks: Bool = false,
        errorOnBrokenSymlinks: Bool = false,
        preserveSymlinks: Bool = false,
        embedSystemFiles: Bool = false,
        skipPermissionErrors: Bool = false,
        ignoreMatcher: SnugIgnoreMatcher? = nil
    ) throws -> SnugArchiveStats {
        // Report scanning phase
        reportProgress(
            filesProcessed: 0,
            totalFiles: nil,
            bytesProcessed: 0,
            totalBytes: nil,
            currentFile: nil,
            phase: .scanning
        )
        
        // 1. Walk directory and collect files
        var entries: [ArchiveEntry] = []
        var hashRegistry: [String: HashDefinition] = [:]
        var processedHashes: Set<String> = []
        var totalSize: Int = 0
        var embeddedFiles: [(hash: String, data: Data, path: String)] = []
        
        // First pass: count files for progress
        let totalFileCount = try countFiles(in: sourceURL, ignoreMatcher: ignoreMatcher)
        
        // Report processing phase
        reportProgress(
            filesProcessed: 0,
            totalFiles: totalFileCount,
            bytesProcessed: 0,
            totalBytes: nil,
            currentFile: nil,
            phase: .processing
        )
        
        // Process directory (concurrent processing infrastructure prepared for future implementation)
        try processDirectory(
            at: sourceURL,
            basePath: "",
            entries: &entries,
            hashRegistry: &hashRegistry,
            processedHashes: &processedHashes,
            totalSize: &totalSize,
            embeddedFiles: &embeddedFiles,
            totalFileCount: totalFileCount,
            verbose: verbose,
            followExternalSymlinks: followExternalSymlinks,
            errorOnBrokenSymlinks: errorOnBrokenSymlinks,
            preserveSymlinks: preserveSymlinks,
            embedSystemFiles: embedSystemFiles,
            skipPermissionErrors: skipPermissionErrors,
            ignoreMatcher: ignoreMatcher
        )
        
        // 2. Create YAML structure
        let archive = SnugArchive(
            format: "snug",
            version: 1,
            hashAlgorithm: hashAlgorithm,
            hashes: hashRegistry.isEmpty ? nil : hashRegistry,
            metadata: nil,
            entries: entries,
            embeddedFilesCount: embeddedFiles.isEmpty ? nil : embeddedFiles.count,
            embeddedSectionOffset: nil  // Will be set after writing YAML
        )
        
        // 3. Encode to YAML
        let encoder = YAMLEncoder()
        let yamlString = try encoder.encode(archive)
        guard let yamlData = yamlString.data(using: .utf8) else {
            throw SnugError.storageError("Failed to encode YAML", nil)
        }
        
        // 4. Create archive with embedded files section
        var archiveData = Data()
        archiveData.append(yamlData)
        
        // 5. Write embedded files section (if any)
        var embeddedOffsets: [String: Int64] = [:]
        if !embeddedFiles.isEmpty {
            let embeddedSectionOffset = Int64(archiveData.count)
            
            // Write file count
            var fileCount = UInt32(embeddedFiles.count)
            archiveData.append(Data(bytes: &fileCount, count: 4))
            
            // Write each embedded file
            for (hash, data, _) in embeddedFiles {
                let fileOffset = Int64(archiveData.count)
                embeddedOffsets[hash] = fileOffset
                
                // Hash length and hash
                let hashData = hash.data(using: .utf8)!
                var hashLength = UInt32(hashData.count)
                archiveData.append(Data(bytes: &hashLength, count: 4))
                archiveData.append(hashData)
                
                // Data length
                var dataLength = UInt64(data.count)
                archiveData.append(Data(bytes: &dataLength, count: 8))
                
                // File data
                archiveData.append(data)
            }
            
            // Update entries with embedded offsets
            for i in 0..<entries.count {
                if entries[i].embedded == true, let hash = entries[i].hash, let offset = embeddedOffsets[hash] {
                    entries[i] = ArchiveEntry(
                        type: entries[i].type,
                        path: entries[i].path,
                        hash: entries[i].hash,
                        size: entries[i].size,
                        target: entries[i].target,
                        permissions: entries[i].permissions,
                        owner: entries[i].owner,
                        group: entries[i].group,
                        modified: entries[i].modified,
                        created: entries[i].created,
                        embedded: true,
                        embeddedOffset: offset
                    )
                }
            }
            
            // Re-encode archive with updated offsets
            let updatedArchive = SnugArchive(
                format: archive.format,
                version: archive.version,
                hashAlgorithm: archive.hashAlgorithm,
                hashes: archive.hashes,
                metadata: archive.metadata,
                entries: entries,
                embeddedFilesCount: archive.embeddedFilesCount,
                embeddedSectionOffset: embeddedSectionOffset
            )
            
            let updatedYamlString = try encoder.encode(updatedArchive)
            guard let updatedYamlData = updatedYamlString.data(using: .utf8) else {
                throw SnugError.storageError("Failed to encode updated YAML", nil)
            }
            
            // Rebuild archive data with updated YAML
            archiveData = Data()
            archiveData.append(updatedYamlData)
            
            // Re-append embedded files section
            var updatedFileCount = UInt32(embeddedFiles.count)
            archiveData.append(Data(bytes: &updatedFileCount, count: 4))
            
            for (hash, data, _) in embeddedFiles {
                let hashData = hash.data(using: .utf8)!
                var hashLength = UInt32(hashData.count)
                archiveData.append(Data(bytes: &hashLength, count: 4))
                archiveData.append(hashData)
                
                var dataLength = UInt64(data.count)
                archiveData.append(Data(bytes: &dataLength, count: 8))
                archiveData.append(data)
            }
        }
        
        // 6. Compress entire archive
        let compressedData = try compressGzip(data: archiveData)
        
        // 7. Write compressed file
        try compressedData.write(to: outputURL)
        
        let fileCount = entries.filter { $0.type == "file" }.count
        let directoryCount = entries.filter { $0.type == "directory" }.count
        let embeddedCount = embeddedFiles.count
        
        // Report completion
        reportProgress(
            filesProcessed: fileCount,
            totalFiles: fileCount,
            bytesProcessed: Int64(totalSize),
            totalBytes: Int64(totalSize),
            currentFile: nil,
            phase: .complete
        )
        
        if verbose {
            print("Archive created: \(entries.count) entries, \(hashRegistry.count) unique hashes")
            if embeddedCount > 0 {
                print("  Embedded files: \(embeddedCount)")
            }
        }
        
        return SnugArchiveStats(
            fileCount: fileCount,
            directoryCount: directoryCount,
            uniqueHashCount: hashRegistry.count,
            totalSize: totalSize
        )
    }
    
    // Helper function to count files for progress estimation
    private func countFiles(in url: URL, ignoreMatcher: SnugIgnoreMatcher?) throws -> Int {
        var count = 0
        let resourceKeys: [URLResourceKey] = [.isDirectoryKey, .isRegularFileKey]
        
        let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsHiddenFiles],
            errorHandler: { _, _ in true }
        )
        
        guard let enumerator = enumerator else {
            return 0
        }
        
        for case let fileURL as URL in enumerator {
            let relativePath = fileURL.path.replacingOccurrences(of: url.path, with: "")
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            
            if let matcher = ignoreMatcher, matcher.shouldIgnore(relativePath) {
                continue // Skip ignored files
            }
            
            let resourceValues = try? fileURL.resourceValues(forKeys: Set(resourceKeys))
            if resourceValues?.isRegularFile == true {
                count += 1
            }
        }
        
        return count
    }
    
    // Helper function to report progress
    private func reportProgress(
        filesProcessed: Int,
        totalFiles: Int?,
        bytesProcessed: Int64,
        totalBytes: Int64?,
        currentFile: String?,
        phase: ProgressPhase
    ) {
        let progress = SnugProgress(
            filesProcessed: filesProcessed,
            totalFiles: totalFiles,
            bytesProcessed: bytesProcessed,
            totalBytes: totalBytes,
            currentFile: currentFile,
            phase: phase
        )
        progressCallback?(progress)
    }
    
    private func processDirectory(
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
    ) throws {
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
            errorHandler: { (url, error) -> Bool in
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
        
        for case let fileURL as URL in enumerator {
            // Normalize path to Unix-style (handle Windows paths)
            var relativePath = fileURL.path.replacingOccurrences(of: url.path, with: basePath)
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            relativePath = normalizePath(relativePath)
            
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
                                continue
                            }
                        }
                        
                        // Check for cycle
                        let canonicalPath = resolvedURL.path
                        if visitedCanonicalPaths.contains(canonicalPath) {
                            if verbose {
                                print("  Warning: Skipping symlink cycle: \(relativePath)")
                            }
                            continue
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
                                continue
                            }
                        } else {
                            visitedCanonicalPaths.insert(canonicalPath)
                        }
                        
                        // Check if resolved path is a directory (will be handled by enumerator)
                        let resolvedResourceValues = try resolvedURL.resourceValues(forKeys: Set(resourceKeys))
                        if resolvedResourceValues.isDirectory ?? false {
                            // Directory symlink - will be handled by enumerator, skip here
                            continue
                        }
                        
                        // Process resolved file - use resolvedURL instead of fileURL
                        // Note: We need to read from resolvedURL, but keep relativePath for entry
                        let fileData = try Data(contentsOf: resolvedURL)
                        totalSize += fileData.count
                        let hash = try hashCache.computeHashSync(for: resolvedURL, data: fileData, hashAlgorithm: hashAlgorithm)
                        
                        // Store file in chunk storage (synchronous wrapper)
                        let identifier = ChunkIdentifier(id: hash)
                        
                        // Get file timestamps
                        let createdDate = try? resolvedURL.resourceValues(forKeys: [.creationDateKey]).creationDate
                        let modifiedDate = try? resolvedURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
                        
                        // Detect if this is a disk image file
                        let (chunkType, contentType) = detectChunkType(for: resolvedURL, data: fileData)
                        
                        let metadata = ChunkMetadata(
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
                        
                        let semaphore = DispatchSemaphore(value: 0)
                        let errorHolder = ErrorHolder()
                        
                        Task { [chunkStorage] in
                            do {
                                _ = try await chunkStorage.writeChunk(fileData, identifier: identifier, metadata: metadata)
                                semaphore.signal()
                            } catch {
                                errorHolder.error = error
                                semaphore.signal()
                            }
                        }
                        
                        semaphore.wait()
                        
                        if let error = errorHolder.error {
                            throw error
                        }
                        
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
                            permissions: getPermissions(from: resolvedURL),
                            owner: getOwnerAndGroup(from: resolvedURL).owner,
                            group: getOwnerAndGroup(from: resolvedURL).group,
                            modified: resourceValues.contentModificationDate,
                            created: resourceValues.creationDate,
                            embedded: false,
                            embeddedOffset: nil
                        )
                        entries.append(entry)
                        
                        filesProcessed += 1
                        reportProgress(
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
                        continue
                    } catch let error as SnugError {
                        throw error
                    } catch {
                        if errorOnBrokenSymlinks {
                            throw SnugError.brokenSymlink(relativePath, target: "")
                        } else {
                            if verbose {
                                print("  Warning: Error resolving symlink \(relativePath): \(error.localizedDescription)")
                            }
                            continue
                        }
                    }
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
                do {
                    let fileData = try Data(contentsOf: fileURL)
                    totalSize += fileData.count
                    
                    // Use hash cache if available
                    let hash = try hashCache.computeHashSync(for: fileURL, data: fileData, hashAlgorithm: hashAlgorithm)
                    
                    // Determine if this should be embedded (system files when embedSystemFiles is true)
                    let shouldEmbed = embedSystemFiles && (isSystem || isHidden || isSystemFile(relativePath))
                    
                    if shouldEmbed {
                        // Embed file directly in archive
                        embeddedFiles.append((hash: hash, data: fileData, path: relativePath))
                        
                        let (owner, group) = self.getOwnerAndGroup(from: fileURL)
                        let entry = ArchiveEntry(
                            type: "file",
                            path: relativePath,
                            hash: hash,
                            size: fileData.count,
                            target: nil,
                            permissions: self.getPermissions(from: fileURL),
                            owner: owner,
                            group: group,
                            modified: resourceValues.contentModificationDate,
                            created: resourceValues.creationDate,
                            embedded: true,
                            embeddedOffset: nil  // Will be set later
                        )
                        entries.append(entry)
                        
                        filesProcessed += 1
                        reportProgress(
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
                
                // Store file in chunk storage (synchronous wrapper)
                let identifier = ChunkIdentifier(id: hash)
                
                // Get file timestamps
                let createdDate = try? fileURL.resourceValues(forKeys: [.creationDateKey]).creationDate
                let modifiedDate = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
                
                // Detect if this is a disk image file
                let (chunkType, contentType) = detectChunkType(for: fileURL, data: fileData)
                
                let metadata = ChunkMetadata(
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
                
                let semaphore = DispatchSemaphore(value: 0)
                let errorHolder = ErrorHolder()
                
                Task { [chunkStorage] in
                    do {
                        _ = try await chunkStorage.writeChunk(fileData, identifier: identifier, metadata: metadata)
                        semaphore.signal()
                    } catch {
                        errorHolder.error = error
                        semaphore.signal()
                    }
                }
                
                semaphore.wait()
                
                if let error = errorHolder.error {
                    throw error
                }
                
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
                let (owner, group) = self.getOwnerAndGroup(from: fileURL)
                let entry = ArchiveEntry(
                    type: "file",
                    path: relativePath,
                    hash: hash,
                    size: fileData.count,
                    target: nil,
                    permissions: self.getPermissions(from: fileURL),
                    owner: owner,
                    group: group,
                    modified: resourceValues.contentModificationDate,
                    created: resourceValues.creationDate,
                    embedded: false,
                    embeddedOffset: nil
                )
                        entries.append(entry)
                        
                        filesProcessed += 1
                        reportProgress(
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
                        continue
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
                        continue
                    } else {
                        // Default: throw error
                        throw error
                    }
                }
            }
        }
    }
    
    // Helper function to normalize paths (Windows to Unix-style)
    private func normalizePath(_ path: String) -> String {
        return path.replacingOccurrences(of: "\\", with: "/")
            .replacingOccurrences(of: "//", with: "/")
    }
    
    // Helper function to get permissions from file URL
    private func getPermissions(from url: URL) -> String? {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            if let permissions = attributes[.posixPermissions] as? NSNumber {
                return String(format: "%o", permissions.intValue)
            }
        } catch {
            // Ignore errors - permissions are optional
        }
        return nil
    }
    
    // Helper function to get owner and group from file URL
    private func getOwnerAndGroup(from url: URL) -> (owner: String?, group: String?) {
        var owner: String? = nil
        var group: String? = nil
        
        // Use FileManager to get owner/group
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            if let ownerName = attributes[.ownerAccountName] as? String {
                owner = ownerName
            }
            if let groupName = attributes[.groupOwnerAccountName] as? String {
                group = groupName
            }
        } catch {
            // Ignore errors - owner/group are optional
        }
        
        return (owner, group)
    }
    
    // Helper function to detect system files
    private func isSystemFile(_ path: String) -> Bool {
        let systemPaths = [
            "System Volume Information",
            "$RECYCLE.BIN",
            "System32",
            "Windows",
            ".Trash",
            ".DS_Store"
        ]
        return systemPaths.contains { path.contains($0) }
    }
    
    private func computeHash(data: Data) throws -> String {
        switch hashAlgorithm.lowercased() {
        case "sha256":
            return data.sha256().map { String(format: "%02x", $0) }.joined()
        case "sha1":
            return data.sha1().map { String(format: "%02x", $0) }.joined()
        case "md5":
            return data.md5().map { String(format: "%02x", $0) }.joined()
        default:
            throw SnugError.unsupportedHashAlgorithm(hashAlgorithm)
        }
    }
    
    private func compressGzip(data: Data) throws -> Data {
        #if canImport(Compression)
        let bufferSize = data.count + (data.count / 10) + 16
        let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { destinationBuffer.deallocate() }
        
        let compressedSize = data.withUnsafeBytes { sourceBuffer -> Int in
            guard let baseAddress = sourceBuffer.baseAddress else {
                return 0
            }
            return compression_encode_buffer(
                destinationBuffer,
                bufferSize,
                baseAddress.assumingMemoryBound(to: UInt8.self),
                data.count,
                nil,
                COMPRESSION_LZFSE
            )
        }
        
        guard compressedSize > 0 else {
            throw SnugError.compressionFailed("Compression returned zero size", nil)
        }
        
        return Data(bytes: destinationBuffer, count: compressedSize)
        #else
        throw SnugError.compressionFailed("Compression not available on this platform", nil)
        #endif
    }
}

// MARK: - Hash Extensions

extension Data {
    func sha256() -> [UInt8] {
        #if canImport(CommonCrypto)
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        self.withUnsafeBytes { bytes in
            _ = CC_SHA256(bytes.baseAddress, CC_LONG(self.count), &hash)
        }
        return hash
        #elseif canImport(CryptoKit)
        let hash = SHA256.hash(data: self)
        return Array(hash)
        #else
        return []
        #endif
    }
    
    func sha1() -> [UInt8] {
        #if canImport(CommonCrypto)
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
        self.withUnsafeBytes { bytes in
            _ = CC_SHA1(bytes.baseAddress, CC_LONG(self.count), &hash)
        }
        return hash
        #elseif canImport(CryptoKit)
        let hash = Insecure.SHA1.hash(data: self)
        return Array(hash)
        #else
        return []
        #endif
    }
    
    func md5() -> [UInt8] {
        #if canImport(CryptoKit)
        // Use CryptoKit's Insecure.MD5 - explicitly marked as insecure for legacy compatibility
        // This is Apple's recommended way to use MD5 (read-only validation, companion files)
        let hash = Insecure.MD5.hash(data: self)
        return Array(hash)
        #elseif canImport(CommonCrypto)
        // Fallback: Use CommonCrypto (deprecated but kept for legacy compatibility)
        // MD5 is intentionally kept for legacy compatibility (companion files, existing checksums)
        // See HASH_ALGORITHM_POLICY.md for details
        // Note: CC_MD5 deprecation warning is intentional - MD5 is read-only legacy support
        var hash = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
        self.withUnsafeBytes { bytes in
            hash.withUnsafeMutableBytes { hashBytes in
                // Using deprecated CC_MD5 intentionally for legacy compatibility
                _ = CC_MD5(bytes.baseAddress, CC_LONG(self.count), hashBytes.baseAddress)
            }
        }
        return hash
        #else
        return []
        #endif
    }
}

// MARK: - SnugArchiver Chunk Type Detection Extension

extension SnugArchiver {
    /// Detect chunk type and content type for a file
    /// Uses the same detection logic as DiskImageAdapter implementations
    /// - Parameters:
    ///   - url: File URL
    ///   - data: File data (may be partial for detection)
    /// - Returns: Tuple of (chunkType, contentType)
    func detectChunkType(for url: URL, data: Data) -> (chunkType: String, contentType: String?) {
        let fileExtension = url.pathExtension.lowercased()
        
        // Check for disk image formats using file extension and magic numbers
        // This matches the detection logic used by DiskImageAdapter implementations
        
        // DMG (Mac disk image)
        if fileExtension == "dmg" {
            // Check for UDIF signature at end of file
            if data.count >= 512 {
                let trailerData = data.subdata(in: (data.count - 512)..<data.count)
                if trailerData[0..<4] == Data([0x6B, 0x6F, 0x6C, 0x79]) { // "koly" UDIF signature
                    return ("disk-image", "application/x-apple-diskimage")
                }
            }
        }
        
        // ISO 9660 (CD-ROM/DVD-ROM)
        if fileExtension == "iso" || fileExtension == "img" {
            if data.count >= 32769 { // ISO 9660 volume descriptor starts at sector 16 (32768 bytes)
                let vdsStart = 32768
                if data.count >= vdsStart + 1 && data[vdsStart] == 0x01 {
                    // Primary Volume Descriptor
                    return ("disk-image", "application/x-iso9660-image")
                }
            }
            // Check for ISO 9660 signature at offset 32769
            if data.count >= 32773 {
                let signature = String(data: data.subdata(in: 32769..<32773), encoding: .isoLatin1) ?? ""
                if signature == "CD001" {
                    return ("disk-image", "application/x-iso9660-image")
                }
            }
        }
        
        // VHD (Virtual Hard Disk)
        if fileExtension == "vhd" {
            if data.count >= 512 {
                let footer = data.subdata(in: (data.count - 512)..<data.count)
                if footer.count >= 8 {
                    let signature = String(data: footer[0..<8], encoding: .ascii) ?? ""
                    if signature == "conectix" {
                        return ("disk-image", "application/x-vhd")
                    }
                }
            }
        }
        
        // Raw disk image (IMG) - check if size suggests a disk image
        if fileExtension == "img" {
            let size = data.count
            if size > 0 && (size % 512 == 0 || size == 1440 * 1024 || size == 2880 * 1024) {
                // Could be a raw disk image
                return ("disk-image", "application/octet-stream")
            }
        }
        
        // Default to regular file
        return ("file", nil)
    }
}


// MARK: - Helper Classes

// Helper class for thread-safe error storage
private final class ErrorHolder: @unchecked Sendable {
    var error: Error?
}

// Helper class for thread-safe processing result storage
private final class ProcessingResultHolder: @unchecked Sendable {
    var entries: [ArchiveEntry] = []
    var hashRegistry: [String: HashDefinition] = [:]
    var processedHashes: Set<String> = []
    var totalSize: Int = 0
    var embeddedFiles: [(hash: String, data: Data, path: String)] = []
    var error: Error?
}
