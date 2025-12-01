// FileSystemKit Tests
// RawDiskData Basic Structure Unit Tests

import XCTest
@testable import FileSystemKit

final class RawDiskDataBasicTests: XCTestCase {
    
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
}

