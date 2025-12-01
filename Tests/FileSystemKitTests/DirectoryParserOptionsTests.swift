// FileSystemKit Tests
// DirectoryParserOptions Unit Tests

import XCTest
@testable import FileSystemKit

final class DirectoryParserOptionsTests: XCTestCase {
    
    // MARK: - Default Options Tests
    
    func testDirectoryParserOptionsDefaults() {
        let options = DirectoryParserOptions()
        
        XCTAssertEqual(options.basePath, "")
        XCTAssertFalse(options.followSymlinks)
        XCTAssertFalse(options.errorOnBrokenSymlinks)
        XCTAssertFalse(options.includeSpecialFiles)
        XCTAssertFalse(options.skipPermissionErrors)
        XCTAssertTrue(options.skipHiddenFiles)
        XCTAssertFalse(options.verbose)
    }
    
    // MARK: - Custom Options Tests
    
    func testDirectoryParserOptionsCustomValues() {
        let options = DirectoryParserOptions(
            basePath: "/custom/base",
            followSymlinks: true,
            errorOnBrokenSymlinks: true,
            includeSpecialFiles: true,
            skipPermissionErrors: true,
            skipHiddenFiles: false,
            verbose: true
        )
        
        XCTAssertEqual(options.basePath, "/custom/base")
        XCTAssertTrue(options.followSymlinks)
        XCTAssertTrue(options.errorOnBrokenSymlinks)
        XCTAssertTrue(options.includeSpecialFiles)
        XCTAssertTrue(options.skipPermissionErrors)
        XCTAssertFalse(options.skipHiddenFiles)
        XCTAssertTrue(options.verbose)
    }
}
