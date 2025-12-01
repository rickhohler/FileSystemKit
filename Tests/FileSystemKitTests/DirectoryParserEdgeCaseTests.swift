// FileSystemKit Tests
// DirectoryParser Edge Case Unit Tests

import XCTest
@testable import FileSystemKit
import Foundation

final class DirectoryParserEdgeCaseTests: DirectoryParserTestBase {
    
    // MARK: - Ignore Pattern Tests
    
    func testParseWithIgnorePattern() throws {
        // Create files
        try "test".data(using: .utf8)!.write(to: tempDirectory.appendingPathComponent("file1.txt"))
        try "test".data(using: .utf8)!.write(to: tempDirectory.appendingPathComponent("file2.txt"))
        try "test".data(using: .utf8)!.write(to: tempDirectory.appendingPathComponent("ignore.txt"))
        
        let entries = NSLockedArray<DirectoryEntry>()
        let delegate = TestDirectoryParserDelegate(entries: entries)
        
        let ignoreMatcher = SnugIgnoreMatcher(patterns: ["ignore.txt"])
        
        let options = DirectoryParserOptions(
            basePath: "",
            followSymlinks: false,
            includeSpecialFiles: false,
            skipPermissionErrors: false,
            skipHiddenFiles: true,
            verbose: false
        )
        
        try DirectoryParser.parse(rootURL: tempDirectory, options: options, delegate: delegate, ignoreMatcher: ignoreMatcher)
        
        XCTAssertEqual(entries.count, 2)
        XCTAssertFalse(entries.contains { (entry: DirectoryEntry) in entry.path == "ignore.txt" })
    }
    
    // MARK: - Hidden Files Tests
    
    func testParseSkipsHiddenFiles() throws {
        // Create hidden file
        try "test".data(using: .utf8)!.write(to: tempDirectory.appendingPathComponent(".hidden"))
        try "test".data(using: .utf8)!.write(to: tempDirectory.appendingPathComponent("visible.txt"))
        
        let entries = NSLockedArray<DirectoryEntry>()
        let delegate = TestDirectoryParserDelegate(entries: entries)
        
        let options = DirectoryParserOptions(
            skipHiddenFiles: true
        )
        
        try DirectoryParser.parse(rootURL: tempDirectory, options: options, delegate: delegate)
        
        let fileEntries = entries.filter { $0.type == "file" }
        XCTAssertEqual(fileEntries.count, 1)
        XCTAssertTrue(fileEntries.contains { $0.path == "visible.txt" })
        XCTAssertFalse(fileEntries.contains { $0.path == ".hidden" })
    }
    
    func testParseIncludesHiddenFiles() throws {
        // Create hidden file
        try "test".data(using: .utf8)!.write(to: tempDirectory.appendingPathComponent(".hidden"))
        try "test".data(using: .utf8)!.write(to: tempDirectory.appendingPathComponent("visible.txt"))
        
        let entries = NSLockedArray<DirectoryEntry>()
        let delegate = TestDirectoryParserDelegate(entries: entries)
        
        let options = DirectoryParserOptions(
            skipHiddenFiles: false
        )
        
        try DirectoryParser.parse(rootURL: tempDirectory, options: options, delegate: delegate)
        
        let fileEntries = entries.filter { $0.type == "file" }
        XCTAssertTrue(fileEntries.count >= 2)
        XCTAssertTrue(fileEntries.contains { $0.path == ".hidden" })
        XCTAssertTrue(fileEntries.contains { $0.path == "visible.txt" })
    }
    
    // MARK: - Base Path Tests
    
    func testParseWithBasePath() throws {
        try "test".data(using: .utf8)!.write(to: tempDirectory.appendingPathComponent("file.txt"))
        
        let entries = NSLockedArray<DirectoryEntry>()
        let delegate = TestDirectoryParserDelegate(entries: entries)
        
        let options = DirectoryParserOptions(
            basePath: "custom/base"
        )
        
        try DirectoryParser.parse(rootURL: tempDirectory, options: options, delegate: delegate)
        
        let fileEntries = entries.filter { $0.type == "file" }
        XCTAssertEqual(fileEntries.count, 1)
        XCTAssertTrue(fileEntries.contains { $0.path == "custom/base/file.txt" })
    }
}

