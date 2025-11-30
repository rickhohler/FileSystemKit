// FileSystemKit Tests
// FileTypeDetector Unit Tests

import XCTest
@testable import FileSystemKit
import Foundation

final class FileTypeDetectorTests: XCTestCase {
    var tempDirectory: URL!
    
    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FileTypeDetectorTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        tempDirectory = nil
        super.tearDown()
    }
    
    // MARK: - DMG Detection Tests
    
    func testDetectDMGFile() throws {
        // Create a test DMG file with UDIF signature
        let testFile = tempDirectory.appendingPathComponent("test.dmg")
        var dmgData = Data(count: 1024) // Small test file
        // Add UDIF signature "koly" at the end
        let kolySignature = Data([0x6B, 0x6F, 0x6C, 0x79]) // "koly"
        dmgData.replaceSubrange((dmgData.count - 512)..<(dmgData.count - 512 + 4), with: kolySignature)
        try dmgData.write(to: testFile)
        
        let testData = try Data(contentsOf: testFile)
        let typeInfo = FileTypeDetector.detect(for: testFile, data: testData)
        
        XCTAssertEqual(typeInfo.type, "disk-image")
        XCTAssertEqual(typeInfo.contentType, "application/x-apple-diskimage")
    }
    
    func testDetectDMGByExtension() throws {
        let testFile = tempDirectory.appendingPathComponent("test.dmg")
        let testData = Data(count: 100) // Small file without signature
        try testData.write(to: testFile)
        
        let typeInfo = FileTypeDetector.detectByExtension(testFile)
        
        XCTAssertEqual(typeInfo.type, "disk-image")
        XCTAssertEqual(typeInfo.contentType, "application/x-apple-diskimage")
    }
    
    // MARK: - ISO 9660 Detection Tests
    
    func testDetectISO9660File() throws {
        // Create a test ISO file with ISO 9660 signature
        let testFile = tempDirectory.appendingPathComponent("test.iso")
        var isoData = Data(count: 32773) // Minimum size for ISO detection
        // Add "CD001" signature at offset 32769
        let cd001Signature = "CD001".data(using: .isoLatin1)!
        isoData.replaceSubrange(32769..<32774, with: cd001Signature)
        try isoData.write(to: testFile)
        
        let testData = try Data(contentsOf: testFile)
        let typeInfo = FileTypeDetector.detect(for: testFile, data: testData)
        
        XCTAssertEqual(typeInfo.type, "disk-image")
        XCTAssertEqual(typeInfo.contentType, "application/x-iso9660-image")
    }
    
    func testDetectISO9660ByExtension() throws {
        let testFile = tempDirectory.appendingPathComponent("test.iso")
        let testData = Data(count: 100)
        try testData.write(to: testFile)
        
        let typeInfo = FileTypeDetector.detectByExtension(testFile)
        
        XCTAssertEqual(typeInfo.type, "disk-image")
        XCTAssertEqual(typeInfo.contentType, "application/x-iso9660-image")
    }
    
    // MARK: - VHD Detection Tests
    
    func testDetectVHDFile() throws {
        // Create a test VHD file with conectix signature
        let testFile = tempDirectory.appendingPathComponent("test.vhd")
        var vhdData = Data(count: 1024)
        // Add "conectix" signature at the end (VHD footer)
        let conectixSignature = "conectix".data(using: .ascii)!
        vhdData.replaceSubrange((vhdData.count - 512)..<(vhdData.count - 512 + 8), with: conectixSignature)
        try vhdData.write(to: testFile)
        
        let testData = try Data(contentsOf: testFile)
        let typeInfo = FileTypeDetector.detect(for: testFile, data: testData)
        
        XCTAssertEqual(typeInfo.type, "disk-image")
        XCTAssertEqual(typeInfo.contentType, "application/x-vhd")
    }
    
    func testDetectVHDByExtension() throws {
        let testFile = tempDirectory.appendingPathComponent("test.vhd")
        let testData = Data(count: 100)
        try testData.write(to: testFile)
        
        let typeInfo = FileTypeDetector.detectByExtension(testFile)
        
        XCTAssertEqual(typeInfo.type, "disk-image")
        XCTAssertEqual(typeInfo.contentType, "application/x-vhd")
    }
    
    // MARK: - Raw IMG Detection Tests
    
    func testDetectRawIMGFile() throws {
        // Create a raw IMG file with typical disk image size
        let testFile = tempDirectory.appendingPathComponent("test.img")
        let imgData = Data(count: 1440 * 1024) // 1.44MB floppy disk size
        try imgData.write(to: testFile)
        
        let testData = try Data(contentsOf: testFile)
        let typeInfo = FileTypeDetector.detect(for: testFile, data: testData)
        
        XCTAssertEqual(typeInfo.type, "disk-image")
        XCTAssertEqual(typeInfo.contentType, "application/octet-stream")
    }
    
    func testDetectRawIMGByExtension() throws {
        let testFile = tempDirectory.appendingPathComponent("test.img")
        let testData = Data(count: 100)
        try testData.write(to: testFile)
        
        let typeInfo = FileTypeDetector.detectByExtension(testFile)
        
        XCTAssertEqual(typeInfo.type, "disk-image")
        XCTAssertEqual(typeInfo.contentType, "application/octet-stream")
    }
    
    // MARK: - Regular File Tests
    
    func testDetectRegularFile() throws {
        // Create a regular text file
        let testFile = tempDirectory.appendingPathComponent("test.txt")
        let textData = "Hello, World!".data(using: .utf8)!
        try textData.write(to: testFile)
        
        let testData = try Data(contentsOf: testFile)
        let typeInfo = FileTypeDetector.detect(for: testFile, data: testData)
        
        XCTAssertEqual(typeInfo.type, "file")
        XCTAssertNil(typeInfo.contentType)
    }
    
    func testDetectRegularFileByExtension() throws {
        let testFile = tempDirectory.appendingPathComponent("test.txt")
        let testData = Data(count: 100)
        try testData.write(to: testFile)
        
        let typeInfo = FileTypeDetector.detectByExtension(testFile)
        
        XCTAssertEqual(typeInfo.type, "file")
        XCTAssertNil(typeInfo.contentType)
    }
    
    // MARK: - Edge Cases
    
    func testDetectSmallFile() throws {
        // File too small for signature detection
        let testFile = tempDirectory.appendingPathComponent("test.dmg")
        let smallData = Data(count: 100) // Too small for DMG signature
        try smallData.write(to: testFile)
        
        let typeInfo = FileTypeDetector.detect(for: testFile, data: smallData)
        
        // Should fall back to extension-based detection
        XCTAssertEqual(typeInfo.type, "disk-image")
        XCTAssertEqual(typeInfo.contentType, "application/x-apple-diskimage")
    }
    
    func testDetectFileWithoutExtension() throws {
        let testFile = tempDirectory.appendingPathComponent("test")
        let testData = Data(count: 1000)
        try testData.write(to: testFile)
        
        let typeInfo = FileTypeDetector.detect(for: testFile, data: testData)
        
        XCTAssertEqual(typeInfo.type, "file")
        XCTAssertNil(typeInfo.contentType)
    }
}

