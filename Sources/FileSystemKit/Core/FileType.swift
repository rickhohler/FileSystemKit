// FileSystemKit Core Library
// File Type System
//
// This file implements basic file type categorization for FileSystemKit

import Foundation

// MARK: - FileTypeCategory

/// File type category (simplified classification)
/// Used for basic classification in FileMetadata
public enum FileTypeCategory: String, Codable {
    case text
    case binary
    case basic
    case assembly
    case data
    case unknown
    
    /// Create FileTypeCategory from string (for unknown types)
    public static func unknown(_ value: String) -> FileTypeCategory {
        return .unknown
    }
}

