// FileSystemKit Tests
// Raw Disk Image Adapter Tests

import XCTest
@testable import FileSystemKit
import Foundation

final class RawDiskImageAdapterTests: DiskImageAdapterTestBase {
    
    func testRawDiskImageAdapterFormat() {
        XCTAssertEqual(RawDiskImageAdapter.format, .raw)
    }
    
    func testRawDiskImageAdapterCanRead() {
        // Raw adapter requires data between 64KB and 10GB
        let minSize = 64 * 1024 // 64KB minimum
        let validData = Data(count: minSize)
        XCTAssertTrue(RawDiskImageAdapter.canRead(data: validData))
        
        // Test with too small data (should fail)
        let tooSmallData = Data(count: 512)
        XCTAssertFalse(RawDiskImageAdapter.canRead(data: tooSmallData))
        
        // Test with too large data (should fail)
        let tooLargeData = Data(count: 11 * 1024 * 1024 * 1024) // 11GB, exceeds 10GB limit
        XCTAssertFalse(RawDiskImageAdapter.canRead(data: tooLargeData))
    }
    
    func testRawDiskImageAdapterRead() async throws {
        let mockStorage = MockChunkStorage()
        let identifier = ChunkIdentifier(id: "test-raw")
        
        // Create test data (simulating a raw sector dump)
        let testData = Data(count: 143360) // 35 tracks * 16 sectors * 256 bytes (typical Apple II disk)
        _ = try await mockStorage.writeChunk(testData, identifier: identifier, metadata: nil)
        
        let diskData = try await RawDiskImageAdapter.read(chunkStorage: mockStorage, identifier: identifier)
        XCTAssertNotNil(diskData)
        XCTAssertEqual(diskData.totalSize, 143360)
        
        // Verify geometry was inferred
        if let geometry = diskData.metadata?.geometry {
            XCTAssertGreaterThan(geometry.tracks, 0)
            XCTAssertGreaterThan(geometry.sectorsPerTrack, 0)
        }
    }
}

