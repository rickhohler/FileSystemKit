// FileSystemKit - SNUG Archive Extraction
// Extracts files from .snug archives

import Foundation

/// Extracts files from SNUG archives
/// Internal implementation of archive extraction
/// Note: Clients should use FileSystemKitArchiveFacade instead for stable API contract
internal class SnugExtractor {
    let storageURL: URL
    let chunkStorage: any ChunkStorage
    
    /// Initialize with storage URL (uses default file system storage or config-based provider)
    /// - Parameter storageURL: URL for storage directory (used if no custom provider configured)
    /// - Throws: Error if storage cannot be created
    /// 
    /// **Note**: If `SnugConfig` specifies a `storageProviderIdentifier`, that provider will be used
    /// instead of file system storage. Otherwise, uses file system storage at `storageURL`.
    public init(storageURL: URL) async throws {
        self.storageURL = storageURL
        
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
    
    /// Initialize with custom storage provider
    /// - Parameter storageProvider: Custom storage provider
    /// - Parameter storageConfiguration: Optional configuration for the provider
    /// - Throws: Error if storage cannot be created
    public init(
        storageProvider: any ChunkStorageProvider,
        storageConfiguration: [String: Any]? = nil
    ) async throws {
        self.storageURL = URL(fileURLWithPath: "/")
        self.chunkStorage = try await SnugStorage.createChunkStorage(
            from: storageProvider,
            configuration: storageConfiguration
        )
    }
    
    /// Initialize with registered storage provider by identifier
    /// - Parameter providerIdentifier: Storage provider identifier
    /// - Parameter storageConfiguration: Optional configuration dictionary
    /// - Throws: Error if provider not found or storage cannot be created
    public init(
        providerIdentifier: String,
        storageConfiguration: [String: Any]? = nil
    ) async throws {
        self.storageURL = URL(fileURLWithPath: "/")
        self.chunkStorage = try await SnugStorage.createChunkStorage(
            providerIdentifier: providerIdentifier,
            configuration: storageConfiguration
        )
    }
    
    /// Initialize with explicit chunk storage (for testing or custom storage)
    public init(chunkStorage: any ChunkStorage) {
        self.storageURL = URL(fileURLWithPath: "/")
        self.chunkStorage = chunkStorage
    }
    
    /// Extract archive from archive URL to output directory
    /// - Parameters:
    ///   - archiveURL: URL of the archive file
    ///   - outputURL: Directory to extract files to
    ///   - verbose: Whether to print progress
    ///   - preservePermissions: Whether to preserve file permissions
    /// - Throws: Error if extraction fails
    /// Thread-safe: Properly async implementation
    public func extractArchive(from archiveURL: URL, to outputURL: URL, verbose: Bool, preservePermissions: Bool = false) async throws {
        try await Self.extractArchiveAsync(from: archiveURL, to: outputURL, verbose: verbose, storage: chunkStorage, preservePermissions: preservePermissions)
    }
    
    private static func extractArchiveAsync(from archiveURL: URL, to outputURL: URL, verbose: Bool, storage: ChunkStorage, preservePermissions: Bool = false) async throws {
    
        // 1. Parse archive
        let parser = SnugParser()
        let archive = try parser.parseArchive(from: archiveURL)
        
        // 2. Ensure output directory exists
        try FileManager.default.createDirectory(
            at: outputURL,
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        // 3. Extract entries with error recovery
        var extractedCount = 0
        var errorCount = 0
        var errors: [String] = []
        
        for entry in archive.entries {
            let entryURL = outputURL.appendingPathComponent(entry.path)
            
            do {
                if entry.type == "directory" {
                    // Create directory
                    try FileManager.default.createDirectory(
                        at: entryURL,
                        withIntermediateDirectories: true,
                        attributes: nil
                    )
                    
                    // Preserve permissions if requested
                    if preservePermissions {
                        applyPermissions(to: entryURL, from: entry)
                    }
                    
                    if verbose {
                        print("  Created directory: \(entry.path)")
                    }
                } else if entry.type == "symlink", let target = entry.target {
                    // Create symlink
                    // Create parent directory if needed
                    try FileManager.default.createDirectory(
                        at: entryURL.deletingLastPathComponent(),
                        withIntermediateDirectories: true,
                        attributes: nil
                    )
                    
                    // Remove existing file/symlink if it exists
                    if FileManager.default.fileExists(atPath: entryURL.path) {
                        try FileManager.default.removeItem(at: entryURL)
                    }
                    
                    // Create symlink
                    try FileManager.default.createSymbolicLink(
                        atPath: entryURL.path,
                        withDestinationPath: target
                    )
                    
                    if verbose {
                        print("  Created symlink: \(entry.path) -> \(target)")
                    }
                } else if entry.type == "file", let hash = entry.hash {
                    // Resolve hash and extract file
                    let identifier = ChunkIdentifier(id: hash)
                    
                    // Read chunk from storage
                    guard let fileData = try await storage.readChunk(identifier) else {
                        throw SnugError.hashNotFound(hash)
                    }
                    
                    // Create parent directory if needed
                    try FileManager.default.createDirectory(
                        at: entryURL.deletingLastPathComponent(),
                        withIntermediateDirectories: true,
                        attributes: nil
                    )
                    
                    // Write file
                    try fileData.write(to: entryURL)
                    
                    // Preserve permissions if requested
                    if preservePermissions {
                        applyPermissions(to: entryURL, from: entry)
                    }
                    
                    if verbose {
                        print("  Extracted: \(entry.path) (\(hash.prefix(8))...)")
                    }
                    
                    extractedCount += 1
                }
            } catch {
                errorCount += 1
                let errorMsg = "Failed to extract \(entry.path): \(error.localizedDescription)"
                errors.append(errorMsg)
                
                if verbose {
                    print("  Error: \(errorMsg)")
                }
                
                // Continue with next entry
                continue
            }
        }
        
        // Report results
        if verbose || errorCount > 0 {
            print("")
            print("Extraction complete:")
            print("  Extracted: \(extractedCount) entries")
            if errorCount > 0 {
                print("  Errors: \(errorCount)")
                for error in errors.prefix(5) {
                    print("    \(error)")
                }
                if errors.count > 5 {
                    print("    ... and \(errors.count - 5) more errors")
                }
            }
        }
        
        // Throw if all extractions failed
        if extractedCount == 0 && errorCount > 0 {
            throw SnugError.storageError("Failed to extract all entries", nil)
        }
    }
}

// Helper function to apply permissions from archive entry
private func applyPermissions(to url: URL, from entry: ArchiveEntry) {
    // Apply file permissions (Unix-style)
    if let permissions = entry.permissions {
        // Parse octal permissions (e.g., "0755")
        if let mode = parseOctalPermissions(permissions) {
            let attributes: [FileAttributeKey: Any] = [.posixPermissions: mode]
            try? FileManager.default.setAttributes(attributes, ofItemAtPath: url.path)
        }
    }
    
    // Note: Setting owner/group requires root privileges on macOS
    // This is typically not possible for regular users, so we skip it
    // In a production system, you might want to use chown via Process if running as root
}

// Helper function to parse octal permissions string
private func parseOctalPermissions(_ permissions: String) -> Int? {
    // Remove leading zeros and parse as octal
    let trimmed = permissions.trimmingCharacters(in: CharacterSet(charactersIn: "0"))
    guard !trimmed.isEmpty else {
        return Int(permissions, radix: 8)
    }
    return Int(trimmed, radix: 8)
}
