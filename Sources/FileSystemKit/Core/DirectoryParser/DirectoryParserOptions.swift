// FileSystemKit Core Library
// DirectoryParserOptions
//
// Configuration options for directory parsing.

import Foundation

/// Configuration options for directory parsing
public struct DirectoryParserOptions: Sendable {
    /// Base path prefix for relative paths (default: "")
    public var basePath: String
    
    /// Follow symlinks instead of preserving them (default: false)
    public var followSymlinks: Bool
    
    /// Throw error on broken symlinks (default: false)
    public var errorOnBrokenSymlinks: Bool
    
    /// Include special files (block devices, character devices, sockets, FIFOs) (default: false)
    public var includeSpecialFiles: Bool
    
    /// Skip files that cause permission errors (default: false)
    public var skipPermissionErrors: Bool
    
    /// Skip hidden files (default: true)
    public var skipHiddenFiles: Bool
    
    /// Verbose logging (default: false)
    public var verbose: Bool
    
    public init(
        basePath: String = "",
        followSymlinks: Bool = false,
        errorOnBrokenSymlinks: Bool = false,
        includeSpecialFiles: Bool = false,
        skipPermissionErrors: Bool = false,
        skipHiddenFiles: Bool = true,
        verbose: Bool = false
    ) {
        self.basePath = basePath
        self.followSymlinks = followSymlinks
        self.errorOnBrokenSymlinks = errorOnBrokenSymlinks
        self.includeSpecialFiles = includeSpecialFiles
        self.skipPermissionErrors = skipPermissionErrors
        self.skipHiddenFiles = skipHiddenFiles
        self.verbose = verbose
    }
}

