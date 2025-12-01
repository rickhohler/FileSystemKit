// FileSystemKit Tests
// SnugConfig Basic Types Unit Tests

import XCTest
@testable import FileSystemKit
import Foundation
import Yams

final class SnugConfigBasicTests: SnugConfigTestBase {
    
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
}

