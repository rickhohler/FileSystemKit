// FileSystemKit - Archive Contract
// Stable API contract for archive operations
// Implementation can evolve, but this contract remains stable

import Foundation

// MARK: - ArchiveContract

/// Stable contract for archive operations using the Snug archive format.
///
/// `ArchiveContract` defines the public API for creating, extracting, validating, and inspecting
/// content-addressable archives. This protocol provides a stable interface that client applications
/// can depend on, while allowing internal implementations to evolve.
///
/// ## Overview
///
/// The Snug archive format uses content-addressable storage, where files are stored by their
/// cryptographic hash rather than by name. This enables:
/// - **Deduplication**: Identical files are stored only once
/// - **Integrity**: Files can be verified using their hash
/// - **Efficiency**: Archives reference files rather than embedding them
///
/// ## Usage
///
/// Create an archive from a directory:
/// ```swift
/// let facade = FileSystemKitArchiveFacade(storageURL: storageURL)
/// let result = try await facade.createArchive(
///     from: sourceDirectoryURL,
///     outputURL: archiveURL,
///     options: .default
/// )
/// print("Created archive with \(result.filesProcessed) files")
/// ```
///
/// Extract an archive:
/// ```swift
/// let result = try await facade.extractArchive(
///     from: archiveURL,
///     to: outputDirectoryURL,
///     options: .preservePermissions
/// )
/// ```
///
/// List archive contents without extracting:
/// ```swift
/// let listing = try await facade.contents(of: archiveURL)
/// for entry in listing.entries {
///     print("\(entry.path): \(entry.size ?? 0) bytes")
/// }
/// ```
///
/// ## Topics
///
/// ### Creating Archives
/// - ``createArchive(from:outputURL:options:)``
/// - ``ArchiveOptions``
/// - ``ArchiveResult``
///
/// ### Extracting Archives
/// - ``extractArchive(from:to:options:)``
/// - ``ExtractOptions``
/// - ``ExtractResult``
///
/// ### Validating Archives
/// - ``validateArchive(at:options:)``
/// - ``ValidateOptions``
/// - ``ValidationResult``
///
/// ### Inspecting Archives
/// - ``contents(of:options:)``
/// - ``loadMetadata(from:)``
/// - ``ArchiveListing``
/// - ``ArchiveListingEntry``
///
/// ## See Also
///
/// - ``FileSystemKitArchiveFacade`` - Default implementation
/// - [Snug Archive Format Documentation](https://github.com/rickhohler/FileSystemKit/wiki/Snug-Format)
/// - [Content-Addressable Storage (Wikipedia)](https://en.wikipedia.org/wiki/Content-addressable_storage) - Overview of content-addressable storage systems
public protocol ArchiveContract: Sendable {
    /// Creates an archive from a directory.
    ///
    /// - Parameters:
    ///   - sourceURL: Source directory to archive
    ///   - outputURL: Output archive file URL
    ///   - options: Archive creation options
    /// - Returns: Archive creation statistics
    /// - Throws: `SnugError.directoryNotFound(path:)` if the source directory doesn't exist,
    ///           `SnugError.notADirectory(path:)` if the source path is not a directory,
    ///           `SnugError.permissionDenied(path:)` if read access is denied,
    ///           `SnugError.storageError(reason:underlyingError:)` if storage is unavailable,
    ///           `FileSystemError.writeFailed(path:underlyingError:)` if the archive cannot be written
    /// - Example:
    ///   ```swift
    ///   let facade = FileSystemKitArchiveFacade(storageURL: storageURL)
    ///   let result = try await facade.createArchive(
    ///       from: sourceURL,
    ///       outputURL: outputURL,
    ///       options: ArchiveOptions()
    ///   )
    ///   print("Processed \(result.filesProcessed) files")
    ///   ```
    @discardableResult
    func createArchive(
        from sourceURL: URL,
        outputURL: URL,
        options: ArchiveOptions
    ) async throws -> ArchiveResult
    
    /// Extracts an archive to a directory.
    ///
    /// - Parameters:
    ///   - archiveURL: Archive file URL
    ///   - outputURL: Output directory URL
    ///   - options: Extraction options
    /// - Returns: Extraction result with statistics
    /// - Throws: `SnugError.archiveNotFound(path:)` if the archive file doesn't exist,
    ///           `SnugError.invalidArchive(reason:)` if the archive is corrupted,
    ///           `SnugError.hashNotFound(hash:)` if required files are missing from storage,
    ///           `SnugError.extractionFailed(reason:underlyingError:)` if extraction fails,
    ///           `FileSystemError.permissionDenied(path:)` if write access is denied
    /// - Example:
    ///   ```swift
    ///   let facade = FileSystemKitArchiveFacade(storageURL: storageURL)
    ///   let result = try await facade.extractArchive(
    ///       from: archiveURL,
    ///       to: outputURL,
    ///       options: ExtractOptions(preservePermissions: true)
    ///   )
    ///   print("Extracted \(result.filesExtracted) files")
    ///   ```
    @discardableResult
    func extractArchive(
        from archiveURL: URL,
        to outputURL: URL,
        options: ExtractOptions
    ) async throws -> ExtractResult
    
    /// Validates archive integrity by checking that all referenced files exist in storage.
    ///
    /// - Parameters:
    ///   - archiveURL: Archive file URL
    ///   - options: Validation options
    /// - Returns: Validation result indicating which files are present or missing
    /// - Throws: `SnugError.archiveNotFound(path:)` if the archive file doesn't exist,
    ///           `SnugError.invalidArchive(reason:)` if the archive cannot be parsed,
    ///           `SnugError.storageError(reason:underlyingError:)` if storage is unavailable
    /// - Example:
    ///   ```swift
    ///   let facade = FileSystemKitArchiveFacade(storageURL: storageURL)
    ///   let result = try await facade.validateArchive(
    ///       archiveURL,
    ///       options: ValidateOptions(verbose: true)
    ///   )
    ///   if result.allFilesExist {
    ///       print("All files are present")
    ///   } else {
    ///       print("Missing \(result.filesMissing) files")
    ///   }
    ///   ```
    func validateArchive(
        at archiveURL: URL,
        options: ValidateOptions
    ) async throws -> ValidationResult
    
    /// Returns the contents of an archive without extracting it.
    ///
    /// - Parameters:
    ///   - archiveURL: Archive file URL
    ///   - options: Listing options
    /// - Returns: Archive listing with file information
    /// - Throws: `SnugError.archiveNotFound(path:)` if the archive file doesn't exist,
    ///           `SnugError.invalidArchive(reason:)` if the archive cannot be parsed
    /// - Example:
    ///   ```swift
    ///   let facade = FileSystemKitArchiveFacade(storageURL: storageURL)
    ///   let listing = try await facade.contents(
    ///       of: archiveURL,
    ///       options: ListOptions(includeMetadata: true)
    ///   )
    ///   for entry in listing.entries {
    ///       print("\(entry.path): \(entry.size ?? 0) bytes")
    ///   }
    ///   ```
    func contents(
        of archiveURL: URL,
        options: ListOptions
    ) async throws -> ArchiveListing
    
    /// Loads archive metadata without extracting files.
    ///
    /// - Parameter archiveURL: Archive file URL
    /// - Returns: Parsed archive metadata including entries, format, and version
    /// - Throws: `SnugError.archiveNotFound(path:)` if the archive file doesn't exist,
    ///           `SnugError.invalidArchive(reason:)` if the archive cannot be parsed or is corrupted
    /// - Example:
    ///   ```swift
    ///   let facade = FileSystemKitArchiveFacade(storageURL: storageURL)
    ///   let archive = try facade.loadMetadata(from: archiveURL)
    ///   print("Format: \(archive.format), Version: \(archive.version)")
    ///   print("Entries: \(archive.entries.count)")
    ///   ```
    func loadMetadata(from archiveURL: URL) throws -> SnugArchive
}

// MARK: - ArchiveOptions

/// Configuration options for creating Snug archives.
///
/// `ArchiveOptions` controls how archives are created, including hash algorithm selection,
/// symlink handling, and file filtering.
///
/// ## Usage
///
/// Use default options:
/// ```swift
/// let options = ArchiveOptions.default
/// ```
///
/// Customize options:
/// ```swift
/// let options = ArchiveOptions(
///     hashAlgorithm: "sha256",
///     ignorePatterns: ["*.tmp", ".git/*"],
///     preserveSymlinks: true
/// )
/// ```
///
/// Use convenience presets:
/// ```swift
/// let verboseOptions = ArchiveOptions.verbose
/// let symlinkOptions = ArchiveOptions.preserveSymlinks
/// ```
///
/// ## Hash Algorithms
///
/// Supported hash algorithms:
/// - `"sha256"` (default, recommended) - Secure and widely supported
/// - `"sha1"` - Faster but less secure
/// - `"md5"` - Fastest but not cryptographically secure
///
/// ## Symlink Handling
///
/// Choose one of:
/// - `preserveSymlinks: true` - Store symlinks as-is in archive
/// - `followSymlinks: true` - Resolve symlinks and store target files
///
/// **Note**: `preserveSymlinks` and `followSymlinks` are mutually exclusive.
///
/// ## Ignore Patterns
///
/// Use glob patterns to exclude files:
/// ```swift
/// let options = ArchiveOptions(
///     ignorePatterns: ["*.tmp", "build/*", ".git/**"]
/// )
/// ```
///
/// Patterns support:
/// - `*` - Matches any characters except `/`
/// - `**` - Matches any characters including `/`
/// - `?` - Matches a single character
///
/// ## See Also
///
/// - ``ArchiveContract/createArchive(from:outputURL:options:)``
public struct ArchiveOptions: Sendable {
    /// Hash algorithm to use for content-addressable storage
    public let hashAlgorithm: String
    
    /// Enable verbose output during archive creation
    public let verbose: Bool
    
    /// Follow external symlinks (resolve symlinks pointing outside the source directory)
    public let followSymlinks: Bool
    
    /// Preserve symlinks in the archive (store symlinks as-is rather than resolving them)
    public let preserveSymlinks: Bool
    
    /// Embed system files (e.g., .DS_Store, ._* files) in the archive
    public let embedSystemFiles: Bool
    
    /// Skip permission errors and continue archiving
    public let skipPermissionErrors: Bool
    
    /// Throw an error if broken symlinks are encountered
    public let errorOnBrokenSymlinks: Bool
    
    /// Patterns to ignore (e.g., ["*.tmp", ".git/*"])
    public let ignorePatterns: [String]
    
    /// Creates archive creation options with the specified values.
    ///
    /// - Parameters:
    ///   - hashAlgorithm: Hash algorithm to use. Supported: `"sha256"` (default, recommended), `"sha1"`, `"md5"`.
    ///   - verbose: Enable verbose output during creation
    ///   - followSymlinks: Follow external symlinks (conflicts with `preserveSymlinks`)
    ///   - preserveSymlinks: Preserve symlinks as-is in archive
    ///   - embedSystemFiles: Include system files like `.DS_Store`
    ///   - skipPermissionErrors: Continue on permission errors
    ///   - errorOnBrokenSymlinks: Throw error for broken symlinks
    ///   - ignorePatterns: Glob patterns to ignore (e.g., `["*.tmp", ".git/*"]`)
    public init(
        hashAlgorithm: String = "sha256",
        verbose: Bool = false,
        followSymlinks: Bool = false,
        preserveSymlinks: Bool = false,
        embedSystemFiles: Bool = false,
        skipPermissionErrors: Bool = false,
        errorOnBrokenSymlinks: Bool = false,
        ignorePatterns: [String] = []
    ) {
        self.hashAlgorithm = hashAlgorithm
        self.verbose = verbose
        self.followSymlinks = followSymlinks
        self.preserveSymlinks = preserveSymlinks
        self.embedSystemFiles = embedSystemFiles
        self.skipPermissionErrors = skipPermissionErrors
        self.errorOnBrokenSymlinks = errorOnBrokenSymlinks
        self.ignorePatterns = ignorePatterns
    }
    
    /// Default archive creation options with recommended settings.
    public static let `default` = ArchiveOptions()
    
    /// Verbose archive creation options for debugging.
    public static let verbose = ArchiveOptions(verbose: true)
    
    /// Options for preserving symlinks in archives.
    public static let preserveSymlinks = ArchiveOptions(preserveSymlinks: true)
    
    /// Options for following symlinks (resolving them).
    public static let followSymlinks = ArchiveOptions(followSymlinks: true)
}

// MARK: - ExtractOptions

/// Configuration options for extracting Snug archives.
///
/// `ExtractOptions` controls how archives are extracted, including permission preservation
/// and output verbosity.
///
/// ## Usage
///
/// Use default options:
/// ```swift
/// let options = ExtractOptions.default
/// ```
///
/// Preserve file permissions (recommended for production):
/// ```swift
/// let options = ExtractOptions.preservePermissions
/// ```
///
/// Customize options:
/// ```swift
/// let options = ExtractOptions(
///     verbose: true,
///     preservePermissions: true
/// )
/// ```
///
/// ## Permission Preservation
///
/// When `preservePermissions` is `true`, file permissions from the archive are restored
/// on extracted files. This is recommended for production use to maintain file security.
///
/// ## See Also
///
/// - ``ArchiveContract/extractArchive(from:to:options:)``
public struct ExtractOptions: Sendable {
    /// Enable verbose output during extraction
    public let verbose: Bool
    
    /// Preserve file permissions from the archive
    public let preservePermissions: Bool
    
    /// Creates extraction options with the specified values.
    ///
    /// - Parameters:
    ///   - verbose: Enable verbose output during extraction
    ///   - preservePermissions: Preserve file permissions from archive (recommended for production)
    public init(
        verbose: Bool = false,
        preservePermissions: Bool = false
    ) {
        self.verbose = verbose
        self.preservePermissions = preservePermissions
    }
    
    /// Default extraction options.
    public static let `default` = ExtractOptions()
    
    /// Verbose extraction options for debugging.
    public static let verbose = ExtractOptions(verbose: true)
    
    /// Options for preserving file permissions (recommended).
    public static let preservePermissions = ExtractOptions(preservePermissions: true)
}

// MARK: - ValidateOptions

/// Configuration options for validating Snug archives.
///
/// `ValidateOptions` controls how archive validation is performed, including output verbosity.
///
/// ## Usage
///
/// Use default options:
/// ```swift
/// let options = ValidateOptions.default
/// ```
///
/// Enable verbose output for debugging:
/// ```swift
/// let options = ValidateOptions.verbose
/// ```
///
/// ## Validation Process
///
/// Validation checks that all files referenced in the archive metadata exist in the
/// content-addressable storage. This is useful for:
/// - Verifying archive integrity
/// - Checking for missing files
/// - Auditing storage completeness
///
/// ## See Also
///
/// - ``ArchiveContract/validateArchive(at:options:)``
/// - ``ValidationResult``
public struct ValidateOptions: Sendable {
    /// Enable verbose output during validation
    public let verbose: Bool
    
    /// Creates validation options with the specified values.
    ///
    /// - Parameter verbose: Enable verbose output showing which files are checked
    public init(verbose: Bool = false) {
        self.verbose = verbose
    }
    
    /// Default validation options.
    public static let `default` = ValidateOptions()
    
    /// Verbose validation options for debugging.
    public static let verbose = ValidateOptions(verbose: true)
}

// MARK: - ListOptions

/// Configuration options for listing Snug archive contents.
///
/// `ListOptions` controls what information is included when listing archive contents,
/// including metadata like file sizes and hashes.
///
/// ## Usage
///
/// List paths only (fastest):
/// ```swift
/// let options = ListOptions.default
/// ```
///
/// Include file metadata:
/// ```swift
/// let options = ListOptions.withMetadata
/// ```
///
/// Customize options:
/// ```swift
/// let options = ListOptions(
///     verbose: true,
///     includeMetadata: true
/// )
/// ```
///
/// ## Metadata Inclusion
///
/// When `includeMetadata` is `true`, the listing includes:
/// - File sizes (in bytes)
/// - Content hashes (if available)
/// - File types (file, directory, symlink)
///
/// **Note**: Including metadata requires reading the archive metadata file, which may
/// be slower for large archives.
///
/// ## See Also
///
/// - ``ArchiveContract/contents(of:options:)``
/// - ``ArchiveListing``
public struct ListOptions: Sendable {
    /// Enable verbose output during listing
    public let verbose: Bool
    
    /// Include file metadata (size, hash) in listing
    public let includeMetadata: Bool
    
    /// Creates listing options with the specified values.
    ///
    /// - Parameters:
    ///   - verbose: Enable verbose output during listing
    ///   - includeMetadata: Include file metadata (size, hash) in results
    public init(
        verbose: Bool = false,
        includeMetadata: Bool = false
    ) {
        self.verbose = verbose
        self.includeMetadata = includeMetadata
    }
    
    /// Default listing options (paths only).
    public static let `default` = ListOptions()
    
    /// Verbose listing options for debugging.
    public static let verbose = ListOptions(verbose: true)
    
    /// Options for listing with full metadata.
    public static let withMetadata = ListOptions(includeMetadata: true)
}

// MARK: - ArchiveResult

/// Result returned after successfully creating a Snug archive.
///
/// `ArchiveResult` provides statistics about the archive creation process, including
/// the number of files processed and total size.
///
/// ## Usage
///
/// ```swift
/// let result = try await facade.createArchive(
///     from: sourceURL,
///     outputURL: outputURL,
///     options: .default
/// )
///
/// print("Processed \(result.filesProcessed) files")
/// print("Total size: \(result.totalSize) bytes")
/// print("Archive location: \(result.archiveURL)")
/// ```
///
/// ## Properties
///
/// - `filesProcessed` - Number of files included in the archive
/// - `totalSize` - Total size of all files in bytes (before deduplication)
/// - `archiveURL` - Location of the created archive file
///
/// ## See Also
///
/// - ``ArchiveContract/createArchive(from:outputURL:options:)``
public struct ArchiveResult: Sendable, CustomStringConvertible {
    /// Number of files processed during archive creation
    public let filesProcessed: Int
    
    /// Total size of all files in the archive (in bytes)
    public let totalSize: Int
    
    /// URL of the created archive file
    public let archiveURL: URL
    
    /// Creates an archive creation result.
    ///
    /// - Parameters:
    ///   - filesProcessed: Number of files processed
    ///   - totalSize: Total size of files in bytes
    ///   - archiveURL: URL of the created archive
    public init(filesProcessed: Int, totalSize: Int, archiveURL: URL) {
        self.filesProcessed = filesProcessed
        self.totalSize = totalSize
        self.archiveURL = archiveURL
    }
    
    /// A textual representation of the archive creation result.
    public var description: String {
        return "ArchiveResult(\(filesProcessed) files, \(totalSize) bytes, \(archiveURL.lastPathComponent))"
    }
}

// MARK: - ExtractResult

/// Result returned after successfully extracting a Snug archive.
///
/// `ExtractResult` provides information about the extraction process, including
/// the number of files extracted and the output location.
///
/// ## Usage
///
/// ```swift
/// let result = try await facade.extractArchive(
///     from: archiveURL,
///     to: outputURL,
///     options: .preservePermissions
/// )
///
/// print("Extracted \(result.filesExtracted) files")
/// print("Output location: \(result.outputURL)")
/// ```
///
/// ## Properties
///
/// - `filesExtracted` - Number of files extracted from the archive
/// - `outputURL` - Directory where files were extracted
///
/// ## See Also
///
/// - ``ArchiveContract/extractArchive(from:to:options:)``
public struct ExtractResult: Sendable, CustomStringConvertible {
    /// Number of files extracted from the archive
    public let filesExtracted: Int
    
    /// URL of the output directory where files were extracted
    public let outputURL: URL
    
    /// Creates an extraction result.
    ///
    /// - Parameters:
    ///   - filesExtracted: Number of files extracted
    ///   - outputURL: URL of the output directory
    public init(filesExtracted: Int, outputURL: URL) {
        self.filesExtracted = filesExtracted
        self.outputURL = outputURL
    }
    
    /// A textual representation of the extraction result.
    public var description: String {
        return "ExtractResult(\(filesExtracted) files, \(outputURL.lastPathComponent))"
    }
}

// MARK: - ValidationResult

/// Result returned after validating a Snug archive.
///
/// `ValidationResult` indicates whether all files referenced in the archive exist
/// in the content-addressable storage, and provides details about missing files if any.
///
/// ## Usage
///
/// ```swift
/// let result = try await facade.validateArchive(at: archiveURL)
///
/// if result.allFilesExist {
///     print("All \(result.totalFiles) files are present")
/// } else {
///     print("Missing \(result.filesMissing) of \(result.totalFiles) files")
///     print("Missing hashes: \(result.missingHashes)")
/// }
/// ```
///
/// ## Properties
///
/// - `allFilesExist` - `true` if all referenced files are present in storage
/// - `totalFiles` - Total number of files referenced in the archive
/// - `filesFound` - Number of files found in storage
/// - `filesMissing` - Number of files missing from storage
/// - `missingHashes` - Array of hash values for missing files
///
/// ## Use Cases
///
/// Validation is useful for:
/// - Verifying archive integrity before extraction
/// - Auditing storage completeness
/// - Identifying missing files that need to be restored
///
/// ## See Also
///
/// - ``ArchiveContract/validateArchive(at:options:)``
public struct ValidationResult: Sendable, CustomStringConvertible {
    /// Whether all files referenced in the archive exist in storage
    public let allFilesExist: Bool
    
    /// Total number of files referenced in the archive
    public let totalFiles: Int
    
    /// Number of files found in storage
    public let filesFound: Int
    
    /// Number of files missing from storage
    public let filesMissing: Int
    
    /// Array of hash values for files that are missing from storage
    public let missingHashes: [String]
    
    /// Creates a validation result.
    ///
    /// - Parameters:
    ///   - allFilesExist: Whether all files exist
    ///   - totalFiles: Total number of files
    ///   - filesFound: Number found
    ///   - filesMissing: Number missing
    ///   - missingHashes: Hashes of missing files
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
    
    /// A textual representation of the validation result.
    public var description: String {
        if allFilesExist {
            return "ValidationResult(all \(totalFiles) files exist)"
        } else {
            return "ValidationResult(\(filesFound)/\(totalFiles) files exist, \(filesMissing) missing)"
        }
    }
}

// MARK: - ArchiveListing

/// Complete listing of files in a Snug archive.
///
/// `ArchiveListing` provides a snapshot of all files in an archive without extracting them.
/// This is useful for previewing archive contents or building file browsers.
///
/// ## Usage
///
/// ```swift
/// let listing = try await facade.contents(of: archiveURL, options: .withMetadata)
///
/// print("Archive contains \(listing.totalFiles) files")
/// print("Total size: \(listing.totalSize) bytes")
///
/// for entry in listing.entries {
///     print("\(entry.path): \(entry.size ?? 0) bytes")
/// }
/// ```
///
/// ## Properties
///
/// - `entries` - Array of file entries in the archive
/// - `totalFiles` - Total number of files
/// - `totalSize` - Total size of all files in bytes
///
/// ## Performance
///
/// Listing archive contents is fast because it only reads the archive metadata file,
/// not the actual file content. Including metadata (`includeMetadata: true`) adds
/// minimal overhead.
///
/// ## See Also
///
/// - ``ArchiveContract/contents(of:options:)``
/// - ``ArchiveListingEntry``
public struct ArchiveListing: Sendable, CustomStringConvertible {
    /// Array of file entries in the archive
    public let entries: [ArchiveListingEntry]
    
    /// Total number of files in the archive
    public let totalFiles: Int
    
    /// Total size of all files in the archive (in bytes)
    public let totalSize: Int
    
    /// Creates an archive listing.
    ///
    /// - Parameters:
    ///   - entries: Array of file entries
    ///   - totalFiles: Total number of files
    ///   - totalSize: Total size in bytes
    public init(entries: [ArchiveListingEntry], totalFiles: Int, totalSize: Int) {
        self.entries = entries
        self.totalFiles = totalFiles
        self.totalSize = totalSize
    }
    
    /// A textual representation of the archive listing.
    public var description: String {
        return "ArchiveListing(\(totalFiles) files, \(totalSize) bytes)"
    }
}

// MARK: - ArchiveListingEntry

/// Represents a single file, directory, or symlink in an archive listing.
///
/// `ArchiveListingEntry` provides information about an individual item in an archive,
/// including its path, type, size, and content hash (if available).
///
/// ## Usage
///
/// ```swift
/// let listing = try await facade.contents(of: archiveURL, options: .withMetadata)
///
/// for entry in listing.entries {
///     switch entry.type {
///     case "file":
///         print("File: \(entry.path) (\(entry.size ?? 0) bytes)")
///     case "directory":
///         print("Directory: \(entry.path)")
///     case "symlink":
///         print("Symlink: \(entry.path)")
///     default:
///         print("Unknown: \(entry.path)")
///     }
/// }
/// ```
///
/// ## Properties
///
/// - `path` - File path within the archive (relative to archive root)
/// - `type` - File type: `"file"`, `"directory"`, or `"symlink"`
/// - `size` - File size in bytes (nil for directories or if not requested)
/// - `hash` - Content hash (nil if not requested or not available)
///
/// ## File Types
///
/// - `"file"` - Regular file
/// - `"directory"` - Directory/folder
/// - `"symlink"` - Symbolic link
///
/// ## See Also
///
/// - ``ArchiveListing``
public struct ArchiveListingEntry: Sendable {
    /// File path within the archive
    public let path: String
    
    /// File type: `"file"`, `"directory"`, or `"symlink"`
    public let type: String
    
    /// File size in bytes (nil if not available)
    public let size: Int?
    
    /// File content hash (nil if not available or not requested)
    public let hash: String?
    
    /// Creates an archive listing entry.
    ///
    /// - Parameters:
    ///   - path: File path within archive
    ///   - type: File type (`"file"`, `"directory"`, `"symlink"`)
    ///   - size: File size in bytes (optional)
    ///   - hash: File content hash (optional)
    public init(path: String, type: String, size: Int?, hash: String?) {
        self.path = path
        self.type = type
        self.size = size
        self.hash = hash
    }
}

