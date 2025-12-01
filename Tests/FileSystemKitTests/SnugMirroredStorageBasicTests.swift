// FileSystemKit Tests
// SnugMirroredStorage Basic Operations Unit Tests

import XCTest
@testable import FileSystemKit
import Foundation

final class SnugMirroredStorageBasicTests: SnugMirroredStorageTestBase {
    
    // MARK: - Glacier Mirroring Tests
    
    func testWriteChunkMirrorsToGlacierStorage() async throws {
        let mirroredStorage = SnugMirroredChunkStorage(
            primaryStorage: primaryStorage,
            mirrorStorages: [],
            glacierStorages: [glacierStorage],
            failOnPrimaryError: true
        )
        
        let testData = Data("Glacier test content".utf8)
        let identifier = ChunkIdentifier(id: "glacierhash123")
        let metadata = ChunkMetadata(
            size: testData.count,
            contentHash: "glacierhash123",
            hashAlgorithm: "sha256",
            originalFilename: "glacier-test.txt"
        )
        
        _ = try await mirroredStorage.writeChunk(testData, identifier: identifier, metadata: metadata)
        
        // Verify data exists in primary
        let primaryData = try await primaryStorage.readChunk(identifier)
        XCTAssertNotNil(primaryData)
        XCTAssertEqual(primaryData, testData)
        
        // Verify data exists in glacier storage
        let glacierData = try await glacierStorage.readChunk(identifier)
        XCTAssertNotNil(glacierData)
        XCTAssertEqual(glacierData, testData)
        
        // Verify metadata exists in both
        let primaryMetadata = try primaryStorage.readMetadata(identifier)
        let glacierMetadata = try glacierStorage.readMetadata(identifier)
        XCTAssertNotNil(primaryMetadata)
        XCTAssertNotNil(glacierMetadata)
        XCTAssertEqual(primaryMetadata?.originalFilename, "glacier-test.txt")
        XCTAssertEqual(glacierMetadata?.originalFilename, "glacier-test.txt")
    }
    
    func testWriteChunkMirrorsToMultipleGlacierStorages() async throws {
        let glacierStorage2 = SnugFileSystemChunkStorage(
            baseURL: tempGlacierDir.appendingPathComponent("glacier2")
        )
        try FileManager.default.createDirectory(
            at: tempGlacierDir.appendingPathComponent("glacier2"),
            withIntermediateDirectories: true
        )
        
        let mirroredStorage = SnugMirroredChunkStorage(
            primaryStorage: primaryStorage,
            mirrorStorages: [],
            glacierStorages: [glacierStorage, glacierStorage2],
            failOnPrimaryError: true
        )
        
        let testData = Data("Multi-glacier test".utf8)
        let identifier = ChunkIdentifier(id: "multiglacier")
        let metadata = ChunkMetadata(
            size: testData.count,
            contentHash: "multiglacier",
            hashAlgorithm: "sha256"
        )
        
        _ = try await mirroredStorage.writeChunk(testData, identifier: identifier, metadata: metadata)
        
        // Verify data exists in all glacier storages
        let glacier1Data = try await glacierStorage.readChunk(identifier)
        let glacier2Data = try await glacierStorage2.readChunk(identifier)
        
        XCTAssertNotNil(glacier1Data)
        XCTAssertNotNil(glacier2Data)
        XCTAssertEqual(glacier1Data, testData)
        XCTAssertEqual(glacier2Data, testData)
    }
    
    // MARK: - Read Operations Tests
    
    func testReadChunkFromPrimaryFirst() async throws {
        let mirroredStorage = SnugMirroredChunkStorage(
            primaryStorage: primaryStorage,
            mirrorStorages: [mirrorStorage],
            glacierStorages: [glacierStorage],
            failOnPrimaryError: true
        )
        
        let testData = Data("Primary read test".utf8)
        let identifier = ChunkIdentifier(id: "primaryread")
        
        // Write to primary only
        _ = try await primaryStorage.writeChunk(testData, identifier: ChunkIdentifier(id: "primaryread"), metadata: nil)
        
        // Read should come from primary
        let readData = try await mirroredStorage.readChunk(identifier)
        XCTAssertNotNil(readData)
        XCTAssertEqual(readData, testData)
        
        // Verify mirror and glacier weren't read from
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: tempMirrorDir.appendingPathComponent("pr").appendingPathComponent("im").appendingPathComponent("primaryread").path
        ))
    }
    
    func testReadChunkFallsBackToMirror() async throws {
        let mirroredStorage = SnugMirroredChunkStorage(
            primaryStorage: primaryStorage,
            mirrorStorages: [mirrorStorage],
            glacierStorages: [glacierStorage],
            failOnPrimaryError: true
        )
        
        let testData = Data("Mirror read test".utf8)
        let identifier = ChunkIdentifier(id: "mirrorread")
        
        // Write to mirror only (not primary)
        _ = try await mirrorStorage.writeChunk(testData, identifier: ChunkIdentifier(id: "mirrorread"), metadata: nil)
        
        // Read should come from mirror
        let readData = try await mirroredStorage.readChunk(identifier)
        XCTAssertNotNil(readData)
        XCTAssertEqual(readData, testData)
    }
    
    func testReadChunkFallsBackToGlacier() async throws {
        let mirroredStorage = SnugMirroredChunkStorage(
            primaryStorage: primaryStorage,
            mirrorStorages: [mirrorStorage],
            glacierStorages: [glacierStorage],
            failOnPrimaryError: true
        )
        
        let testData = Data("Glacier read test".utf8)
        let identifier = ChunkIdentifier(id: "glacierread")
        
        // Write to glacier only
        _ = try await glacierStorage.writeChunk(testData, identifier: ChunkIdentifier(id: "glacierread"), metadata: nil)
        
        // Read should come from glacier (after checking primary and mirror)
        let readData = try await mirroredStorage.readChunk(identifier)
        XCTAssertNotNil(readData)
        XCTAssertEqual(readData, testData)
    }
    
    // MARK: - Delete Operations Tests
    
    func testDeleteChunkRemovesFromAllStorages() async throws {
        let mirroredStorage = SnugMirroredChunkStorage(
            primaryStorage: primaryStorage,
            mirrorStorages: [mirrorStorage],
            glacierStorages: [glacierStorage],
            failOnPrimaryError: true
        )
        
        let testData = Data("Delete test".utf8)
        let identifier = ChunkIdentifier(id: "deletehash")
        
        // Write to all storages
        _ = try await primaryStorage.writeChunk(testData, identifier: identifier, metadata: nil)
        _ = try await mirrorStorage.writeChunk(testData, identifier: identifier, metadata: nil)
        _ = try await glacierStorage.writeChunk(testData, identifier: identifier, metadata: nil)
        
        // Verify all have the data
        let primaryChunk = try await primaryStorage.readChunk(identifier)
        let mirrorChunk = try await mirrorStorage.readChunk(identifier)
        let glacierChunk = try await glacierStorage.readChunk(identifier)
        XCTAssertNotNil(primaryChunk)
        XCTAssertNotNil(mirrorChunk)
        XCTAssertNotNil(glacierChunk)
        
        // Delete from mirrored storage
        try await mirroredStorage.deleteChunk(identifier)
        
        // Verify all are deleted
        let primaryResult = try await primaryStorage.readChunk(identifier)
        let mirrorResult = try await mirrorStorage.readChunk(identifier)
        let glacierResult = try await glacierStorage.readChunk(identifier)
        XCTAssertNil(primaryResult)
        XCTAssertNil(mirrorResult)
        XCTAssertNil(glacierResult)
    }
    
    // MARK: - Existence Checks Tests
    
    func testChunkExistsChecksAllStorages() async throws {
        let mirroredStorage = SnugMirroredChunkStorage(
            primaryStorage: primaryStorage,
            mirrorStorages: [mirrorStorage],
            glacierStorages: [glacierStorage],
            failOnPrimaryError: true
        )
        
        let testData = Data("Exists test".utf8)
        let identifier = ChunkIdentifier(id: "existshash")
        
        // Write only to glacier
        _ = try await glacierStorage.writeChunk(testData, identifier: identifier, metadata: nil)
        
        // Should find it in glacier
        let exists = try await mirroredStorage.chunkExists(identifier)
        XCTAssertTrue(exists)
    }
    
    func testChunkExistsReturnsFalseWhenNotInAnyStorage() async throws {
        let mirroredStorage = SnugMirroredChunkStorage(
            primaryStorage: primaryStorage,
            mirrorStorages: [mirrorStorage],
            glacierStorages: [glacierStorage],
            failOnPrimaryError: true
        )
        
        let identifier = ChunkIdentifier(id: "nonexistent")
        
        let exists = try await mirroredStorage.chunkExists(identifier)
        XCTAssertFalse(exists)
    }
}

