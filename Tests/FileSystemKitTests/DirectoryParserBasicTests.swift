// FileSystemKit Tests
// DirectoryParser Basic Parsing Unit Tests

import XCTest
@testable import FileSystemKit
import Foundation

final class DirectoryParserBasicTests: DirectoryParserTestBase {
    
    // MARK: - Basic Parsing Tests
    
    func testParseEmptyDirectory() throws {
        let entries = NSLockedArray<DirectoryEntry>()
        let delegate = TestDirectoryParserDelegate(entries: entries)
        
        let options = DirectoryParserOptions(
            basePath: "",
            followSymlinks: false,
            includeSpecialFiles: false,
            skipPermissionErrors: false,
            skipHiddenFiles: true,
            verbose: false
        )
        
        try DirectoryParser.parse(rootURL: tempDirectory, options: options, delegate: delegate)
        
        XCTAssertEqual(entries.count, 0)
    }
    
    func testParseDirectoryWithFiles() throws {
        // Create test files
        try "test1".data(using: .utf8)!.write(to: tempDirectory.appendingPathComponent("file1.txt"))
        try "test2".data(using: .utf8)!.write(to: tempDirectory.appendingPathComponent("file2.txt"))
        
        let entries = NSLockedArray<DirectoryEntry>()
        let delegate = TestDirectoryParserDelegate(entries: entries)
        
        let options = DirectoryParserOptions(
            basePath: "",
            followSymlinks: false,
            includeSpecialFiles: false,
            skipPermissionErrors: false,
            skipHiddenFiles: true,
            verbose: false
        )
        
        try DirectoryParser.parse(rootURL: tempDirectory, options: options, delegate: delegate)
        
        // Get all entries as an array - DirectoryParser processes directories too
        let allEntries = entries.filter { _ in true }
        let fileEntries = allEntries.filter { $0.type == "file" }
        
        // Should have exactly 2 file entries (DirectoryParser doesn't include root directory)
        XCTAssertEqual(fileEntries.count, 2, "Expected 2 files, found \(fileEntries.count)")
        
        // Check that both files are present
        let file1Found = fileEntries.contains { $0.path == "file1.txt" }
        let file2Found = fileEntries.contains { $0.path == "file2.txt" }
        
        XCTAssertTrue(file1Found, "file1.txt not found")
        XCTAssertTrue(file2Found, "file2.txt not found")
    }
    
    func testParseDirectoryWithSubdirectories() throws {
        // Create subdirectory
        let subDir = tempDirectory.appendingPathComponent("subdir")
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
        
        // Create files
        try "test".data(using: .utf8)!.write(to: tempDirectory.appendingPathComponent("file.txt"))
        try "test".data(using: .utf8)!.write(to: subDir.appendingPathComponent("subfile.txt"))
        
        let entries = NSLockedArray<DirectoryEntry>()
        let delegate = TestDirectoryParserDelegate(entries: entries)
        
        let options = DirectoryParserOptions(
            basePath: "",
            followSymlinks: false,
            includeSpecialFiles: false,
            skipPermissionErrors: false,
            skipHiddenFiles: true,
            verbose: false
        )
        
        try DirectoryParser.parse(rootURL: tempDirectory, options: options, delegate: delegate)
        
        // Should find directory, file in root, and file in subdir
        XCTAssertTrue(entries.count >= 3)
        XCTAssertTrue(entries.contains { (entry: DirectoryEntry) in entry.type == "directory" && entry.path == "subdir" })
        XCTAssertTrue(entries.contains { (entry: DirectoryEntry) in entry.path == "file.txt" })
        XCTAssertTrue(entries.contains { (entry: DirectoryEntry) in entry.path == "subdir/subfile.txt" })
    }
    
    // MARK: - ParseToFileSystem Tests
    
    func testParseToFileSystem() throws {
        // Create test files
        try "test1".data(using: .utf8)!.write(to: tempDirectory.appendingPathComponent("file1.txt"))
        try "test2".data(using: .utf8)!.write(to: tempDirectory.appendingPathComponent("file2.txt"))
        
        let options = DirectoryParserOptions()
        let rootFolder = try DirectoryParser.parseToFileSystem(rootURL: tempDirectory, options: options)
        
        XCTAssertEqual(rootFolder.name, tempDirectory.lastPathComponent)
        XCTAssertEqual(rootFolder.children.count, 2)
        
        let file1 = rootFolder.getFile(named: "file1.txt")
        let file2 = rootFolder.getFile(named: "file2.txt")
        
        XCTAssertNotNil(file1)
        XCTAssertNotNil(file2)
        XCTAssertEqual(file1?.size, 5) // "test1" is 5 bytes
        XCTAssertEqual(file2?.size, 5) // "test2" is 5 bytes
    }
    
    func testParseToFileSystemWithSubdirectories() throws {
        // Create subdirectory
        let subDir = tempDirectory.appendingPathComponent("subdir")
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
        
        // Create files
        try "test".data(using: .utf8)!.write(to: tempDirectory.appendingPathComponent("file.txt"))
        try "test".data(using: .utf8)!.write(to: subDir.appendingPathComponent("subfile.txt"))
        
        let options = DirectoryParserOptions()
        let rootFolder = try DirectoryParser.parseToFileSystem(rootURL: tempDirectory, options: options)
        
        XCTAssertEqual(rootFolder.children.count, 2) // file.txt and subdir
        
        let subdirFolder = rootFolder.children.first { $0.name == "subdir" } as? FileSystemFolder
        XCTAssertNotNil(subdirFolder)
        XCTAssertEqual(subdirFolder?.children.count, 1)
        
        let subfile = subdirFolder?.getFile(named: "subfile.txt")
        XCTAssertNotNil(subfile)
    }
}

