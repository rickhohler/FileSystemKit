// FileSystemKit Tests
// PathUtilities Unit Tests

import XCTest
@testable import FileSystemKit
import Foundation

final class PathUtilitiesTests: XCTestCase {
    
    // MARK: - Path Normalization Tests
    
    func testNormalizeWindowsPath() {
        let windowsPath = "C:\\Users\\Test\\file.txt"
        let normalized = PathUtilities.normalize(windowsPath)
        
        XCTAssertEqual(normalized, "C:/Users/Test/file.txt")
    }
    
    func testNormalizeDoubleSlashes() {
        let pathWithDoubleSlashes = "path//to//file.txt"
        let normalized = PathUtilities.normalize(pathWithDoubleSlashes)
        
        XCTAssertEqual(normalized, "path/to/file.txt")
    }
    
    func testNormalizeUnixPath() {
        let unixPath = "/usr/local/bin/file"
        let normalized = PathUtilities.normalize(unixPath)
        
        XCTAssertEqual(normalized, "/usr/local/bin/file")
    }
    
    func testNormalizeTrailingSlashes() {
        let pathWithTrailingSlash = "path/to/file/"
        let normalized = PathUtilities.normalize(pathWithTrailingSlash)
        
        XCTAssertEqual(normalized, "path/to/file")
    }
    
    // MARK: - Relative Path Tests
    
    func testRelativePath() throws {
        let baseURL = URL(fileURLWithPath: "/base/directory")
        let fileURL = URL(fileURLWithPath: "/base/directory/sub/file.txt")
        
        let relativePath = PathUtilities.relativePath(from: fileURL, baseURL: baseURL, basePath: "")
        
        XCTAssertEqual(relativePath, "sub/file.txt")
    }
    
    func testRelativePathWithBasePath() throws {
        let baseURL = URL(fileURLWithPath: "/base/directory")
        let fileURL = URL(fileURLWithPath: "/base/directory/sub/file.txt")
        
        let relativePath = PathUtilities.relativePath(from: fileURL, baseURL: baseURL, basePath: "archive")
        
        XCTAssertEqual(relativePath, "archive/sub/file.txt")
    }
    
    func testRelativePathRootFile() throws {
        let baseURL = URL(fileURLWithPath: "/base/directory")
        let fileURL = URL(fileURLWithPath: "/base/directory/file.txt")
        
        let relativePath = PathUtilities.relativePath(from: fileURL, baseURL: baseURL, basePath: "")
        
        XCTAssertEqual(relativePath, "file.txt")
    }
    
    // MARK: - System File Detection Tests
    
    func testIsSystemFileDSStore() {
        let path = ".DS_Store"
        XCTAssertTrue(PathUtilities.isSystemFile(path))
    }
    
    func testIsSystemFileSystemVolumeInformation() {
        let path = "System Volume Information/file.txt"
        XCTAssertTrue(PathUtilities.isSystemFile(path))
    }
    
    func testIsSystemFileRecycleBin() {
        let path = "$RECYCLE.BIN/file.txt"
        XCTAssertTrue(PathUtilities.isSystemFile(path))
    }
    
    func testIsSystemFileWindows() {
        let path = "Windows/System32/file.dll"
        XCTAssertTrue(PathUtilities.isSystemFile(path))
    }
    
    func testIsSystemFileTrash() {
        let path = ".Trash/file.txt"
        XCTAssertTrue(PathUtilities.isSystemFile(path))
    }
    
    func testIsNotSystemFile() {
        let path = "Documents/file.txt"
        XCTAssertFalse(PathUtilities.isSystemFile(path))
    }
    
    // MARK: - Hidden File Detection Tests
    
    func testIsHiddenDotFile() {
        let path = ".hidden"
        XCTAssertTrue(PathUtilities.isHidden(path))
    }
    
    func testIsHiddenInSubdirectory() {
        let path = "path/to/.hidden/file.txt"
        XCTAssertTrue(PathUtilities.isHidden(path))
    }
    
    func testIsNotHidden() {
        let path = "path/to/file.txt"
        XCTAssertFalse(PathUtilities.isHidden(path))
    }
    
    func testIsNotHiddenCurrentDirectory() {
        let path = "."
        XCTAssertFalse(PathUtilities.isHidden(path))
    }
    
    func testIsNotHiddenParentDirectory() {
        let path = ".."
        XCTAssertFalse(PathUtilities.isHidden(path))
    }
}

