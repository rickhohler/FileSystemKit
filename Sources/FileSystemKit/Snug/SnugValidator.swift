// FileSystemKit - SNUG Archive Validator
// Validates that archive files exist in storage

import Foundation

/// Validates SNUG archives
public class SnugValidator {
    let storageURL: URL
    let chunkStorage: SnugFileSystemChunkStorage
    
    public init(storageURL: URL) throws {
        self.storageURL = storageURL
        self.chunkStorage = try SnugStorage.createChunkStorage(at: storageURL)
    }
    
    /// Validate that all files in archive exist in storage
    /// - Parameters:
    ///   - archive: Archive to validate
    ///   - verbose: Whether to print progress
    /// - Returns: Validation result
    /// - Throws: Error if validation fails
    /// Thread-safe: Properly async implementation
    public func validateArchive(_ archive: SnugArchive, verbose: Bool) async throws -> SnugValidationResult {
        let fileEntries = archive.entries.filter { $0.type == "file" && $0.hash != nil }
        
        var foundCount = 0
        var missingHashes: [String] = []
        
        for entry in fileEntries {
            guard let hash = entry.hash else { continue }
            let identifier = ChunkIdentifier(id: hash)
            
            let exists = try await chunkStorage.chunkExists(identifier)
            if exists {
                foundCount += 1
                if verbose {
                    print("  ✓ \(entry.path) (\(hash.prefix(8))...)")
                }
            } else {
                missingHashes.append(hash)
                if verbose {
                    print("  ✗ \(entry.path) (\(hash.prefix(8))...) - MISSING")
                }
            }
        }
        
        return SnugValidationResult(
            allFilesExist: missingHashes.isEmpty,
            totalFiles: fileEntries.count,
            filesFound: foundCount,
            filesMissing: missingHashes.count,
            missingHashes: missingHashes
        )
    }
}
