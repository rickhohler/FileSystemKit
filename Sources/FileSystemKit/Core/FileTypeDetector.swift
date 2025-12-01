// FileSystemKit Core Library
// File Type Detection
//
// This module provides common file type detection logic that can be reused
// across different archive and file system implementations. It detects disk
// images and other special file types using magic numbers and file extensions.

import Foundation

// MARK: - FileTypeInfo

/// Information about a detected file type
public struct FileTypeInfo: Sendable {
    /// Type identifier (e.g., "file", "disk-image")
    public let type: String
    
    /// MIME content type (e.g., "application/x-apple-diskimage")
    public let contentType: String?
    
    public init(type: String, contentType: String?) {
        self.type = type
        self.contentType = contentType
    }
}

// MARK: - FileTypeDetector

/// Detects file types using file extensions and magic numbers
public struct FileTypeDetector {
    /// Detect file type and content type for a file
    /// - Parameters:
    ///   - url: File URL
    ///   - data: File data (may be partial for detection, at least 512 bytes recommended)
    /// - Returns: FileTypeInfo with detected type and content type
    public static func detect(for url: URL, data: Data) -> FileTypeInfo {
        let fileExtension = url.pathExtension.lowercased()
        
        // Check for disk image formats using file extension and magic numbers
        
        // DMG (Mac disk image)
        if fileExtension == "dmg" {
            if data.count >= 512 {
                let trailerData = data.subdata(in: (data.count - 512)..<data.count)
                if trailerData.count >= 4 && trailerData[0..<4] == Data([0x6B, 0x6F, 0x6C, 0x79]) {
                    // "koly" UDIF signature
                    return FileTypeInfo(type: "disk-image", contentType: "application/x-apple-diskimage")
                }
            }
            // Fall back to extension-based detection if file is too small for signature
            return FileTypeInfo(type: "disk-image", contentType: "application/x-apple-diskimage")
        }
        
        // ISO 9660 (CD-ROM/DVD-ROM)
        if fileExtension == "iso" || fileExtension == "img" {
            // Check for ISO 9660 volume descriptor at sector 16 (32768 bytes)
            if data.count > 32768 {
                let vdsStart = 32768
                if data[vdsStart] == 0x01 {
                    // Primary Volume Descriptor
                    return FileTypeInfo(type: "disk-image", contentType: "application/x-iso9660-image")
                }
            }
            // Check for ISO 9660 signature "CD001" at offset 32769
            if data.count >= 32774 {
                let signature = String(data: data.subdata(in: 32769..<32774), encoding: .isoLatin1) ?? ""
                if signature == "CD001" {
                    return FileTypeInfo(type: "disk-image", contentType: "application/x-iso9660-image")
                }
            }
            // Fall back to extension-based detection if file is too small for signature
            if fileExtension == "iso" {
                return FileTypeInfo(type: "disk-image", contentType: "application/x-iso9660-image")
            }
        }
        
        // VHD (Virtual Hard Disk)
        if fileExtension == "vhd" {
            if data.count >= 512 {
                let footer = data.subdata(in: (data.count - 512)..<data.count)
                if footer.count >= 8 {
                    let signature = String(data: footer[0..<8], encoding: .ascii) ?? ""
                    if signature == "conectix" {
                        return FileTypeInfo(type: "disk-image", contentType: "application/x-vhd")
                    }
                }
            }
            // Fall back to extension-based detection if file is too small for signature
            return FileTypeInfo(type: "disk-image", contentType: "application/x-vhd")
        }
        
        // Raw disk image (IMG) - check if size suggests a disk image
        if fileExtension == "img" {
            let size = data.count
            if size > 0 && (size % 512 == 0 || size == 1440 * 1024 || size == 2880 * 1024) {
                // Could be a raw disk image
                return FileTypeInfo(type: "disk-image", contentType: "application/octet-stream")
            }
            // Fall back to extension-based detection
            return FileTypeInfo(type: "disk-image", contentType: "application/octet-stream")
        }
        
        // Default to regular file
        return FileTypeInfo(type: "file", contentType: nil)
    }
    
    /// Detect file type using only file extension (faster but less accurate)
    /// - Parameter url: File URL
    /// - Returns: FileTypeInfo with detected type based on extension
    public static func detectByExtension(_ url: URL) -> FileTypeInfo {
        let fileExtension = url.pathExtension.lowercased()
        
        // Common disk image extensions
        let diskImageExtensions: [String: String] = [
            "dmg": "application/x-apple-diskimage",
            "iso": "application/x-iso9660-image",
            "img": "application/octet-stream",
            "vhd": "application/x-vhd",
            "vmdk": "application/x-vmdk",
            "qcow": "application/x-qcow",
            "qcow2": "application/x-qcow2"
        ]
        
        if let contentType = diskImageExtensions[fileExtension] {
            return FileTypeInfo(type: "disk-image", contentType: contentType)
        }
        
        return FileTypeInfo(type: "file", contentType: nil)
    }
}

