// FileSystemKit - SNUG Archive Extraction
// Extracts files from .snug archives

import Foundation

/// Extracts files from SNUG archives
public class SnugExtractor {
    let storageURL: URL
    let chunkStorage: SnugFileSystemChunkStorage
    
    public init(storageURL: URL) throws {
        self.storageURL = storageURL
        self.chunkStorage = try SnugStorage.createChunkStorage(at: storageURL)
    }
    
    // Synchronous wrapper for async operations
    public func extractArchive(from archiveURL: URL, to outputURL: URL, verbose: Bool) throws {
        let semaphore = DispatchSemaphore(value: 0)
        let resultHolder = ExtractionResultHolder()
        let storage = chunkStorage
        
        Task { @Sendable [storage, archiveURL, outputURL, verbose, resultHolder] in
            do {
                try await Self.extractArchiveAsync(from: archiveURL, to: outputURL, verbose: verbose, storage: storage)
                semaphore.signal()
            } catch {
                resultHolder.error = error
                semaphore.signal()
            }
        }
        
        semaphore.wait()
        
        if let error = resultHolder.error {
            throw error
        }
    }
    
    private static func extractArchiveAsync(from archiveURL: URL, to outputURL: URL, verbose: Bool, storage: SnugFileSystemChunkStorage) async throws {
    
        // 1. Parse archive
        let parser = SnugParser()
        let archive = try parser.parseArchive(from: archiveURL)
        
        // 2. Ensure output directory exists
        try FileManager.default.createDirectory(
            at: outputURL,
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        // 3. Extract entries
        for entry in archive.entries {
            let entryURL = outputURL.appendingPathComponent(entry.path)
            
            if entry.type == "directory" {
                // Create directory
                try FileManager.default.createDirectory(
                    at: entryURL,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
                
                if verbose {
                    print("  Created directory: \(entry.path)")
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
                
                if verbose {
                    print("  Extracted: \(entry.path) (\(hash.prefix(8))...)")
                }
            }
        }
    }
}

// Helper class for thread-safe error storage
private final class ExtractionResultHolder: @unchecked Sendable {
    var error: Error?
}


