// FileSystemKit Core Library
// Gzip Compression Adapter

import Foundation
#if canImport(Compression)
import Compression
#endif

/// Gzip compression adapter (.gz, .gzip)
/// Note: GZIP format is backward compatible across versions.
/// Modern implementations can read older GZIP files, so version-specific
/// handling is not required. The format uses DEFLATE compression.
public struct GzipCompressionAdapter: CompressionAdapter {
    public static var format: CompressionFormat { .gzip }
    
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
        let data = try Data(contentsOf: url)
        
        // Validate GZIP format (magic bytes: 0x1f 0x8b)
        guard data.count >= 10 else {
            throw CompressionError.invalidFormat
        }
        
        guard data[0] == 0x1f && data[1] == 0x8b else {
            throw CompressionError.invalidFormat
        }
        
        // GZIP header is 10 bytes:
        // - 0-1: Magic bytes (0x1f 0x8b)
        // - 2: Compression method (8 = DEFLATE)
        // - 3: Flags
        // - 4-7: Modification time (Unix timestamp)
        // - 8: Extra flags
        // - 9: Operating system
        
        let compressionMethod = data[2]
        guard compressionMethod == 8 else {  // 8 = DEFLATE
            throw CompressionError.notImplemented  // Only DEFLATE is supported
        }
        
        // Skip GZIP header (10 bytes) and optional extra fields
        var offset = 10
        let flags = data[3]
        
        // Skip optional extra field if present
        if (flags & 0x04) != 0 {  // FEXTRA flag
            guard offset + 2 <= data.count else {
                throw CompressionError.invalidFormat
            }
            let xlen = UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
            offset += 2 + Int(xlen)
        }
        
        // Skip optional filename if present
        if (flags & 0x08) != 0 {  // FNAME flag
            while offset < data.count && data[offset] != 0 {
                offset += 1
            }
            offset += 1  // Skip null terminator
        }
        
        // Skip optional comment if present
        if (flags & 0x10) != 0 {  // FCOMMENT flag
            while offset < data.count && data[offset] != 0 {
                offset += 1
            }
            offset += 1  // Skip null terminator
        }
        
        // Skip optional CRC16 header if present
        if (flags & 0x02) != 0 {  // FHCRC flag
            offset += 2
        }
        
        // GZIP footer is last 8 bytes:
        // - Last 4 bytes: CRC32
        // - Last 8-4 bytes: Uncompressed size (mod 2^32)
        guard data.count >= offset + 8 else {
            throw CompressionError.invalidFormat
        }
        
        let compressedDataEnd = data.count - 8
        let compressedData = data.subdata(in: offset..<compressedDataEnd)
        
        // Decompress using DEFLATE
        let decompressedData = try decompressGzip(data: compressedData)
        
        // Verify footer CRC32 and size (optional - can be skipped for MVP)
        // For now, we'll trust the decompression
        
        // Create temporary file for decompressed data
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        
        try decompressedData.write(to: tempURL)
        return tempURL
    }
    
    public static func compress(data: Data, to url: URL) throws {
        let compressed = try compressGzip(data: data)
        try compressed.write(to: url)
    }
    
    // MARK: - Private Helpers
    
    #if canImport(Compression)
    private static func decompressGzip(data: Data) throws -> Data {
        // Use Compression framework with zlib algorithm for DEFLATE decompression
        // GZIP uses DEFLATE compression, which is compatible with zlib
        
        // Allocate buffer for decompression (estimate 4x original size, but allow growth)
        var bufferSize = max(data.count * 4, 1024 * 1024)  // Start with at least 1MB
        var destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { destinationBuffer.deallocate() }
        
        var result: Int = 0
        var attempts = 0
        let maxAttempts = 3
        
        // Try decompression with increasing buffer sizes if needed
        while attempts < maxAttempts {
            let destinationBufferSize = bufferSize
            result = data.withUnsafeBytes { sourceBuffer -> Int in
                guard let baseAddress = sourceBuffer.baseAddress else {
                    return 0
                }
                // Use zlib algorithm for DEFLATE decompression (GZIP uses DEFLATE)
                // COMPRESSION_ZLIB is available in Compression framework
                return compression_decode_buffer(
                    destinationBuffer,
                    destinationBufferSize,
                    baseAddress.assumingMemoryBound(to: UInt8.self),
                    data.count,
                    nil,
                    COMPRESSION_ZLIB  // Use zlib for DEFLATE/gzip compatibility
                )
            }
            
            if result > 0 {
                // Success
                break
            }
            
            // If buffer was too small, try with larger buffer
            if result == 0 && attempts < maxAttempts - 1 {
                destinationBuffer.deallocate()
                bufferSize *= 2
                destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
            }
            
            attempts += 1
        }
        
        if result == 0 {
            throw CompressionError.decompressionFailed
        }
        
        return Data(bytes: destinationBuffer, count: result)
    }
    
    private static func compressGzip(data: Data) throws -> Data {
        // Use Compression framework with DEFLATE algorithm
        // GZIP uses DEFLATE compression
        
        // Allocate buffer for compression (estimate compressed size)
        let bufferSize = data.count + 1024
        let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { destinationBuffer.deallocate() }
        
        let destinationBufferSize = bufferSize
        let result = data.withUnsafeBytes { sourceBuffer -> Int in
            guard let baseAddress = sourceBuffer.baseAddress else {
                return 0
            }
            // Use zlib algorithm for DEFLATE compression (compatible with GZIP)
            return compression_encode_buffer(
                destinationBuffer,
                destinationBufferSize,
                baseAddress.assumingMemoryBound(to: UInt8.self),
                data.count,
                nil,
                COMPRESSION_ZLIB  // Use zlib for DEFLATE/gzip compatibility
            )
        }
        
        if result == 0 {
            throw CompressionError.compressionFailed
        }
        
        // Create GZIP format: header + compressed data + footer
        var gzipData = Data()
        
        // GZIP header (10 bytes)
        gzipData.append(contentsOf: [0x1f, 0x8b])  // Magic bytes
        gzipData.append(8)  // Compression method: DEFLATE
        gzipData.append(0)  // Flags: none
        gzipData.append(contentsOf: [0, 0, 0, 0])  // Modification time (unset)
        gzipData.append(0)  // Extra flags
        gzipData.append(255)  // Operating system: unknown
        
        // Compressed data
        gzipData.append(Data(bytes: destinationBuffer, count: result))
        
        // GZIP footer (8 bytes): CRC32 + uncompressed size
        // For MVP, we'll use placeholder values
        let crc32: UInt32 = 0  // TODO: Calculate actual CRC32
        let uncompressedSize: UInt32 = UInt32(data.count)
        
        gzipData.append(contentsOf: withUnsafeBytes(of: crc32.littleEndian) { Data($0) })
        gzipData.append(contentsOf: withUnsafeBytes(of: uncompressedSize.littleEndian) { Data($0) })
        
        return gzipData
    }
    #else
    private static func decompressGzip(data: Data) throws -> Data {
        throw CompressionError.notSupported
    }
    
    private static func compressGzip(data: Data) throws -> Data {
        throw CompressionError.notSupported
    }
    #endif
}

