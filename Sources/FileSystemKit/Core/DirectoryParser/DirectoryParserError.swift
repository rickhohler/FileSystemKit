// FileSystemKit Core Library
// DirectoryParserError
//
// Errors that can occur during directory parsing.

import Foundation

/// Errors that can occur during directory parsing
public enum DirectoryParserError: Error, Sendable {
    case failedToEnumerate(URL)
    case brokenSymlink(String, target: String)
    case permissionDenied(URL)
    
    public var localizedDescription: String {
        switch self {
        case .failedToEnumerate(let url):
            return "Failed to enumerate directory: \(url.path)"
        case .brokenSymlink(let path, let target):
            return "Broken symlink: \(path) -> \(target)"
        case .permissionDenied(let url):
            return "Permission denied: \(url.path)"
        }
    }
}

