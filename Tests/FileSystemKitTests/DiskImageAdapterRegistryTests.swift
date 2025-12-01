// FileSystemKit Tests
// DiskImageAdapterRegistry Tests

import XCTest
@testable import FileSystemKit
import Foundation

final class DiskImageAdapterRegistryTests: XCTestCase {
    
    func testDiskImageAdapterRegistryFindAdapter() {
        let registry = DiskImageAdapterRegistry.shared
        
        // Test finding adapters by extension
        let dmgAdapter = registry.findAdapter(forExtension: "dmg")
        XCTAssertNotNil(dmgAdapter, "Should find DMG adapter")
        
        let isoAdapter = registry.findAdapter(forExtension: "iso")
        XCTAssertNotNil(isoAdapter, "Should find ISO9660 adapter")
        
        let vhdAdapter = registry.findAdapter(forExtension: "vhd")
        XCTAssertNotNil(vhdAdapter, "Should find VHD adapter")
        
        let imgAdapter = registry.findAdapter(forExtension: "img")
        XCTAssertNotNil(imgAdapter, "Should find IMG adapter")
        
        let unknownAdapter = registry.findAdapter(forExtension: "unknown")
        XCTAssertNil(unknownAdapter, "Should not find adapter for unknown extension")
    }
    
    func testDiskImageAdapterRegistryFindAdapterByURL() {
        let registry = DiskImageAdapterRegistry.shared
        
        // Test finding adapter by extension
        let dmgAdapter = registry.findAdapter(forExtension: "dmg")
        XCTAssertNotNil(dmgAdapter)
        
        let isoAdapter = registry.findAdapter(forExtension: "iso")
        XCTAssertNotNil(isoAdapter)
        
        // Test finding adapter by data (format detection)
        var dmgData = Data(count: 512)
        let kolySignature = Data([0x6B, 0x6F, 0x6C, 0x79]) // "koly"
        dmgData.replaceSubrange(0..<4, with: kolySignature)
        let detectedDMGAdapter = registry.findAdapter(for: dmgData)
        XCTAssertNotNil(detectedDMGAdapter)
    }
}

