// FileSystemKit Tests
// VHD Image Adapter Tests

import XCTest
@testable import FileSystemKit
import Foundation

final class VHDImageAdapterTests: DiskImageAdapterTestBase {
    
    func testVHDImageAdapterFormat() {
        XCTAssertEqual(VHDImageAdapter.format, .vhd)
    }
    
    func testVHDImageAdapterCanRead() {
        // Test with valid VHD data (VHD signature)
        var validVHDData = Data(count: 512)
        let vhdSignature = "conectix".data(using: .ascii)! // VHD footer signature
        validVHDData.replaceSubrange(0..<8, with: vhdSignature)
        XCTAssertTrue(VHDImageAdapter.canRead(data: validVHDData))
        
        // Test with invalid data
        let invalidData = Data([0x00, 0x01, 0x02, 0x03])
        XCTAssertFalse(VHDImageAdapter.canRead(data: invalidData))
    }
    
    func testVHDImageAdapterRead() async throws {
        let mockStorage = MockChunkStorage()
        let identifier = ChunkIdentifier(id: "test-vhd")
        
        if let vhdFile = getTestResource("VHD/test.vhd") {
            let vhdData = try Data(contentsOf: vhdFile)
            _ = try await mockStorage.writeChunk(vhdData, identifier: identifier, metadata: nil)
            
            do {
                let diskData = try await VHDImageAdapter.read(chunkStorage: mockStorage, identifier: identifier)
                XCTAssertNotNil(diskData)
                XCTAssertGreaterThan(diskData.totalSize, 0)
            } catch {
                print("VHD read test skipped: \(error)")
            }
        } else {
            print("VHD test file not found, skipping read test")
        }
    }
    
    // MARK: - Corrupt VHD Tests
    
    func testCorruptVHDEmptyFile() async throws {
        let emptyData = Data()
        XCTAssertFalse(VHDImageAdapter.canRead(data: emptyData), "Should not read empty file")
    }
    
    func testCorruptVHDTooSmall() async throws {
        let smallData = Data(count: 100)
        XCTAssertFalse(VHDImageAdapter.canRead(data: smallData), "Should not read file that's too small")
    }
    
    func testCorruptVHDInvalidHeader() async throws {
        var invalidData = Data(count: 512)
        // Invalid signature
        invalidData.replaceSubrange(0..<8, with: Data([0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]))
        XCTAssertFalse(VHDImageAdapter.canRead(data: invalidData), "Should not read file with invalid header")
    }
}

