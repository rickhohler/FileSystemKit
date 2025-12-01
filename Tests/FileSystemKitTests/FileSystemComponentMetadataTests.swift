// FileSystemKit Tests
// FileSystemComponent Metadata Unit Tests

import XCTest
@testable import FileSystemKit

final class FileSystemComponentMetadataTests: XCTestCase {
    
    // MARK: - FileLocation Tests
    
    func testFileLocation() {
        let location = FileLocation(track: 1, sector: 2, offset: 100, length: 50)
        
        XCTAssertEqual(location.track, 1)
        XCTAssertEqual(location.sector, 2)
        XCTAssertEqual(location.offset, 100)
        XCTAssertEqual(location.length, 50)
    }
    
    func testFileLocationWithoutTrackSector() {
        let location = FileLocation(offset: 200, length: 100)
        
        XCTAssertNil(location.track)
        XCTAssertNil(location.sector)
        XCTAssertEqual(location.offset, 200)
        XCTAssertEqual(location.length, 100)
    }
    
    // MARK: - FileHash Tests
    
    func testFileHash() {
        let data = Data([0x01, 0x02, 0x03])
        let hash = FileHash(algorithm: HashAlgorithm.sha256, value: data)
        
        XCTAssertEqual(hash.algorithm, .sha256)
        XCTAssertEqual(hash.value, data)
        XCTAssertFalse(hash.hexString.isEmpty)
        XCTAssertTrue(hash.identifier.hasPrefix("sha256:"))
    }
    
    func testFileHashEquality() {
        let data = Data([0x01, 0x02, 0x03])
        let hash1 = FileHash(algorithm: HashAlgorithm.sha256, value: data)
        let hash2 = FileHash(algorithm: HashAlgorithm.sha256, value: data)
        let hash3 = FileHash(algorithm: HashAlgorithm.sha256, value: Data([0x04, 0x05, 0x06]))
        
        XCTAssertEqual(hash1, hash2)
        XCTAssertNotEqual(hash1, hash3)
    }
    
    // MARK: - FileSystemEntryMetadata Tests
    
    func testFileSystemEntryMetadata() {
        let location = FileLocation(offset: 0, length: 100)
        let metadata = FileSystemEntryMetadata(
            name: "METADATA_TEST",
            size: 100,
            modificationDate: Date(),
            fileType: FileTypeCategory.text,
            attributes: ["key": "value"],
            location: location
        )
        
        XCTAssertEqual(metadata.name, "METADATA_TEST")
        XCTAssertEqual(metadata.size, 100)
        XCTAssertNotNil(metadata.modificationDate)
        XCTAssertEqual(metadata.fileType, FileTypeCategory.text)
        XCTAssertEqual(metadata.attributes["key"] as? String, "value")
        XCTAssertEqual(metadata.location, location)
    }
}

