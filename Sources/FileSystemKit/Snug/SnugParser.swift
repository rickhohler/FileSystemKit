// FileSystemKit - SNUG Archive Parser
// Parses .snug archives (decompresses and decodes YAML)

import Foundation
import Yams
#if canImport(Compression)
import Compression
#endif

/// Parses SNUG archives from compressed YAML files
/// Internal implementation - clients should use FileSystemKitArchiveFacade.parseArchive instead
internal class SnugParser {
    internal init() {}
    
    internal func parseArchive(from archiveURL: URL) throws -> SnugArchive {
        // 1. Read compressed data
        let compressedData = try Data(contentsOf: archiveURL)
        
        // 2. Decompress
        let decompressedData = try decompressGzip(data: compressedData)
        
        // 3. Parse YAML
        let decoder = YAMLDecoder()
        let archive = try decoder.decode(SnugArchive.self, from: decompressedData)
        
        return archive
    }
    
    private func decompressGzip(data: Data) throws -> Data {
        #if canImport(Compression)
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
            throw SnugError.invalidArchive("Decompression failed")
        }
        
        return Data(bytes: destinationBuffer, count: decompressedSize)
        #else
        throw SnugError.invalidArchive("Compression not available on this platform")
        #endif
    }
}

