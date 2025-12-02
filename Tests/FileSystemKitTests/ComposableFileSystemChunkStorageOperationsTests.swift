// FileSystemKit Tests
// Operations unit tests for ComposableFileSystemChunkStorage implementation

import XCTest
@testable import FileSystemKit

final class ComposableFileSystemChunkStorageOperationsTests: XCTestCase {
    var tempDirectory: URL!
    
    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("composable-storage-ops-test-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        tempDirectory = nil
        super.tearDown()
    }
    
    // MARK: - Write/Read Tests
    
    func testWriteAndReadChunk() async throws {
        let storage = ComposableFileSystemChunkStorage(baseURL: tempDirectory)
        let testData = Data([0x01, 0x02, 0x03, 0x04])
        let hash = "a1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456"
        let identifier = ChunkIdentifier(id: hash)
        let metadata = ChunkMetadata(size: testData.count)
        
        let result = try await storage.writeChunk(testData, identifier: identifier, metadata: metadata)
        
        XCTAssertEqual(result.id, identifier.id)
        
        let readData = try await storage.readChunk(identifier)
        XCTAssertNotNil(readData)
        XCTAssertEqual(readData, testData)
    }
    
    func testReadChunkNotFound() async throws {
        let storage = ComposableFileSystemChunkStorage(baseURL: tempDirectory)
        let hash = "nonexistent123456789012345678901234567890abcdef1234567890abcdef123456"
        let identifier = ChunkIdentifier(id: hash)
        
        let readData = try await storage.readChunk(identifier)
        
        XCTAssertNil(readData)
    }
    
    func testReadChunkPartial() async throws {
        let storage = ComposableFileSystemChunkStorage(baseURL: tempDirectory)
        let testData = Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08])
        let hash = "a1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456"
        let identifier = ChunkIdentifier(id: hash)
        
        _ = try await storage.writeChunk(testData, identifier: identifier, metadata: nil)
        
        // Read partial chunk (offset 2, length 3)
        let partialData = try await storage.readChunk(identifier, offset: 2, length: 3)
        
        XCTAssertNotNil(partialData)
        XCTAssertEqual(partialData, Data([0x03, 0x04, 0x05]))
    }
    
    // MARK: - Existence Tests
    
    func testChunkExists() async throws {
        let storage = ComposableFileSystemChunkStorage(baseURL: tempDirectory)
        let testData = Data([0x01])
        let hash = "a1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456"
        let identifier = ChunkIdentifier(id: hash)
        
        let existsBefore = try await storage.chunkExists(identifier)
        XCTAssertFalse(existsBefore)
        
        _ = try await storage.writeChunk(testData, identifier: identifier, metadata: nil)
        
        let existsAfter = try await storage.chunkExists(identifier)
        XCTAssertTrue(existsAfter)
    }
    
    // MARK: - Update/Delete Tests
    
    func testUpdateChunk() async throws {
        let storage = ComposableFileSystemChunkStorage(baseURL: tempDirectory)
        let originalData = Data([0x01, 0x02])
        let updatedData = Data([0x03, 0x04])
        let hash = "a1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456"
        let identifier = ChunkIdentifier(id: hash)
        
        _ = try await storage.writeChunk(originalData, identifier: identifier, metadata: nil)
        
        let result = try await storage.updateChunk(updatedData, identifier: identifier, metadata: nil)
        
        XCTAssertEqual(result.id, identifier.id)
        
        let readData = try await storage.readChunk(identifier)
        XCTAssertEqual(readData, updatedData)
    }
    
    func testDeleteChunk() async throws {
        let storage = ComposableFileSystemChunkStorage(baseURL: tempDirectory)
        let testData = Data([0x01, 0x02])
        let hash = "a1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456"
        let identifier = ChunkIdentifier(id: hash)
        
        _ = try await storage.writeChunk(testData, identifier: identifier, metadata: nil)
        
        let existsBefore = try await storage.chunkExists(identifier)
        XCTAssertTrue(existsBefore)
        
        try await storage.deleteChunk(identifier)
        
        let existsAfter = try await storage.chunkExists(identifier)
        XCTAssertFalse(existsAfter)
    }
    
    // MARK: - Size Tests
    
    func testChunkSize() async throws {
        let storage = ComposableFileSystemChunkStorage(baseURL: tempDirectory)
        let testData = Data([0x01, 0x02, 0x03, 0x04, 0x05])
        let hash = "a1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456"
        let identifier = ChunkIdentifier(id: hash)
        
        _ = try await storage.writeChunk(testData, identifier: identifier, metadata: nil)
        
        let size = try await storage.chunkSize(identifier)
        
        XCTAssertNotNil(size)
        XCTAssertEqual(size, testData.count)
    }
    
    func testChunkSizeNotFound() async throws {
        let storage = ComposableFileSystemChunkStorage(baseURL: tempDirectory)
        let hash = "nonexistent123456789012345678901234567890abcdef1234567890abcdef123456"
        let identifier = ChunkIdentifier(id: hash)
        
        let size = try await storage.chunkSize(identifier)
        
        XCTAssertNil(size)
    }
}

