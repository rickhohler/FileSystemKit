// FileSystemKit Tests
// UTI Generator Unit Tests
//
// This test suite validates UTI identifier generation with version support

import XCTest
@testable import FileSystemKit

final class UTIGeneratorTests: XCTestCase {
    
    func testGenerateUTIWithDOS33Version() {
        let uti = UTIGenerator.generateUTI(
            diskImageFormat: .raw,
            fileSystemFormat: .appleDOS33,
            fileSystemVersion: "3.3"
        )
        XCTAssertEqual(uti, "com.apple.disk-image.raw.dos33.v3.3")
    }
    
    func testGenerateUTIWithDOS32Version() {
        let uti = UTIGenerator.generateUTI(
            diskImageFormat: .raw,
            fileSystemFormat: .appleDOS33,
            fileSystemVersion: "3.2"
        )
        // Should use dos32 in layer 3, not dos33
        XCTAssertEqual(uti, "com.apple.disk-image.raw.dos32.v3.2")
    }
    
    func testGenerateUTIWithDOS31Version() {
        let uti = UTIGenerator.generateUTI(
            diskImageFormat: .d13,
            fileSystemFormat: .appleDOS33,
            fileSystemVersion: "3.1"
        )
        // Should use dos31 in layer 3, not dos33
        XCTAssertEqual(uti, "com.apple.disk-image.d13.dos31.v3.1")
    }
    
    func testGenerateUTIWithProDOS24Version() {
        let uti = UTIGenerator.generateUTI(
            diskImageFormat: .raw,
            fileSystemFormat: .proDOS,
            fileSystemVersion: "2.4"
        )
        XCTAssertEqual(uti, "com.apple.disk-image.raw.prodos.v2.4")
    }
    
    func testGenerateUTIWithProDOS10Version() {
        let uti = UTIGenerator.generateUTI(
            diskImageFormat: .po,
            fileSystemFormat: .proDOS,
            fileSystemVersion: "1.0"
        )
        XCTAssertEqual(uti, "com.apple.disk-image.po.prodos.v1.0")
    }
    
    func testGenerateUTIWithoutVersion() {
        let uti = UTIGenerator.generateUTI(
            diskImageFormat: .raw,
            fileSystemFormat: .proDOS,
            fileSystemVersion: nil
        )
        XCTAssertEqual(uti, "com.apple.disk-image.raw.prodos")
    }
    
    func testGenerateUTIWithoutFileSystem() {
        let uti = UTIGenerator.generateUTI(
            diskImageFormat: .raw,
            fileSystemFormat: nil,
            fileSystemVersion: nil
        )
        XCTAssertEqual(uti, "com.apple.disk-image.raw")
    }
    
    func testGenerateUTIFromMetadata() {
        var metadata = DiskImageMetadata()
        metadata.detectedDiskImageFormat = .woz
        metadata.detectedFileSystemFormat = .appleDOS33
        metadata.detectedFileSystemVersion = "3.3"
        
        let uti = UTIGenerator.generateUTI(from: metadata)
        XCTAssertEqual(uti, "com.apple.disk-image.woz.dos33.v3.3")
    }
    
    func testGenerateUTIWithWOZFormat() {
        let uti = UTIGenerator.generateUTI(
            diskImageFormat: .woz,
            fileSystemFormat: .appleDOS33,
            fileSystemVersion: "3.3"
        )
        XCTAssertEqual(uti, "com.apple.disk-image.woz.dos33.v3.3")
    }
    
    func testGenerateUTIWith2MGFormat() {
        let uti = UTIGenerator.generateUTI(
            diskImageFormat: .twoMG,
            fileSystemFormat: .proDOS,
            fileSystemVersion: "2.4"
        )
        XCTAssertEqual(uti, "com.apple.disk-image.2mg.prodos.v2.4")
    }
    
    func testVersionNormalization() {
        // Test that versions are normalized correctly
        let uti1 = UTIGenerator.generateUTI(
            diskImageFormat: .raw,
            fileSystemFormat: .appleDOS33,
            fileSystemVersion: "v3.3"  // Already has "v" prefix
        )
        XCTAssertEqual(uti1, "com.apple.disk-image.raw.dos33.v3.3")
        
        let uti2 = UTIGenerator.generateUTI(
            diskImageFormat: .raw,
            fileSystemFormat: .appleDOS33,
            fileSystemVersion: "3-3"  // Has dash instead of dot
        )
        XCTAssertEqual(uti2, "com.apple.disk-image.raw.dos33.v3.3")
    }
}

