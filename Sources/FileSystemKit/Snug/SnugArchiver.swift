// FileSystemKit - SNUG Archive Creation
// SnugArchiver - Main class for creating SNUG archives
//
// NOTE: This file has been refactored. Components are now in:
// - Processing/DirectoryProcessor.swift - Directory traversal and file processing
// - Utilities/ProgressReporter.swift - Progress reporting
// - Utilities/SnugHashComputation.swift - Hash computation wrapper
// - Utilities/CompressionHelpers.swift - Compression utilities

import Foundation
import Yams

/// Creates SNUG archives from directory structures
/// Internal implementation of archive creation
/// Note: Clients should use FileSystemKitArchiveFacade instead for stable API contract
internal class SnugArchiver {
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
    
    /// Create archive from source directory
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
    ) async throws -> SnugArchiveStats {
        let progressReporter = ProgressReporter(callback: progressCallback)
        
        // Report scanning phase
        progressReporter.report(
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
        let totalFileCount = try FileCounter.countFiles(in: sourceURL, ignoreMatcher: ignoreMatcher)
        
        // Report processing phase
        progressReporter.report(
            filesProcessed: 0,
            totalFiles: totalFileCount,
            bytesProcessed: 0,
            totalBytes: nil,
            currentFile: nil,
            phase: .processing
        )
        
        // Process directory
        let directoryProcessor = DirectoryProcessor(
            hashAlgorithm: hashAlgorithm,
            hashCache: hashCache,
            chunkStorage: chunkStorage,
            progressReporter: progressReporter
        )
        
        try await directoryProcessor.processDirectory(
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
        let compressedData = try SnugCompressionHelpers.compressGzip(data: archiveData)
        
        // 7. Write compressed file
        try compressedData.write(to: outputURL)
        
        let fileCount = entries.filter { $0.type == "file" }.count
        let directoryCount = entries.filter { $0.type == "directory" }.count
        let embeddedCount = embeddedFiles.count
        
        // Report completion
        progressReporter.report(
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
}

