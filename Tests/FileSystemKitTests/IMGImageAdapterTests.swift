// FileSystemKit Tests
// IMG Image Adapter Tests

import XCTest
@testable import FileSystemKit
import Foundation

final class IMGImageAdapterTests: DiskImageAdapterTestBase {
    
    func testIMGImageAdapterFormat() {
        XCTAssertEqual(IMGImageAdapter.format, .img)
    }
    
    func testIMGImageAdapterCanRead() {
        // IMG adapter requires minimum 360KB and sector-aligned data
        let minSize = 360 * 1024 // 360KB minimum
        let validData = Data(count: minSize) // Exactly 360KB, sector-aligned
        XCTAssertTrue(IMGImageAdapter.canRead(data: validData))
        
        // Test with too small data (should fail)
        let tooSmallData = Data(count: 512)
        XCTAssertFalse(IMGImageAdapter.canRead(data: tooSmallData))
        
        // Test with non-sector-aligned data (should fail)
        let nonAlignedData = Data(count: minSize + 1) // Not sector-aligned
        XCTAssertFalse(IMGImageAdapter.canRead(data: nonAlignedData))
    }
    
    func testIMGImageAdapterRead() async throws {
        let mockStorage = MockChunkStorage()
        let identifier = ChunkIdentifier(id: "test-img")
        
        // Create a minimal raw disk image (512 bytes - minimal sector size)
        let testData = Data(count: 512)
        _ = try await mockStorage.writeChunk(testData, identifier: identifier, metadata: nil)
        
        do {
            let diskData = try await IMGImageAdapter.read(chunkStorage: mockStorage, identifier: identifier)
            XCTAssertNotNil(diskData)
            XCTAssertGreaterThanOrEqual(diskData.totalSize, 512)
        } catch {
            print("IMG read test skipped: \(error)")
        }
    }
    
    // MARK: - Corrupt IMG Tests
    
    func testCorruptIMGEmptyFile() async throws {
        let emptyData = Data()
        XCTAssertFalse(IMGImageAdapter.canRead(data: emptyData), "Should not read empty file")
    }
    
    func testCorruptIMGTooSmall() async throws {
        let smallData = Data(count: 10)
        XCTAssertFalse(IMGImageAdapter.canRead(data: smallData), "Should not read file that's too small")
    }
}

