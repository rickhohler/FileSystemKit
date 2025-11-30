// FileSystemKit Core Library
// Path Utilities
//
// This module provides common path manipulation utilities that can be
// reused across different archive and file system implementations.

import Foundation

// MARK: - PathUtilities

/// Utilities for path manipulation and normalization
public struct PathUtilities {
    /// Normalize a path to use forward slashes and remove redundant separators
    /// - Parameter path: Path to normalize
    /// - Returns: Normalized path (preserves leading slash for absolute paths)
    public static func normalize(_ path: String) -> String {
        let hasLeadingSlash = path.hasPrefix("/")
        var normalized = path
            .replacingOccurrences(of: "\\", with: "/")
            .replacingOccurrences(of: "//", with: "/")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if hasLeadingSlash && !normalized.isEmpty {
            normalized = "/" + normalized
        }
        return normalized
    }
    
    /// Get relative path from a base URL
    /// - Parameters:
    ///   - url: File URL
    ///   - baseURL: Base directory URL
    ///   - basePath: Optional base path prefix
    /// - Returns: Relative path string
    public static func relativePath(from url: URL, baseURL: URL, basePath: String = "") -> String {
        // Resolve symlinks to handle macOS /var -> /private/var symlink
        let resolvedBaseURL = baseURL.resolvingSymlinksInPath()
        let resolvedURL = url.resolvingSymlinksInPath()
        
        let relativePath = resolvedURL.path.replacingOccurrences(of: resolvedBaseURL.path, with: basePath)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return normalize(relativePath)
    }
    
    /// Check if a path represents a system file
    /// - Parameter path: Path to check
    /// - Returns: True if the path represents a system file
    public static func isSystemFile(_ path: String) -> Bool {
        let systemPaths = [
            "System Volume Information",
            "$RECYCLE.BIN",
            "System32",
            "Windows",
            ".Trash",
            ".DS_Store",
            ".Spotlight-V100",
            ".fseventsd",
            ".TemporaryItems"
        ]
        return systemPaths.contains { path.contains($0) }
    }
    
    /// Check if a path is hidden (starts with dot on Unix-like systems)
    /// - Parameter path: Path to check
    /// - Returns: True if the path appears to be hidden
    public static func isHidden(_ path: String) -> Bool {
        let components = path.split(separator: "/")
        return components.contains { $0.hasPrefix(".") && $0 != "." && $0 != ".." }
    }
}

