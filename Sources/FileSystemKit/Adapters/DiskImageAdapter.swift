// FileSystemKit - Disk Image Adapter Protocol (Layer 2)
//
// This file implements the DiskImageAdapter protocol for handling modern disk image formats.
// Layer 2: Modern Disk Image Format Layer
//
// The DiskImageAdapter extracts raw disk data from various modern image formats
// (e.g., .dmg, .iso, .vhd, .img) and converts them to RawDiskData.
//
// Note: Vintage formats (pre-2000) can be handled by packages that extend FileSystemKit

import Foundation

// MARK: - DiskImageAdapter Protocol

/// Protocol for adapters that handle modern disk image formats (Layer 2)
///
/// DiskImageAdapters extract raw disk data from various modern image formats
/// and convert them to RawDiskData structures. They handle the format-specific
/// details of how disk images are stored in files today.
///
/// **Layer 2**: Modern Disk Image Format Layer
/// - Input: Modern disk image file (.dmg, .iso, .vhd, .img, etc.)
/// - Output: RawDiskData (sectors, tracks, flux data, metadata)
///
/// The same file system (e.g., ISO 9660) can appear in different modern image
/// formats (e.g., .iso, .dmg). The DiskImageAdapter extracts the raw
/// data, then the FileSystemStrategy (Layer 3) parses it.
///
/// **Storage Protocol Usage**:
/// - Binary data operations use `ChunkStorage` protocol
/// - Metadata operations use `MetadataStorage` protocol
public protocol DiskImageAdapter: AnyObject {
    /// The disk image format this adapter handles
    static var format: DiskImageFormat { get }
    
    /// File extensions supported by this adapter
    static var supportedExtensions: [String] { get }
    
    /// Check if this adapter can read data with the given format signature
    /// - Parameter data: First few bytes of the disk image data (for format detection)
    /// - Returns: `true` if this adapter can read the data, `false` otherwise
    static func canRead(data: Data) -> Bool
    
    /// Extract raw disk data from a modern disk image format using ChunkStorage
    /// - Parameters:
    ///   - chunkStorage: ChunkStorage provider for reading binary data
    ///   - identifier: ChunkIdentifier for the disk image
    /// - Returns: RawDiskData containing sectors, tracks, flux data, and metadata
    /// - Throws: DiskImageError if the file cannot be read or parsed
    static func read(chunkStorage: ChunkStorage, identifier: ChunkIdentifier) async throws -> RawDiskData
    
    /// Extract metadata from a disk image using MetadataStorage
    /// - Parameters:
    ///   - metadataStorage: MetadataStorage provider for reading metadata
    ///   - hash: DiskImageHash identifier
    /// - Returns: DiskImageMetadata if available, `nil` if metadata cannot be extracted
    /// - Throws: DiskImageError if the metadata cannot be read
    static func extractMetadata(metadataStorage: MetadataStorage, hash: DiskImageHash) async throws -> DiskImageMetadata?
    
    /// Extract metadata from disk image data without fully reading it
    /// - Parameter data: Disk image data (may be partial for format detection)
    /// - Returns: DiskImageMetadata if available, `nil` if metadata cannot be extracted
    /// - Throws: DiskImageError if the metadata cannot be extracted
    static func extractMetadata(from data: Data) throws -> DiskImageMetadata?
    
    /// Write raw disk data to storage using ChunkStorage
    /// - Parameters:
    ///   - diskData: RawDiskData to write
    ///   - metadata: Optional metadata to include
    ///   - chunkStorage: ChunkStorage provider for writing binary data
    ///   - identifier: ChunkIdentifier for the disk image
    /// - Returns: The ChunkIdentifier of the stored chunk
    /// - Throws: DiskImageError if the data cannot be written
    static func write(diskData: RawDiskData, metadata: DiskImageMetadata?, chunkStorage: ChunkStorage, identifier: ChunkIdentifier) async throws -> ChunkIdentifier
}

// MARK: - DiskImageAdapterRegistry

/// Registry for disk image adapters
/// Uses singleton pattern to manage available adapters
public final class DiskImageAdapterRegistry {
    /// Shared singleton instance
    public static nonisolated(unsafe) let shared = DiskImageAdapterRegistry()
    
    /// Registered adapters by format
    private var adapters: [DiskImageFormat: DiskImageAdapter.Type] = [:]
    
    /// Registered adapters by file extension
    private var adaptersByExtension: [String: DiskImageAdapter.Type] = [:]
    
    private init() {
        // Register default adapters
        register(DMGImageAdapter.self)
        register(ISO9660ImageAdapter.self)
        register(VHDImageAdapter.self)
        register(IMGImageAdapter.self)
        register(RawDiskImageAdapter.self)
    }
    
    /// Register a disk image adapter
    /// - Parameter adapter: The adapter type to register
    public func register(_ adapter: DiskImageAdapter.Type) {
        adapters[adapter.format] = adapter
        
        // Register by extension
        for ext in adapter.supportedExtensions {
            adaptersByExtension[ext.lowercased()] = adapter
        }
    }
    
    /// Find an adapter for data with format detection
    /// - Parameter data: First few bytes of the disk image data (for format detection)
    /// - Returns: The adapter type that can handle this data, or `nil` if none found
    public func findAdapter(for data: Data) -> DiskImageAdapter.Type? {
        // Try all adapters to see which can read this data
        for (_, adapter) in adapters {
            if adapter.canRead(data: data) {
                return adapter
            }
        }
        
        return nil
    }
    
    /// Find an adapter for a given file extension (for initial detection)
    /// - Parameter extension: File extension (without dot)
    /// - Returns: The adapter type that typically handles this extension, or `nil` if none found
    public func findAdapter(forExtension ext: String) -> DiskImageAdapter.Type? {
        return adaptersByExtension[ext.lowercased()]
    }
    
    /// Find an adapter by reading a chunk from ChunkStorage
    /// - Parameters:
    ///   - chunkStorage: ChunkStorage provider
    ///   - identifier: ChunkIdentifier to read
    ///   - maxBytes: Maximum bytes to read for format detection (default: 512)
    /// - Returns: The adapter type that can handle this chunk, or `nil` if none found
    public func findAdapter(chunkStorage: ChunkStorage, identifier: ChunkIdentifier, maxBytes: Int = 512) async throws -> DiskImageAdapter.Type? {
        // Read first few bytes for format detection
        guard let data = try await chunkStorage.readChunk(identifier, offset: 0, length: maxBytes) else {
            return nil
        }
        
        return findAdapter(for: data)
    }
    
    /// Get all registered adapters
    /// - Returns: Array of registered adapter types
    public func allAdapters() -> [DiskImageAdapter.Type] {
        return Array(adapters.values)
    }
    
    /// Get adapter for a specific format
    /// - Parameter format: The disk image format
    /// - Returns: The adapter type for the format, or `nil` if not registered
    public func adapter(for format: DiskImageFormat) -> DiskImageAdapter.Type? {
        return adapters[format]
    }
}

// MARK: - DiskImageError

/// Errors that can occur in disk image operations
public enum DiskImageError: LocalizedError {
    case invalidFormat
    case unsupportedFormat
    case readFailed
    case writeFailed
    case metadataExtractionFailed
    case invalidData
    case notImplemented
    
    public var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "Invalid disk image format"
        case .unsupportedFormat:
            return "Unsupported disk image format"
        case .readFailed:
            return "Failed to read disk image"
        case .writeFailed:
            return "Failed to write disk image"
        case .metadataExtractionFailed:
            return "Failed to extract metadata from disk image"
        case .invalidData:
            return "Invalid disk image data"
        case .notImplemented:
            return "Disk image operation not yet implemented"
        }
    }
}

