// FileSystemKit - Archive Facade Implementation
// Facade that provides stable API contract while delegating to internal implementation

import Foundation

// MARK: - FileSystemKitArchiveFacade

/// Facade implementation of ArchiveContract
/// Provides stable API while internal implementation can evolve
public struct FileSystemKitArchiveFacade: ArchiveContract {
    private let storageURL: URL
    private let hashAlgorithm: String
    
    /// Initialize facade with storage configuration
    /// - Parameters:
    ///   - storageURL: Storage directory URL
    ///   - hashAlgorithm: Hash algorithm to use
    public init(storageURL: URL, hashAlgorithm: String = "sha256") {
        self.storageURL = storageURL
        self.hashAlgorithm = hashAlgorithm
    }
    
    public func createArchive(
        from sourceURL: URL,
        outputURL: URL,
        options: ArchiveOptions
    ) async throws -> ArchiveResult {
        // Delegate to internal implementation
        let archiver = try await SnugArchiver(
            storageURL: storageURL,
            hashAlgorithm: options.hashAlgorithm.isEmpty ? hashAlgorithm : options.hashAlgorithm
        )
        
        let stats = try await archiver.createArchive(
            from: sourceURL,
            outputURL: outputURL,
            verbose: options.verbose,
            followExternalSymlinks: options.followSymlinks,
            errorOnBrokenSymlinks: false,
            preserveSymlinks: options.preserveSymlinks,
            embedSystemFiles: options.embedSystemFiles,
            skipPermissionErrors: options.skipPermissionErrors,
            ignoreMatcher: nil
        )
        
        return ArchiveResult(
            filesProcessed: stats.fileCount,
            totalSize: stats.totalSize,
            archiveURL: outputURL
        )
    }
    
    public func extractArchive(
        from archiveURL: URL,
        to outputURL: URL,
        options: ExtractOptions
    ) async throws -> ExtractResult {
        // Delegate to internal implementation
        let extractor = try await SnugExtractor(storageURL: storageURL)
        try await extractor.extractArchive(
            from: archiveURL,
            to: outputURL,
            verbose: options.verbose,
            preservePermissions: options.preservePermissions
        )
        
        // Count extracted files (simplified - could be enhanced)
        let fileManager = FileManager.default
        var fileCount = 0
        let resourceKeys: [URLResourceKey] = [.isRegularFileKey]
        if let enumerator = fileManager.enumerator(at: outputURL, includingPropertiesForKeys: resourceKeys) {
            // Collect URLs first (enumerator iteration not available in async context)
            var allURLs: [URL] = []
            while let fileURL = enumerator.nextObject() as? URL {
                allURLs.append(fileURL)
            }
            // Count files
            for fileURL in allURLs {
                if let resourceValues = try? fileURL.resourceValues(forKeys: Set(resourceKeys)),
                   resourceValues.isRegularFile == true {
                    fileCount += 1
                }
            }
        }
        
        return ExtractResult(filesExtracted: fileCount, outputURL: outputURL)
    }
    
    public func validateArchive(
        _ archiveURL: URL,
        options: ValidateOptions
    ) async throws -> ValidationResult {
        // Delegate to internal implementation
        let validator = try SnugValidator(storageURL: storageURL)
        let parser = SnugParser()
        let archive = try parser.parseArchive(from: archiveURL)
        
        let result = try await validator.validateArchive(archive, verbose: options.verbose)
        
        return ValidationResult(
            allFilesExist: result.allFilesExist,
            totalFiles: result.totalFiles,
            filesFound: result.filesFound,
            filesMissing: result.filesMissing,
            missingHashes: result.missingHashes
        )
    }
    
    public func listArchive(
        _ archiveURL: URL,
        options: ListOptions
    ) async throws -> ArchiveListing {
        // Delegate to internal implementation
        let parser = SnugParser()
        let archive = try parser.parseArchive(from: archiveURL)
        
        let entries = archive.entries.map { entry in
            ArchiveListingEntry(
                path: entry.path,
                type: entry.type,
                size: entry.size,
                hash: entry.hash
            )
        }
        
        let totalSize = entries.compactMap { $0.size }.reduce(0, +)
        
        return ArchiveListing(
            entries: entries,
            totalFiles: entries.filter { $0.type == "file" }.count,
            totalSize: totalSize
        )
    }
}

