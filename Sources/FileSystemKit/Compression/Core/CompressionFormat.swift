// FileSystemKit Core Library
// Compression Format Enumeration

import Foundation

/// Compression format enumeration
public enum CompressionFormat: String, Codable, CaseIterable {
    case gzip = "gzip"
    case zip = "zip"
    case toast = "toast"
    case stuffit = "stuffit"
    case tar = "tar"
    case arc = "arc"
    case shrinkit = "shrinkit"
    case archiveorg = "archiveorg"
    case snug = "snug"
    case unknown = "unknown"
    
    /// File extensions for this format
    public var extensions: [String] {
        switch self {
        case .gzip: return [".gz", ".gzip"]
        case .zip: return [".zip"]
        case .toast: return [".toast"]
        case .stuffit: return [".sit", ".sitx"]
        case .tar: return [".tar"]
        case .arc: return [".arc", ".ark"]
        case .shrinkit: return [".shk", ".sdk"]
        case .archiveorg: return [".archiveorg"]
        case .snug: return [".snug"]
        case .unknown: return []
        }
    }
    
    /// Display name (localized)
    public var displayName: String {
        // Return rawValue as display name for now to avoid potential Bundle.module issues
        // TODO: Re-enable localization once Bundle.module is properly configured
        return rawValue.uppercased()
    }
    
    /// Detect format from file extension
    /// - Parameter fileExtension: File extension (with or without dot)
    /// - Returns: Detected compression format, or nil if unknown
    public static func detect(from fileExtension: String) -> CompressionFormat? {
        let ext = fileExtension.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
        
        for format in CompressionFormat.allCases {
            if format.extensions.contains(where: { $0.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ".")) == ext }) {
                return format
            }
        }
        
        return nil
    }
}

