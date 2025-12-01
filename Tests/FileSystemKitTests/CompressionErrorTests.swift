// FileSystemKit Tests
// CompressionError Unit Tests

import XCTest
@testable import FileSystemKit

final class CompressionErrorTests: XCTestCase {
    
    // MARK: - CompressionError Tests
    
    func testCompressionErrorDescriptions() {
        let errors: [CompressionError] = [
            .decompressionFailed,
            .compressionFailed,
            .notSupported,
            .notImplemented,
            .invalidFormat,
            .nestedCompressionNotSupported
        ]
        
        for error in errors {
            let description = error.errorDescription
            XCTAssertNotNil(description, "Error \(error) should have a description")
            XCTAssertFalse(description?.isEmpty ?? true, "Error description should not be empty")
        }
    }
}

