// FileSystemKit Tests
// Unit tests for ChunkStorageRetrieval protocol and implementations

import XCTest
@testable import FileSystemKit

final class ChunkStorageRetrievalTests: XCTestCase {
    var tempDirectory: URL!
    
    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("chunk-retrieval-test-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        tempDirectory = nil
        super.tearDown()
    }
    
    // MARK: - FileSystemRetrieval Tests
    
    func testFileSystemRetrievalReadChunk() async throws {
        let retrieval = FileSystemRetrieval(baseURL: tempDirectory)
        let testData = Data([0x01, 0x02, 0x03, 0x04])
        let path = "test-chunk.dat"
        
        // Write data first
        try await retrieval.writeChunk(testData, at: path, metadata: nil)
        
        // Read it back
        let readData = try await retrieval.readChunk(at: path)
        
        XCTAssertNotNil(readData)
        XCTAssertEqual(readData, testData)
    }
    
    func testFileSystemRetrievalReadChunkNotFound() async throws {
        let retrieval = FileSystemRetrieval(baseURL: tempDirectory)
        let path = "non-existent.dat"
        
        let readData = try await retrieval.readChunk(at: path)
        
        XCTAssertNil(readData)
    }
    
    func testFileSystemRetrievalWriteChunk() async throws {
        let retrieval = FileSystemRetrieval(baseURL: tempDirectory)
        let testData = Data([0x05, 0x06, 0x07])
        let path = "write-test.dat"
        
        try await retrieval.writeChunk(testData, at: path, metadata: nil)
        
        // Verify file exists
        let fileURL = tempDirectory.appendingPathComponent(path)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
        
        // Verify content
        let savedData = try Data(contentsOf: fileURL)
        XCTAssertEqual(savedData, testData)
    }
    
    func testFileSystemRetrievalWriteChunkWithMetadata() async throws {
        let retrieval = FileSystemRetrieval(baseURL: tempDirectory)
        let testData = Data([0x08, 0x09])
        let path = "metadata-test.dat"
        let metadata = ChunkMetadata(
            size: testData.count,
            contentHash: "abc123",
            hashAlgorithm: "sha256"
        )
        
        try await retrieval.writeChunk(testData, at: path, metadata: metadata)
        
        // Verify data file exists
        let fileURL = tempDirectory.appendingPathComponent(path)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
        
        // Verify metadata file exists
        let metadataURL = fileURL.appendingPathExtension("meta")
        XCTAssertTrue(FileManager.default.fileExists(atPath: metadataURL.path))
        
        // Verify metadata content
        let metadataData = try Data(contentsOf: metadataURL)
        let decoder = JSONDecoder()
        let decodedMetadata = try decoder.decode(ChunkMetadata.self, from: metadataData)
        XCTAssertEqual(decodedMetadata.size, metadata.size)
        XCTAssertEqual(decodedMetadata.contentHash, metadata.contentHash)
    }
    
    func testFileSystemRetrievalWriteChunkCreatesDirectories() async throws {
        let retrieval = FileSystemRetrieval(baseURL: tempDirectory)
        let testData = Data([0x0A, 0x0B])
        let path = "subdir/nested/deep/file.dat"
        
        try await retrieval.writeChunk(testData, at: path, metadata: nil)
        
        // Verify directory structure was created
        let fileURL = tempDirectory.appendingPathComponent(path)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
        
        // Verify parent directories exist
        let subdirURL = tempDirectory.appendingPathComponent("subdir")
        XCTAssertTrue(FileManager.default.fileExists(atPath: subdirURL.path))
    }
    
    func testFileSystemRetrievalChunkExists() async {
        let retrieval = FileSystemRetrieval(baseURL: tempDirectory)
        let testData = Data([0x0C, 0x0D])
        let path = "exists-test.dat"
        
        // Should not exist initially
        let existsBefore = await retrieval.chunkExists(at: path)
        XCTAssertFalse(existsBefore)
        
        // Write chunk
        try? await retrieval.writeChunk(testData, at: path, metadata: nil)
        
        // Should exist now
        let existsAfter = await retrieval.chunkExists(at: path)
        XCTAssertTrue(existsAfter)
    }
    
    func testFileSystemRetrievalDeleteChunk() async throws {
        let retrieval = FileSystemRetrieval(baseURL: tempDirectory)
        let testData = Data([0x0E, 0x0F])
        let path = "delete-test.dat"
        let metadata = ChunkMetadata(size: testData.count)
        
        // Write chunk with metadata
        try await retrieval.writeChunk(testData, at: path, metadata: metadata)
        
        // Verify both files exist
        let fileURL = tempDirectory.appendingPathComponent(path)
        let metadataURL = fileURL.appendingPathExtension("meta")
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: metadataURL.path))
        
        // Delete chunk
        try await retrieval.deleteChunk(at: path)
        
        // Verify both files are deleted
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: metadataURL.path))
    }
    
    func testFileSystemRetrievalDeleteChunkWithoutMetadata() async throws {
        let retrieval = FileSystemRetrieval(baseURL: tempDirectory)
        let testData = Data([0x10, 0x11])
        let path = "delete-no-meta.dat"
        
        // Write chunk without metadata
        try await retrieval.writeChunk(testData, at: path, metadata: nil)
        
        // Delete chunk (should not error even if metadata doesn't exist)
        try await retrieval.deleteChunk(at: path)
        
        // Verify file is deleted
        let fileURL = tempDirectory.appendingPathComponent(path)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
    }
    
    // MARK: - Protocol Conformance Tests
    
    func testFileSystemRetrievalSendable() {
        let retrieval = FileSystemRetrieval(baseURL: tempDirectory)
        // If this compiles, Sendable conformance is correct
        let _: ChunkStorageRetrieval = retrieval
    }
}

