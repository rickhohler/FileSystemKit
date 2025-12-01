// FileSystemKit Tests
// DirectoryEntry Unit Tests

import XCTest
@testable import FileSystemKit
import Foundation

final class DirectoryEntryTests: XCTestCase {
    
    // MARK: - DirectoryEntry Initialization Tests
    
    func testDirectoryEntryInitialization() {
        let url = URL(fileURLWithPath: "/test/file.txt")
        let entry = DirectoryEntry(
            path: "file.txt",
            url: url,
            type: "file",
            size: 100,
            permissions: "0644",
            owner: "user",
            group: "group",
            modified: Date(),
            created: Date(),
            isHidden: false,
            isSystem: false,
            isSpecialFile: false
        )
        
        XCTAssertEqual(entry.path, "file.txt")
        XCTAssertEqual(entry.url, url)
        XCTAssertEqual(entry.type, "file")
        XCTAssertEqual(entry.size, 100)
        XCTAssertEqual(entry.permissions, "0644")
        XCTAssertEqual(entry.owner, "user")
        XCTAssertEqual(entry.group, "group")
        XCTAssertNotNil(entry.modified)
        XCTAssertNotNil(entry.created)
        XCTAssertFalse(entry.isHidden)
        XCTAssertFalse(entry.isSystem)
        XCTAssertFalse(entry.isSpecialFile)
    }
    
    func testDirectoryEntryWithSymlink() {
        let url = URL(fileURLWithPath: "/test/link")
        let entry = DirectoryEntry(
            path: "link",
            url: url,
            type: "symlink",
            symlinkTarget: "/target/file",
            isHidden: false,
            isSystem: false,
            isSpecialFile: false
        )
        
        XCTAssertEqual(entry.type, "symlink")
        XCTAssertEqual(entry.symlinkTarget, "/target/file")
        XCTAssertNil(entry.size)
    }
    
    func testDirectoryEntryWithSpecialFile() {
        let url = URL(fileURLWithPath: "/dev/disk0")
        let entry = DirectoryEntry(
            path: "disk0",
            url: url,
            type: "block-device",
            isSpecialFile: true
        )
        
        XCTAssertTrue(entry.isSpecialFile)
        XCTAssertEqual(entry.type, "block-device")
    }
    
    // MARK: - DirectoryEntry Conversion Tests
    
    func testDirectoryEntryToFileSystemEntryMetadata() {
        let url = URL(fileURLWithPath: "/test/file.txt")
        let entry = DirectoryEntry(
            path: "file.txt",
            url: url,
            type: "file",
            size: 100,
            permissions: "0644",
            owner: "user",
            group: "group",
            modified: Date(),
            created: Date(),
            isHidden: true,
            isSystem: false,
            isSpecialFile: false
        )
        
        let metadata = entry.toFileSystemEntryMetadata()
        
        XCTAssertEqual(metadata.name, "file.txt")
        XCTAssertEqual(metadata.size, 100)
        XCTAssertNotNil(metadata.modificationDate)
        XCTAssertEqual(metadata.attributes["permissions"] as? String, "0644")
        XCTAssertEqual(metadata.attributes["owner"] as? String, "user")
        XCTAssertEqual(metadata.attributes["group"] as? String, "group")
        XCTAssertEqual(metadata.attributes["isHidden"] as? Bool, true)
    }
    
    func testDirectoryEntryToFileSystemEntryMetadataWithSpecialFile() {
        let url = URL(fileURLWithPath: "/dev/disk0")
        let entry = DirectoryEntry(
            path: "disk0",
            url: url,
            type: "block-device",
            isSpecialFile: true
        )
        
        let metadata = entry.toFileSystemEntryMetadata()
        
        XCTAssertEqual(metadata.name, "disk0")
        XCTAssertEqual(metadata.specialFileType, "block-device")
    }
    
    func testDirectoryEntryToFileSystemEntry() {
        let url = URL(fileURLWithPath: "/test/file.txt")
        let entry = DirectoryEntry(
            path: "file.txt",
            url: url,
            type: "file",
            size: 100
        )
        
        let fileEntry = entry.toFileSystemEntry()
        
        XCTAssertNotNil(fileEntry)
        XCTAssertEqual(fileEntry?.name, "file.txt")
        XCTAssertEqual(fileEntry?.size, 100)
    }
    
    func testDirectoryEntryToFileSystemEntryReturnsNilForDirectory() {
        let url = URL(fileURLWithPath: "/test/dir")
        let entry = DirectoryEntry(
            path: "dir",
            url: url,
            type: "directory"
        )
        
        let fileEntry = entry.toFileSystemEntry()
        
        XCTAssertNil(fileEntry)
    }
    
    func testDirectoryEntryToFileSystemFolder() {
        let url = URL(fileURLWithPath: "/test/dir")
        let modifiedDate = Date()
        let entry = DirectoryEntry(
            path: "dir",
            url: url,
            type: "directory",
            modified: modifiedDate
        )
        
        let folder = entry.toFileSystemFolder()
        
        XCTAssertNotNil(folder)
        XCTAssertEqual(folder?.name, "dir")
        XCTAssertEqual(folder?.modificationDate, modifiedDate)
    }
    
    func testDirectoryEntryToFileSystemFolderReturnsNilForFile() {
        let url = URL(fileURLWithPath: "/test/file.txt")
        let entry = DirectoryEntry(
            path: "file.txt",
            url: url,
            type: "file"
        )
        
        let folder = entry.toFileSystemFolder()
        
        XCTAssertNil(folder)
    }
}

