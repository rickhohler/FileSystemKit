// FileSystemKit Tests
// SnugConfig Validation Unit Tests

import XCTest
@testable import FileSystemKit
import Foundation

final class SnugConfigValidationTests: SnugConfigTestBase {
    
    // MARK: - Configuration Validation Tests
    
    func testValidateConfigurationWithRequiredStorageMissing() throws {
        let config = SnugConfig(
            storageLocations: [
                StorageLocation(
                    path: "/nonexistent/path",
                    label: "required-primary",
                    required: true,
                    priority: 0,
                    volumeType: .primary
                )
            ],
            enableMirroring: false,
            failIfPrimaryUnavailable: true
        )
        
        let validation = try SnugConfigManager.validateConfiguration(config)
        
        XCTAssertFalse(validation.isValid)
        XCTAssertTrue(validation.issues.contains { issue in
            if case .requiredStorageMissing(let path, _) = issue {
                return path == "/nonexistent/path"
            }
            return false
        })
    }
    
    func testValidateConfigurationWithOptionalStorageMissing() throws {
        let config = SnugConfig(
            storageLocations: [
                StorageLocation(
                    path: "/nonexistent/path",
                    label: "optional-secondary",
                    required: false,
                    priority: 100,
                    volumeType: .secondary
                )
            ],
            enableMirroring: false,
            failIfPrimaryUnavailable: false
        )
        
        let validation = try SnugConfigManager.validateConfiguration(config)
        
        // Should be valid (optional storage missing is OK)
        XCTAssertTrue(validation.isValid)
        // But should have warnings
        XCTAssertFalse(validation.warnings.isEmpty)
    }
    
    func testValidateConfigurationWithValidStorage() throws {
        let validDir = tempConfigDir.appendingPathComponent("valid")
        try FileManager.default.createDirectory(at: validDir, withIntermediateDirectories: true)
        
        let config = SnugConfig(
            storageLocations: [
                StorageLocation(
                    path: validDir.path,
                    label: "valid-primary",
                    required: true,
                    priority: 0,
                    volumeType: .primary
                )
            ],
            enableMirroring: false,
            failIfPrimaryUnavailable: true
        )
        
        let validation = try SnugConfigManager.validateConfiguration(config)
        
        XCTAssertTrue(validation.isValid)
        XCTAssertTrue(validation.issues.isEmpty)
    }
}

