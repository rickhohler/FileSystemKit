// FileSystemKit Tests
// SnugConfig Test Base

import XCTest
@testable import FileSystemKit
import Foundation

class SnugConfigTestBase: XCTestCase {
    var tempConfigDir: URL!
    var originalConfigPath: URL!
    
    override func setUp() {
        super.setUp()
        tempConfigDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("snug-config-test-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempConfigDir, withIntermediateDirectories: true)
        
        // Save original config path and override for testing
        originalConfigPath = SnugConfigManager.configFilePath()
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: tempConfigDir)
        tempConfigDir = nil
        super.tearDown()
    }
}

