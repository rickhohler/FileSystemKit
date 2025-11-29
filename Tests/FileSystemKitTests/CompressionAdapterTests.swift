import XCTest
@testable import FileSystemKit
import Foundation

final class CompressionAdapterTests: XCTestCase {
    var tempDirectory: URL!
    
    override func setUp() {
        super.setUp()
        // Create a temporary directory for test files
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }
    
    override func tearDown() {
        // Clean up temporary directory
        try? FileManager.default.removeItem(at: tempDirectory)
        tempDirectory = nil
        super.tearDown()
    }
    
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
    
    // MARK: - CompressionAdapterRegistry Tests
    
    func testCompressionAdapterRegistrySingleton() {
        let registry1 = CompressionAdapterRegistry.shared
        let registry2 = CompressionAdapterRegistry.shared
        XCTAssertTrue(registry1 === registry2, "Should be the same singleton instance")
    }
    
    func testCompressionAdapterRegistryFindAdapter() {
        let registry = CompressionAdapterRegistry.shared
        
        // Register test adapters
        registry.register(GzipCompressionAdapter.self)
        registry.register(ZipCompressionAdapter.self)
        registry.register(ARCCompressionAdapter.self)
        
        // Find by format
        let gzipAdapter = registry.findAdapter(for: .gzip)
        XCTAssertNotNil(gzipAdapter)
        XCTAssertEqual(gzipAdapter?.format, .gzip)
        
        let zipAdapter = registry.findAdapter(for: .zip)
        XCTAssertNotNil(zipAdapter)
        XCTAssertEqual(zipAdapter?.format, .zip)
        
        let arcAdapter = registry.findAdapter(for: .arc)
        XCTAssertNotNil(arcAdapter)
        XCTAssertEqual(arcAdapter?.format, .arc)
        
        let unknownAdapter = registry.findAdapter(for: .unknown)
        XCTAssertNil(unknownAdapter)
    }
    
    func testCompressionAdapterRegistryFindAdapterByURL() {
        let registry = CompressionAdapterRegistry.shared
        
        // Register test adapters
        registry.register(GzipCompressionAdapter.self)
        registry.register(ZipCompressionAdapter.self)
        
        // Create test URLs
        let gzipURL = tempDirectory.appendingPathComponent("test.gz")
        let zipURL = tempDirectory.appendingPathComponent("test.zip")
        let unknownURL = tempDirectory.appendingPathComponent("test.unknown")
        
        // Find by URL
        let gzipAdapter = registry.findAdapter(for: gzipURL)
        XCTAssertNotNil(gzipAdapter)
        XCTAssertEqual(gzipAdapter?.format, .gzip)
        
        let zipAdapter = registry.findAdapter(for: zipURL)
        XCTAssertNotNil(zipAdapter)
        XCTAssertEqual(zipAdapter?.format, .zip)
        
        let unknownAdapter = registry.findAdapter(for: unknownURL)
        XCTAssertNil(unknownAdapter)
    }
    
    func testCompressionAdapterRegistryAllAdapters() {
        let registry = CompressionAdapterRegistry.shared
        
        // Clear and register test adapters
        registry.clear()
        registry.register(GzipCompressionAdapter.self)
        registry.register(ZipCompressionAdapter.self)
        registry.register(ARCCompressionAdapter.self)
        
        let allAdapters = registry.allAdapters()
        XCTAssertEqual(allAdapters.count, 3)
        // Check that adapters are registered (can't use === with protocol types)
        let adapterTypes = allAdapters.map { String(describing: $0) }
        XCTAssertTrue(adapterTypes.contains { $0.contains("GzipCompressionAdapter") })
        XCTAssertTrue(adapterTypes.contains { $0.contains("ZipCompressionAdapter") })
        XCTAssertTrue(adapterTypes.contains { $0.contains("ARCCompressionAdapter") })
    }
    
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
    
    // MARK: - Integration Tests
    
    func testCompressionAdapterRegistryIntegration() {
        let registry = CompressionAdapterRegistry.shared
        registry.clear()
        
        // Register all adapters
        registry.register(GzipCompressionAdapter.self)
        registry.register(ZipCompressionAdapter.self)
        registry.register(ARCCompressionAdapter.self)
        registry.register(ToastCompressionAdapter.self)
        registry.register(StuffItCompressionAdapter.self)
        registry.register(TarCompressionAdapter.self)
        
        // Test finding each adapter
        let testURLs: [(URL, CompressionAdapter.Type)] = [
            (tempDirectory.appendingPathComponent("test.gz"), GzipCompressionAdapter.self),
            (tempDirectory.appendingPathComponent("test.zip"), ZipCompressionAdapter.self),
            (tempDirectory.appendingPathComponent("test.arc"), ARCCompressionAdapter.self),
            (tempDirectory.appendingPathComponent("test.toast"), ToastCompressionAdapter.self),
            (tempDirectory.appendingPathComponent("test.sit"), StuffItCompressionAdapter.self),
            (tempDirectory.appendingPathComponent("test.tar"), TarCompressionAdapter.self)
        ]
        
        for (url, expectedAdapter) in testURLs {
            let foundAdapter = registry.findAdapter(for: url)
            XCTAssertNotNil(foundAdapter, "Should find adapter for \(url.lastPathComponent)")
            // Check that the found adapter matches the expected type
            let foundType = String(describing: foundAdapter!)
            let expectedType = String(describing: expectedAdapter)
            XCTAssertTrue(foundType.contains(expectedType.components(separatedBy: ".").last ?? ""), 
                         "Should find correct adapter for \(url.lastPathComponent)")
        }
    }
}

