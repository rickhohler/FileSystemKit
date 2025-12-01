// FileSystemKit Core Library
// Compression Adapter Protocol
//
// This file implements Layer 1: Compression Wrapper Layer
// - CompressionAdapter: Base protocol for compression adapters
//
// Critical Design: Transparent Decompression
// - Compression adapters decompress transparently
// - Decompressed data is passed to DiskImageAdapter (Layer 2)
// - Handles nested compression (e.g., .tar.gz)

import Foundation

/// Protocol for compression adapters (Layer 1).
/// Handles compressed or archived disk images, decompressing them to reveal the underlying disk image format.
public protocol CompressionAdapter {
    /// Compression format this adapter handles
    static var format: CompressionFormat { get }
    
    /// File extensions supported by this adapter
    static var supportedExtensions: [String] { get }
    
    /// Check if this adapter can handle the given URL
    /// - Parameter url: URL to check
    /// - Returns: true if this adapter can handle the file
    static func canHandle(url: URL) -> Bool
    
    /// Decompress the file at the given URL
    /// - Parameter url: URL of compressed file
    /// - Returns: URL to temporary file containing decompressed data
    /// - Throws: Error if decompression fails
    static func decompress(url: URL) throws -> URL
    
    /// Compress data to the given URL
    /// - Parameters:
    ///   - data: Data to compress
    ///   - url: Destination URL for compressed file
    /// - Throws: Error if compression fails
    static func compress(data: Data, to url: URL) throws
    
    /// Check if file is compressed (has compression wrapper)
    /// - Parameter url: URL to check
    /// - Returns: true if file appears to be compressed
    static func isCompressed(url: URL) -> Bool
}

