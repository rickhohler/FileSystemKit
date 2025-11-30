// FileSystemKit Tests
// FileMetadataCollector Unit Tests

import XCTest
@testable import FileSystemKit
import Foundation

final class FileMetadataTests: XCTestCase {
    var tempDirectory: URL!
    
    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FileMetadataTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        tempDirectory = nil
        super.tearDown()
    }
    
    // MARK: - Metadata Collection Tests
    
    func testCollectMetadataForFile() throws {
        let testFile = tempDirectory.appendingPathComponent("test.txt")
        let testData = "Hello, World!".data(using: .utf8)!
        try testData.write(to: testFile)
        
        let metadata = FileMetadataCollector.collect(from: testFile)
        
        XCTAssertNotNil(metadata)
        XCTAssertEqual(metadata.size, testData.count)
        XCTAssertNotNil(metadata.modified)
        XCTAssertNotNil(metadata.created)
    }
    
    func testCollectMetadataForDirectory() throws {
        let testDir = tempDirectory.appendingPathComponent("testdir")
        try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
        
        let metadata = FileMetadataCollector.collect(from: testDir)
        
        XCTAssertNotNil(metadata)
        XCTAssertNil(metadata.size) // Directories don't have size
        XCTAssertNotNil(metadata.modified)
        XCTAssertNotNil(metadata.created)
    }
    
    // MARK: - Permissions Tests
    
    func testGetPermissions() throws {
        let testFile = tempDirectory.appendingPathComponent("test.txt")
        let testData = "test".data(using: .utf8)!
        try testData.write(to: testFile)
        
        let permissions = FileMetadataCollector.getPermissions(from: testFile)
        
        XCTAssertNotNil(permissions)
        // Permissions should be a valid octal string (4 digits)
        if let perms = permissions {
            XCTAssertEqual(perms.count, 4)
            XCTAssertTrue(perms.allSatisfy { "01234567".contains($0) })
        }
    }
    
    func testGetPermissionsForDirectory() throws {
        let testDir = tempDirectory.appendingPathComponent("testdir")
        try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
        
        let permissions = FileMetadataCollector.getPermissions(from: testDir)
        
        XCTAssertNotNil(permissions)
    }
    
    // MARK: - Owner and Group Tests
    
    func testGetOwnerAndGroup() throws {
        let testFile = tempDirectory.appendingPathComponent("test.txt")
        let testData = "test".data(using: .utf8)!
        try testData.write(to: testFile)
        
        let (owner, group) = FileMetadataCollector.getOwnerAndGroup(from: testFile)
        
        // Owner and group may be nil on some systems, but if present should be non-empty strings
        if let owner = owner {
            XCTAssertFalse(owner.isEmpty)
        }
        if let group = group {
            XCTAssertFalse(group.isEmpty)
        }
    }
    
    func testGetOwnerAndGroupForDirectory() throws {
        let testDir = tempDirectory.appendingPathComponent("testdir")
        try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
        
        let (owner, group) = FileMetadataCollector.getOwnerAndGroup(from: testDir)
        
        // Owner and group may be nil on some systems
        if let owner = owner {
            XCTAssertFalse(owner.isEmpty)
        }
        if let group = group {
            XCTAssertFalse(group.isEmpty)
        }
    }
    
    // MARK: - FileSystemMetadata Tests
    
    func testFileSystemMetadataInitialization() {
        let metadata = FileSystemMetadata(
            permissions: "0644",
            owner: "testuser",
            group: "testgroup",
            modified: Date(),
            created: Date(),
            size: 1024,
            isExecutable: false
        )
        
        XCTAssertEqual(metadata.permissions, "0644")
        XCTAssertEqual(metadata.owner, "testuser")
        XCTAssertEqual(metadata.group, "testgroup")
        XCTAssertEqual(metadata.size, 1024)
        XCTAssertFalse(metadata.isExecutable)
    }
    
    func testFileSystemMetadataWithDefaults() {
        let metadata = FileSystemMetadata()
        
        XCTAssertNil(metadata.permissions)
        XCTAssertNil(metadata.owner)
        XCTAssertNil(metadata.group)
        XCTAssertNil(metadata.modified)
        XCTAssertNil(metadata.created)
        XCTAssertNil(metadata.size)
        XCTAssertFalse(metadata.isExecutable)
    }
}

