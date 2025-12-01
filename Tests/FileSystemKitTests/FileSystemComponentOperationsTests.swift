// FileSystemKit Tests
// FileSystemComponent Operations Unit Tests

import XCTest
@testable import FileSystemKit

final class FileSystemComponentOperationsTests: XCTestCase {
    
    // MARK: - File Read Operations Tests
    
    func testFileReadData() throws {
        let testData = Data([0x01, 0x02, 0x03, 0x04, 0x05])
        let location = FileLocation(offset: 0, length: testData.count)
        let metadata = FileSystemEntryMetadata(
            name: "READ_TEST",
            size: testData.count,
            location: location
        )
        let file = FileSystemEntry(metadata: metadata)
        
        // Create raw disk data
        let rawDiskData = RawDiskData(rawData: testData)
        
        // Read file data (lazy-loaded)
        let readData = try file.readData(from: rawDiskData)
        
        XCTAssertEqual(readData, testData)
        XCTAssertEqual(readData.count, testData.count)
    }
    
    func testFileReadDataWithChunkStorage() async throws {
        let testData = Data([0x01, 0x02, 0x03, 0x04, 0x05])
        let location = FileLocation(offset: 0, length: testData.count)
        let metadata = FileSystemEntryMetadata(
            name: "READ_TEST_CHUNK",
            size: testData.count,
            location: location
        )
        _ = FileSystemEntry(metadata: metadata)
        
        // Create mock chunk storage
        let mockStorage = MockChunkStorage()
        let identifier = ChunkIdentifier(id: "test-file-chunk")
        
        // Store data in chunk storage
        _ = try await mockStorage.writeChunk(testData, identifier: identifier, metadata: nil)
        
        // Note: File.readData doesn't directly support ChunkStorage yet
        // This test documents the expected future API
        // For now, we test the legacy method above
        XCTAssertEqual(mockStorage.chunkCount, 1)
    }
    
    // MARK: - File Hash Generation Tests
    
    func testFileHashGeneration() throws {
        let testData = Data("Hello, World!".utf8)
        let location = FileLocation(offset: 0, length: testData.count)
        let metadata = FileSystemEntryMetadata(
            name: "HASH_TEST",
            size: testData.count,
            location: location
        )
        let file = FileSystemEntry(metadata: metadata)
        
        let rawDiskData = RawDiskData(rawData: testData)
        
        // Load file data first (required for hash generation)
        _ = try file.readData(from: rawDiskData)
        
        // Generate hash (default: SHA-256)
        let hash = try file.generateHash(algorithm: HashAlgorithm.sha256)
        
        XCTAssertEqual(hash.algorithm, HashAlgorithm.sha256)
        XCTAssertEqual(hash.value.count, 32) // SHA-256 produces 32 bytes
        XCTAssertFalse(hash.hexString.isEmpty)
        XCTAssertTrue(hash.identifier.hasPrefix("sha256:"))
    }
    
    // MARK: - Traverse Operations Tests
    
    func testFileTraverse() {
        let location = FileLocation(offset: 0, length: 10)
        let metadata = FileSystemEntryMetadata(
            name: "TRAVERSE_TEST",
            size: 10,
            location: location
        )
        let file = FileSystemEntry(metadata: metadata)
        
        let components = file.traverse()
        XCTAssertEqual(components.count, 1)
        XCTAssertTrue(components.first === file)
    }
    
    func testDirectoryTraverse() {
        let root = FileSystemFolder(name: "ROOT")
        let subdir = FileSystemFolder(name: "SUBDIR")
        let location = FileLocation(offset: 0, length: 10)
        let metadata = FileSystemEntryMetadata(
            name: "FILE",
            size: 10,
            location: location
        )
        let file = FileSystemEntry(metadata: metadata)
        
        root.addChild(subdir)
        subdir.addChild(file)
        
        let components = root.traverse()
        XCTAssertEqual(components.count, 3) // root, subdir, file
        XCTAssertTrue(components.contains { $0.name == "ROOT" })
        XCTAssertTrue(components.contains { $0.name == "SUBDIR" })
        XCTAssertTrue(components.contains { $0.name == "FILE" })
    }
}

