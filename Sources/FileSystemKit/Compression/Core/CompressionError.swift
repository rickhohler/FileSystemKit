// FileSystemKit Core Library
// Compression Error Types

import Foundation

/// Errors that can occur in compression operations
public enum CompressionError: Error, LocalizedError {
    case decompressionFailed
    case compressionFailed
    case notSupported
    case notImplemented
    case invalidFormat
    case nestedCompressionNotSupported
    case unsupportedPlatform
    
    public var errorDescription: String? {
        switch self {
        case .decompressionFailed:
            return "Decompression failed"
        case .compressionFailed:
            return "Compression failed"
        case .notSupported:
            return "Compression format not supported"
        case .notImplemented:
            return "Compression format not yet implemented"
        case .invalidFormat:
            return "Invalid compression format"
        case .nestedCompressionNotSupported:
            return "Nested compression not supported"
        case .unsupportedPlatform:
            return "Compression format not supported on this platform"
        }
    }
}

