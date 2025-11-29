// FileSystemKit Tests
// Unit tests for ChunkStorage protocol and implementations

import XCTest
@testable import FileSystemKit

final class ChunkStorageTests: XCTestCase {
    var mockStorage: MockChunkStorage!
    
    override func setUp() {
        super.setUp()
        mockStorage = MockChunkStorage()
    }
    
    override func tearDown() {
        mockStorage = nil
        super.tearDown()
    }
    
    // MARK: - ChunkIdentifier Tests
    
    func testChunkIdentifierInitialization() {
        let identifier = ChunkIdentifier(id: "test-id-123")
        
        XCTAssertEqual(identifier.id, "test-id-123")
        XCTAssertNil(identifier.metadata)
    }
    
    func testChunkIdentifierWithMetadata() {
        let metadata = ChunkMetadata(
            size: 1024,
            contentHash: "abc123",
            hashAlgorithm: "sha256",
            contentType: "application/octet-stream",
            chunkType: "disk-image"
        )
        let identifier = ChunkIdentifier(id: "test-id", metadata: metadata)
        
        XCTAssertEqual(identifier.id, "test-id")
        XCTAssertNotNil(identifier.metadata)
        XCTAssertEqual(identifier.metadata?.size, 1024)
    }
    
    func testChunkIdentifierEquality() {
        let id1 = ChunkIdentifier(id: "same-id")
        let id2 = ChunkIdentifier(id: "same-id")
        let id3 = ChunkIdentifier(id: "different-id")
        
        XCTAssertEqual(id1, id2)
        XCTAssertNotEqual(id1, id3)
    }
    
    // MARK: - ChunkMetadata Tests
    
    func testChunkMetadataInitialization() {
        let metadata = ChunkMetadata(
            size: 2048,
            contentHash: "def456",
            hashAlgorithm: "sha256",
            contentType: "application/octet-stream",
            chunkType: "disk-image",
            originalFilename: "test.dsk"
        )
        
        XCTAssertEqual(metadata.size, 2048)
        XCTAssertEqual(metadata.contentHash, "def456")
        XCTAssertEqual(metadata.hashAlgorithm, "sha256")
        XCTAssertEqual(metadata.contentType, "application/octet-stream")
        XCTAssertEqual(metadata.chunkType, "disk-image")
        XCTAssertEqual(metadata.originalFilename, "test.dsk")
    }
    
    func testChunkMetadataEquality() {
        let metadata1 = ChunkMetadata(
            size: 1024,
            contentHash: "abc",
            hashAlgorithm: "sha256"
        )
        let metadata2 = ChunkMetadata(
            size: 1024,
            contentHash: "abc",
            hashAlgorithm: "sha256"
        )
        let metadata3 = ChunkMetadata(
            size: 2048,
            contentHash: "abc",
            hashAlgorithm: "sha256"
        )
        
        XCTAssertEqual(metadata1, metadata2)
        XCTAssertNotEqual(metadata1, metadata3)
    }
    
    // MARK: - ChunkStorage Protocol Tests
    
    func testWriteChunk() async throws {
        let testData = Data([0x01, 0x02, 0x03, 0x04])
        let identifier = ChunkIdentifier(id: "test-chunk-1")
        let metadata = ChunkMetadata(
            size: testData.count,
            contentHash: "test-hash",
            hashAlgorithm: "sha256"
        )
        
        let result = try await mockStorage.writeChunk(testData, identifier: identifier, metadata: metadata)
        
        XCTAssertEqual(result.id, identifier.id)
        XCTAssertEqual(mockStorage.writeCount, 1)
        XCTAssertEqual(mockStorage.chunkCount, 1)
    }
    
    func testReadChunk() async throws {
        let testData = Data([0x05, 0x06, 0x07])
        let identifier = ChunkIdentifier(id: "read-test")
        
        // Write first
        _ = try await mockStorage.writeChunk(testData, identifier: identifier, metadata: nil)
        
        // Read back
        let readData = try await mockStorage.readChunk(identifier)
        
        XCTAssertNotNil(readData)
        XCTAssertEqual(readData, testData)
        XCTAssertEqual(mockStorage.readCount, 1)
    }
    
    func testReadChunkNotFound() async throws {
        let identifier = ChunkIdentifier(id: "non-existent")
        
        let readData = try await mockStorage.readChunk(identifier)
        
        XCTAssertNil(readData)
    }
    
    func testReadChunkPartial() async throws {
        let testData = Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08])
        let identifier = ChunkIdentifier(id: "partial-test")
        
        _ = try await mockStorage.writeChunk(testData, identifier: identifier, metadata: nil)
        
        // Read partial chunk (offset 2, length 3)
        let partialData = try await mockStorage.readChunk(identifier, offset: 2, length: 3)
        
        XCTAssertNotNil(partialData)
        XCTAssertEqual(partialData, Data([0x03, 0x04, 0x05]))
    }
    
    func testReadChunkPartialOutOfBounds() async throws {
        let testData = Data([0x01, 0x02])
        let identifier = ChunkIdentifier(id: "bounds-test")
        
        _ = try await mockStorage.writeChunk(testData, identifier: identifier, metadata: nil)
        
        // Try to read beyond bounds
        let partialData = try await mockStorage.readChunk(identifier, offset: 0, length: 10)
        
        // Should return only available data
        XCTAssertNotNil(partialData)
        XCTAssertEqual(partialData?.count, 2)
    }
    
    func testUpdateChunk() async throws {
        let originalData = Data([0x01, 0x02])
        let updatedData = Data([0x03, 0x04])
        let identifier = ChunkIdentifier(id: "update-test")
        
        _ = try await mockStorage.writeChunk(originalData, identifier: identifier, metadata: nil)
        
        let result = try await mockStorage.updateChunk(updatedData, identifier: identifier, metadata: nil)
        
        XCTAssertEqual(result.id, identifier.id)
        
        let readData = try await mockStorage.readChunk(identifier)
        XCTAssertEqual(readData, updatedData)
    }
    
    func testDeleteChunk() async throws {
        let testData = Data([0x01, 0x02])
        let identifier = ChunkIdentifier(id: "delete-test")
        
        _ = try await mockStorage.writeChunk(testData, identifier: identifier, metadata: nil)
        XCTAssertEqual(mockStorage.chunkCount, 1)
        
        try await mockStorage.deleteChunk(identifier)
        
        XCTAssertEqual(mockStorage.deleteCount, 1)
        XCTAssertEqual(mockStorage.chunkCount, 0)
        
        let readData = try await mockStorage.readChunk(identifier)
        XCTAssertNil(readData)
    }
    
    func testChunkExists() async throws {
        let testData = Data([0x01])
        let identifier = ChunkIdentifier(id: "exists-test")
        
        let existsBefore = try await mockStorage.chunkExists(identifier)
        XCTAssertFalse(existsBefore)
        
        _ = try await mockStorage.writeChunk(testData, identifier: identifier, metadata: nil)
        
        let existsAfter = try await mockStorage.chunkExists(identifier)
        XCTAssertTrue(existsAfter)
    }
    
    func testChunkStorageErrorHandling() async throws {
        let testError = NSError(domain: "TestError", code: 1)
        mockStorage.shouldThrowError = testError
        
        let testData = Data([0x01])
        let identifier = ChunkIdentifier(id: "error-test")
        
        do {
            _ = try await mockStorage.writeChunk(testData, identifier: identifier, metadata: nil)
            XCTFail("Should have thrown error")
        } catch {
            XCTAssertNotNil(error)
        }
    }
}

