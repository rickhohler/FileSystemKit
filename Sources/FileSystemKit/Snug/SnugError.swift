// FileSystemKit - SNUG Archive Errors

import Foundation

/// Errors that can occur when working with SNUG archives
public enum SnugError: Error, CustomStringConvertible {
    case directoryNotFound(String)
    case notADirectory(String)
    case archiveNotFound(String)
    case invalidArchive(String)
    case storageError(String)
    case hashNotFound(String)
    case extractionFailed(String)
    case unsupportedHashAlgorithm(String)
    case compressionFailed(String)
    case brokenSymlink(String, target: String)
    case symlinkCycle(String)
    case permissionDenied(String)
    case embeddedFileNotFound(String)
    
    public var description: String {
        switch self {
        case .directoryNotFound(let path):
            return "Directory not found: \(path)"
        case .notADirectory(let path):
            return "Not a directory: \(path)"
        case .archiveNotFound(let path):
            return "Archive not found: \(path)"
        case .invalidArchive(let reason):
            return "Invalid archive: \(reason)"
        case .storageError(let reason):
            return "Storage error: \(reason)"
        case .hashNotFound(let hash):
            return "Hash not found in storage: \(hash)"
        case .extractionFailed(let reason):
            return "Extraction failed: \(reason)"
        case .unsupportedHashAlgorithm(let algorithm):
            return "Unsupported hash algorithm: \(algorithm)"
        case .compressionFailed(let reason):
            return "Compression failed: \(reason)"
        case .brokenSymlink(let path, let target):
            return "Broken symlink: \(path) -> \(target)"
        case .symlinkCycle(let path):
            return "Symlink cycle detected: \(path)"
        case .permissionDenied(let path):
            return "Permission denied: \(path)"
        case .embeddedFileNotFound(let hash):
            return "Embedded file not found in archive: \(hash)"
        }
    }
}

