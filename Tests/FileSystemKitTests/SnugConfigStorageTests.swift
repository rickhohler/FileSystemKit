// FileSystemKit Tests
// SnugConfig Storage Location Management Unit Tests

import XCTest
@testable import FileSystemKit
import Foundation

final class SnugConfigStorageTests: SnugConfigTestBase {
    
    // MARK: - Get Available Storage Locations Tests
    
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
    
    // MARK: - Get Primary Storage Location Tests
    
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
    
    // MARK: - Get All Storage Locations Tests
    
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
}

