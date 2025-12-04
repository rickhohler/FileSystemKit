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
import DesignAlgorithmsKit

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

/// Base protocol for file system parsing strategies using the Strategy Pattern.
///
/// `FileSystemStrategy` defines the interface for parsing different file system formats.
/// Each file system format (ISO9660, FAT32, etc.) implements this protocol to handle
/// its specific layout and structure.
///
/// ## Overview
///
/// File system strategies enable:
/// - **Format Detection**: Identify file system formats automatically
/// - **Metadata Parsing**: Extract file system structure without loading file content
/// - **On-Demand Reading**: Load file content only when needed
/// - **Format-Specific Operations**: Handle format-specific features
///
/// ## Critical Design: Metadata-First Parsing
///
/// The strategy pattern uses a metadata-first approach:
/// - `parse()` returns `FileSystemFolder` with `FileSystemEntry` objects containing **metadata only**
/// - File content is **not** loaded during parsing
/// - File content is loaded on-demand via `readFile()` method
/// - This enables fast parsing of thousands of files without loading all content
///
/// ## Usage
///
/// Detect file system format:
/// ```swift
/// let diskData: RawDiskData = // ... obtained from disk image adapter
///
/// if let format = ISO9660Strategy.detectFormat(in: diskData) {
///     print("Detected format: \(format)")
/// }
/// ```
///
/// Parse file system structure:
/// ```swift
/// let strategy = ISO9660Strategy()
/// let rootFolder = try strategy.parse(diskData: diskData)
///
/// // Traverse files (metadata only, no content loaded)
/// for component in rootFolder.traverse() {
///     print("\(component.name): \(component.size) bytes")
/// }
/// ```
///
/// Read file content on-demand:
/// ```swift
/// let file: FileSystemEntry = // ... obtained from parsing
/// let chunkStorage: ChunkStorage = // ... storage provider
/// let identifier = ChunkIdentifier(id: file.hash?.hexString ?? "")
///
/// // Load file content only when needed
/// let fileData = try await strategy.readFile(
///     file,
///     chunkStorage: chunkStorage,
///     identifier: identifier
/// )
/// ```
///
/// ## Performance Considerations
///
/// - **Parsing**: Fast - only reads file system metadata structures
/// - **Content Loading**: On-demand - only loads files that are accessed
/// - **Memory**: Efficient - avoids loading entire disk images into memory
///
/// ## See Also
///
/// - ``FileSystemFormat`` - Supported file system formats
/// - ``FileSystemStrategyFactory`` - Factory for creating strategies
/// - ``FileSystemFolder`` - Result of parsing
/// - ``FileSystemEntry`` - File metadata
/// - [Strategy Pattern (Wikipedia)](https://en.wikipedia.org/wiki/Strategy_pattern) - Design pattern for algorithms
/// - Uses DesignAlgorithmsKit.Strategy protocol for strategy identification
public protocol FileSystemStrategy: Strategy {
    /// File system format this strategy handles
    static var format: FileSystemFormat { get }
    
    /// Whether this file system supports subdirectories (hierarchical directory structure)
    /// - `true`: File system supports nested subdirectories (e.g., ProDOS, ISO9660, FAT32)
    /// - `false`: File system only supports flat directory structure (e.g., DOS 3.3, Commodore 64)
    /// 
    /// ## Examples
    /// 
    /// File systems with subdirectory support:
    /// - ProDOS: Supports nested subdirectories
    /// - ISO9660: Supports directory hierarchies
    /// - FAT32: Supports nested directories
    /// 
    /// File systems with flat directory only:
    /// - Apple DOS 3.3: Single catalog, no subdirectories
    /// - Commodore 64 (1541): Single directory, no subdirectories
    /// - Atari DOS: Single directory, no subdirectories
    static var supportsSubdirectories: Bool { get }
    
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
    ///   - file: FileSystemEntry object (with metadata and location)
    ///   - chunkStorage: ChunkStorage provider for reading binary data
    ///   - identifier: ChunkIdentifier for the file content
    /// - Returns: File content as Data
    /// - Throws: Error if file cannot be read
    func readFile(_ file: FileSystemEntry, chunkStorage: ChunkStorage, identifier: ChunkIdentifier) async throws -> Data
    
    /// Write file content to storage using ChunkStorage.
    /// - Parameters:
    ///   - data: File content to write
    ///   - file: FileSystemEntry object (with metadata and location)
    ///   - chunkStorage: ChunkStorage provider for writing binary data
    ///   - identifier: ChunkIdentifier for the file content
    /// - Returns: The ChunkIdentifier of the stored file content
    /// - Throws: Error if file cannot be written
    func writeFile(_ data: Data, as file: FileSystemEntry, chunkStorage: ChunkStorage, identifier: ChunkIdentifier) async throws -> ChunkIdentifier
    
    // MARK: - Legacy methods (for backward compatibility)
    
    /// Read file content from raw disk data (on-demand loading) - Legacy method.
    /// - Parameters:
    ///   - file: FileSystemEntry object (with metadata and location)
    ///   - diskData: Raw disk data containing file content
    /// - Returns: File content as Data
    /// - Throws: Error if file cannot be read
    @available(*, deprecated, message: "Use readFile(_:chunkStorage:identifier:) instead")
    func readFile(_ file: FileSystemEntry, from diskData: RawDiskData) throws -> Data
    
    /// Write file content to raw disk data - Legacy method.
    /// - Parameters:
    ///   - data: File content to write
    ///   - file: FileSystemEntry object (with metadata and location)
    ///   - diskData: Raw disk data to write to (modified in place)
    /// - Throws: Error if file cannot be written
    @available(*, deprecated, message: "Use writeFile(_:as:chunkStorage:identifier:) instead")
    func writeFile(_ data: Data, as file: FileSystemEntry, to diskData: inout RawDiskData) throws
    
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
    
    /// Whether this file system instance supports subdirectories
    /// Delegates to the static `supportsSubdirectories` property
    var supportsSubdirectories: Bool { get }
}

// MARK: - FileSystemStrategy Default Implementations

extension FileSystemStrategy {
    /// Default implementation: Strategy ID uses format rawValue
    public var strategyID: String {
        Self.format.rawValue
    }
    
    /// Default implementation: Instance property delegates to static property
    public var supportsSubdirectories: Bool {
        Self.supportsSubdirectories
    }
    /// Default implementation: Read file from ChunkStorage
    /// Converts ChunkIdentifier to diskData-based read for backward compatibility
    public func readFile(_ file: FileSystemEntry, chunkStorage: ChunkStorage, identifier: ChunkIdentifier) async throws -> Data {
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
    public func writeFile(_ data: Data, as file: FileSystemEntry, chunkStorage: ChunkStorage, identifier: ChunkIdentifier) async throws -> ChunkIdentifier {
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
    /// Use thread-safe lazy initialization to avoid static initialization order issues
    nonisolated(unsafe) private static var _registeredStrategies: [FileSystemFormat: FileSystemStrategy.Type]?
    nonisolated private static let lock = NSLock()
    
    /// Thread-safe access to registered strategies
    private static var registeredStrategies: [FileSystemFormat: FileSystemStrategy.Type] {
        lock.lock()
        defer { lock.unlock() }
        if _registeredStrategies == nil {
            _registeredStrategies = [:]
            // Initialize defaults without recursion
            _registeredStrategies?[ISO9660FileSystemStrategy.format] = ISO9660FileSystemStrategy.self
        }
        return _registeredStrategies!
    }
    
    /// Register a file system strategy
    /// - Parameter strategyType: Strategy type to register
    /// Thread-safe: Can be called concurrently
    public static func register<T: FileSystemStrategy>(_ strategyType: T.Type) {
        lock.lock()
        defer { lock.unlock() }
        if _registeredStrategies == nil {
            _registeredStrategies = [:]
            // Initialize defaults without recursion
            _registeredStrategies?[ISO9660FileSystemStrategy.format] = ISO9660FileSystemStrategy.self
        }
        _registeredStrategies?[strategyType.format] = strategyType
    }
    
    /// Get all registered strategies
    /// - Returns: Array of registered strategy types
    public static func allStrategies() -> [FileSystemStrategy.Type] {
        Array(registeredStrategies.values)
    }
    
    /// Detect file system format in raw disk data
    /// - Parameter diskData: Raw disk data to analyze
    /// - Returns: Detected file system format, or nil if unknown
    /// - Note: This detects the file system format (Layer 3), not the disk image format (Layer 2)
    ///   The disk image format should already be detected and stored in diskData.metadata.detectedDiskImageFormat
    public static func detectFormat(in diskData: RawDiskData) -> FileSystemFormat? {
        // Access registeredStrategies property (which ensures initialization)
        let strategies = registeredStrategies
        // Try each registered strategy
        for strategyType in strategies.values {
            if let format = strategyType.detectFormat(in: diskData) {
                // Store detected format in metadata
                if diskData.metadata == nil {
                    diskData.metadata = DiskImageMetadata()
                }
                diskData.metadata?.detectedFileSystemFormat = format
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
        // Access registeredStrategies property (which ensures initialization)
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
        // Access registeredStrategies property (which ensures initialization)
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

