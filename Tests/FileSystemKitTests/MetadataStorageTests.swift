// FileSystemKit Tests
// Unit tests for MetadataStorage protocol and implementations

import XCTest
@testable import FileSystemKit

final class MetadataStorageTests: XCTestCase {
    var mockStorage: MockMetadataStorage!
    
    override func setUp() {
        super.setUp()
        mockStorage = MockMetadataStorage()
    }
    
    override func tearDown() {
        mockStorage = nil
        super.tearDown()
    }
    
    // MARK: - DiskImageSearchCriteria Tests
    
    func testDiskImageSearchCriteriaInitialization() {
        let criteria = DiskImageSearchCriteria()
        
        XCTAssertNil(criteria.hash)
        XCTAssertNil(criteria.exactFilename)
        XCTAssertNil(criteria.filenameContains)
        XCTAssertNil(criteria.titleContains)
        XCTAssertNil(criteria.publisher)
        XCTAssertNil(criteria.developer)
    }
    
    func testDiskImageSearchCriteriaWithValues() {
        let hash = DiskImageHash(algorithm: .sha256, value: Data([0x01, 0x02]))
        let criteria = DiskImageSearchCriteria(
            hash: hash,
            exactFilename: "test.dsk",
            filenameContains: "test",
            titleContains: "Test",
            publisher: "Test Publisher",
            developer: "Test Developer"
        )
        
        XCTAssertNotNil(criteria.hash)
        XCTAssertEqual(criteria.exactFilename, "test.dsk")
        XCTAssertEqual(criteria.filenameContains, "test")
        XCTAssertEqual(criteria.titleContains, "Test")
        XCTAssertEqual(criteria.publisher, "Test Publisher")
        XCTAssertEqual(criteria.developer, "Test Developer")
    }
    
    // MARK: - MetadataStorage Protocol Tests
    
    func testWriteMetadata() async throws {
        let hash = DiskImageHash(algorithm: .sha256, value: Data([0x01, 0x02]))
        let metadata = DiskImageMetadata(
            title: "Test Disk",
            publisher: "Test Publisher"
        )
        
        try await mockStorage.writeMetadata(metadata, for: hash)
        
        XCTAssertEqual(mockStorage.writeCount, 1)
        XCTAssertEqual(mockStorage.metadataCount, 1)
    }
    
    func testReadMetadata() async throws {
        let hash = DiskImageHash(algorithm: .sha256, value: Data([0x01, 0x02]))
        let metadata = DiskImageMetadata(
            title: "Read Test",
            developer: "Test Dev"
        )
        
        try await mockStorage.writeMetadata(metadata, for: hash)
        
        let readMetadata = try await mockStorage.readMetadata(for: hash)
        
        XCTAssertNotNil(readMetadata)
        XCTAssertEqual(readMetadata?.title, "Read Test")
        XCTAssertEqual(readMetadata?.developer, "Test Dev")
        XCTAssertEqual(mockStorage.readCount, 1)
    }
    
    func testReadMetadataNotFound() async throws {
        let hash = DiskImageHash(algorithm: .sha256, value: Data([0x99, 0x99]))
        
        let readMetadata = try await mockStorage.readMetadata(for: hash)
        
        XCTAssertNil(readMetadata)
    }
    
    func testUpdateMetadata() async throws {
        let hash = DiskImageHash(algorithm: .sha256, value: Data([0x01, 0x02]))
        let originalMetadata = DiskImageMetadata(title: "Original")
        let updatedMetadata = DiskImageMetadata(title: "Updated")
        
        try await mockStorage.writeMetadata(originalMetadata, for: hash)
        try await mockStorage.updateMetadata(updatedMetadata, for: hash)
        
        let readMetadata = try await mockStorage.readMetadata(for: hash)
        XCTAssertEqual(readMetadata?.title, "Updated")
    }
    
    func testDeleteMetadata() async throws {
        let hash = DiskImageHash(algorithm: .sha256, value: Data([0x01, 0x02]))
        let metadata = DiskImageMetadata(title: "Delete Test")
        
        try await mockStorage.writeMetadata(metadata, for: hash)
        XCTAssertEqual(mockStorage.metadataCount, 1)
        
        try await mockStorage.deleteMetadata(for: hash)
        
        XCTAssertEqual(mockStorage.deleteCount, 1)
        XCTAssertEqual(mockStorage.metadataCount, 0)
        
        let readMetadata = try await mockStorage.readMetadata(for: hash)
        XCTAssertNil(readMetadata)
    }
    
    func testMetadataExists() async throws {
        let hash = DiskImageHash(algorithm: .sha256, value: Data([0x01, 0x02]))
        
        let existsBefore = try await mockStorage.metadataExists(for: hash)
        XCTAssertFalse(existsBefore)
        
        let metadata = DiskImageMetadata(title: "Exists Test")
        try await mockStorage.writeMetadata(metadata, for: hash)
        
        let existsAfter = try await mockStorage.metadataExists(for: hash)
        XCTAssertTrue(existsAfter)
    }
    
    func testSearchMetadataByTitle() async throws {
        let hash1 = DiskImageHash(algorithm: .sha256, value: Data([0x01]))
        let hash2 = DiskImageHash(algorithm: .sha256, value: Data([0x02]))
        
        let metadata1 = DiskImageMetadata(title: "Apple Works")
        let metadata2 = DiskImageMetadata(title: "Word Processor")
        
        try await mockStorage.writeMetadata(metadata1, for: hash1)
        try await mockStorage.writeMetadata(metadata2, for: hash2)
        
        let criteria = DiskImageSearchCriteria(titleContains: "Apple")
        let results = try await mockStorage.searchMetadata(criteria: criteria)
        
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(mockStorage.searchCount, 1)
    }
    
    func testSearchMetadataByPublisher() async throws {
        let hash1 = DiskImageHash(algorithm: .sha256, value: Data([0x01]))
        let hash2 = DiskImageHash(algorithm: .sha256, value: Data([0x02]))
        
        let metadata1 = DiskImageMetadata(publisher: "Apple Computer")
        let metadata2 = DiskImageMetadata(publisher: "Microsoft")
        
        try await mockStorage.writeMetadata(metadata1, for: hash1)
        try await mockStorage.writeMetadata(metadata2, for: hash2)
        
        let criteria = DiskImageSearchCriteria(publisher: "Apple Computer")
        let results = try await mockStorage.searchMetadata(criteria: criteria)
        
        XCTAssertEqual(results.count, 1)
    }
    
    func testSearchMetadataByDeveloper() async throws {
        let hash1 = DiskImageHash(algorithm: .sha256, value: Data([0x01]))
        let hash2 = DiskImageHash(algorithm: .sha256, value: Data([0x02]))
        
        let metadata1 = DiskImageMetadata(developer: "Apple")
        let metadata2 = DiskImageMetadata(developer: "Microsoft")
        
        try await mockStorage.writeMetadata(metadata1, for: hash1)
        try await mockStorage.writeMetadata(metadata2, for: hash2)
        
        let criteria = DiskImageSearchCriteria(developer: "Apple")
        let results = try await mockStorage.searchMetadata(criteria: criteria)
        
        XCTAssertEqual(results.count, 1)
    }
    
    func testSearchMetadataByHash() async throws {
        let hash1 = DiskImageHash(algorithm: .sha256, value: Data([0x01]))
        let hash2 = DiskImageHash(algorithm: .sha256, value: Data([0x02]))
        
        let metadata1 = DiskImageMetadata(title: "Disk 1")
        let metadata2 = DiskImageMetadata(title: "Disk 2")
        
        try await mockStorage.writeMetadata(metadata1, for: hash1)
        try await mockStorage.writeMetadata(metadata2, for: hash2)
        
        let criteria = DiskImageSearchCriteria(hash: hash1)
        let results = try await mockStorage.searchMetadata(criteria: criteria)
        
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.hexString, hash1.hexString)
    }
    
    func testMetadataStorageErrorHandling() async throws {
        let testError = NSError(domain: "TestError", code: 1)
        mockStorage.shouldThrowError = testError
        
        let hash = DiskImageHash(algorithm: .sha256, value: Data([0x01]))
        let metadata = DiskImageMetadata(title: "Error Test")
        
        do {
            try await mockStorage.writeMetadata(metadata, for: hash)
            XCTFail("Should have thrown error")
        } catch {
            XCTAssertNotNil(error)
        }
    }
}

