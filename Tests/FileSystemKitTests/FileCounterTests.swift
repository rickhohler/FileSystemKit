// FileSystemKit Tests
// FileCounter Unit Tests

import XCTest
@testable import FileSystemKit
import Foundation

final class FileCounterTests: XCTestCase {
    var tempDirectory: URL!
    
    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FileCounterTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        tempDirectory = nil
        super.tearDown()
    }
    
    // MARK: - Basic Counting Tests
    
    func testCountFilesEmptyDirectory() throws {
        let count = try FileCounter.countFiles(in: tempDirectory)
        
        XCTAssertEqual(count, 0)
    }
    
    func testCountFilesSingleFile() throws {
        let testFile = tempDirectory.appendingPathComponent("test.txt")
        try "test".data(using: .utf8)!.write(to: testFile)
        
        let count = try FileCounter.countFiles(in: tempDirectory)
        
        XCTAssertEqual(count, 1)
    }
    
    func testCountFilesMultipleFiles() throws {
        for i in 1...5 {
            let testFile = tempDirectory.appendingPathComponent("test\(i).txt")
            try "test\(i)".data(using: .utf8)!.write(to: testFile)
        }
        
        let count = try FileCounter.countFiles(in: tempDirectory)
        
        XCTAssertEqual(count, 5)
    }
    
    func testCountFilesWithSubdirectories() throws {
        // Create files in root
        for i in 1...3 {
            let testFile = tempDirectory.appendingPathComponent("file\(i).txt")
            try "test".data(using: .utf8)!.write(to: testFile)
        }
        
        // Create subdirectory with files
        let subDir = tempDirectory.appendingPathComponent("subdir")
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
        for i in 1...2 {
            let testFile = subDir.appendingPathComponent("file\(i).txt")
            try "test".data(using: .utf8)!.write(to: testFile)
        }
        
        let count = try FileCounter.countFiles(in: tempDirectory)
        
        XCTAssertEqual(count, 5) // 3 in root + 2 in subdir
    }
    
    func testCountFilesExcludesDirectories() throws {
        // Create a directory
        let subDir = tempDirectory.appendingPathComponent("subdir")
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
        
        // Create a file
        let testFile = tempDirectory.appendingPathComponent("test.txt")
        try "test".data(using: .utf8)!.write(to: testFile)
        
        let count = try FileCounter.countFiles(in: tempDirectory)
        
        XCTAssertEqual(count, 1) // Only the file, not the directory
    }
    
    // MARK: - Ignore Pattern Tests
    
    func testCountFilesWithIgnorePattern() throws {
        // Create files
        for i in 1...5 {
            let testFile = tempDirectory.appendingPathComponent("test\(i).txt")
            try "test".data(using: .utf8)!.write(to: testFile)
        }
        
        // Create ignore matcher that ignores test3.txt
        let ignoreMatcher = SnugIgnoreMatcher(patterns: ["test3.txt"])
        
        let count = try FileCounter.countFiles(in: tempDirectory, ignoreMatcher: ignoreMatcher)
        
        XCTAssertEqual(count, 4) // 5 files minus 1 ignored
    }
    
    func testCountFilesWithIgnorePatternMultiple() throws {
        // Create files
        for i in 1...5 {
            let testFile = tempDirectory.appendingPathComponent("test\(i).txt")
            try "test".data(using: .utf8)!.write(to: testFile)
        }
        
        // Create ignore matcher that ignores test2.txt and test4.txt
        let ignoreMatcher = SnugIgnoreMatcher(patterns: ["test2.txt", "test4.txt"])
        
        let count = try FileCounter.countFiles(in: tempDirectory, ignoreMatcher: ignoreMatcher)
        
        XCTAssertEqual(count, 3) // 5 files minus 2 ignored
    }
    
    func testCountFilesWithIgnorePatternGlob() throws {
        // Create files with different extensions
        try "test".data(using: .utf8)!.write(to: tempDirectory.appendingPathComponent("test1.txt"))
        try "test".data(using: .utf8)!.write(to: tempDirectory.appendingPathComponent("test2.txt"))
        try "test".data(using: .utf8)!.write(to: tempDirectory.appendingPathComponent("test.log"))
        
        // Create ignore matcher that ignores .log files
        let ignoreMatcher = SnugIgnoreMatcher(patterns: ["*.log"])
        
        let count = try FileCounter.countFiles(in: tempDirectory, ignoreMatcher: ignoreMatcher)
        
        XCTAssertEqual(count, 2) // Only .txt files
    }
    
    // MARK: - Hidden Files Tests
    
    func testCountFilesSkipsHiddenFiles() throws {
        // Create regular file
        try "test".data(using: .utf8)!.write(to: tempDirectory.appendingPathComponent("test.txt"))
        
        // Create hidden file
        try "test".data(using: .utf8)!.write(to: tempDirectory.appendingPathComponent(".hidden"))
        
        let count = try FileCounter.countFiles(in: tempDirectory, skipHiddenFiles: true)
        
        XCTAssertEqual(count, 1) // Only the regular file
    }
    
    func testCountFilesIncludesHiddenFiles() throws {
        // Create regular file
        try "test".data(using: .utf8)!.write(to: tempDirectory.appendingPathComponent("test.txt"))
        
        // Create hidden file
        try "test".data(using: .utf8)!.write(to: tempDirectory.appendingPathComponent(".hidden"))
        
        let count = try FileCounter.countFiles(in: tempDirectory, skipHiddenFiles: false)
        
        XCTAssertEqual(count, 2) // Both files
    }
    
    // MARK: - Edge Cases
    
    func testCountFilesNonExistentDirectory() throws {
        let nonExistentDir = tempDirectory.appendingPathComponent("nonexistent")
        
        // Should return 0 for non-existent directory
        let count = try FileCounter.countFiles(in: nonExistentDir)
        
        XCTAssertEqual(count, 0)
    }
    
    func testCountFilesNestedStructure() throws {
        // Create nested directory structure
        let level1 = tempDirectory.appendingPathComponent("level1")
        try FileManager.default.createDirectory(at: level1, withIntermediateDirectories: true)
        
        let level2 = level1.appendingPathComponent("level2")
        try FileManager.default.createDirectory(at: level2, withIntermediateDirectories: true)
        
        // Create files at each level
        try "test".data(using: .utf8)!.write(to: tempDirectory.appendingPathComponent("root.txt"))
        try "test".data(using: .utf8)!.write(to: level1.appendingPathComponent("level1.txt"))
        try "test".data(using: .utf8)!.write(to: level2.appendingPathComponent("level2.txt"))
        
        let count = try FileCounter.countFiles(in: tempDirectory)
        
        XCTAssertEqual(count, 3) // All three files
    }
}

