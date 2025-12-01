// FileSystemKit Tests
// SnugArchiver Archive Creation Tests

import XCTest
@testable import FileSystemKit

final class SnugArchiverCreationTests: SnugArchiverTestBase {
    
    func testCreateArchiveWithRegularFile() async throws {
        let archiver = try await SnugArchiver(
            storageURL: storageURL,
            hashAlgorithm: "sha256"
        )
        
        // Create test directory with a file
        let testDir = tempDirectory.appendingPathComponent("testdir")
        try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
        
        let testFile = testDir.appendingPathComponent("test.txt")
        try "Hello, World!".write(to: testFile, atomically: true, encoding: .utf8)
        
        let outputURL = tempDirectory.appendingPathComponent("archive.snug")
        
        let stats = try await archiver.createArchive(
            from: testDir,
            outputURL: outputURL,
            verbose: false
        )
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
        XCTAssertGreaterThan(stats.fileCount, 0)
        XCTAssertGreaterThan(stats.totalSize, 0)
    }
    
    func testCreateArchiveWithDiskImage() async throws {
        let archiver = try await SnugArchiver(
            storageURL: storageURL,
            hashAlgorithm: "sha256"
        )
        
        // Create test directory with a DMG file
        let testDir = tempDirectory.appendingPathComponent("testdir")
        try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
        
        let testFile = testDir.appendingPathComponent("test.dmg")
        var dmgData = Data(count: 1024)
        let kolySignature = Data([0x6B, 0x6F, 0x6C, 0x79])
        dmgData.replaceSubrange((dmgData.count - 512)..<(dmgData.count - 512 + 4), with: kolySignature)
        try dmgData.write(to: testFile)
        
        let outputURL = tempDirectory.appendingPathComponent("archive.snug")
        
        let stats = try await archiver.createArchive(
            from: testDir,
            outputURL: outputURL,
            verbose: false
        )
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
        XCTAssertGreaterThan(stats.fileCount, 0)
        
        // Verify that the chunk was stored with disk-image type
        // Read the archive and check metadata using facade
        let facade = FileSystemKitArchiveFacade(storageURL: storageURL)
        let archive = try facade.loadMetadata(from: outputURL)
        
        // Find the DMG file entry
        let dmgEntry = archive.entries.first { $0.path.contains("test.dmg") }
        XCTAssertNotNil(dmgEntry)
        
        if let hash = dmgEntry?.hash {
            let identifier = ChunkIdentifier(id: hash)
            // Cast to SnugFileSystemChunkStorage to access readMetadata
            if let fileStorage = archiver.chunkStorage as? SnugFileSystemChunkStorage {
                let metadata = try fileStorage.readMetadata(identifier)
                
                XCTAssertEqual(metadata?.chunkType, "disk-image")
                XCTAssertEqual(metadata?.contentType, "application/x-apple-diskimage")
            } else {
                // If not file storage, verify chunk exists
                let exists = try await archiver.chunkStorage.chunkExists(identifier)
                XCTAssertTrue(exists)
            }
        }
    }
}

