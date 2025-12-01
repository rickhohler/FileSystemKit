// FileSystemKit - SNUG Archive Creation
// Compression Utilities

import Foundation
#if canImport(Compression)
import Compression
#endif

/// Compression utilities for SnugArchiver
internal struct SnugCompressionHelpers {
    /// Compress data using GZIP compression
    static func compressGzip(data: Data) throws -> Data {
        #if canImport(Compression)
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
            throw SnugError.compressionFailed("Compression returned zero size", nil)
        }
        
        return Data(bytes: destinationBuffer, count: compressedSize)
        #else
        throw SnugError.compressionFailed("Compression not available on this platform", nil)
        #endif
    }
}

