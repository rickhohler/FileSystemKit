//
//  FileTypeGroup.swift
//  FileSystemKit
//
//  File type grouping system for categorizing related file types.
//  Groups related file types together (e.g., all image formats under "Image").
//
//  Key Features:
//  - Groups modern and vintage file formats together
//  - Image type includes both modern formats (png, jpg, gif) and vintage formats (pict, mac, sgi, etc.)
//  - Supports legacy binary image formats
//

import Foundation

/// File type groups for categorizing individual file types.
///
/// Groups related file types together (e.g., all image formats under "Image").
/// This allows filtering and grouping of files by logical category rather than
/// specific format.
///
/// ## Image Type Grouping
///
/// The **Image** type group includes both modern and vintage image formats:
///
/// **Modern Formats**: png, jpg, jpeg, gif, tiff, tif, bmp, heic, heif, webp
///
/// **Vintage Formats**: pict, pct, mac, sgi, rgb, rgba, bw, icon, icns
///
/// **Legacy Binary Formats**: img, ima, imz
///
/// This allows users to filter for all image-related files regardless of format era.
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public enum FileTypeGroup: String, CaseIterable, Codable, Sendable {
    case image = "image"
    case text = "text"
    case binary = "binary"
    case basic = "basic"
    case archive = "archive"
    case audio = "audio"
    case video = "video"
    case graphics = "graphics"
    case system = "system"
    case data = "data"
    case unknown = "unknown"
    
    /// Display name for the file type group
    public var displayName: String {
        switch self {
        case .image: return "Images"
        case .text: return "Text Files"
        case .binary: return "Binary Files"
        case .basic: return "BASIC Programs"
        case .archive: return "Archives"
        case .audio: return "Audio Files"
        case .video: return "Video Files"
        case .graphics: return "Graphics"
        case .system: return "System Files"
        case .data: return "Data Files"
        case .unknown: return "Unknown"
        }
    }
    
    /// Icon name for the file type group
    public var iconName: String {
        switch self {
        case .image: return "photo"
        case .text: return "doc.text"
        case .binary: return "doc.binary"
        case .basic: return "terminal"
        case .archive: return "archivebox"
        case .audio: return "music.note"
        case .video: return "video"
        case .graphics: return "paintbrush"
        case .system: return "gear"
        case .data: return "tablecells"
        case .unknown: return "questionmark"
        }
    }
    
    /// Image file extensions (modern and vintage formats)
    ///
    /// Includes both modern formats (png, jpg, gif) and vintage formats (pict, mac, sgi, etc.)
    /// as well as legacy binary image formats (img, ima, imz).
    public static var imageExtensions: Set<String> {
        [
            // Modern formats
            "png", "jpg", "jpeg", "gif", "tiff", "tif", "bmp", "heic", "heif", "webp",
            // Vintage formats
            "pict", "pct", "mac", "sgi", "rgb", "rgba", "bw", "icon", "icns",
            // Legacy binary formats
            "img", "ima", "imz"
        ]
    }
    
    /// Map FileTypeCategory to FileTypeGroup
    public static func from(fileTypeCategory: FileTypeCategory?) -> FileTypeGroup {
        guard let category = fileTypeCategory else {
            return .unknown
        }
        
        switch category {
        case .text:
            return .text
        case .basic:
            return .basic
        case .binary:
            return .binary
        case .assembly:
            return .binary // Assembly files are binary executables
        case .data:
            return .data
        case .unknown:
            return .unknown
        }
    }
    
    /// Map FileTypeCategory string (from metadata) to FileTypeGroup
    /// This handles cases where FileTypeCategory is stored as a string
    public static func from(fileTypeCategoryString: String?) -> FileTypeGroup {
        guard let categoryString = fileTypeCategoryString else {
            return .unknown
        }
        
        // Try to parse as FileTypeCategory enum first
        if let category = FileTypeCategory(rawValue: categoryString.lowercased()) {
            return from(fileTypeCategory: category)
        }
        
        // Fallback to string matching for extended categories
        switch categoryString.lowercased() {
        case "text":
            return .text
        case "basic":
            return .basic
        case "binary":
            return .binary
        case "graphics":
            return .graphics
        case "audio":
            return .audio
        case "video":
            return .video
        case "archive":
            return .archive
        case "system":
            return .system
        case "data":
            return .data
        case "document":
            return .text
        default:
            return .unknown
        }
    }
    
    /// Map file extension to FileTypeGroup
    public static func from(fileExtension: String) -> FileTypeGroup {
        let ext = fileExtension.lowercased()
        
        // Image formats (modern and vintage) - uses shared imageExtensions set
        if imageExtensions.contains(ext) {
            return .image
        }
        
        // Text formats
        let textExtensions = ["txt", "text", "md", "markdown", "rtf", "doc", "docx"]
        if textExtensions.contains(ext) {
            return .text
        }
        
        // BASIC programs
        let basicExtensions = ["bas"]
        if basicExtensions.contains(ext) {
            return .basic
        }
        
        // Binary executables
        let binaryExtensions = ["bin", "exe", "com", "app", "dmg"]
        if binaryExtensions.contains(ext) {
            return .binary
        }
        
        // Archive formats
        let archiveExtensions = ["zip", "tar", "gz", "bz2", "xz", "7z", "rar", "sit", "sitx"]
        if archiveExtensions.contains(ext) {
            return .archive
        }
        
        // Audio formats
        let audioExtensions = ["mp3", "wav", "aiff", "aif", "m4a", "flac", "ogg", "au", "snd"]
        if audioExtensions.contains(ext) {
            return .audio
        }
        
        // Video formats
        let videoExtensions = ["mp4", "mov", "avi", "mkv", "wmv", "flv", "m4v"]
        if videoExtensions.contains(ext) {
            return .video
        }
        
        // Graphics formats (vintage) - note: some overlap with imageExtensions
        let graphicsExtensions = ["pict", "pct", "mac", "sgi", "rgb", "rgba", "bw"]
        if graphicsExtensions.contains(ext) {
            return .graphics
        }
        
        return .unknown
    }
}

/// Extension to FileSystemEntryMetadata for file type group determination
extension FileSystemEntryMetadata {
    /// Determine the file type group for this file entry
    public var fileTypeGroup: FileTypeGroup {
        // Use file type category if available
        if let fileType = fileType {
            return FileTypeGroup.from(fileTypeCategory: fileType)
        }
        
        // Fallback to file extension from name
        let ext = (name as NSString).pathExtension.lowercased()
        if !ext.isEmpty {
            return FileTypeGroup.from(fileExtension: ext)
        }
        
        return .unknown
    }
}

