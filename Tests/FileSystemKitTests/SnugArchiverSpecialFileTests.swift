// FileSystemKit Tests
// SnugArchiver Special File Handling Tests

import XCTest
@testable import FileSystemKit
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

final class SnugArchiverSpecialFileTests: SnugArchiverTestBase {
    
    func testSpecialFileDetectionForRegularFile() async throws {
        // Create a regular file
        let regularFile = tempDirectory.appendingPathComponent("regular.txt")
        try "test content".write(to: regularFile, atomically: true, encoding: .utf8)
        
        // Special file detection should return nil for regular files
        // Note: We can't directly test the private detectSpecialFile function,
        // but we can verify that regular files are processed normally
        let archiver = try await SnugArchiver(
            storageURL: storageURL,
            hashAlgorithm: "sha256"
        )
        
        let outputURL = tempDirectory.appendingPathComponent("archive.snug")
        _ = try await archiver.createArchive(
            from: tempDirectory,
            outputURL: outputURL,
            verbose: false,
            embedSystemFiles: false
        )
        
        // Load archive metadata to check entries using facade
        let facade = FileSystemKitArchiveFacade(storageURL: storageURL)
        let archive = try facade.loadMetadata(from: outputURL)
        
        // Regular file should be included
        let regularFileEntry = archive.entries.first { $0.path == "regular.txt" }
        XCTAssertNotNil(regularFileEntry, "Regular file should be included in archive")
        XCTAssertEqual(regularFileEntry?.type, "file", "Regular file should have type 'file'")
    }
    
    func testSpecialFileSkippedWhenEmbedSystemFilesFalse() async throws {
        // Create a FIFO (named pipe) - this is the easiest special file to create
        let fifoPath = tempDirectory.appendingPathComponent("test_fifo")
        
        // Create FIFO using mkfifo system call
        let path = fifoPath.path
        let result = mkfifo(path, 0o644)
        
        // If mkfifo fails (e.g., on some systems), skip this test
        guard result == 0 else {
            throw XCTSkip("Cannot create FIFO on this system (may require specific permissions)")
        }
        
        defer {
            // Clean up FIFO
            try? FileManager.default.removeItem(at: fifoPath)
        }
        
        let archiver = try await SnugArchiver(
            storageURL: storageURL,
            hashAlgorithm: "sha256"
        )
        
        // Archive with embedSystemFiles = false
        let outputURL = tempDirectory.appendingPathComponent("archive.snug")
        _ = try await archiver.createArchive(
            from: tempDirectory,
            outputURL: outputURL,
            verbose: false,
            embedSystemFiles: false
        )
        
        // Load archive metadata to check entries using facade
        let facade = FileSystemKitArchiveFacade(storageURL: storageURL)
        let archive = try facade.loadMetadata(from: outputURL)
        
        // FIFO should NOT be included when embedSystemFiles is false
        let fifoEntry = archive.entries.first { $0.path == "test_fifo" }
        XCTAssertNil(fifoEntry, "FIFO should be skipped when embedSystemFiles is false")
    }
    
    func testSpecialFileIncludedWhenEmbedSystemFilesTrue() async throws {
        // Create a FIFO (named pipe)
        let fifoPath = tempDirectory.appendingPathComponent("test_fifo")
        let path = fifoPath.path
        let result = mkfifo(path, 0o644)
        
        guard result == 0 else {
            throw XCTSkip("Cannot create FIFO on this system")
        }
        
        defer {
            try? FileManager.default.removeItem(at: fifoPath)
        }
        
        let archiver = try await SnugArchiver(
            storageURL: storageURL,
            hashAlgorithm: "sha256"
        )
        
        // Archive with embedSystemFiles = true
        let outputURL = tempDirectory.appendingPathComponent("archive.snug")
        _ = try await archiver.createArchive(
            from: tempDirectory,
            outputURL: outputURL,
            verbose: false,
            embedSystemFiles: true
        )
        
        // Load archive metadata to check entries using facade
        let facade = FileSystemKitArchiveFacade(storageURL: storageURL)
        let archive = try facade.loadMetadata(from: outputURL)
        
        // FIFO should be included when embedSystemFiles is true
        let fifoEntry = archive.entries.first { $0.path == "test_fifo" }
        XCTAssertNotNil(fifoEntry, "FIFO should be included when embedSystemFiles is true")
        XCTAssertEqual(fifoEntry?.type, "special", "FIFO should have type 'special'")
    }
    
    func testSpecialFileMetadataPreserved() async throws {
        // Create a FIFO
        let fifoPath = tempDirectory.appendingPathComponent("test_fifo")
        let path = fifoPath.path
        let result = mkfifo(path, 0o644)
        
        guard result == 0 else {
            throw XCTSkip("Cannot create FIFO on this system")
        }
        
        defer {
            try? FileManager.default.removeItem(at: fifoPath)
        }
        
        let archiver = try await SnugArchiver(
            storageURL: storageURL,
            hashAlgorithm: "sha256"
        )
        
        let outputURL = tempDirectory.appendingPathComponent("archive.snug")
        _ = try await archiver.createArchive(
            from: tempDirectory,
            outputURL: outputURL,
            verbose: false,
            embedSystemFiles: true
        )
        
        // Parse archive to check metadata using facade
        let facade = FileSystemKitArchiveFacade(storageURL: storageURL)
        let archive = try facade.loadMetadata(from: outputURL)
        
        let fifoEntry = archive.entries.first { $0.path == "test_fifo" }
        XCTAssertNotNil(fifoEntry, "FIFO should be included")
        
        // Verify metadata is preserved
        if let hash = fifoEntry?.hash {
            let identifier = ChunkIdentifier(id: hash)
            if let fileStorage = archiver.chunkStorage as? SnugFileSystemChunkStorage {
                let metadata = try fileStorage.readMetadata(identifier)
                XCTAssertNotNil(metadata)
                XCTAssertEqual(metadata?.chunkType, "special")
                XCTAssertNotNil(metadata?.originalFilename)
            }
        }
    }
    
    func testMultipleSpecialFilesHandled() async throws {
        // Create multiple FIFOs
        let fifo1 = tempDirectory.appendingPathComponent("fifo1")
        let fifo2 = tempDirectory.appendingPathComponent("fifo2")
        
        let result1 = mkfifo(fifo1.path, 0o644)
        let result2 = mkfifo(fifo2.path, 0o644)
        
        guard result1 == 0 && result2 == 0 else {
            throw XCTSkip("Cannot create FIFOs on this system")
        }
        
        defer {
            try? FileManager.default.removeItem(at: fifo1)
            try? FileManager.default.removeItem(at: fifo2)
        }
        
        let archiver = try await SnugArchiver(
            storageURL: storageURL,
            hashAlgorithm: "sha256"
        )
        
        let outputURL = tempDirectory.appendingPathComponent("archive.snug")
        _ = try await archiver.createArchive(
            from: tempDirectory,
            outputURL: outputURL,
            verbose: false,
            embedSystemFiles: true
        )
        
        let facade = FileSystemKitArchiveFacade(storageURL: storageURL)
        let archive = try facade.loadMetadata(from: outputURL)
        
        // Both FIFOs should be included
        let fifo1Entry = archive.entries.first { $0.path == "fifo1" }
        let fifo2Entry = archive.entries.first { $0.path == "fifo2" }
        
        XCTAssertNotNil(fifo1Entry, "First FIFO should be included")
        XCTAssertNotNil(fifo2Entry, "Second FIFO should be included")
    }
    
    func testSpecialFilesWithRegularFiles() async throws {
        // Create mix of regular files and special files
        let regularFile = tempDirectory.appendingPathComponent("regular.txt")
        try "test content".write(to: regularFile, atomically: true, encoding: .utf8)
        
        let fifoPath = tempDirectory.appendingPathComponent("test_fifo")
        let result = mkfifo(fifoPath.path, 0o644)
        
        guard result == 0 else {
            throw XCTSkip("Cannot create FIFO on this system")
        }
        
        defer {
            try? FileManager.default.removeItem(at: fifoPath)
        }
        
        let archiver = try await SnugArchiver(
            storageURL: storageURL,
            hashAlgorithm: "sha256"
        )
        
        let outputURL = tempDirectory.appendingPathComponent("archive.snug")
        _ = try await archiver.createArchive(
            from: tempDirectory,
            outputURL: outputURL,
            verbose: false,
            embedSystemFiles: true
        )
        
        let facade = FileSystemKitArchiveFacade(storageURL: storageURL)
        let archive = try facade.loadMetadata(from: outputURL)
        
        // Both should be included
        let regularEntry = archive.entries.first { $0.path == "regular.txt" }
        let fifoEntry = archive.entries.first { $0.path == "test_fifo" }
        
        XCTAssertNotNil(regularEntry, "Regular file should be included")
        XCTAssertNotNil(fifoEntry, "FIFO should be included")
        XCTAssertEqual(regularEntry?.type, "file")
        XCTAssertEqual(fifoEntry?.type, "special")
    }
}

