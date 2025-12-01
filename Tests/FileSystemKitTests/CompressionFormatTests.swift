// FileSystemKit Tests
// CompressionFormat Unit Tests

import XCTest
@testable import FileSystemKit

final class CompressionFormatTests: XCTestCase {
    
    // MARK: - CompressionFormat Tests
    
    func testCompressionFormatAllCases() {
        let formats = CompressionFormat.allCases
        XCTAssertFalse(formats.isEmpty, "Should have compression formats")
        XCTAssertTrue(formats.contains(.gzip))
        XCTAssertTrue(formats.contains(.zip))
        XCTAssertTrue(formats.contains(.arc))
        XCTAssertTrue(formats.contains(.unknown))
    }
    
    func testCompressionFormatExtensions() {
        XCTAssertEqual(CompressionFormat.gzip.extensions, [".gz", ".gzip"])
        XCTAssertEqual(CompressionFormat.zip.extensions, [".zip"])
        XCTAssertEqual(CompressionFormat.arc.extensions, [".arc", ".ark"])
        XCTAssertEqual(CompressionFormat.toast.extensions, [".toast"])
        XCTAssertEqual(CompressionFormat.stuffit.extensions, [".sit", ".sitx"])
        XCTAssertEqual(CompressionFormat.tar.extensions, [".tar"])
        XCTAssertEqual(CompressionFormat.unknown.extensions, [])
    }
    
    func testCompressionFormatDetect() {
        XCTAssertEqual(CompressionFormat.detect(from: "gz"), .gzip)
        XCTAssertEqual(CompressionFormat.detect(from: ".gz"), .gzip)
        XCTAssertEqual(CompressionFormat.detect(from: "GZ"), .gzip)
        XCTAssertEqual(CompressionFormat.detect(from: "zip"), .zip)
        XCTAssertEqual(CompressionFormat.detect(from: ".zip"), .zip)
        XCTAssertEqual(CompressionFormat.detect(from: "arc"), .arc)
        XCTAssertEqual(CompressionFormat.detect(from: ".arc"), .arc)
        XCTAssertEqual(CompressionFormat.detect(from: "ark"), .arc)
        XCTAssertEqual(CompressionFormat.detect(from: "unknown"), nil)
    }
    
    func testCompressionFormatDisplayName() {
        // Display names should be non-empty
        for format in CompressionFormat.allCases {
            if format != .unknown {
                XCTAssertFalse(format.displayName.isEmpty, "Format \(format) should have a display name")
            }
        }
    }
}

