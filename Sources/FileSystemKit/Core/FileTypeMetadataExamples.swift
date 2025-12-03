// FileSystemKit Core Library
// File Type Metadata Examples
//
// This file provides example implementations of FileTypeMetadata protocol
// demonstrating how to use the protocol for various file types.

import Foundation

// MARK: - Example: Apple II ProDOS Disk Image

/// Example implementation: Apple II Disk Image Prodos Order
///
/// This demonstrates how to implement FileTypeMetadata for a vintage disk image format.
/// The format uses:
/// - UTI-style identifier: "com.apple.disk-image.prodos-order"
/// - Short ID: "apo"
/// - Display name: "Apple II Disk Image Prodos Order"
/// - Magic number detection for ProDOS format
public struct AppleIIProDOSDiskImageMetadata: FileTypeMetadata {
    public var typeIdentifier: String {
        "com.apple.disk-image.prodos-order"
    }
    
    public var shortID: String {
        "apo"
    }
    
    public var displayName: String {
        "Apple II Disk Image Prodos Order"
    }
    
    public var version: FileTypeVersion? {
        FileTypeVersion(major: 1, minor: 0)
    }
    
    public var mimeType: String? {
        "application/x-apple-diskimage-prodos"
    }
    
    public var extensions: [String] {
        ["po", "prodos"]
    }
    
    public var magicNumbers: [FileTypeMagicNumber] {
        [
            // ProDOS volume directory header signature
            FileTypeMagicNumber(
                offset: 0x00,
                bytes: [0x01, 0x00], // Volume directory block
                mask: nil
            ),
            // Alternative: Check for ProDOS signature at sector 0
            FileTypeMagicNumber(
                offset: 0x00,
                bytes: [0x50, 0x52, 0x4F, 0x44], // "PROD" (ProDOS signature)
                mask: nil
            )
        ]
    }
    
    public var category: FileTypeMetadataCategory {
        .diskImage
    }
    
    public var vendor: String? {
        "Apple Computer"
    }
    
    public var inceptionDate: Date? {
        // ProDOS was introduced in 1983
        var components = DateComponents()
        components.year = 1983
        components.month = 1
        components.day = 1
        return Calendar.current.date(from: components)
    }
    
    public var references: [URL] {
        [
            URL(string: "https://en.wikipedia.org/wiki/ProDOS")!,
            URL(string: "https://www.apple2.org.za/gswv/a2zine/GS.WorldView/Resources/TECH.DOCS/ProDOS.TRM/ProDOS.TRM.html")!
        ]
    }
    
    public var additionalMetadata: [String: String] {
        [
            "specification": "ProDOS Technical Reference Manual",
            "platform": "Apple II",
            "fileSystem": "ProDOS"
        ]
    }
}

// MARK: - Example: Generic Disk Image Metadata

/// Example implementation: Generic disk image metadata
///
/// Shows how to create metadata for a generic disk image format.
public struct GenericDiskImageMetadata: FileTypeMetadata {
    private let identifier: String
    private let name: String
    private let shortIDValue: String
    private let extensionsValue: [String]
    private let magicBytes: [UInt8]
    
    public init(
        identifier: String,
        name: String,
        shortID: String,
        extensions: [String],
        magicBytes: [UInt8]
    ) {
        self.identifier = identifier
        self.name = name
        self.shortIDValue = shortID
        self.extensionsValue = extensions
        self.magicBytes = magicBytes
    }
    
    public var typeIdentifier: String {
        identifier
    }
    
    public var shortID: String {
        shortIDValue
    }
    
    public var displayName: String {
        name
    }
    
    public var version: FileTypeVersion? {
        nil // Generic format, no version
    }
    
    public var mimeType: String? {
        "application/x-disk-image"
    }
    
    public var extensions: [String] {
        extensionsValue
    }
    
    public var magicNumbers: [FileTypeMagicNumber] {
        [
            FileTypeMagicNumber(offset: 0, bytes: magicBytes)
        ]
    }
    
    public var category: FileTypeMetadataCategory {
        .diskImage
    }
    
    public var vendor: String? {
        return nil // Generic format, no specific vendor
    }
    
    public var inceptionDate: Date? {
        return nil // Generic format, no specific date
    }
    
    public var references: [URL] {
        return [] // No specific references for generic format
    }
}

// MARK: - Example: Archive Format Metadata

/// Example implementation: Archive format metadata
///
/// Shows how to create metadata for archive/compression formats.
public struct ArchiveFormatMetadata: FileTypeMetadata {
    private let identifier: String
    private let name: String
    private let shortIDValue: String
    private let extensionsValue: [String]
    private let magicBytes: [UInt8]
    
    public init(
        identifier: String,
        name: String,
        shortID: String,
        extensions: [String],
        magicBytes: [UInt8]
    ) {
        self.identifier = identifier
        self.name = name
        self.shortIDValue = shortID
        self.extensionsValue = extensions
        self.magicBytes = magicBytes
    }
    
    public var typeIdentifier: String {
        identifier
    }
    
    public var shortID: String {
        shortIDValue
    }
    
    public var displayName: String {
        name
    }
    
    public var version: FileTypeVersion? {
        nil
    }
    
    public var mimeType: String? {
        "application/x-archive"
    }
    
    public var extensions: [String] {
        extensionsValue
    }
    
    public var magicNumbers: [FileTypeMagicNumber] {
        [
            FileTypeMagicNumber(offset: 0, bytes: magicBytes)
        ]
    }
    
    public var category: FileTypeMetadataCategory {
        .archive
    }
    
    public var vendor: String? {
        return nil // Generic archive format, no specific vendor
    }
    
    public var inceptionDate: Date? {
        return nil // Generic archive format, no specific date
    }
    
    public var references: [URL] {
        return [] // No specific references for generic format
    }
}

// MARK: - Example Usage

/// Example usage of FileTypeMetadata
public enum FileTypeMetadataExamples {
    /// Register example metadata types
    public static func registerExamples() async {
        let registry = FileTypeMetadataRegistry.shared
        
        // Register Apple II ProDOS disk image
        await registry.register(AppleIIProDOSDiskImageMetadata())
        
        // Register generic disk image
        let genericDiskImage = GenericDiskImageMetadata(
            identifier: "com.example.disk-image.raw",
            name: "Raw Disk Image",
            shortID: "raw",
            extensions: ["img", "raw"],
            magicBytes: []
        )
        await registry.register(genericDiskImage)
        
        // Register archive format
        let zipArchive = ArchiveFormatMetadata(
            identifier: "com.pkware.zip",
            name: "ZIP Archive",
            shortID: "zip",
            extensions: ["zip"],
            magicBytes: [0x50, 0x4B, 0x03, 0x04] // "PK" signature
        )
        await registry.register(zipArchive)
    }
    
    /// Example: Detect file type from data
    public static func detectFileType(from data: Data) async -> (any FileTypeMetadata)? {
        let registry = FileTypeMetadataRegistry.shared
        return await registry.detect(from: data)
    }
    
    /// Example: Detect file type from extension and data (handles ambiguous extensions)
    /// 
    /// This demonstrates how to handle cases where multiple formats share the same extension.
    /// The registry will use magic numbers to disambiguate between formats.
    public static func detectFileType(extension: String, data: Data) async -> (any FileTypeMetadata)? {
        let registry = FileTypeMetadataRegistry.shared
        return await registry.detect(extension: `extension`, data: data)
    }
    
    /// Example: Detect file type from URL and data
    public static func detectFileType(url: URL, data: Data) async -> (any FileTypeMetadata)? {
        let registry = FileTypeMetadataRegistry.shared
        return await registry.detect(url: url, data: data)
    }
    
    /// Example: Find metadata by short ID
    public static func findMetadata(byShortID shortID: String) async -> (any FileTypeMetadata)? {
        let registry = FileTypeMetadataRegistry.shared
        return await registry.find(byShortID: shortID)
    }
    
    /// Example: Find all metadata sharing the same extension
    /// 
    /// This demonstrates how to get all formats that use a particular extension.
    public static func findAllMetadata(byExtension extension: String) async -> [any FileTypeMetadata] {
        let registry = FileTypeMetadataRegistry.shared
        return await registry.find(byExtension: `extension`)
    }
}

