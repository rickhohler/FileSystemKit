// FileSystemKit Tests
// ZipCompressionMethod Unit Tests

import XCTest
@testable import FileSystemKit

final class ZipCompressionMethodTests: XCTestCase {
    
    // MARK: - ZipCompressionMethod Tests
    
    func testZipCompressionMethodPKZIP1_0() {
        XCTAssertTrue(ZipCompressionMethod.shrink.isPKZIP1_0)
        XCTAssertTrue(ZipCompressionMethod.reduce1.isPKZIP1_0)
        XCTAssertTrue(ZipCompressionMethod.reduce2.isPKZIP1_0)
        XCTAssertTrue(ZipCompressionMethod.reduce3.isPKZIP1_0)
        XCTAssertTrue(ZipCompressionMethod.reduce4.isPKZIP1_0)
        XCTAssertTrue(ZipCompressionMethod.implode.isPKZIP1_0)
        
        XCTAssertFalse(ZipCompressionMethod.deflate.isPKZIP1_0)
        XCTAssertFalse(ZipCompressionMethod.store.isPKZIP1_0)
    }
    
    func testZipCompressionMethodPKZIP2_0Plus() {
        XCTAssertTrue(ZipCompressionMethod.deflate.isPKZIP2_0Plus)
        XCTAssertTrue(ZipCompressionMethod.deflate64.isPKZIP2_0Plus)
        XCTAssertTrue(ZipCompressionMethod.bzip2.isPKZIP2_0Plus)
        XCTAssertTrue(ZipCompressionMethod.lzma.isPKZIP2_0Plus)
        XCTAssertTrue(ZipCompressionMethod.zstd.isPKZIP2_0Plus)
        XCTAssertTrue(ZipCompressionMethod.xz.isPKZIP2_0Plus)
        
        XCTAssertFalse(ZipCompressionMethod.shrink.isPKZIP2_0Plus)
        XCTAssertFalse(ZipCompressionMethod.store.isPKZIP2_0Plus)
    }
    
    func testZipCompressionMethodDisplayName() {
        // All methods should have display names
        let methods: [ZipCompressionMethod] = [
            .store, .shrink, .reduce1, .reduce2, .reduce3, .reduce4,
            .implode, .deflate, .deflate64, .bzip2, .lzma, .zstd, .xz, .unknown
        ]
        
        for method in methods {
            XCTAssertFalse(method.displayName.isEmpty, "Method \(method) should have a display name")
        }
    }
}

