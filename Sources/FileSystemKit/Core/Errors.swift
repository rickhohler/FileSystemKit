// FileSystemKit Core Library
// Error Types
//
// This file defines error types used throughout FileSystemKit

import Foundation

/// Errors that can occur in file system operations
public enum FileSystemError: Error, LocalizedError {
    case diskDataNotAvailable
    case invalidOffset
    case hashNotImplemented
    case fileNotFound
    case invalidFileSystem
    case unsupportedFileSystemFormat
    case storageUnavailable
    case readFailed
    case writeFailed
    case permissionDenied
    
    public var errorDescription: String? {
        switch self {
        case .diskDataNotAvailable:
            return "Disk data not available"
        case .invalidOffset:
            return "Invalid offset"
        case .hashNotImplemented:
            return "Hash algorithm not implemented"
        case .fileNotFound:
            return "File not found"
        case .unsupportedFileSystemFormat:
            return "Unsupported file system format"
        case .invalidFileSystem:
            return "Invalid file system"
        case .storageUnavailable:
            return "Storage unavailable"
        case .readFailed:
            return "Read operation failed"
        case .writeFailed:
            return "Write operation failed"
        case .permissionDenied:
            return "Permission denied"
        }
    }
}

