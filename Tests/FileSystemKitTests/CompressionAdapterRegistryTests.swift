// FileSystemKit Tests
// CompressionAdapterRegistry Unit Tests

import XCTest
@testable import FileSystemKit
import Foundation

final class CompressionAdapterRegistryTests: CompressionAdapterTestBase {
    
    // MARK: - Registry Singleton Tests
    
    func testCompressionAdapterRegistrySingleton() {
        let registry1 = CompressionAdapterRegistry.shared
        let registry2 = CompressionAdapterRegistry.shared
        XCTAssertTrue(registry1 === registry2, "Should be the same singleton instance")
    }
    
    // MARK: - Find Adapter Tests
    
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
    
    // MARK: - All Adapters Tests
    
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
}

