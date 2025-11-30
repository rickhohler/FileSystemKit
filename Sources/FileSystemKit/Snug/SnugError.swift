// FileSystemKit - Snug Archive Errors

import Foundation

/// Errors that can occur when working with Snug archives
public enum SnugError: Error, CustomStringConvertible, LocalizedError {
    case directoryNotFound(String) // path
    case notADirectory(String) // path
    case archiveNotFound(String) // path
    case invalidArchive(String) // reason
    case storageError(String, Error?) // reason, underlying error
    case hashNotFound(String) // hash
    case extractionFailed(String, Error?) // reason, underlying error
    case unsupportedHashAlgorithm(String) // algorithm
    case compressionFailed(String, Error?) // reason, underlying error
    case brokenSymlink(String, target: String) // path, target
    case symlinkCycle(String) // path
    case permissionDenied(String) // path
    case embeddedFileNotFound(String) // hash
    
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
        case .storageError(let reason, let underlyingError):
            if let underlying = underlyingError {
                return "Storage error: \(reason) (\(underlying.localizedDescription))"
            }
            return "Storage error: \(reason)"
        case .hashNotFound(let hash):
            return "Hash not found in storage: \(hash)"
        case .extractionFailed(let reason, let underlyingError):
            if let underlying = underlyingError {
                return "Extraction failed: \(reason) (\(underlying.localizedDescription))"
            }
            return "Extraction failed: \(reason)"
        case .unsupportedHashAlgorithm(let algorithm):
            return "Unsupported hash algorithm: \(algorithm). Supported algorithms: sha256, sha1, md5"
        case .compressionFailed(let reason, let underlyingError):
            if let underlying = underlyingError {
                return "Compression failed: \(reason) (\(underlying.localizedDescription))"
            }
            return "Compression failed: \(reason)"
        case .brokenSymlink(let _, let target):
            return "Broken symlink: \(path) -> \(target)"
        case .symlinkCycle(let path):
            return "Symlink cycle detected: \(path)"
        case .permissionDenied(let path):
            return "Permission denied: \(path)"
        case .embeddedFileNotFound(let hash):
            return "Embedded file not found in archive: \(hash)"
        }
    }
    
    public var errorDescription: String? {
        return description
    }
    
    /// Recovery suggestion for the error
    public var recoverySuggestion: String? {
        switch self {
        case .directoryNotFound(let path):
            return "Verify the directory path '\(path)' exists and is accessible."
        case .archiveNotFound(let path):
            return "Verify the archive file '\(path)' exists. Check the file path and permissions."
        case .invalidArchive:
            return "The archive file may be corrupted. Try recreating the archive or verify the file integrity."
        case .storageError:
            return "Check storage configuration and ensure storage locations are accessible. Run 'snug storage verify' to check storage integrity."
        case .hashNotFound(let hash):
            return "The requested hash '\(hash)' is not in storage. Run 'snug storage clean' to check for orphaned files, or verify the archive was created correctly."
        case .extractionFailed:
            return "Verify you have write permissions for the extraction destination. Check disk space and ensure the destination directory exists."
        case .unsupportedHashAlgorithm:
            return "Use a supported hash algorithm: sha256 (recommended), sha1, or md5."
        case .compressionFailed:
            return "Check available disk space and verify the source file is not corrupted. Try decompressing manually to verify the file."
        case .brokenSymlink(let _, let target):
            return "The symlink target '\(target)' does not exist. Verify the target path or recreate the symlink."
        case .symlinkCycle(let path):
            return "A circular symlink reference was detected at '\(path)'. Remove the circular reference."
        case .permissionDenied(let path):
            return "Run with appropriate permissions or change file permissions for '\(path)'."
        case .embeddedFileNotFound(let hash):
            return "The embedded file with hash '\(hash)' is missing from the archive. The archive may be incomplete or corrupted."
        default:
            return nil
        }
    }
}

