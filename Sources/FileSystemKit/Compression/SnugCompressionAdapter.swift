// FileSystemKit - SNUG Compression Adapter
// Implements CompressionAdapter protocol for SNUG archives

import Foundation
#if canImport(Compression)
import Compression
#endif

/// Compression adapter for SNUG archives
/// SNUG files are compressed YAML documents (gzip/deflate)
public struct SnugCompressionAdapter: CompressionAdapter {
    public static var format: CompressionFormat { .snug }
    
    public static var supportedExtensions: [String] {
        format.extensions
    }
    
    public static func canHandle(url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return supportedExtensions.contains(where: { $0.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ".")) == ext })
    }
    
    public static func isCompressed(url: URL) -> Bool {
        return canHandle(url: url)
    }
    
    public static func decompress(url: URL) throws -> URL {
        // 1. Read compressed data
        let compressedData = try Data(contentsOf: url)
        
        // 2. Decompress gzip/deflate
        let decompressedData = try decompressGzip(data: compressedData)
        
        // 3. Create temporary YAML file
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("yaml")
        
        try decompressedData.write(to: tempURL)
        return tempURL
    }
    
    public static func compress(data: Data, to url: URL) throws {
        // 1. Compress YAML data with gzip/deflate
        let compressedData = try compressGzip(data: data)
        
        // 2. Write compressed file
        try compressedData.write(to: url)
    }
    
    #if canImport(Compression)
    private static func decompressGzip(data: Data) throws -> Data {
        let bufferSize = max(data.count * 4, 1024 * 1024)  // At least 1MB
        let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { destinationBuffer.deallocate() }
        
        let decompressedSize = data.withUnsafeBytes { sourceBuffer -> Int in
            guard let baseAddress = sourceBuffer.baseAddress else {
                return 0
            }
            return compression_decode_buffer(
                destinationBuffer,
                bufferSize,
                baseAddress.assumingMemoryBound(to: UInt8.self),
                data.count,
                nil,
                COMPRESSION_LZFSE
            )
        }
        
        guard decompressedSize > 0 else {
            throw CompressionError.decompressionFailed
        }
        
        return Data(bytes: destinationBuffer, count: decompressedSize)
    }
    
    private static func compressGzip(data: Data) throws -> Data {
        let bufferSize = data.count + (data.count / 10) + 16
        let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { destinationBuffer.deallocate() }
        
        let compressedSize = data.withUnsafeBytes { sourceBuffer -> Int in
            guard let baseAddress = sourceBuffer.baseAddress else {
                return 0
            }
            return compression_encode_buffer(
                destinationBuffer,
                bufferSize,
                baseAddress.assumingMemoryBound(to: UInt8.self),
                data.count,
                nil,
                COMPRESSION_LZFSE
            )
        }
        
        guard compressedSize > 0 else {
            throw CompressionError.compressionFailed
        }
        
        return Data(bytes: destinationBuffer, count: compressedSize)
    }
    #else
    private static func decompressGzip(data: Data) throws -> Data {
        throw CompressionError.notImplemented
    }
    
    private static func compressGzip(data: Data) throws -> Data {
        throw CompressionError.notImplemented
    }
    #endif
}

