// FileSystemKit - Archive Contract Extensions
// Protocol extensions providing convenience methods and default implementations

import Foundation

// MARK: - ArchiveContract Extensions

extension ArchiveContract {
    /// Creates an archive from a directory using default options.
    ///
    /// Convenience method that uses `ArchiveOptions.default`.
    ///
    /// - Parameters:
    ///   - sourceURL: Source directory to archive
    ///   - outputURL: Output archive file URL
    /// - Returns: Archive creation statistics
    /// - Throws: Same errors as `createArchive(from:outputURL:options:)`
    /// - Example:
    ///   ```swift
    ///   let facade = FileSystemKitArchiveFacade(storageURL: storageURL)
    ///   let result = try await facade.createArchive(from: sourceURL, outputURL: outputURL)
    ///   ```
    @discardableResult
    public func createArchive(
        from sourceURL: URL,
        outputURL: URL
    ) async throws -> ArchiveResult {
        return try await createArchive(from: sourceURL, outputURL: outputURL, options: .default)
    }
    
    /// Extracts an archive to a directory using default options.
    ///
    /// Convenience method that uses `ExtractOptions.default`.
    ///
    /// - Parameters:
    ///   - archiveURL: Archive file URL
    ///   - outputURL: Output directory URL
    /// - Returns: Extraction result with statistics
    /// - Throws: Same errors as `extractArchive(from:to:options:)`
    /// - Example:
    ///   ```swift
    ///   let facade = FileSystemKitArchiveFacade(storageURL: storageURL)
    ///   let result = try await facade.extractArchive(from: archiveURL, to: outputURL)
    ///   ```
    @discardableResult
    public func extractArchive(
        from archiveURL: URL,
        to outputURL: URL
    ) async throws -> ExtractResult {
        return try await extractArchive(from: archiveURL, to: outputURL, options: .default)
    }
    
    /// Validates archive integrity using default options.
    ///
    /// Convenience method that uses `ValidateOptions.default`.
    ///
    /// - Parameter archiveURL: Archive file URL
    /// - Returns: Validation result indicating which files are present or missing
    /// - Throws: Same errors as `validateArchive(at:options:)`
    /// - Example:
    ///   ```swift
    ///   let facade = FileSystemKitArchiveFacade(storageURL: storageURL)
    ///   let result = try await facade.validateArchive(at: archiveURL)
    ///   ```
    public func validateArchive(at archiveURL: URL) async throws -> ValidationResult {
        return try await validateArchive(at: archiveURL, options: .default)
    }
    
    /// Returns the contents of an archive without extracting it, using default options.
    ///
    /// Convenience method that uses `ListOptions.default`.
    ///
    /// - Parameter archiveURL: Archive file URL
    /// - Returns: Archive listing with file information
    /// - Throws: Same errors as `contents(of:options:)`
    /// - Example:
    ///   ```swift
    ///   let facade = FileSystemKitArchiveFacade(storageURL: storageURL)
    ///   let listing = try await facade.contents(of: archiveURL)
    ///   ```
    public func contents(of archiveURL: URL) async throws -> ArchiveListing {
        return try await contents(of: archiveURL, options: .default)
    }
}

