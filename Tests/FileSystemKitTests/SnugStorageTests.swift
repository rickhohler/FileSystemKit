// FileSystemKit Tests
// Unit tests for SNUG Storage features: metadata persistence, volume types, glacier mirroring

import XCTest
@testable import FileSystemKit
import Foundation

final class SnugStorageTests: XCTestCase {
    var tempDirectory: URL!
    var storage: SnugFileSystemChunkStorage!
    
    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("snug-test-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        storage = SnugFileSystemChunkStorage(baseURL: tempDirectory)
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        tempDirectory = nil
        storage = nil
        super.tearDown()
    }
    
    // MARK: - Metadata Persistence Tests
    
    func testWriteChunkCreatesMetadataFile() async throws {
        let testData = Data("Hello, World!".utf8)
        let identifier = ChunkIdentifier(id: "abc123def456")
        let metadata = ChunkMetadata(
            size: testData.count,
            contentHash: "abc123def456",
            hashAlgorithm: "sha256",
            originalFilename: "test.txt",
            originalPaths: ["test.txt"],
            created: Date(),
            modified: Date()
        )
        
        _ = try await storage.writeChunk(testData, identifier: identifier, metadata: metadata)
        
        // Verify data file exists
        let dataFile = tempDirectory
            .appendingPathComponent("ab")
            .appendingPathComponent("c1")
            .appendingPathComponent("abc123def456")
        XCTAssertTrue(FileManager.default.fileExists(atPath: dataFile.path), "Data file should exist")
        
        // Verify metadata file exists
        let metadataFile = dataFile.appendingPathExtension("meta")
        XCTAssertTrue(FileManager.default.fileExists(atPath: metadataFile.path), "Metadata file should exist")
        
        // Verify metadata content
        let readMetadata = try storage.readMetadata(identifier)
        XCTAssertNotNil(readMetadata, "Should be able to read metadata")
        XCTAssertEqual(readMetadata?.originalFilename, "test.txt")
        XCTAssertEqual(readMetadata?.size, testData.count)
        XCTAssertEqual(readMetadata?.hashAlgorithm, "sha256")
        XCTAssertNotNil(readMetadata?.created)
        XCTAssertNotNil(readMetadata?.modified)
    }
    
    func testMetadataFileContainsAllFields() async throws {
        let testData = Data("Test content".utf8)
        let identifier = ChunkIdentifier(id: "testhash123")
        let createdDate = Date(timeIntervalSince1970: 1609459200) // 2021-01-01
        let modifiedDate = Date(timeIntervalSince1970: 1640995200) // 2022-01-01
        
        let metadata = ChunkMetadata(
            size: testData.count,
            contentHash: "testhash123",
            hashAlgorithm: "sha256",
            contentType: "text/plain",
            chunkType: "file",
            originalFilename: "document.txt",
            originalPaths: ["documents/document.txt", "backup/document.txt"],
            created: createdDate,
            modified: modifiedDate
        )
        
        _ = try await storage.writeChunk(testData, identifier: identifier, metadata: metadata)
        
        let readMetadata = try storage.readMetadata(identifier)
        XCTAssertNotNil(readMetadata)
        XCTAssertEqual(readMetadata?.size, testData.count)
        XCTAssertEqual(readMetadata?.contentHash, "testhash123")
        XCTAssertEqual(readMetadata?.hashAlgorithm, "sha256")
        XCTAssertEqual(readMetadata?.contentType, "text/plain")
        XCTAssertEqual(readMetadata?.chunkType, "file")
        XCTAssertEqual(readMetadata?.originalFilename, "document.txt")
        XCTAssertEqual(readMetadata?.originalPaths?.count, 2)
        XCTAssertTrue(readMetadata?.originalPaths?.contains("documents/document.txt") ?? false)
        XCTAssertTrue(readMetadata?.originalPaths?.contains("backup/document.txt") ?? false)
        XCTAssertEqual(readMetadata?.created, createdDate)
        XCTAssertEqual(readMetadata?.modified, modifiedDate)
    }
    
    func testMetadataMergingOnDeduplication() async throws {
        let testData = Data("Same content".utf8)
        let hash = "samehash123"
        let identifier = ChunkIdentifier(id: hash)
        
        // First write
        let metadata1 = ChunkMetadata(
            size: testData.count,
            contentHash: hash,
            hashAlgorithm: "sha256",
            originalFilename: "file1.txt",
            originalPaths: ["dir1/file1.txt"],
            created: Date(timeIntervalSince1970: 1609459200),
            modified: Date(timeIntervalSince1970: 1609459200)
        )
        
        _ = try await storage.writeChunk(testData, identifier: identifier, metadata: metadata1)
        
        // Second write with same hash (deduplication)
        let metadata2 = ChunkMetadata(
            size: testData.count,
            contentHash: hash,
            hashAlgorithm: "sha256",
            originalFilename: "file2.txt",
            originalPaths: ["dir2/file2.txt"],
            created: Date(timeIntervalSince1970: 1609545600), // Later date
            modified: Date(timeIntervalSince1970: 1609545600) // Later date
        )
        
        _ = try await storage.writeChunk(testData, identifier: identifier, metadata: metadata2)
        
        // Verify metadata was merged
        let mergedMetadata = try storage.readMetadata(identifier)
        XCTAssertNotNil(mergedMetadata)
        
        // Should have both original paths
        XCTAssertEqual(mergedMetadata?.originalPaths?.count, 2)
        XCTAssertTrue(mergedMetadata?.originalPaths?.contains("dir1/file1.txt") ?? false)
        XCTAssertTrue(mergedMetadata?.originalPaths?.contains("dir2/file2.txt") ?? false)
        
        // Should use earliest created date
        XCTAssertEqual(mergedMetadata?.created, Date(timeIntervalSince1970: 1609459200))
        
        // Should use latest modified date
        XCTAssertEqual(mergedMetadata?.modified, Date(timeIntervalSince1970: 1609545600))
        
        // Original filename should be from first write (or could be either)
        XCTAssertNotNil(mergedMetadata?.originalFilename)
    }
    
    func testMetadataMergingPreservesAllFields() async throws {
        let testData = Data("Content".utf8)
        let identifier = ChunkIdentifier(id: "hash456")
        
        // First write with compression info
        let compression1 = CompressionInfo(algorithm: "gzip", uncompressedSize: 100, compressedSize: 50)
        let metadata1 = ChunkMetadata(
            size: testData.count,
            contentHash: "hash456",
            hashAlgorithm: "sha256",
            contentType: "text/plain",
            chunkType: "file",
            originalFilename: "file1.txt",
            originalPaths: ["path1/file1.txt"],
            created: Date(timeIntervalSince1970: 1609459200),
            modified: Date(timeIntervalSince1970: 1609459200),
            compression: compression1
        )
        
        _ = try await storage.writeChunk(testData, identifier: identifier, metadata: metadata1)
        
        // Second write without compression
        let metadata2 = ChunkMetadata(
            size: testData.count,
            contentHash: "hash456",
            hashAlgorithm: "sha256",
            contentType: "text/html", // Different content type
            chunkType: "file",
            originalFilename: "file2.html",
            originalPaths: ["path2/file2.html"],
            created: Date(timeIntervalSince1970: 1609545600),
            modified: Date(timeIntervalSince1970: 1609545600)
        )
        
        _ = try await storage.writeChunk(testData, identifier: identifier, metadata: metadata2)
        
        let mergedMetadata = try storage.readMetadata(identifier)
        XCTAssertNotNil(mergedMetadata)
        
        // Compression should be preserved from first write
        XCTAssertNotNil(mergedMetadata?.compression)
        XCTAssertEqual(mergedMetadata?.compression?.algorithm, "gzip")
        
        // Content type should be from first write
        XCTAssertEqual(mergedMetadata?.contentType, "text/plain")
        
        // Should have both paths
        XCTAssertEqual(mergedMetadata?.originalPaths?.count, 2)
    }
    
    func testDeleteChunkRemovesMetadataFile() async throws {
        let testData = Data("Test".utf8)
        let identifier = ChunkIdentifier(id: "deletehash")
        let metadata = ChunkMetadata(
            size: testData.count,
            contentHash: "deletehash",
            hashAlgorithm: "sha256",
            originalFilename: "delete.txt"
        )
        
        _ = try await storage.writeChunk(testData, identifier: identifier, metadata: metadata)
        
        // Verify both files exist
        let dataFile = tempDirectory
            .appendingPathComponent("de")
            .appendingPathComponent("le")
            .appendingPathComponent("deletehash")
        let metadataFile = dataFile.appendingPathExtension("meta")
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: dataFile.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: metadataFile.path))
        
        // Delete chunk
        try await storage.deleteChunk(identifier)
        
        // Verify both files are deleted
        XCTAssertFalse(FileManager.default.fileExists(atPath: dataFile.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: metadataFile.path))
        
        // Verify metadata read returns nil
        let readMetadata = try storage.readMetadata(identifier)
        XCTAssertNil(readMetadata)
    }
    
    func testReadMetadataReturnsNilWhenNotExists() throws {
        let identifier = ChunkIdentifier(id: "nonexistent")
        let metadata = try storage.readMetadata(identifier)
        XCTAssertNil(metadata)
    }
    
    func testMetadataFileIsValidJSON() async throws {
        let testData = Data("JSON test".utf8)
        let identifier = ChunkIdentifier(id: "jsonhash")
        let metadata = ChunkMetadata(
            size: testData.count,
            contentHash: "jsonhash",
            hashAlgorithm: "sha256",
            originalFilename: "test.json",
            originalPaths: ["data/test.json"],
            created: Date(),
            modified: Date()
        )
        
        _ = try await storage.writeChunk(testData, identifier: identifier, metadata: metadata)
        
        // Read metadata file directly and verify it's valid JSON
        let dataFile = tempDirectory
            .appendingPathComponent("js")
            .appendingPathComponent("on")
            .appendingPathComponent("jsonhash")
        let metadataFile = dataFile.appendingPathExtension("meta")
        
        let jsonData = try Data(contentsOf: metadataFile)
        let jsonObject = try JSONSerialization.jsonObject(with: jsonData)
        XCTAssertNotNil(jsonObject)
        
        // Verify it can be decoded
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decodedMetadata = try decoder.decode(ChunkMetadata.self, from: jsonData)
        XCTAssertEqual(decodedMetadata.originalFilename, "test.json")
    }
}

