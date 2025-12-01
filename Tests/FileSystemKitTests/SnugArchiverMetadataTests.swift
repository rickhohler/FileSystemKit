// FileSystemKit Tests
// SnugArchiver Metadata Consistency Tests

import XCTest
@testable import FileSystemKit

final class SnugArchiverMetadataTests: SnugArchiverTestBase {
    
    func testChunkMetadataConsistency() async throws {
        let archiver = try await SnugArchiver(
            storageURL: storageURL,
            hashAlgorithm: "sha256"
        )
        
        // Create test file
        let testFile = tempDirectory.appendingPathComponent("test.txt")
        try "Test content".write(to: testFile, atomically: true, encoding: .utf8)
        
        // Archive it
        let testDir = tempDirectory.appendingPathComponent("testdir")
        try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
        try FileManager.default.moveItem(at: testFile, to: testDir.appendingPathComponent("test.txt"))
        
        let outputURL = tempDirectory.appendingPathComponent("archive.snug")
        let stats = try await archiver.createArchive(
            from: testDir,
            outputURL: outputURL,
            verbose: false
        )
        
        XCTAssertGreaterThan(stats.fileCount, 0)
        
        // Verify metadata structure matches ChunkMetadata using facade
        let facade = FileSystemKitArchiveFacade(storageURL: storageURL)
        let archive = try facade.loadMetadata(from: outputURL)
        let fileEntry = archive.entries.first { $0.path.contains("test.txt") }
        
        if let hash = fileEntry?.hash {
            let identifier = ChunkIdentifier(id: hash)
            // Cast to SnugFileSystemChunkStorage to access readMetadata
            if let fileStorage = archiver.chunkStorage as? SnugFileSystemChunkStorage {
                let metadata = try fileStorage.readMetadata(identifier)
                
                // Verify ChunkMetadata structure
                XCTAssertNotNil(metadata)
                XCTAssertEqual(metadata?.chunkType, "file")
                XCTAssertNotNil(metadata?.size)
                XCTAssertNotNil(metadata?.contentHash)
                XCTAssertNotNil(metadata?.hashAlgorithm)
                XCTAssertNotNil(metadata?.originalFilename)
                XCTAssertNotNil(metadata?.originalPaths)
            } else {
                // If not file storage, verify chunk exists
                let exists = try await archiver.chunkStorage.chunkExists(identifier)
                XCTAssertTrue(exists)
            }
        }
    }
}

