// FileSystemKit Tests
// DirectoryParser Unit Tests

import XCTest
@testable import FileSystemKit
import Foundation

final class DirectoryParserTests: XCTestCase {
    var tempDirectory: URL!
    
    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DirectoryParserTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        tempDirectory = nil
        super.tearDown()
    }
    
    // MARK: - Basic Parsing Tests
    
    func testParseEmptyDirectory() throws {
        var entries: [DirectoryEntry] = []
        
        let delegate = TestDirectoryParserDelegate { entry in
            entries.append(entry)
            return true
        }
        
        let options = DirectoryParserOptions(
            basePath: "",
            followSymlinks: false,
            includeSpecialFiles: false,
            skipPermissionErrors: false,
            skipHiddenFiles: true,
            verbose: false
        )
        
        let parser = DirectoryParser(options: options, delegate: delegate)
        try parser.parse(tempDirectory)
        
        XCTAssertEqual(entries.count, 0)
    }
    
    func testParseDirectoryWithFiles() throws {
        // Create test files
        try "test1".data(using: .utf8)!.write(to: tempDirectory.appendingPathComponent("file1.txt"))
        try "test2".data(using: .utf8)!.write(to: tempDirectory.appendingPathComponent("file2.txt"))
        
        var entries: [DirectoryEntry] = []
        
        let delegate = TestDirectoryParserDelegate { entry in
            entries.append(entry)
            return true
        }
        
        let options = DirectoryParserOptions(
            basePath: "",
            followSymlinks: false,
            includeSpecialFiles: false,
            skipPermissionErrors: false,
            skipHiddenFiles: true,
            verbose: false
        )
        
        let parser = DirectoryParser(options: options, delegate: delegate)
        try parser.parse(tempDirectory)
        
        XCTAssertEqual(entries.count, 2)
        XCTAssertTrue(entries.contains { $0.path == "file1.txt" })
        XCTAssertTrue(entries.contains { $0.path == "file2.txt" })
    }
    
    func testParseDirectoryWithSubdirectories() throws {
        // Create subdirectory
        let subDir = tempDirectory.appendingPathComponent("subdir")
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
        
        // Create files
        try "test".data(using: .utf8)!.write(to: tempDirectory.appendingPathComponent("file.txt"))
        try "test".data(using: .utf8)!.write(to: subDir.appendingPathComponent("subfile.txt"))
        
        var entries: [DirectoryEntry] = []
        
        let delegate = TestDirectoryParserDelegate { entry in
            entries.append(entry)
            return true
        }
        
        let options = DirectoryParserOptions(
            basePath: "",
            followSymlinks: false,
            includeSpecialFiles: false,
            skipPermissionErrors: false,
            skipHiddenFiles: true,
            verbose: false
        )
        
        let parser = DirectoryParser(options: options, delegate: delegate)
        try parser.parse(tempDirectory)
        
        // Should find directory, file in root, and file in subdir
        XCTAssertTrue(entries.count >= 3)
        XCTAssertTrue(entries.contains { $0.type == "directory" && $0.path == "subdir" })
        XCTAssertTrue(entries.contains { $0.path == "file.txt" })
        XCTAssertTrue(entries.contains { $0.path == "subdir/subfile.txt" })
    }
    
    // MARK: - Ignore Pattern Tests
    
    func testParseWithIgnorePattern() throws {
        // Create files
        try "test".data(using: .utf8)!.write(to: tempDirectory.appendingPathComponent("file1.txt"))
        try "test".data(using: .utf8)!.write(to: tempDirectory.appendingPathComponent("file2.txt"))
        try "test".data(using: .utf8)!.write(to: tempDirectory.appendingPathComponent("ignore.txt"))
        
        var entries: [DirectoryEntry] = []
        
        let delegate = TestDirectoryParserDelegate { entry in
            entries.append(entry)
            return true
        }
        
        let ignoreMatcher = SnugIgnoreMatcher(patterns: ["ignore.txt"])
        
        let options = DirectoryParserOptions(
            basePath: "",
            followSymlinks: false,
            includeSpecialFiles: false,
            skipPermissionErrors: false,
            skipHiddenFiles: true,
            verbose: false
        )
        
        let parser = DirectoryParser(options: options, delegate: delegate, ignoreMatcher: ignoreMatcher)
        try parser.parse(tempDirectory)
        
        XCTAssertEqual(entries.count, 2)
        XCTAssertFalse(entries.contains { $0.path == "ignore.txt" })
    }
    
    // MARK: - Helper Class
    
    private class TestDirectoryParserDelegate: DirectoryParserDelegate {
        let processEntryHandler: (DirectoryEntry) throws -> Bool
        
        init(processEntryHandler: @escaping (DirectoryEntry) throws -> Bool) {
            self.processEntryHandler = processEntryHandler
        }
        
        func processEntry(_ entry: DirectoryEntry) throws -> Bool {
            return try processEntryHandler(entry)
        }
        
        func handleError(url: URL, error: Error) -> Bool {
            return true // Continue on error
        }
    }
}

