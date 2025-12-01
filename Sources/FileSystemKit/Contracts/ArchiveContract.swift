// FileSystemKit - Archive Contract
// Stable API contract for archive operations
// Implementation can evolve, but this contract remains stable

import Foundation

// MARK: - ArchiveContract

/// Stable contract for archive operations
/// This protocol defines the public API that client applications depend on.
/// Internal implementations can change freely as long as they conform to this contract.
public protocol ArchiveContract: Sendable {
    /// Create archive from directory
    /// - Parameters:
    ///   - sourceURL: Source directory to archive
    ///   - outputURL: Output archive file URL
    ///   - options: Archive creation options
    /// - Returns: Archive creation statistics
    /// - Throws: Error if archive creation fails
    func createArchive(
        from sourceURL: URL,
        outputURL: URL,
        options: ArchiveOptions
    ) async throws -> ArchiveResult
    
    /// Extract archive to directory
    /// - Parameters:
    ///   - archiveURL: Archive file URL
    ///   - outputURL: Output directory URL
    ///   - options: Extraction options
    /// - Returns: Extraction result with statistics
    /// - Throws: Error if extraction fails
    func extractArchive(
        from archiveURL: URL,
        to outputURL: URL,
        options: ExtractOptions
    ) async throws -> ExtractResult
    
    /// Validate archive integrity
    /// - Parameters:
    ///   - archiveURL: Archive file URL
    ///   - options: Validation options
    /// - Returns: Validation result
    /// - Throws: Error if validation fails
    func validateArchive(
        _ archiveURL: URL,
        options: ValidateOptions
    ) async throws -> ValidationResult
    
    /// List archive contents
    /// - Parameters:
    ///   - archiveURL: Archive file URL
    ///   - options: Listing options
    /// - Returns: Archive listing with file information
    /// - Throws: Error if listing fails
    func listArchive(
        _ archiveURL: URL,
        options: ListOptions
    ) async throws -> ArchiveListing
}

// MARK: - ArchiveOptions

/// Options for archive creation (stable contract)
public struct ArchiveOptions: Sendable {
    public let hashAlgorithm: String
    public let verbose: Bool
    public let followSymlinks: Bool
    public let preserveSymlinks: Bool
    public let embedSystemFiles: Bool
    public let skipPermissionErrors: Bool
    
    public init(
        hashAlgorithm: String = "sha256",
        verbose: Bool = false,
        followSymlinks: Bool = false,
        preserveSymlinks: Bool = false,
        embedSystemFiles: Bool = false,
        skipPermissionErrors: Bool = false
    ) {
        self.hashAlgorithm = hashAlgorithm
        self.verbose = verbose
        self.followSymlinks = followSymlinks
        self.preserveSymlinks = preserveSymlinks
        self.embedSystemFiles = embedSystemFiles
        self.skipPermissionErrors = skipPermissionErrors
    }
}

// MARK: - ExtractOptions

/// Options for archive extraction (stable contract)
public struct ExtractOptions: Sendable {
    public let verbose: Bool
    public let preservePermissions: Bool
    
    public init(
        verbose: Bool = false,
        preservePermissions: Bool = false
    ) {
        self.verbose = verbose
        self.preservePermissions = preservePermissions
    }
}

// MARK: - ValidateOptions

/// Options for archive validation (stable contract)
public struct ValidateOptions: Sendable {
    public let verbose: Bool
    
    public init(verbose: Bool = false) {
        self.verbose = verbose
    }
}

// MARK: - ListOptions

/// Options for archive listing (stable contract)
public struct ListOptions: Sendable {
    public let verbose: Bool
    public let includeMetadata: Bool
    
    public init(
        verbose: Bool = false,
        includeMetadata: Bool = false
    ) {
        self.verbose = verbose
        self.includeMetadata = includeMetadata
    }
}

// MARK: - ArchiveResult

/// Result of archive creation (stable contract)
public struct ArchiveResult: Sendable {
    public let filesProcessed: Int
    public let totalSize: Int
    public let archiveURL: URL
    
    public init(filesProcessed: Int, totalSize: Int, archiveURL: URL) {
        self.filesProcessed = filesProcessed
        self.totalSize = totalSize
        self.archiveURL = archiveURL
    }
}

// MARK: - ExtractResult

/// Result of archive extraction (stable contract)
public struct ExtractResult: Sendable {
    public let filesExtracted: Int
    public let outputURL: URL
    
    public init(filesExtracted: Int, outputURL: URL) {
        self.filesExtracted = filesExtracted
        self.outputURL = outputURL
    }
}

// MARK: - ValidationResult

/// Result of archive validation (stable contract)
public struct ValidationResult: Sendable {
    public let allFilesExist: Bool
    public let totalFiles: Int
    public let filesFound: Int
    public let filesMissing: Int
    public let missingHashes: [String]
    
    public init(
        allFilesExist: Bool,
        totalFiles: Int,
        filesFound: Int,
        filesMissing: Int,
        missingHashes: [String]
    ) {
        self.allFilesExist = allFilesExist
        self.totalFiles = totalFiles
        self.filesFound = filesFound
        self.filesMissing = filesMissing
        self.missingHashes = missingHashes
    }
}

// MARK: - ArchiveListing

/// Archive file listing (stable contract)
public struct ArchiveListing: Sendable {
    public let entries: [ArchiveListingEntry]
    public let totalFiles: Int
    public let totalSize: Int
    
    public init(entries: [ArchiveListingEntry], totalFiles: Int, totalSize: Int) {
        self.entries = entries
        self.totalFiles = totalFiles
        self.totalSize = totalSize
    }
}

// MARK: - ArchiveListingEntry

/// Single entry in archive listing (stable contract)
public struct ArchiveListingEntry: Sendable {
    public let path: String
    public let type: String
    public let size: Int?
    public let hash: String?
    
    public init(path: String, type: String, size: Int?, hash: String?) {
        self.path = path
        self.type = type
        self.size = size
        self.hash = hash
    }
}

