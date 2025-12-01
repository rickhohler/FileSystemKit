// FileSystemKit Tests
// RawDiskData Operations Unit Tests

import XCTest
@testable import FileSystemKit

final class RawDiskDataOperationsTests: XCTestCase {
    
    // MARK: - RawDiskData Initialization Tests
    
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
    
    // MARK: - RawDiskData Read Operations Tests
    
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
    
    // MARK: - RawDiskData Hash Generation Tests
    
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

