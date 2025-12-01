// FileSystemKit Core Library
// IgnoreMatcher
//
// Protocol for matching file paths against ignore patterns.

import Foundation

/// Protocol for matching file paths against ignore patterns
public protocol IgnoreMatcher: Sendable {
    /// Check if a path should be ignored
    /// - Parameter path: Relative path to check
    /// - Returns: true if path should be ignored, false otherwise
    func shouldIgnore(_ path: String) -> Bool
}

