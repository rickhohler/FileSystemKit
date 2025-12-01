// FileSystemKit - Archive Facade Implementation
// Facade that provides stable API contract while delegating to internal implementation

import Foundation

// MARK: - FileSystemKitArchiveFacade

/// Default implementation of `ArchiveContract` for working with Snug archives.
///
/// `FileSystemKitArchiveFacade` provides a stable API for creating, extracting, validating,
/// and inspecting content-addressable archives. The facade pattern ensures that the public API
/// remains stable while internal implementations can evolve.
///
/// ## Overview
///
/// The facade manages content-addressable storage where files are stored by their cryptographic
/// hash. This enables deduplication, integrity verification, and efficient storage.
///
/// ## Initialization
///
/// Create a facade with a storage directory:
/// ```swift
/// let storageURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
/// let facade = FileSystemKitArchiveFacade(storageURL: storageURL)
/// ```
///
/// Use a custom hash algorithm:
/// ```swift
/// let facade = FileSystemKitArchiveFacade(
///     storageURL: storageURL,
///     hashAlgorithm: "sha256"
/// )
/// ```
///
/// ## Creating Archives
///
/// Create an archive from a directory:
/// ```swift
/// let sourceURL = URL(fileURLWithPath: "/path/to/source")
/// let archiveURL = URL(fileURLWithPath: "/path/to/archive.snug")
///
/// let result = try await facade.createArchive(
///     from: sourceURL,
///     outputURL: archiveURL,
///     options: .default
/// )
///
/// print("Created archive with \(result.filesProcessed) files")
/// print("Total size: \(result.totalSize) bytes")
/// ```
///
/// Create with custom options:
/// ```swift
/// let options = ArchiveOptions(
///     hashAlgorithm: "sha256",
///     ignorePatterns: ["*.tmp", ".git/*", "build/"],
///     preserveSymlinks: true,
///     verbose: true
/// )
///
/// let result = try await facade.createArchive(
///     from: sourceURL,
///     outputURL: archiveURL,
///     options: options
/// )
/// ```
///
/// ## Extracting Archives
///
/// Extract an archive to a directory:
/// ```swift
/// let archiveURL = URL(fileURLWithPath: "/path/to/archive.snug")
/// let outputURL = URL(fileURLWithPath: "/path/to/output")
///
/// let result = try await facade.extractArchive(
///     from: archiveURL,
///     to: outputURL,
///     options: .preservePermissions
/// )
///
/// print("Extracted \(result.filesExtracted) files to \(result.outputURL)")
/// ```
///
/// ## Validating Archives
///
/// Check that all files in an archive exist in storage:
/// ```swift
/// let archiveURL = URL(fileURLWithPath: "/path/to/archive.snug")
///
/// let result = try await facade.validateArchive(at: archiveURL)
///
/// if result.allFilesExist {
///     print("✓ All \(result.totalFiles) files are present")
/// } else {
///     print("✗ Missing \(result.filesMissing) of \(result.totalFiles) files")
///     for hash in result.missingHashes {
///         print("  Missing: \(hash)")
///     }
/// }
/// ```
///
/// ## Listing Archive Contents
///
/// List files in an archive without extracting:
/// ```swift
/// let archiveURL = URL(fileURLWithPath: "/path/to/archive.snug")
///
/// let listing = try await facade.contents(
///     of: archiveURL,
///     options: .withMetadata
/// )
///
/// print("Archive contains \(listing.totalFiles) files (\(listing.totalSize) bytes)")
///
/// for entry in listing.entries {
///     if entry.type == "file" {
///         print("  \(entry.path): \(entry.size ?? 0) bytes")
///     } else if entry.type == "directory" {
///         print("  \(entry.path)/")
///     }
/// }
/// ```
///
/// ## Loading Metadata
///
/// Load archive metadata for programmatic access:
/// ```swift
/// let archiveURL = URL(fileURLWithPath: "/path/to/archive.snug")
///
/// let archive = try facade.loadMetadata(from: archiveURL)
///
/// print("Format: \(archive.format)")
/// print("Version: \(archive.version)")
/// print("Entries: \(archive.entries.count)")
///
/// for entry in archive.entries {
///     print("  \(entry.path) (\(entry.type))")
/// }
/// ```
///
/// ## Storage Requirements
///
/// The `storageURL` must:
/// - Point to a persistent directory that will remain available
/// - Have write permissions for archive creation
/// - Have read permissions for archive extraction and validation
/// - Be accessible for the lifetime of archives created with this facade
///
/// **Important**: The storage directory contains content-addressable chunks that may be
/// shared across multiple archives. Do not delete files from this directory manually.
///
/// ## Thread Safety
///
/// `FileSystemKitArchiveFacade` is thread-safe and can be used concurrently from multiple
/// threads or async tasks. Each facade instance manages its own storage configuration.
///
/// ## See Also
///
/// - ``ArchiveContract`` - Protocol definition
/// - ``ArchiveOptions`` - Archive creation options
/// - ``ExtractOptions`` - Extraction options
/// - [Facade Pattern (Wikipedia)](https://en.wikipedia.org/wiki/Facade_pattern) - Design pattern for simplified interfaces
/// - [Content-Addressable Storage (Wikipedia)](https://en.wikipedia.org/wiki/Content-addressable_storage) - Overview of content-addressable storage
public struct FileSystemKitArchiveFacade: ArchiveContract {
    private let storageURL: URL
    private let hashAlgorithm: String
    
    /// Creates a facade instance with storage configuration.
    ///
    /// - Parameters:
    ///   - storageURL: Storage directory URL where archive content chunks will be stored.
    ///                 This should be a persistent directory that will remain available
    ///                 for the lifetime of archives created with this facade.
    ///   - hashAlgorithm: Hash algorithm to use for content-addressable storage.
    ///                    Supported values: `"sha256"` (default, recommended), `"sha1"`, `"md5"`.
    ///                    The algorithm must match when creating and extracting archives.
    /// - Example:
    ///   ```swift
    ///   let storageURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
    ///   let facade = FileSystemKitArchiveFacade(storageURL: storageURL)
    ///   ```
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
        
        // Build ignore matcher from patterns
        let ignoreMatcher: SnugIgnoreMatcher? = options.ignorePatterns.isEmpty ? nil : SnugIgnoreMatcher(patterns: options.ignorePatterns)
        
        let stats = try await archiver.createArchive(
            from: sourceURL,
            outputURL: outputURL,
            verbose: options.verbose,
            followExternalSymlinks: options.followSymlinks,
            errorOnBrokenSymlinks: options.errorOnBrokenSymlinks,
            preserveSymlinks: options.preserveSymlinks,
            embedSystemFiles: options.embedSystemFiles,
            skipPermissionErrors: options.skipPermissionErrors,
            ignoreMatcher: ignoreMatcher
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
        at archiveURL: URL,
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
    
    public func contents(
        of archiveURL: URL,
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
    
    public func loadMetadata(from archiveURL: URL) throws -> SnugArchive {
        // Delegate to internal implementation
        let parser = SnugParser()
        return try parser.parseArchive(from: archiveURL)
    }
}

