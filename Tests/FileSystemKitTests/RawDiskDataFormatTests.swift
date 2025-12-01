// FileSystemKit Tests
// RawDiskData Format-Related Unit Tests

import XCTest
@testable import FileSystemKit

final class RawDiskDataFormatTests: XCTestCase {
    
    // MARK: - DiskImageHash Tests
    
    func testDiskImageHash() {
        let data = Data([0x01, 0x02, 0x03])
        let hash = DiskImageHash(algorithm: .sha256, value: data)
        
        XCTAssertEqual(hash.algorithm, .sha256)
        XCTAssertEqual(hash.value, data)
        XCTAssertFalse(hash.hexString.isEmpty)
        XCTAssertTrue(hash.identifier.hasPrefix("sha256:"))
    }
    
    func testDiskImageHashEquality() {
        let data = Data([0x01, 0x02, 0x03])
        let hash1 = DiskImageHash(algorithm: .sha256, value: data)
        let hash2 = DiskImageHash(algorithm: .sha256, value: data)
        let hash3 = DiskImageHash(algorithm: .sha256, value: Data([0x04, 0x05, 0x06]))
        
        XCTAssertEqual(hash1, hash2)
        XCTAssertNotEqual(hash1, hash3)
    }
    
    // MARK: - DiskGeometry Tests
    
    func testDiskGeometry() {
        let geometry = DiskGeometry(
            tracks: 35,
            sides: 1,
            sectorsPerTrack: 16,
            sectorSize: 256
        )
        
        XCTAssertEqual(geometry.tracks, 35)
        XCTAssertEqual(geometry.sides, 1)
        XCTAssertEqual(geometry.sectorsPerTrack, 16)
        XCTAssertEqual(geometry.sectorSize, 256)
        XCTAssertEqual(geometry.totalCapacity, 35 * 1 * 16 * 256)
    }
    
    func testDiskGeometryDoubleSided() {
        let geometry = DiskGeometry(
            tracks: 40,
            sides: 2,
            sectorsPerTrack: 18,
            sectorSize: 512
        )
        
        XCTAssertEqual(geometry.sides, 2)
        XCTAssertEqual(geometry.totalCapacity, 40 * 2 * 18 * 512)
    }
    
    // MARK: - CopyProtectionInfo Tests
    
    func testCopyProtectionInfo() {
        let info = CopyProtectionInfo(
            type: .weakBits,
            characteristics: ["track 0", "sector 1"]
        )
        
        XCTAssertEqual(info.type, .weakBits)
        XCTAssertEqual(info.characteristics.count, 2)
    }
    
    // MARK: - DiskImageMetadata Tests
    
    func testDiskImageMetadata() {
        let metadata = DiskImageMetadata(
            title: "Test Disk",
            publisher: "Test Publisher",
            version: "1.0"
        )
        
        XCTAssertEqual(metadata.title, "Test Disk")
        XCTAssertEqual(metadata.publisher, "Test Publisher")
        XCTAssertEqual(metadata.version, "1.0")
        XCTAssertTrue(metadata.tags.isEmpty, "Tags should default to empty array")
    }
    
    func testDiskImageMetadataWithGeometry() {
        let geometry = DiskGeometry(tracks: 35, sectorsPerTrack: 16, sectorSize: 256)
        let metadata = DiskImageMetadata(
            title: "Test",
            geometry: geometry
        )
        
        XCTAssertNotNil(metadata.geometry)
        XCTAssertEqual(metadata.geometry?.tracks, 35)
        XCTAssertTrue(metadata.tags.isEmpty, "Tags should default to empty array")
    }
    
    func testDiskImageMetadataWithTags() {
        let tags = ["dsk", "apple-ii", "floppy-disk"]
        let metadata = DiskImageMetadata(
            title: "Test Disk",
            tags: tags
        )
        
        XCTAssertEqual(metadata.tags, tags)
        XCTAssertEqual(metadata.tags.count, 3)
        XCTAssertTrue(metadata.tags.contains("dsk"))
        XCTAssertTrue(metadata.tags.contains("apple-ii"))
        XCTAssertTrue(metadata.tags.contains("floppy-disk"))
    }
    
    func testDiskImageMetadataTagsDefaultEmpty() {
        let metadata = DiskImageMetadata()
        XCTAssertTrue(metadata.tags.isEmpty, "Tags should default to empty array")
    }
}

