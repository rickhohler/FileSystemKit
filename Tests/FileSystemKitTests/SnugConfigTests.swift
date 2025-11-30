// FileSystemKit Tests
// Unit tests for SNUG Configuration: volume types, glacier mirroring, storage management

import XCTest
@testable import FileSystemKit
import Foundation
import Yams

final class SnugConfigTests: XCTestCase {
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
    
    // MARK: - StorageVolumeType Tests
    
    func testStorageVolumeTypeEnum() {
        XCTAssertEqual(StorageVolumeType.primary.rawValue, "primary")
        XCTAssertEqual(StorageVolumeType.secondary.rawValue, "secondary")
        XCTAssertEqual(StorageVolumeType.glacier.rawValue, "glacier")
        XCTAssertEqual(StorageVolumeType.mirror.rawValue, "mirror")
    }
    
    func testStorageVolumeTypeDefaultPriority() {
        XCTAssertEqual(StorageVolumeType.primary.defaultPriority, 0)
        XCTAssertEqual(StorageVolumeType.secondary.defaultPriority, 100)
        XCTAssertEqual(StorageVolumeType.glacier.defaultPriority, 200)
        XCTAssertEqual(StorageVolumeType.mirror.defaultPriority, 150)
    }
    
    func testStorageVolumeTypeComparable() {
        XCTAssertTrue(StorageVolumeType.primary.defaultPriority < StorageVolumeType.secondary.defaultPriority)
        XCTAssertTrue(StorageVolumeType.secondary.defaultPriority < StorageVolumeType.mirror.defaultPriority)
        XCTAssertTrue(StorageVolumeType.mirror.defaultPriority < StorageVolumeType.glacier.defaultPriority)
    }
    
    // MARK: - StorageLocation with VolumeType Tests
    
    func testStorageLocationWithVolumeType() {
        let location = StorageLocation(
            path: "/test/path",
            label: "test-label",
            required: true,
            priority: 10,
            speed: .fast,
            volumeType: .glacier
        )
        
        XCTAssertEqual(location.path, "/test/path")
        XCTAssertEqual(location.label, "test-label")
        XCTAssertTrue(location.required)
        XCTAssertEqual(location.priority, 10)
        XCTAssertEqual(location.speed, .fast)
        XCTAssertEqual(location.volumeType, .glacier)
    }
    
    func testStorageLocationUsesDefaultPriorityFromVolumeType() {
        let location1 = StorageLocation(
            path: "/primary",
            volumeType: .primary
        )
        XCTAssertEqual(location1.priority, 0)
        
        let location2 = StorageLocation(
            path: "/glacier",
            volumeType: .glacier
        )
        XCTAssertEqual(location2.priority, 200)
        
        let location3 = StorageLocation(
            path: "/secondary",
            priority: 50, // Explicit priority overrides default
            volumeType: .secondary
        )
        XCTAssertEqual(location3.priority, 50) // Explicit takes precedence
    }
    
    // MARK: - SnugConfig with Volume Types Tests
    
    func testSnugConfigWithVolumeTypes() throws {
        let config = SnugConfig(
            storageLocations: [
                StorageLocation(
                    path: "/primary/storage",
                    label: "primary",
                    required: true,
                    priority: 0,
                    volumeType: .primary
                ),
                StorageLocation(
                    path: "/secondary/storage",
                    label: "secondary",
                    required: false,
                    priority: 100,
                    volumeType: .secondary
                ),
                StorageLocation(
                    path: "/glacier/storage",
                    label: "glacier-backup",
                    required: false,
                    priority: 200,
                    volumeType: .glacier
                ),
                StorageLocation(
                    path: "/mirror/storage",
                    label: "mirror",
                    required: false,
                    priority: 150,
                    volumeType: .mirror
                )
            ],
            enableMirroring: false,
            failIfPrimaryUnavailable: true
        )
        
        XCTAssertEqual(config.storageLocations.count, 4)
        
        let primary = config.storageLocations.first { $0.volumeType == .primary }
        XCTAssertNotNil(primary)
        XCTAssertEqual(primary?.label, "primary")
        
        let glacier = config.storageLocations.first { $0.volumeType == .glacier }
        XCTAssertNotNil(glacier)
        XCTAssertEqual(glacier?.label, "glacier-backup")
    }
    
    func testSnugConfigCodableWithVolumeTypes() throws {
        let config = SnugConfig(
            storageLocations: [
                StorageLocation(
                    path: "/test/primary",
                    label: "primary",
                    volumeType: .primary
                ),
                StorageLocation(
                    path: "/test/glacier",
                    label: "glacier",
                    volumeType: .glacier
                )
            ],
            enableMirroring: false,
            failIfPrimaryUnavailable: true
        )
        
        // Encode to YAML
        let encoder = YAMLEncoder()
        let yamlString = try encoder.encode(config)
        XCTAssertFalse(yamlString.isEmpty)
        
        // Decode from YAML
        let decoder = YAMLDecoder()
        let decodedConfig = try decoder.decode(SnugConfig.self, from: yamlString)
        
        XCTAssertEqual(decodedConfig.storageLocations.count, 2)
        XCTAssertEqual(decodedConfig.storageLocations[0].volumeType, .primary)
        XCTAssertEqual(decodedConfig.storageLocations[1].volumeType, .glacier)
    }
    
    // MARK: - SnugConfigManager Volume Type Tests
    
    func testGetAvailableStorageLocationsFiltersByVolumeType() throws {
        // Create test directories
        let primaryDir = tempConfigDir.appendingPathComponent("primary")
        let glacierDir = tempConfigDir.appendingPathComponent("glacier")
        let unavailableDir = tempConfigDir.appendingPathComponent("unavailable")
        
        try FileManager.default.createDirectory(at: primaryDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: glacierDir, withIntermediateDirectories: true)
        // unavailableDir doesn't exist
        
        let config = SnugConfig(
            storageLocations: [
                StorageLocation(
                    path: primaryDir.path,
                    label: "primary",
                    required: true,
                    priority: 0,
                    volumeType: .primary
                ),
                StorageLocation(
                    path: glacierDir.path,
                    label: "glacier",
                    required: false,
                    priority: 200,
                    volumeType: .glacier
                ),
                StorageLocation(
                    path: unavailableDir.path,
                    label: "unavailable",
                    required: false,
                    priority: 100,
                    volumeType: .secondary
                )
            ],
            enableMirroring: false,
            failIfPrimaryUnavailable: true
        )
        
        let available = try SnugConfigManager.getAvailableStorageLocations(from: config)
        
        // Should only return available locations
        XCTAssertEqual(available.count, 2)
        XCTAssertTrue(available.contains { $0.volumeType == .primary })
        XCTAssertTrue(available.contains { $0.volumeType == .glacier })
        XCTAssertFalse(available.contains { $0.path == unavailableDir.path })
    }
    
    func testGetAvailableStorageLocationsSortsByPriority() throws {
        let dir1 = tempConfigDir.appendingPathComponent("dir1")
        let dir2 = tempConfigDir.appendingPathComponent("dir2")
        let dir3 = tempConfigDir.appendingPathComponent("dir3")
        
        try FileManager.default.createDirectory(at: dir1, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: dir2, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: dir3, withIntermediateDirectories: true)
        
        let config = SnugConfig(
            storageLocations: [
                StorageLocation(
                    path: dir3.path,
                    label: "low-priority",
                    priority: 200,
                    volumeType: .glacier
                ),
                StorageLocation(
                    path: dir1.path,
                    label: "high-priority",
                    priority: 0,
                    volumeType: .primary
                ),
                StorageLocation(
                    path: dir2.path,
                    label: "medium-priority",
                    priority: 100,
                    volumeType: .secondary
                )
            ],
            enableMirroring: false,
            failIfPrimaryUnavailable: true
        )
        
        let available = try SnugConfigManager.getAvailableStorageLocations(from: config)
        
        XCTAssertEqual(available.count, 3)
        XCTAssertEqual(available[0].priority, 0) // Primary first
        XCTAssertEqual(available[1].priority, 100) // Secondary second
        XCTAssertEqual(available[2].priority, 200) // Glacier last
    }
    
    func testGetPrimaryStorageLocationReturnsPrimaryVolumeType() throws {
        let primaryDir = tempConfigDir.appendingPathComponent("primary")
        let secondaryDir = tempConfigDir.appendingPathComponent("secondary")
        
        try FileManager.default.createDirectory(at: primaryDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: secondaryDir, withIntermediateDirectories: true)
        
        let config = SnugConfig(
            storageLocations: [
                StorageLocation(
                    path: secondaryDir.path,
                    label: "secondary",
                    priority: 100,
                    volumeType: .secondary
                ),
                StorageLocation(
                    path: primaryDir.path,
                    label: "primary",
                    priority: 0,
                    volumeType: .primary
                )
            ],
            enableMirroring: false,
            failIfPrimaryUnavailable: true
        )
        
        let primary = try SnugConfigManager.getPrimaryStorageLocation(from: config)
        XCTAssertEqual(primary.volumeType, .primary)
        XCTAssertEqual(primary.path, primaryDir.path)
    }
    
    func testGetAllStorageLocationsSeparatesByAvailability() throws {
        let availableDir = tempConfigDir.appendingPathComponent("available")
        let unavailableDir = tempConfigDir.appendingPathComponent("unavailable")
        
        try FileManager.default.createDirectory(at: availableDir, withIntermediateDirectories: true)
        // unavailableDir doesn't exist
        
        let config = SnugConfig(
            storageLocations: [
                StorageLocation(
                    path: availableDir.path,
                    label: "available",
                    priority: 0,
                    volumeType: .primary
                ),
                StorageLocation(
                    path: unavailableDir.path,
                    label: "unavailable",
                    priority: 100,
                    volumeType: .secondary
                )
            ],
            enableMirroring: false,
            failIfPrimaryUnavailable: true
        )
        
        let (available, unavailable) = try SnugConfigManager.getAllStorageLocations(from: config)
        
        XCTAssertEqual(available.count, 1)
        XCTAssertEqual(available[0].path, availableDir.path)
        
        XCTAssertEqual(unavailable.count, 1)
        XCTAssertEqual(unavailable[0].path, unavailableDir.path)
    }
    
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

