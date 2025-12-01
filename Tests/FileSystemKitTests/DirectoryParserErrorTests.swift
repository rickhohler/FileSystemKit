// FileSystemKit Tests
// DirectoryParserError Unit Tests

import XCTest
@testable import FileSystemKit
import Foundation

final class DirectoryParserErrorTests: XCTestCase {
    
    // MARK: - Error Description Tests
    
    func testDirectoryParserErrorFailedToEnumerate() {
        let url = URL(fileURLWithPath: "/nonexistent/path")
        let error = DirectoryParserError.failedToEnumerate(url)
        
        let description = error.localizedDescription
        XCTAssertTrue(description.contains("Failed to enumerate directory"))
        XCTAssertTrue(description.contains("/nonexistent/path"))
    }
    
    func testDirectoryParserErrorBrokenSymlink() {
        let error = DirectoryParserError.brokenSymlink("link.txt", target: "/target/file")
        
        let description = error.localizedDescription
        XCTAssertTrue(description.contains("Broken symlink"))
        XCTAssertTrue(description.contains("link.txt"))
        XCTAssertTrue(description.contains("/target/file"))
    }
    
    func testDirectoryParserErrorPermissionDenied() {
        let url = URL(fileURLWithPath: "/protected/file")
        let error = DirectoryParserError.permissionDenied(url)
        
        let description = error.localizedDescription
        XCTAssertTrue(description.contains("Permission denied"))
        XCTAssertTrue(description.contains("/protected/file"))
    }
}

