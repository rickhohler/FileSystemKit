//
//  FileTypeSystemTests.swift
//  FileSystemKitTests
//
//  Comprehensive tests for the new UTI-based file type system
//

import XCTest
@testable import FileSystemKit

final class FileTypeSystemTests: XCTestCase {
    
    // MARK: - Setup/Teardown
    
    override func setUp() async throws {
        // Clear registry before each test
        // Note: In production, registry is singleton, so tests may affect each other
        // For proper isolation, would need a way to reset registry
    }
    
    // MARK: - UTI Tests
    
    func testUTIConformance() {
        let jpeg = UTI.jpeg
        
        XCTAssertTrue(jpeg.conforms(to: .image))
        XCTAssertTrue(jpeg.conforms(to: .data))
        XCTAssertTrue(jpeg.conforms(to: jpeg))  // Self conformance
        XCTAssertFalse(jpeg.conforms(to: .text))
    }
    
    func testUTIAncestors() {
        let jpeg = UTI.jpeg
        let ancestors = jpeg.ancestors
        
        XCTAssertTrue(ancestors.contains(.image))
        XCTAssertTrue(ancestors.contains(.data))
        XCTAssertTrue(ancestors.contains(.content))
    }
    
    func testUTIEquality() {
        let uti1 = UTI(identifier: "com.test.type")
        let uti2 = UTI(identifier: "com.test.type")
        let uti3 = UTI(identifier: "com.test.other")
        
        XCTAssertEqual(uti1, uti2)
        XCTAssertNotEqual(uti1, uti3)
    }
    
    // MARK: - File Type Registration Tests
    
    func testRegisterFileType() async throws {
        let registry = FileTypeRegistry.shared
        
        let testType = FileTypeDefinition(
            uti: UTI(identifier: "com.test.file-type"),
            shortID: "test",
            displayName: "Test File",
            extensions: ["tst"],
            icon: .sfSymbol("doc"),
            category: .document
        )
        
        // First registration should succeed
        try await registry.register(fileType: testType)
        
        // Verify registration
        let found = await registry.fileType(for: "test")
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.shortID, "test")
        XCTAssertEqual(found?.displayName, "Test File")
    }
    
    func testRegisterDuplicateShortIDThrows() async throws {
        let registry = FileTypeRegistry.shared
        
        let type1 = FileTypeDefinition(
            uti: UTI(identifier: "com.test.type1"),
            shortID: "dup",
            displayName: "Type 1",
            extensions: ["t1"],
            icon: .sfSymbol("doc"),
            category: .document
        )
        
        let type2 = FileTypeDefinition(
            uti: UTI(identifier: "com.test.type2"),
            shortID: "dup",  // Same shortID
            displayName: "Type 2",
            extensions: ["t2"],
            icon: .sfSymbol("doc"),
            category: .document
        )
        
        try await registry.register(fileType: type1)
        
        // Second registration with same shortID should throw
        do {
            try await registry.register(fileType: type2)
            XCTFail("Expected FileTypeRegistryError.duplicateShortID")
        } catch FileTypeRegistryError.duplicateShortID(let id) {
            XCTAssertEqual(id, "dup")
        }
    }
    
    func testRegisterWithOverride() async throws {
        let registry = FileTypeRegistry.shared
        
        let type1 = FileTypeDefinition(
            uti: UTI(identifier: "com.test.override1"),
            shortID: "ovr",
            displayName: "Original",
            extensions: ["ovr"],
            icon: .sfSymbol("doc"),
            category: .document
        )
        
        let type2 = FileTypeDefinition(
            uti: UTI(identifier: "com.test.override2"),
            shortID: "ovr",
            displayName: "Updated",
            extensions: ["ovr"],
            icon: .sfSymbol("doc.fill"),
            category: .document
        )
        
        try await registry.register(fileType: type1)
        
        // Override should succeed
        try await registry.register(fileType: type2, allowOverride: true)
        
        let found = await registry.fileType(for: "ovr")
        XCTAssertEqual(found?.displayName, "Updated")
    }
    
    func testInvalidShortIDThrows() async throws {
        let registry = FileTypeRegistry.shared
        
        // Too short
        let tooShort = FileTypeDefinition(
            uti: UTI(identifier: "com.test.short"),
            shortID: "ab",  // Only 2 chars
            displayName: "Too Short",
            extensions: ["ts"],
            icon: .sfSymbol("doc"),
            category: .document
        )
        
        do {
            try await registry.register(fileType: tooShort)
            XCTFail("Expected invalidShortID error")
        } catch FileTypeRegistryError.invalidShortID {
            // Expected
        }
        
        // Too long
        let tooLong = FileTypeDefinition(
            uti: UTI(identifier: "com.test.long"),
            shortID: "verylongid",  // 10 chars
            displayName: "Too Long",
            extensions: ["tl"],
            icon: .sfSymbol("doc"),
            category: .document
        )
        
        do {
            try await registry.register(fileType: tooLong)
            XCTFail("Expected invalidShortID error")
        } catch FileTypeRegistryError.invalidShortID {
            // Expected
        }
    }
    
    // MARK: - File Type Lookup Tests
    
    func testLookupByShortID() async throws {
        let registry = FileTypeRegistry.shared
        
        let fileType = FileTypeDefinition(
            uti: UTI(identifier: "com.test.lookup"),
            shortID: "lookup",
            displayName: "Lookup Test",
            extensions: ["lkp"],
            icon: .sfSymbol("doc"),
            category: .document
        )
        
        try await registry.register(fileType: fileType)
        
        let found = await registry.fileType(for: "lookup")
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.uti.identifier, "com.test.lookup")
    }
    
    func testLookupByUTI() async throws {
        let registry = FileTypeRegistry.shared
        
        let uti = UTI(identifier: "com.test.uti-lookup")
        let fileType = FileTypeDefinition(
            uti: uti,
            shortID: "utilkp",
            displayName: "UTI Lookup Test",
            extensions: ["ul"],
            icon: .sfSymbol("doc"),
            category: .document
        )
        
        try await registry.register(fileType: fileType)
        
        let found = await registry.fileType(for: uti)
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.shortID, "utilkp")
    }
    
    func testLookupByExtension() async throws {
        let registry = FileTypeRegistry.shared
        
        let fileType = FileTypeDefinition(
            uti: UTI(identifier: "com.test.extension"),
            shortID: "exttest",
            displayName: "Extension Test",
            extensions: ["ext", "ext2"],
            icon: .sfSymbol("doc"),
            category: .document
        )
        
        try await registry.register(fileType: fileType)
        
        let found1 = await registry.fileTypes(for: "ext")
        XCTAssertEqual(found1.count, 1)
        XCTAssertEqual(found1.first?.shortID, "exttest")
        
        let found2 = await registry.fileTypes(for: "ext2")
        XCTAssertEqual(found2.count, 1)
    }
    
    func testConformanceLookup() async throws {
        let registry = FileTypeRegistry.shared
        
        let baseUTI = UTI(identifier: "com.test.base")
        let childUTI = UTI(
            identifier: "com.test.child",
            conformsTo: [baseUTI],
            description: "Child Type"
        )
        
        let childType = FileTypeDefinition(
            uti: childUTI,
            shortID: "child",
            displayName: "Child Type",
            extensions: ["chd"],
            icon: .sfSymbol("doc"),
            category: .document
        )
        
        try await registry.register(fileType: childType)
        
        let conforming = await registry.fileTypes(conformingTo: baseUTI)
        XCTAssertEqual(conforming.count, 1)
        XCTAssertEqual(conforming.first?.shortID, "child")
    }
    
    // MARK: - Signature Pattern Tests
    
    func testSignaturePatternMatchesBytes() {
        let pattern = FileSignaturePattern(
            offset: .absolute(0),
            test: .equals,
            value: .bytes([0x50, 0x4B, 0x03, 0x04])  // ZIP signature
        )
        
        let zipData = Data([0x50, 0x4B, 0x03, 0x04, 0x00, 0x00])
        XCTAssertTrue(pattern.matches(data: zipData))
        
        let notZipData = Data([0x00, 0x00, 0x00, 0x00])
        XCTAssertFalse(pattern.matches(data: notZipData))
    }
    
    func testSignaturePatternMatchesString() {
        let pattern = FileSignaturePattern(
            offset: .absolute(0),
            test: .equals,
            value: .string("WOZ1")
        )
        
        let wozData = "WOZ1".data(using: .utf8)!
        XCTAssertTrue(pattern.matches(data: wozData))
        
        let notWozData = "WOZ2".data(using: .utf8)!
        XCTAssertFalse(pattern.matches(data: notWozData))
    }
    
    // MARK: - Detection Engine Tests
    
    func testDetectionByMagicNumber() async throws {
        let registry = FileTypeRegistry.shared
        let engine = FileTypeDetectionEngine.shared
        
        let wozType = FileTypeDefinition(
            uti: UTI(identifier: "com.test.woz"),
            shortID: "woz",
            displayName: "WOZ Disk Image",
            extensions: ["woz"],
            magicNumbers: [
                FileSignaturePattern(
                    offset: .absolute(0),
                    test: .equals,
                    value: .bytes([0x57, 0x4F, 0x5A, 0x31])  // "WOZ1"
                )
            ],
            icon: .sfSymbol("opticaldisc"),
            category: .diskImage
        )
        
        try await registry.register(fileType: wozType)
        
        let wozData = Data([0x57, 0x4F, 0x5A, 0x31, 0x00, 0x00])
        let result = await engine.detect(data: wozData)
        
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.fileType.shortID, "woz")
        XCTAssertEqual(result?.strategy, .magicNumber)
        XCTAssertGreaterThan(result?.confidence ?? 0, 0.8)
    }
    
    func testDetectionByExtension() async throws {
        let registry = FileTypeRegistry.shared
        let engine = FileTypeDetectionEngine.shared
        
        let txtType = FileTypeDefinition(
            uti: UTI(identifier: "com.test.text"),
            shortID: "txt",
            displayName: "Text File",
            extensions: ["txt"],
            icon: .sfSymbol("doc.text"),
            category: .document
        )
        
        try await registry.register(fileType: txtType)
        
        let textData = "Hello, World!".data(using: .utf8)!
        let result = await engine.detect(data: textData, extension: "txt")
        
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.fileType.shortID, "txt")
        XCTAssertEqual(result?.strategy, .extension)
    }
    
    
    // MARK: - FileSystemEntry Integration Tests
    
    func testFileSystemEntryMetadataWithFileTypeID() {
        let metadata = FileSystemEntryMetadata(
            name: "test.txt",
            size: 100,
            fileTypeID: "txt"
        )
        
        XCTAssertEqual(metadata.fileTypeID, "txt")
        XCTAssertEqual(metadata.name, "test.txt")
    }
    
    func testFileSystemEntryMetadataLookup() async throws {
        let registry = FileTypeRegistry.shared
        
        let txtType = FileTypeDefinition(
            uti: UTI(identifier: "com.test.plaintext"),
            shortID: "plaintxt",
            displayName: "Plain Text",
            extensions: ["txt"],
            icon: .sfSymbol("doc.text"),
            category: .document
        )
        
        try await registry.register(fileType: txtType)
        
        let metadata = FileSystemEntryMetadata(
            name: "test.txt",
            size: 100,
            fileTypeID: "plaintxt"
        )
        
        let definition = await metadata.fileTypeDefinition()
        XCTAssertNotNil(definition)
        XCTAssertEqual(definition?.displayName, "Plain Text")
        
        let uti = await metadata.uti()
        XCTAssertNotNil(uti)
        XCTAssertEqual(uti?.identifier, "com.test.plaintext")
    }
}
