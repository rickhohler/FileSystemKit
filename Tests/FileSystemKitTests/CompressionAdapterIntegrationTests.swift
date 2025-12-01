// FileSystemKit Tests
// CompressionAdapter Integration Tests

import XCTest
@testable import FileSystemKit
import Foundation

final class CompressionAdapterIntegrationTests: CompressionAdapterTestBase {
    
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

