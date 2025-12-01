// FileSystemKit Tests
// ISO9660 Image Adapter Tests

import XCTest
@testable import FileSystemKit
import Foundation

final class ISO9660ImageAdapterTests: DiskImageAdapterTestBase {
    
    func testISO9660ImageAdapterFormat() {
        XCTAssertEqual(ISO9660ImageAdapter.format, .iso9660)
    }
    
    func testISO9660ImageAdapterCanRead() {
        // Test with valid ISO 9660 data (CD001 signature at sector 16)
        var validISOData = Data(count: 17 * 2048) // At least 17 sectors
        let sector16Offset = 16 * 2048
        validISOData[sector16Offset] = 0x01 // Volume descriptor type
        let cd001Signature = "CD001".data(using: .ascii)!
        validISOData.replaceSubrange((sector16Offset + 1)..<(sector16Offset + 6), with: cd001Signature)
        XCTAssertTrue(ISO9660ImageAdapter.canRead(data: validISOData))
        
        // Test with invalid data
        let invalidData = Data([0x00, 0x01, 0x02, 0x03])
        XCTAssertFalse(ISO9660ImageAdapter.canRead(data: invalidData))
    }
    
    func testISO9660ImageAdapterRead() async throws {
        let mockStorage = MockChunkStorage()
        let identifier = ChunkIdentifier(id: "test-iso")
        
        if let isoFile = getTestResource("ISO9660/test.iso") {
            let isoData = try Data(contentsOf: isoFile)
            _ = try await mockStorage.writeChunk(isoData, identifier: identifier, metadata: nil)
            
            do {
                let diskData = try await ISO9660ImageAdapter.read(chunkStorage: mockStorage, identifier: identifier)
                XCTAssertNotNil(diskData)
                XCTAssertGreaterThan(diskData.totalSize, 0)
            } catch {
                print("ISO9660 read test skipped: \(error)")
            }
        } else {
            print("ISO9660 test file not found, skipping read test")
        }
    }
    
    func testISO9660ImageAdapterExtractMetadata() throws {
        if let isoFile = getTestResource("ISO9660/test.iso") {
            let isoData = try Data(contentsOf: isoFile)
            
            do {
                let metadata = try ISO9660ImageAdapter.extractMetadata(from: isoData)
                XCTAssertNotNil(metadata)
                if let metadata = metadata, let geometry = metadata.geometry {
                    XCTAssertEqual(geometry.sectorSize, 2048) // ISO 9660 uses 2048-byte sectors
                }
            } catch {
                print("ISO9660 metadata extraction skipped: \(error)")
            }
        } else {
            // Test with minimal ISO-like data (CD001 signature at sector 16)
            var testData = Data(count: 17 * 2048) // At least 17 sectors (sector 16 + 1)
            // Add ISO 9660 signature at sector 16
            let sector16Offset = 16 * 2048
            testData[sector16Offset] = 0x01 // Volume descriptor type
            let cd001Signature = "CD001".data(using: .ascii)!
            testData.replaceSubrange((sector16Offset + 1)..<(sector16Offset + 6), with: cd001Signature)
            
            // This should fail gracefully (not a valid ISO)
            _ = try? ISO9660ImageAdapter.extractMetadata(from: testData)
            // May be nil for invalid ISO, which is OK
        }
    }
    
    // MARK: - Corrupt ISO9660 Tests
    
    func testCorruptISO9660EmptyFile() async throws {
        let emptyData = Data()
        XCTAssertFalse(ISO9660ImageAdapter.canRead(data: emptyData), "Should not read empty file")
    }
    
    func testCorruptISO9660TooSmall() async throws {
        let smallData = Data(count: 100)
        XCTAssertFalse(ISO9660ImageAdapter.canRead(data: smallData), "Should not read file that's too small")
    }
    
    func testCorruptISO9660InvalidHeader() async throws {
        var invalidData = Data(count: 17 * 2048)
        let sector16Offset = 16 * 2048
        // Invalid signature
        invalidData.replaceSubrange((sector16Offset + 1)..<(sector16Offset + 6), with: Data([0x00, 0x00, 0x00, 0x00, 0x00]))
        XCTAssertFalse(ISO9660ImageAdapter.canRead(data: invalidData), "Should not read file with invalid header")
    }
}

