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
    
    public func validateArchive(_ archive: SnugArchive, verbose: Bool) throws -> SnugValidationResult {
        let fileEntries = archive.entries.filter { $0.type == "file" && $0.hash != nil }
        
        let semaphore = DispatchSemaphore(value: 0)
        let resultHolder = ValidationResultHolder()
        let storage = chunkStorage
        
        Task {
            var foundCount = 0
            var missingHashes: [String] = []
            
            for entry in fileEntries {
                guard let hash = entry.hash else { continue }
                let identifier = ChunkIdentifier(id: hash)
                
                do {
                    let exists = try await storage.chunkExists(identifier)
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
                } catch {
                    resultHolder.error = error
                    semaphore.signal()
                    return
                }
            }
            
            resultHolder.foundCount = foundCount
            resultHolder.missingHashes = missingHashes
            semaphore.signal()
        }
        
        semaphore.wait()
        
        if let error = resultHolder.error {
            throw error
        }
        
        return SnugValidationResult(
            allFilesExist: resultHolder.missingHashes.isEmpty,
            totalFiles: fileEntries.count,
            filesFound: resultHolder.foundCount,
            filesMissing: resultHolder.missingHashes.count,
            missingHashes: resultHolder.missingHashes
        )
    }
}

// Helper class for thread-safe storage
private final class ValidationResultHolder: @unchecked Sendable {
    var foundCount: Int = 0
    var missingHashes: [String] = []
    var error: Error?
}


