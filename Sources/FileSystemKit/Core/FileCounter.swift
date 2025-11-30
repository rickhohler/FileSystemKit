// FileSystemKit Core Library
// File Counter
//
// This module provides utilities for counting files in directory trees,
// which is useful for progress reporting and planning operations.

import Foundation

// MARK: - FileCounter

/// Utility for counting files in directory trees
public struct FileCounter {
    /// Count regular files in a directory tree
    /// - Parameters:
    ///   - url: Root directory URL
    ///   - ignoreMatcher: Optional ignore pattern matcher
    ///   - skipHiddenFiles: Whether to skip hidden files (default: true)
    /// - Returns: Number of regular files found
    /// - Throws: Errors encountered during enumeration
    public static func countFiles(
        in url: URL,
        ignoreMatcher: IgnoreMatcher? = nil,
        skipHiddenFiles: Bool = true
    ) throws -> Int {
        var count = 0
        let resourceKeys: [URLResourceKey] = [.isDirectoryKey, .isRegularFileKey]
        
        var enumeratorOptions: FileManager.DirectoryEnumerationOptions = []
        if skipHiddenFiles {
            enumeratorOptions.insert(.skipsHiddenFiles)
        }
        
        let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: resourceKeys,
            options: enumeratorOptions,
            errorHandler: { _, _ in true }
        )
        
        guard let enumerator = enumerator else {
            return 0
        }
        
        for case let fileURL as URL in enumerator {
            let relativePath = PathUtilities.relativePath(from: fileURL, baseURL: url, basePath: "")
            
            if let matcher = ignoreMatcher, matcher.shouldIgnore(relativePath) {
                continue // Skip ignored files
            }
            
            let resourceValues = try? fileURL.resourceValues(forKeys: Set(resourceKeys))
            if resourceValues?.isRegularFile == true {
                count += 1
            }
        }
        
        return count
    }
}

