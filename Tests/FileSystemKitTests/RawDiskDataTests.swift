// FileSystemKit Tests
// Unit tests for RawDiskData and related structures

import XCTest
@testable import FileSystemKit

final class RawDiskDataTests: XCTestCase {
    
    // MARK: - SectorData Tests
    
    func testSectorDataInitialization() {
        let data = Data([0x01, 0x02, 0x03, 0x04])
        let sector = SectorData(track: 0, sector: 1, data: data)
        
        XCTAssertEqual(sector.track, 0)
        XCTAssertEqual(sector.sector, 1)
        XCTAssertEqual(sector.data, data)
        XCTAssertEqual(sector.size, 4)
        XCTAssertNil(sector.flags)
    }
    
    func testSectorDataWithFlags() {
        let data = Data([0x01, 0x02])
        let flags = SectorFlags.deleted
        let sector = SectorData(track: 1, sector: 2, data: data, flags: flags)
        
        XCTAssertEqual(sector.track, 1)
        XCTAssertEqual(sector.sector, 2)
        XCTAssertEqual(sector.flags, flags)
    }
    
    func testSectorFlags() {
        let deleted = SectorFlags.deleted
        let weak = SectorFlags.weak
        let damaged = SectorFlags.damaged
        
        XCTAssertTrue(deleted.contains(.deleted))
        XCTAssertTrue(weak.contains(.weak))
        XCTAssertTrue(damaged.contains(.damaged))
        
        let combined = [deleted, weak]
        let combinedFlags = combined.reduce(SectorFlags()) { $0.union($1) }
        XCTAssertTrue(combinedFlags.contains(.deleted))
        XCTAssertTrue(combinedFlags.contains(.weak))
    }
    
    // MARK: - TrackData Tests
    
    func testTrackDataInitialization() {
        let sectors = [
            SectorData(track: 0, sector: 0, data: Data([0x01])),
            SectorData(track: 0, sector: 1, data: Data([0x02]))
        ]
        let track = TrackData(track: 0, sectors: sectors)
        
        XCTAssertEqual(track.track, 0)
        XCTAssertEqual(track.side, 0)
        XCTAssertEqual(track.sectors.count, 2)
        XCTAssertNil(track.encoding)
        XCTAssertNil(track.density)
    }
    
    func testTrackDataWithEncoding() {
        let sectors = [SectorData(track: 0, sector: 0, data: Data([0x01]))]
        let track = TrackData(
            track: 1,
            side: 0,
            sectors: sectors,
            encoding: .gcr,
            density: .double
        )
        
        XCTAssertEqual(track.track, 1)
        XCTAssertEqual(track.encoding, .gcr)
        XCTAssertEqual(track.density, .double)
    }
    
    // MARK: - FluxTrack Tests
    
    func testFluxTrackInitialization() {
        let fluxTransitions: [UInt32] = [100, 200, 300]
        let indexSignals: [UInt32] = [0, 50000]
        let track = FluxTrack(
            location: 0,
            fluxTransitions: fluxTransitions,
            indexSignals: indexSignals
        )
        
        XCTAssertEqual(track.location, 0)
        XCTAssertEqual(track.fluxTransitions, fluxTransitions)
        XCTAssertEqual(track.indexSignals, indexSignals)
        XCTAssertNil(track.mirrorDistance)
    }
    
    func testFluxTrackWithMirrorDistance() {
        let mirrorDistance = MirrorDistance(outward: 5, inward: 3)
        let track = FluxTrack(
            location: 1,
            fluxTransitions: [100, 200],
            mirrorDistance: mirrorDistance
        )
        
        XCTAssertNotNil(track.mirrorDistance)
        XCTAssertEqual(track.mirrorDistance?.outward, 5)
        XCTAssertEqual(track.mirrorDistance?.inward, 3)
    }
    
    // MARK: - FluxData Tests
    
    func testFluxDataInitialization() {
        let tracks = [
            FluxTrack(location: 0, fluxTransitions: [100, 200]),
            FluxTrack(location: 1, fluxTransitions: [150, 250])
        ]
        let fluxData = FluxData(
            tracks: tracks,
            resolution: 62500,
            captureType: .timing
        )
        
        XCTAssertEqual(fluxData.tracks.count, 2)
        XCTAssertEqual(fluxData.resolution, 62500)
        XCTAssertEqual(fluxData.captureType, .timing)
        XCTAssertNil(fluxData.indexSignals)
    }
    
    func testFluxDataWithIndexSignals() {
        let tracks = [FluxTrack(location: 0, fluxTransitions: [100])]
        let indexSignals: [UInt32] = [0, 50000, 100000]
        let fluxData = FluxData(
            tracks: tracks,
            resolution: 62500,
            indexSignals: indexSignals,
            captureType: .xtiming
        )
        
        XCTAssertEqual(fluxData.indexSignals, indexSignals)
        XCTAssertEqual(fluxData.captureType, .xtiming)
    }
    
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
    
    // MARK: - RawDiskData Tests
    
    func testRawDiskDataInitialization() {
        let rawData = Data([0x01, 0x02, 0x03, 0x04])
        let diskData = RawDiskData(rawData: rawData)
        
        XCTAssertEqual(diskData.totalSize, 4)
        XCTAssertNil(diskData.sectors)
        XCTAssertNil(diskData.tracks)
        XCTAssertNil(diskData.fluxData)
        XCTAssertNil(diskData.metadata)
        XCTAssertNil(diskData.hash)
    }
    
    func testRawDiskDataWithSectors() {
        let rawData = Data([0x01, 0x02])
        let sectors = [
            SectorData(track: 0, sector: 0, data: Data([0x01])),
            SectorData(track: 0, sector: 1, data: Data([0x02]))
        ]
        let diskData = RawDiskData(sectors: sectors, rawData: rawData)
        
        XCTAssertNotNil(diskData.sectors)
        XCTAssertEqual(diskData.sectors?.count, 2)
    }
    
    func testRawDiskDataWithTracks() {
        let rawData = Data([0x01, 0x02])
        let sectors = [SectorData(track: 0, sector: 0, data: Data([0x01]))]
        let tracks = [TrackData(track: 0, sectors: sectors)]
        let diskData = RawDiskData(tracks: tracks, rawData: rawData)
        
        XCTAssertNotNil(diskData.tracks)
        XCTAssertEqual(diskData.tracks?.count, 1)
    }
    
    func testRawDiskDataWithFluxData() {
        let rawData = Data([0x01, 0x02])
        let fluxTracks = [FluxTrack(location: 0, fluxTransitions: [100, 200])]
        let fluxData = FluxData(tracks: fluxTracks, resolution: 62500)
        let diskData = RawDiskData(fluxData: fluxData, rawData: rawData)
        
        XCTAssertNotNil(diskData.fluxData)
        XCTAssertEqual(diskData.fluxData?.tracks.count, 1)
    }
    
    func testRawDiskDataReadData() throws {
        let rawData = Data([0x01, 0x02, 0x03, 0x04, 0x05])
        let diskData = RawDiskData(rawData: rawData)
        
        let readData = try diskData.readData(at: 1, length: 3)
        XCTAssertEqual(readData, Data([0x02, 0x03, 0x04]))
    }
    
    func testRawDiskDataReadDataInvalidOffset() {
        let rawData = Data([0x01, 0x02])
        let diskData = RawDiskData(rawData: rawData)
        
        XCTAssertThrowsError(try diskData.readData(at: 10, length: 5)) { error in
            if let fsError = error as? FileSystemError {
                if case .invalidOffset = fsError {
                    // Expected error case
                } else {
                    XCTFail("Expected invalidOffset error, got \(fsError)")
                }
            } else {
                XCTFail("Expected FileSystemError, got \(error)")
            }
        }
    }
    
    func testRawDiskDataGenerateHash() throws {
        let testData = Data("Hello, World!".utf8)
        let diskData = RawDiskData(rawData: testData)
        
        let hash = try diskData.generateHash(algorithm: .sha256)
        
        XCTAssertEqual(hash.algorithm, .sha256)
        XCTAssertEqual(hash.value.count, 32) // SHA-256 produces 32 bytes
        XCTAssertFalse(hash.hexString.isEmpty)
        XCTAssertTrue(hash.identifier.hasPrefix("sha256:"))
        
        // Hash should be cached
        let hash2 = try diskData.generateHash(algorithm: .sha256)
        XCTAssertEqual(hash, hash2)
    }
    
    func testRawDiskDataHashDifferentAlgorithms() throws {
        let testData = Data("Test Data".utf8)
        let diskData = RawDiskData(rawData: testData)
        
        let sha256Hash = try diskData.generateHash(algorithm: .sha256)
        let sha1Hash = try diskData.generateHash(algorithm: .sha1)
        
        XCTAssertNotEqual(sha256Hash, sha1Hash)
        XCTAssertEqual(sha256Hash.algorithm, .sha256)
        XCTAssertEqual(sha1Hash.algorithm, .sha1)
    }
}

