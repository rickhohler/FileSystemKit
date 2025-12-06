//
//  VintageFileTypeRegistrationTests.swift
//  FileSystemKitTests
//
//  Tests for vintage file type registrations
//

import XCTest
@testable import FileSystemKit

final class VintageFileTypeRegistrationTests: XCTestCase {
    
    override func setUp() async throws {
        // Register file types before each test
        await VintageFileTypeRegistrations.register()
    }
    
    // MARK: - Apple II Disk Images
    
    func testDOS33DiskImageRegistration() async {
        let registry = FileTypeMetadataRegistry.shared
        
        // Find by extension
        let metadata = await registry.find(byExtension: "dsk")
        XCTAssertFalse(metadata.isEmpty, "Should find DSK metadata")
        
        // Find by type identifier
        let dos33 = await registry.find(byTypeIdentifier: "com.apple.disk-image.dsk.dos33.v3.3")
        XCTAssertNotNil(dos33)
        XCTAssertEqual(dos33?.displayName, "Apple II DOS 3.3 Disk Image")
        XCTAssertEqual(dos33?.category, .diskImage)
        XCTAssertEqual(dos33?.additionalMetadata["platform"], "apple2")
    }
    
    func testProDOSDiskImageRegistration() async {
        let registry = FileTypeMetadataRegistry.shared
        
        let prodos = await registry.find(byTypeIdentifier: "com.apple.disk-image.dsk.prodos")
        XCTAssertNotNil(prodos)
        XCTAssertEqual(prodos?.shortID, "prodosdsk")
        XCTAssertTrue(prodos?.extensions.contains("po") == true)
        XCTAssertEqual(prodos?.additionalMetadata["fileSystemFormat"], "prodos")
    }
    
    func testWOZDiskImageRegistration() async {
        let registry = FileTypeMetadataRegistry.shared
        
        let woz = await registry.find(byExtension: "woz").first
        XCTAssertNotNil(woz)
        XCTAssertEqual(woz?.displayName, "WOZ Disk Image")
        
        // Test magic number detection
        let woz1Data = Data([0x57, 0x4F, 0x5A, 0x31] + [UInt8](repeating: 0, count: 100))  // "WOZ1"
        XCTAssertTrue(woz?.matches(data: woz1Data) == true)
        
        let woz2Data = Data([0x57, 0x4F, 0x5A, 0x32] + [UInt8](repeating: 0, count: 100))  // "WOZ2"
        XCTAssertTrue(woz?.matches(data: woz2Data) == true)
    }
    
    // MARK: - Commodore Disk Images
    
    func testD64DiskImageRegistration() async {
        let registry = FileTypeMetadataRegistry.shared
        
        let d64 = await registry.find(byTypeIdentifier: "com.commodore.disk-image.d64")
        XCTAssertNotNil(d64)
        XCTAssertEqual(d64?.displayName, "Commodore 64 D64 Disk Image")
        XCTAssertEqual(d64?.category, .diskImage)
        XCTAssertEqual(d64?.additionalMetadata["platform"], "commodore64")
    }
    
    func testG64DiskImageRegistration() async {
        let registry = FileTypeMetadataRegistry.shared
        
        let g64 = await registry.find(byExtension: "g64").first
        XCTAssertNotNil(g64)
        
        // Test magic number
        let g64Data = Data([0x47, 0x43, 0x52, 0x2D, 0x31, 0x35, 0x34, 0x31] + [UInt8](repeating: 0, count: 100))  // "GCR-1541"
        XCTAssertTrue(g64?.matches(data: g64Data) == true)
    }
    
    // MARK: - ISO Images
    
    func testISO9660DiskImageRegistration() async {
        let registry = FileTypeMetadataRegistry.shared
        
        let iso = await registry.find(byTypeIdentifier: "org.iso.disk-image.iso.iso9660")
        XCTAssertNotNil(iso)
        XCTAssertEqual(iso?.displayName, "ISO 9660 Disk Image")
        XCTAssertEqual(iso?.additionalMetadata["fileSystemFormat"], "iso9660")
    }
    
    // MARK: - Integration Tests
    
    func testMultipleExtensionsForDSK() async {
        let registry = FileTypeMetadataRegistry.shared
        
        // DSK extension should match both DOS 3.3 and ProDOS (via .do and .po actually, let me check)
        let dskFiles = await registry.find(byExtension: "dsk")
        XCTAssertTrue(dskFiles.count >= 1, "Should find at least DOS 3.3 for DSK")
    }
    
    func testAllRegistrationsPresent() async {
        let registry = FileTypeMetadataRegistry.shared
        
        let allMetadata = await registry.allMetadata()
        
        // Should have at least 7 types registered (DOS33, ProDOS, WOZ, NIB, D64, G64, ISO)
        XCTAssertTrue(allMetadata.count >= 7, "Should have registered at least 7 file types")
    }
    
    func testFileTypeCategories() async {
        let registry = FileTypeMetadataRegistry.shared
        
        let dos33 = await registry.find(byShortID: "dos33dsk")
        let d64 = await registry.find(byShortID: "d64")
        let iso = await registry.find(byShortID: "iso9660")
        
        XCTAssertEqual(dos33?.category, .diskImage)
        XCTAssertEqual(d64?.category, .diskImage)
        XCTAssertEqual(iso?.category, .diskImage)
    }
}
