// FileSystemKit Core Library
// Error Types
//
// This file defines error types used throughout FileSystemKit

import Foundation

/// Errors that can occur in file system operations
public enum FileSystemError: Error, LocalizedError {
    case diskDataNotAvailable
    case invalidOffset(offset: Int? = nil, maxOffset: Int? = nil)
    case hashNotImplemented(algorithm: String? = nil)
    case fileNotFound(path: String? = nil)
    case invalidFileSystem(reason: String? = nil)
    case unsupportedFileSystemFormat(format: String? = nil)
    case storageUnavailable(reason: String? = nil)
    case readFailed(path: String? = nil, underlyingError: Error? = nil)
    case writeFailed(path: String? = nil, underlyingError: Error? = nil)
    case permissionDenied(path: String? = nil)
    
    public var errorDescription: String? {
        switch self {
        case .diskDataNotAvailable:
            return "Disk data not available"
        case .invalidOffset(let offset, let maxOffset):
            if let offset = offset, let maxOffset = maxOffset {
                return "Invalid offset: \(offset) (maximum: \(maxOffset))"
            } else if let offset = offset {
                return "Invalid offset: \(offset)"
            }
            return "Invalid offset"
        case .hashNotImplemented(let algorithm):
            if let algorithm = algorithm {
                return "Hash algorithm not implemented: \(algorithm). Supported algorithms: sha256, sha1, md5, crc32"
            }
            return "Hash algorithm not implemented. Supported algorithms: sha256, sha1, md5, crc32"
        case .fileNotFound(let path):
            if let path = path {
                return "File not found: \(path)"
            }
            return "File not found"
        case .unsupportedFileSystemFormat(let format):
            if let format = format {
                return "Unsupported file system format: \(format)"
            }
            return "Unsupported file system format"
        case .invalidFileSystem(let reason):
            if let reason = reason {
                return "Invalid file system: \(reason)"
            }
            return "Invalid file system"
        case .storageUnavailable(let reason):
            if let reason = reason {
                return "Storage unavailable: \(reason)"
            }
            return "Storage unavailable"
        case .readFailed(let path, let underlyingError):
            let pathStr = path ?? "unknown path"
            if let underlying = underlyingError {
                return "Read operation failed for '\(pathStr)': \(underlying.localizedDescription)"
            }
            return "Read operation failed for '\(pathStr)'"
        case .writeFailed(let path, let underlyingError):
            let pathStr = path ?? "unknown path"
            if let underlying = underlyingError {
                return "Write operation failed for '\(pathStr)': \(underlying.localizedDescription)"
            }
            return "Write operation failed for '\(pathStr)'"
        case .permissionDenied(let path):
            if let path = path {
                return "Permission denied: \(path). Check file permissions and try again."
            }
            return "Permission denied. Check file permissions and try again."
        }
    }
    
    /// Recovery suggestion for the error
    public var recoverySuggestion: String? {
        switch self {
        case .fileNotFound:
            return "Verify the file path is correct. If this is a Snug archive file, run 'snug storage clean' to check for orphaned files."
        case .storageUnavailable:
            return "Check storage configuration and ensure the storage location is accessible. Verify disk space and permissions."
        case .readFailed:
            return "Verify the file exists and is readable. Check file permissions and disk space."
        case .writeFailed(let path, _):
            let pathStr = path ?? "the file"
            return "Verify you have write permissions for '\(pathStr)'. Check disk space and ensure the directory exists."
        case .permissionDenied(let path):
            let pathStr = path ?? "the file"
            return "Run with appropriate permissions or change file permissions for '\(pathStr)'."
        case .hashNotImplemented:
            return "Use a supported hash algorithm: sha256 (recommended), sha1, md5, or crc32."
        case .unsupportedFileSystemFormat:
            return "Check if the file system format is supported. Consider converting to a supported format."
        default:
            return nil
        }
    }
}

