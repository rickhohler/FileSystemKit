// FileSystemKit Tests
// Individual CompressionAdapter Unit Tests

import XCTest
@testable import FileSystemKit
import Foundation

final class CompressionAdapterIndividualTests: CompressionAdapterTestBase {
    
    // MARK: - GzipCompressionAdapter Tests
    
    func testGzipCompressionAdapterFormat() {
        XCTAssertEqual(GzipCompressionAdapter.format, .gzip)
    }
    
    func testGzipCompressionAdapterSupportedExtensions() {
        let extensions = GzipCompressionAdapter.supportedExtensions
        XCTAssertTrue(extensions.contains(".gz"))
        XCTAssertTrue(extensions.contains(".gzip"))
    }
    
    func testGzipCompressionAdapterCanHandle() {
        let gzURL = tempDirectory.appendingPathComponent("test.gz")
        let gzipURL = tempDirectory.appendingPathComponent("test.gzip")
        let zipURL = tempDirectory.appendingPathComponent("test.zip")
        
        XCTAssertTrue(GzipCompressionAdapter.canHandle(url: gzURL))
        XCTAssertTrue(GzipCompressionAdapter.canHandle(url: gzipURL))
        XCTAssertFalse(GzipCompressionAdapter.canHandle(url: zipURL))
    }
    
    func testGzipCompressionAdapterIsCompressed() {
        let gzURL = tempDirectory.appendingPathComponent("test.gz")
        let txtURL = tempDirectory.appendingPathComponent("test.txt")
        
        XCTAssertTrue(GzipCompressionAdapter.isCompressed(url: gzURL))
        XCTAssertFalse(GzipCompressionAdapter.isCompressed(url: txtURL))
    }
    
    // MARK: - ZipCompressionAdapter Tests
    
    func testZipCompressionAdapterFormat() {
        XCTAssertEqual(ZipCompressionAdapter.format, .zip)
    }
    
    func testZipCompressionAdapterSupportedExtensions() {
        let extensions = ZipCompressionAdapter.supportedExtensions
        XCTAssertTrue(extensions.contains(".zip"))
    }
    
    func testZipCompressionAdapterCanHandle() {
        let zipURL = tempDirectory.appendingPathComponent("test.zip")
        let gzURL = tempDirectory.appendingPathComponent("test.gz")
        
        XCTAssertTrue(ZipCompressionAdapter.canHandle(url: zipURL))
        XCTAssertFalse(ZipCompressionAdapter.canHandle(url: gzURL))
    }
    
    func testZipCompressionAdapterIsCompressed() {
        let zipURL = tempDirectory.appendingPathComponent("test.zip")
        let txtURL = tempDirectory.appendingPathComponent("test.txt")
        
        XCTAssertTrue(ZipCompressionAdapter.isCompressed(url: zipURL))
        XCTAssertFalse(ZipCompressionAdapter.isCompressed(url: txtURL))
    }
    
    // MARK: - ARCCompressionAdapter Tests
    
    func testARCCompressionAdapterFormat() {
        XCTAssertEqual(ARCCompressionAdapter.format, .arc)
    }
    
    func testARCCompressionAdapterSupportedExtensions() {
        let extensions = ARCCompressionAdapter.supportedExtensions
        XCTAssertTrue(extensions.contains(".arc"))
        XCTAssertTrue(extensions.contains(".ark"))
    }
    
    func testARCCompressionAdapterCanHandle() {
        let arcURL = tempDirectory.appendingPathComponent("test.arc")
        let arkURL = tempDirectory.appendingPathComponent("test.ark")
        let zipURL = tempDirectory.appendingPathComponent("test.zip")
        
        XCTAssertTrue(ARCCompressionAdapter.canHandle(url: arcURL))
        XCTAssertTrue(ARCCompressionAdapter.canHandle(url: arkURL))
        XCTAssertFalse(ARCCompressionAdapter.canHandle(url: zipURL))
    }
    
    func testARCCompressionAdapterIsCompressed() {
        let arcURL = tempDirectory.appendingPathComponent("test.arc")
        let txtURL = tempDirectory.appendingPathComponent("test.txt")
        
        XCTAssertTrue(ARCCompressionAdapter.isCompressed(url: arcURL))
        XCTAssertFalse(ARCCompressionAdapter.isCompressed(url: txtURL))
    }
    
    // MARK: - ToastCompressionAdapter Tests
    
    func testToastCompressionAdapterFormat() {
        XCTAssertEqual(ToastCompressionAdapter.format, .toast)
    }
    
    func testToastCompressionAdapterCanHandle() {
        let toastURL = tempDirectory.appendingPathComponent("test.toast")
        let zipURL = tempDirectory.appendingPathComponent("test.zip")
        
        XCTAssertTrue(ToastCompressionAdapter.canHandle(url: toastURL))
        XCTAssertFalse(ToastCompressionAdapter.canHandle(url: zipURL))
    }
    
    // MARK: - StuffItCompressionAdapter Tests
    
    func testStuffItCompressionAdapterFormat() {
        XCTAssertEqual(StuffItCompressionAdapter.format, .stuffit)
    }
    
    func testStuffItCompressionAdapterSupportedExtensions() {
        let extensions = StuffItCompressionAdapter.supportedExtensions
        XCTAssertTrue(extensions.contains(".sit"))
        XCTAssertTrue(extensions.contains(".sitx"))
    }
    
    func testStuffItCompressionAdapterCanHandle() {
        let sitURL = tempDirectory.appendingPathComponent("test.sit")
        let sitxURL = tempDirectory.appendingPathComponent("test.sitx")
        let zipURL = tempDirectory.appendingPathComponent("test.zip")
        
        XCTAssertTrue(StuffItCompressionAdapter.canHandle(url: sitURL))
        XCTAssertTrue(StuffItCompressionAdapter.canHandle(url: sitxURL))
        XCTAssertFalse(StuffItCompressionAdapter.canHandle(url: zipURL))
    }
    
    // MARK: - TarCompressionAdapter Tests
    
    func testTarCompressionAdapterFormat() {
        XCTAssertEqual(TarCompressionAdapter.format, .tar)
    }
    
    func testTarCompressionAdapterCanHandle() {
        let tarURL = tempDirectory.appendingPathComponent("test.tar")
        let zipURL = tempDirectory.appendingPathComponent("test.zip")
        
        XCTAssertTrue(TarCompressionAdapter.canHandle(url: tarURL))
        XCTAssertFalse(TarCompressionAdapter.canHandle(url: zipURL))
    }
}

