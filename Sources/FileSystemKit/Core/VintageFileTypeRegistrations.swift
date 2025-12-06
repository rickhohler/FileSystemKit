//
//  VintageFileTypeRegistrations.swift
//  FileSystemKit
//
//  File type metadata registrations for vintage disk images and file formats
//  Registers disk images, archives, and common vintage file types
//

import Foundation

// MARK: - Apple II Disk Images

/// DOS 3.3 Disk Image (.dsk, .do)
public struct DOS33DiskImageFileType: FileTypeMetadata {
    public var typeIdentifier: String {
        "com.apple.disk-image.dsk.dos33.v3.3"
    }
    
    public var shortID: String {
        "dos33dsk"
    }
    
    public var displayName: String {
        "Apple II DOS 3.3 Disk Image"
    }
    
    public var version: FileTypeVersion? {
        FileTypeVersion(major: 3, minor: 3)
    }
    
    public var mimeType: String? {
        "application/x-apple-diskimage-dos33"
    }
    
    public var extensions: [String] {
        ["dsk", "do"]
    }
    
    public var magicNumbers: [FileTypeMagicNumber] {
        // DOS 3.3 VTOC track 17 sector 0
        []  // No universal magic, detected by structure
    }
    
    public var category: FileTypeMetadataCategory {
        .diskImage
    }
    
    public var vendor: String? {
        "Apple Computer"
    }
    
    public var additionalMetadata: [String: String] {
        [
            "containerFormat": "dsk",
            "fileSystemFormat": "dos33",
            "fileSystemVersion": "3.3",
            "platform": "apple2",
            "sectorOrder": "dos",
            "tracks": "35",
            "sectorsPerTrack": "16"
        ]
    }
    
    public var iconName: String? {
        "opticaldisc"
    }
}

/// ProDOS Disk Image (.po, .prodos)
public struct ProDOSDiskImageFileType: FileTypeMetadata {
    public var typeIdentifier: String {
        "com.apple.disk-image.dsk.prodos"
    }
    
    public var shortID: String {
        "prodosdsk"
    }
    
    public var displayName: String {
        "Apple II ProDOS Disk Image"
    }
    
    public var version: FileTypeVersion? {
        nil  // ProDOS had many versions
    }
    
    public var mimeType: String? {
        "application/x-apple-diskimage-prodos"
    }
    
    public var extensions: [String] {
        ["po", "prodos"]
    }
    
    public var magicNumbers: [FileTypeMagicNumber] {
        // ProDOS volume directory header
        []  // Complex detection needed
    }
    
    public var category: FileTypeMetadataCategory {
        .diskImage
    }
    
    public var vendor: String? {
        "Apple Computer"
    }
    
    public var additionalMetadata: [String: String] {
        [
            "containerFormat": "dsk",
            "fileSystemFormat": "prodos",
            "platform": "apple2",
            "sectorOrder": "prodos", 
            "tracks": "35",
            "sectorsPerTrack": "16"
        ]
    }
    
    public var iconName: String? {
        "opticaldisc"
    }
}

/// WOZ Disk Image (v1/v2)
public struct WOZDiskImageFileType: FileTypeMetadata {
    public var typeIdentifier: String {
        "com.apple.disk-image.woz"
    }
    
    public var shortID: String {
        "woz"
    }
    
    public var displayName: String {
        "WOZ Disk Image"
    }
    
    public var version: FileTypeVersion? {
        FileTypeVersion(major: 2, minor: 0)
    }
    
    public var mimeType: String? {
        "application/x-woz-disk-image"
    }
    
    public var extensions: [String] {
        ["woz"]
    }
    
    public var magicNumbers: [FileTypeMagicNumber] {
        [
            // WOZ1 or WOZ2 signature
            FileTypeMagicNumber(offset: 0, bytes: [0x57, 0x4F, 0x5A, 0x31]),  // "WOZ1"
            FileTypeMagicNumber(offset: 0, bytes: [0x57, 0x4F, 0x5A, 0x32])   // "WOZ2"
        ]
    }
    
    public var category: FileTypeMetadataCategory {
        .diskImage
    }
    
    public var vendor: String? {
        "John Morris (Applesauce)"
    }
    
    public var additionalMetadata: [String: String] {
        [
            "containerFormat": "woz",
            "platform": "apple2",
            "preservesCopyProtection": "true",
            "bitAccurate": "true"
        ]
    }
    
    public var iconName: String? {
        "opticaldisc"
    }
}

/// NIB Disk Image (nibble format)
public struct NIBDiskImageFileType: FileTypeMetadata {
    public var typeIdentifier: String {
        "com.apple.disk-image.nib"
    }
    
    public var shortID: String {
        "nib"
    }
    
    public var displayName: String {
        "Apple II NIB Disk Image"
    }
    
    public var version: FileTypeVersion? {
        nil
    }
    
    public var mimeType: String? {
        "application/x-nib-disk-image"
    }
    
    public var extensions: [String] {
        ["nib"]
    }
    
    public var magicNumbers: [FileTypeMagicNumber] {
        []  // No magic number, raw nibble data
    }
    
    public var category: FileTypeMetadataCategory {
        .diskImage
    }
    
    public var vendor: String? {
        "Apple Computer"
    }
    
    public var additionalMetadata: [String: String] {
        [
            "containerFormat": "nib",
            "platform": "apple2",
            "encoding": "nibble"
        ]
    }
}

// MARK: - Commodore Disk Images

/// Commodore 64 D64 Disk Image
public struct D64DiskImageFileType: FileTypeMetadata {
    public var typeIdentifier: String {
        "com.commodore.disk-image.d64"
    }
    
    public var shortID: String {
        "d64"
    }
    
    public var displayName: String {
        "Commodore 64 D64 Disk Image"
    }
    
    public var version: FileTypeVersion? {
        nil
    }
    
    public var mimeType: String? {
        "application/x-d64-disk-image"
    }
    
    public var extensions: [String] {
        ["d64"]
    }
    
    public var magicNumbers: [FileTypeMagicNumber] {
        []  // Size-based detection (174,848 bytes typical)
    }
    
    public var category: FileTypeMetadataCategory {
        .diskImage
    }
    
    public var vendor: String? {
        "Commodore Business Machines"
    }
    
    public var additionalMetadata: [String: String] {
        [
            "containerFormat": "d64",
            "fileSystemFormat": "cbm",
            "platform": "commodore64",
            "tracks": "35",
            "standardSize": "174848"
        ]
    }
    
    public var iconName: String? {
        "opticaldisc"
    }
}

/// Commodore G64 Disk Image
public struct G64DiskImageFileType: FileTypeMetadata {
    public var typeIdentifier: String {
        "com.commodore.disk-image.g64"
    }
    
    public var shortID: String {
        "g64"
    }
    
    public var displayName: String {
        "Commodore 64 G64 Disk Image"
    }
    
    public var version: FileTypeVersion? {
        nil
    }
    
    public var mimeType: String? {
        "application/x-g64-disk-image"
    }
    
    public var extensions: [String] {
        ["g64"]
    }
    
    public var magicNumbers: [FileTypeMagicNumber] {
        [
            // G64 signature
            FileTypeMagicNumber(offset: 0, bytes: [0x47, 0x43, 0x52, 0x2D, 0x31, 0x35, 0x34, 0x31])  // "GCR-1541"
        ]
    }
    
    public var category: FileTypeMetadataCategory {
        .diskImage
    }
    
    public var vendor: String? {
        "Commodore Business Machines"
    }
    
    public var additionalMetadata: [String: String] {
        [
            "containerFormat": "g64",
            "platform": "commodore64",
            "preservesCopyProtection": "true",
            "encoding": "gcr"
        ]
    }
}

// MARK: - ISO Images

/// ISO 9660 Disk Image
public struct ISO9660DiskImageFileType: FileTypeMetadata {
    public var typeIdentifier: String {
        "org.iso.disk-image.iso.iso9660"
    }
    
    public var shortID: String {
        "iso9660"
    }
    
    public var displayName: String {
        "ISO 9660 Disk Image"
    }
    
    public var version: FileTypeVersion? {
        nil
    }
    
    public var mimeType: String? {
        "application/x-iso9660-image"
    }
    
    public var extensions: [String] {
        ["iso"]
    }
    
    public var magicNumbers: [FileTypeMagicNumber] {
        [
            // ISO 9660 signature at sector 16
            FileTypeMagicNumber(offset: 0x8001, bytes: [0x43, 0x44, 0x30, 0x30, 0x31])  // "CD001"
        ]
    }
    
    public var category: FileTypeMetadataCategory {
        .diskImage
    }
    
    public var vendor: String? {
        "International Organization for Standardization"
    }
    
    public var additionalMetadata: [String: String] {
        [
            "containerFormat": "iso",
            "fileSystemFormat": "iso9660",
            "standard": "ISO 9660:1988"
        ]
    }
    
    public var iconName: String? {
        "opticaldisc"
    }
}

// MARK: - Registration

/// Registers vintage file type metadata with FileSystemKit
public struct VintageFileTypeRegistrations {
    
    /// Register all vintage file types
    public static func register() async {
        let registry = FileTypeMetadataRegistry.shared
        
        // Apple II disk images
        await registry.register(DOS33DiskImageFileType())
        await registry.register(ProDOSDiskImageFileType())
        await registry.register(WOZDiskImageFileType())
        await registry.register(NIBDiskImageFileType())
        
        // Commodore disk images
        await registry.register(D64DiskImageFileType())
        await registry.register(G64DiskImageFileType())
        
        // ISO images
        await registry.register(ISO9660DiskImageFileType())
    }
}
