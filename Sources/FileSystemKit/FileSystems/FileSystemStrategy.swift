// FileSystemKit Core Library
// File System Strategy Protocol
//
// This file implements the Strategy Pattern for modern file system layouts:
// - FileSystemStrategy: Base protocol for all file system strategies
// - FileSystemFormat: Enumeration of supported modern file system formats
// - FileSystemStrategyFactory: Factory for creating and detecting strategies
//
// Critical Design: Metadata-First Parsing
// - parse() returns FileSystemFolder with File objects containing metadata only
// - File content is NOT loaded during parsing
// - File content is loaded on-demand via readFile() method
// - This enables fast parsing of thousands of files
//
// Note: Vintage file systems (pre-2000) can be handled by packages that extend FileSystemKit

import Foundation

// MARK: - FormatParameters

/// Parameters for formatting a new disk image
public struct FormatParameters: Codable {
    /// File system format
    public let format: FileSystemFormat
    
    /// Disk geometry (optional, uses defaults if nil)
    public var geometry: DiskGeometry?
    
    /// Volume name/label
    public var volumeName: String?
    
    /// Additional format-specific parameters
    public var options: [String: Any]
    
    public init(
        format: FileSystemFormat,
        geometry: DiskGeometry? = nil,
        volumeName: String? = nil,
        options: [String: Any] = [:]
    ) {
        self.format = format
        self.geometry = geometry
        self.volumeName = volumeName
        self.options = options
    }
    
    // Custom Codable implementation for options (Dictionary with Any values)
    enum CodingKeys: String, CodingKey {
        case format, geometry, volumeName
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        format = try container.decode(FileSystemFormat.self, forKey: .format)
        geometry = try container.decodeIfPresent(DiskGeometry.self, forKey: .geometry)
        volumeName = try container.decodeIfPresent(String.self, forKey: .volumeName)
        options = [:] // Options not encoded (Any type not Codable)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(format, forKey: .format)
        try container.encodeIfPresent(geometry, forKey: .geometry)
        try container.encodeIfPresent(volumeName, forKey: .volumeName)
        // Options not encoded (Any type not Codable)
    }
}

// MARK: - FileSystemStrategy Protocol

/// Base protocol for file system strategies (Strategy Pattern).
/// Each modern file system format implements this protocol to parse its specific layout.
///
/// **Critical Design: Metadata-First Parsing**
/// - `parse()` returns FileSystemFolder with File objects containing **metadata only** (no content loaded)
/// - File content is loaded on-demand via `readFile()` method
/// - This enables fast parsing of thousands of files without loading all content
public protocol FileSystemStrategy {
    /// File system format this strategy handles
    static var format: FileSystemFormat { get }
    
    /// Check if this strategy can handle the given raw disk data
    /// - Parameter diskData: Raw disk data to check
    /// - Returns: true if this strategy can handle the data
    static func canHandle(diskData: RawDiskData) -> Bool
    
    /// Detect the file system format in the given raw disk data
    /// - Parameter diskData: Raw disk data to analyze
    /// - Returns: Detected file system format, or nil if unknown
    static func detectFormat(in diskData: RawDiskData) -> FileSystemFormat?
    
    /// Parse the file system structure from raw disk data.
    /// **Returns files with metadata only - no content loaded.**
    /// - Parameter diskData: Raw disk data to parse
    /// - Returns: Root folder containing files and subfolders (metadata only)
    /// - Throws: Error if parsing fails
    func parse(diskData: RawDiskData) throws -> FileSystemFolder
    
    /// Read file content from storage using ChunkStorage.
    /// - Parameters:
    ///   - file: File object (with metadata and location)
    ///   - chunkStorage: ChunkStorage provider for reading binary data
    ///   - identifier: ChunkIdentifier for the file content
    /// - Returns: File content as Data
    /// - Throws: Error if file cannot be read
    func readFile(_ file: File, chunkStorage: ChunkStorage, identifier: ChunkIdentifier) async throws -> Data
    
    /// Write file content to storage using ChunkStorage.
    /// - Parameters:
    ///   - data: File content to write
    ///   - file: File object (with metadata and location)
    ///   - chunkStorage: ChunkStorage provider for writing binary data
    ///   - identifier: ChunkIdentifier for the file content
    /// - Returns: The ChunkIdentifier of the stored file content
    /// - Throws: Error if file cannot be written
    func writeFile(_ data: Data, as file: File, chunkStorage: ChunkStorage, identifier: ChunkIdentifier) async throws -> ChunkIdentifier
    
    // MARK: - Legacy methods (for backward compatibility)
    
    /// Read file content from raw disk data (on-demand loading) - Legacy method.
    /// - Parameters:
    ///   - file: File object (with metadata and location)
    ///   - diskData: Raw disk data containing file content
    /// - Returns: File content as Data
    /// - Throws: Error if file cannot be read
    @available(*, deprecated, message: "Use readFile(_:chunkStorage:identifier:) instead")
    func readFile(_ file: File, from diskData: RawDiskData) throws -> Data
    
    /// Write file content to raw disk data - Legacy method.
    /// - Parameters:
    ///   - data: File content to write
    ///   - file: File object (with metadata and location)
    ///   - diskData: Raw disk data to write to (modified in place)
    /// - Throws: Error if file cannot be written
    @available(*, deprecated, message: "Use writeFile(_:as:chunkStorage:identifier:) instead")
    func writeFile(_ data: Data, as file: File, to diskData: inout RawDiskData) throws
    
    /// Create a new formatted disk image.
    /// - Parameter parameters: Format parameters
    /// - Returns: New raw disk data with formatted file system
    /// - Throws: Error if formatting fails
    static func format(parameters: FormatParameters) throws -> RawDiskData
    
    /// Get file system format information
    var format: FileSystemFormat { get }
    
    /// Get disk capacity in bytes
    var capacity: Int { get }
    
    /// Get block/sector size in bytes
    var blockSize: Int { get }
}

// MARK: - FileSystemStrategy Default Implementations

extension FileSystemStrategy {
    /// Default implementation: Read file from ChunkStorage
    /// Converts ChunkIdentifier to diskData-based read for backward compatibility
    public func readFile(_ file: File, chunkStorage: ChunkStorage, identifier: ChunkIdentifier) async throws -> Data {
        // Read chunk data
        guard let data = try await chunkStorage.readChunk(identifier) else {
            throw FileSystemError.fileNotFound(path: "chunk:\(identifier.id)")
        }
        
        // For now, return the full chunk data
        // In the future, adapters can override to extract specific file content
        return data
    }
    
    /// Default implementation: Write file to ChunkStorage
    /// Converts to diskData-based write for backward compatibility, then stores in ChunkStorage
    public func writeFile(_ data: Data, as file: File, chunkStorage: ChunkStorage, identifier: ChunkIdentifier) async throws -> ChunkIdentifier {
        // Store directly in ChunkStorage
        // Note: Legacy writeFile modifies diskData in place, but we're storing the file content directly
        let chunkMetadata = ChunkMetadata(
            size: data.count,
            contentHash: identifier.id,
            hashAlgorithm: "sha256",
            contentType: "application/octet-stream",
            chunkType: "file-content",
            originalFilename: file.name
        )
        
        return try await chunkStorage.writeChunk(data, identifier: identifier, metadata: chunkMetadata)
    }
}

// MARK: - FileSystemStrategyFactory

/// Factory for creating and detecting file system strategies
public class FileSystemStrategyFactory {
    /// Registered strategies (format -> strategy type)
    /// Note: This is typically initialized at startup, so concurrency safety is managed by initialization order
    nonisolated(unsafe) private static var registeredStrategies: [FileSystemFormat: FileSystemStrategy.Type] = [:]
    
    /// Initialize default strategies
    private static func initializeDefaults() {
        // Register ISO9660 strategy
        register(ISO9660FileSystemStrategy.self)
    }
    
    /// Ensure defaults are initialized (called on first access)
    private static func ensureInitialized() {
        if registeredStrategies.isEmpty {
            initializeDefaults()
        }
    }
    
    /// Register a file system strategy
    /// - Parameter strategyType: Strategy type to register
    public static func register<T: FileSystemStrategy>(_ strategyType: T.Type) {
        ensureInitialized()
        registeredStrategies[T.format] = strategyType
    }
    
    /// Get all registered strategies
    /// - Returns: Array of registered strategy types
    public static func allStrategies() -> [FileSystemStrategy.Type] {
        Array(registeredStrategies.values)
    }
    
    /// Detect file system format in raw disk data
    /// - Parameter diskData: Raw disk data to analyze
    /// - Returns: Detected file system format, or nil if unknown
    public static func detectFormat(in diskData: RawDiskData) -> FileSystemFormat? {
        ensureInitialized()
        // Try each registered strategy
        for strategyType in registeredStrategies.values {
            if let format = strategyType.detectFormat(in: diskData) {
                return format
            }
        }
        return nil
    }
    
    /// Create a strategy instance for the given format
    /// - Parameter format: File system format
    /// - Returns: Strategy instance, or nil if not registered
    /// - Note: This creates a "detection-only" instance. For parsing, use `createStrategy(for:diskData:)` instead.
    public static func createStrategy(for format: FileSystemFormat) -> FileSystemStrategy? {
        ensureInitialized()
        guard registeredStrategies[format] != nil else {
            return nil
        }
        
        // For strategies that require diskData for initialization, we can't create an instance here
        // Instead, return nil and require callers to use createStrategy(for:diskData:) for parsing
        // This method is primarily for checking if a strategy is available
        return nil
    }
    
    /// Create a strategy instance for the given format with disk data
    /// - Parameters:
    ///   - format: File system format
    ///   - diskData: Raw disk data to parse
    /// - Returns: Strategy instance, or nil if not registered or initialization fails
    public static func createStrategy(for format: FileSystemFormat, diskData: RawDiskData) throws -> FileSystemStrategy? {
        ensureInitialized()
        guard registeredStrategies[format] != nil else {
            return nil
        }
        
        // Try to create instance using the strategy's initializer
        // Strategies should implement init(diskData: RawDiskData) throws
        // We'll use a type-erased approach to call the initializer
        
        switch format {
        case .iso9660:
            return try ISO9660FileSystemStrategy(diskData: diskData)
        default:
            // For other formats, return nil (not yet implemented)
            return nil
        }
    }
    
    /// Get strategy type for the given format
    /// - Parameter format: File system format
    /// - Returns: Strategy type, or nil if not registered
    public static func strategyType(for format: FileSystemFormat) -> FileSystemStrategy.Type? {
        return registeredStrategies[format]
    }
    
    /// Check if a strategy is registered for the given format
    /// - Parameter format: File system format
    /// - Returns: true if strategy is registered
    public static func isRegistered(format: FileSystemFormat) -> Bool {
        return registeredStrategies[format] != nil
    }
}

// MARK: - FileSystemError Extensions

extension FileSystemError {
    /// File system format not supported
    public static let unsupportedFormat = FileSystemError.invalidFileSystem(reason: nil)
    
    /// File system format not detected
    public static let formatNotDetected = FileSystemError.invalidFileSystem(reason: nil)
    
    /// Get error for unsupported format
    public static func unsupportedFormatError() -> FileSystemError {
        return .invalidFileSystem(reason: nil)
    }
    
    /// Get error for format not detected
    public static func formatNotDetectedError() -> FileSystemError {
        return .invalidFileSystem(reason: nil)
    }
}

