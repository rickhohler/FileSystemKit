// FileSystemKit Core Library
// UTI Generator Utility
//
// This file provides utilities for generating UTI (Uniform Type Identifier) strings
// from disk image formats and file system formats, including version information.

import Foundation

/// Utility for generating UTI identifiers for disk images
///
/// Generates UTI identifiers following the format:
/// `com.apple.disk-image.[layer2-format].[layer3-format].[version]`
///
/// Where:
/// - **Layer 2 (Disk Image Format)**: Required - how the disk image is stored (dsk, woz, 2mg, etc.)
/// - **Layer 3 (File System Format)**: Optional - file system structure (dos33, prodos, sos, etc.)
/// - **Version**: Optional - file system version (v3.3, v2.4, v1.0, etc.)
///
/// ## Examples
///
/// ```swift
/// // DOS 3.3 disk in DSK format
/// let uti = UTIGenerator.generateUTI(
///     diskImageFormat: .raw,
///     fileSystemFormat: .appleDOS33,
///     fileSystemVersion: "3.3"
/// )
/// // Returns: "com.apple.disk-image.raw.dos33.v3.3"
///
/// // ProDOS 2.4 disk in WOZ format
/// let uti = UTIGenerator.generateUTI(
///     diskImageFormat: .woz,
///     fileSystemFormat: .proDOS,
///     fileSystemVersion: "2.4"
/// )
/// // Returns: "com.apple.disk-image.woz.prodos.v2.4"
///
/// // Unknown file system format
/// let uti = UTIGenerator.generateUTI(
///     diskImageFormat: .raw,
///     fileSystemFormat: nil,
///     fileSystemVersion: nil
/// )
/// // Returns: "com.apple.disk-image.raw"
/// ```
public enum UTIGenerator {
    /// Generate UTI identifier from disk image format and file system format
    /// - Parameters:
    ///   - diskImageFormat: Disk image format (Layer 2) - required
    ///   - fileSystemFormat: File system format (Layer 3) - optional
    ///   - fileSystemVersion: File system version (e.g., "3.3", "2.4") - optional
    /// - Returns: UTI identifier string
    ///
    /// Format: `com.apple.disk-image.[layer2].[layer3].[version]`
    ///
    /// - Layer 2 is always included (disk image format)
    /// - Layer 3 is included if file system format is known
    /// - Version is included if file system version is known and file system format is present
    public static func generateUTI(
        diskImageFormat: DiskImageFormat,
        fileSystemFormat: FileSystemFormat? = nil,
        fileSystemVersion: String? = nil
    ) -> String {
        var components = ["com", "apple", "disk-image"]
        
        // Add Layer 2 (disk image format) - required
        let layer2 = normalizeFormatName(diskImageFormat.rawValue)
        components.append(layer2)
        
        // Add Layer 3 (file system format) - optional
        if let fileSystemFormat = fileSystemFormat {
            // For DOS formats, use version to determine correct layer 3 name (dos31, dos32, dos33)
            // Otherwise, normalize the format name normally
            let layer3: String
            if fileSystemFormat == .appleDOS33, let version = fileSystemVersion {
                // Extract major.minor version (e.g., "3.3", "3.2", "3.1")
                if version.hasPrefix("3.") {
                    let minorVersion = String(version.dropFirst(2)) // Remove "3."
                    layer3 = "dos3\(minorVersion)" // e.g., "dos33", "dos32", "dos31"
                } else {
                    // Fallback: use default normalization
                    layer3 = normalizeFormatName(fileSystemFormat.rawValue)
                }
            } else {
                layer3 = normalizeFormatName(fileSystemFormat.rawValue)
            }
            components.append(layer3)
            
            // Add version - optional, only if file system format is present
            if let version = fileSystemVersion, !version.isEmpty {
                // Normalize version: ensure it starts with "v" and uses dots
                let normalizedVersion = normalizeVersion(version)
                components.append(normalizedVersion)
            }
        }
        
        return components.joined(separator: ".")
    }
    
    /// Generate UTI identifier from metadata
    /// - Parameter metadata: DiskImageMetadata containing format and version information
    /// - Returns: UTI identifier string
    public static func generateUTI(from metadata: DiskImageMetadata) -> String {
        return generateUTI(
            diskImageFormat: metadata.detectedDiskImageFormat ?? .raw,
            fileSystemFormat: metadata.detectedFileSystemFormat,
            fileSystemVersion: metadata.operatingSystemVersion?.version?.versionString
        )
    }
    
    /// Normalize format name for UTI (convert to lowercase, replace hyphens/underscores)
    /// - Parameter format: Format name (e.g., "apple-dos-3.3", "twoMG")
    /// - Returns: Normalized format name (e.g., "dos33", "2mg")
    private static func normalizeFormatName(_ format: String) -> String {
        var normalized = format.lowercased()
        
        // Handle special cases for file system formats
        if normalized.hasPrefix("apple-dos-") {
            // Extract version and convert to dos33, dos32, dos31
            if let versionMatch = normalized.range(of: #"3\.\d+"#, options: .regularExpression) {
                let version = String(normalized[versionMatch])
                normalized = "dos\(version.replacingOccurrences(of: ".", with: ""))"
            } else {
                normalized = "dos33" // Default fallback
            }
        } else if normalized == "prodos" {
            normalized = "prodos"
        } else if normalized == "ucsd-pascal" {
            normalized = "pascal"
        } else if normalized == "apple-ii-cpm" {
            normalized = "cpm"
        } else if normalized == "iso-9660" {
            normalized = "iso9660"
        } else if normalized == "2mg" || normalized == "twomg" {
            normalized = "2mg"
        } else {
            // Remove common prefixes and normalize
            normalized = normalized
                .replacingOccurrences(of: "apple-", with: "")
                .replacingOccurrences(of: "apple", with: "")
                .replacingOccurrences(of: "-", with: "")
                .replacingOccurrences(of: "_", with: "")
        }
        
        return normalized
    }
    
    /// Normalize version string for UTI (ensure it starts with "v" and uses dots)
    /// - Parameter version: Version string (e.g., "3.3", "2.4", "v1.0")
    /// - Returns: Normalized version string (e.g., "v3.3", "v2.4", "v1.0")
    private static func normalizeVersion(_ version: String) -> String {
        var normalized = version.trimmingCharacters(in: .whitespaces)
        
        // Ensure version starts with "v"
        if !normalized.hasPrefix("v") {
            normalized = "v\(normalized)"
        }
        
        // Ensure dots are used (not dashes or other separators)
        normalized = normalized.replacingOccurrences(of: "-", with: ".")
        
        return normalized
    }
}

