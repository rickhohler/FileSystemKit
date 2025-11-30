// FileSystemKit Tests
// SnugArchiver Unit Tests

import XCTest
@testable import FileSystemKit
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

final class SnugArchiverTests: XCTestCase {
    var tempDirectory: URL!
    var storageURL: URL!
    
    override func setUp() async throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SnugArchiverTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        
        storageURL = tempDirectory.appendingPathComponent("storage")
        try FileManager.default.createDirectory(at: storageURL, withIntermediateDirectories: true)
    }
    
    override func tearDown() async throws {
        if let tempDirectory = tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
    }
    
    // MARK: - Initialization Tests
    
    func testInitWithStorageURL() async throws {
        let archiver = try await SnugArchiver(
            storageURL: storageURL,
            hashAlgorithm: "sha256"
        )
        
        // hashAlgorithm is private, so we can't test it directly
        // But we can verify the archiver was created successfully
        XCTAssertNotNil(archiver.chunkStorage)
    }
    
    func testInitWithCustomChunkStorage() async throws {
        let customStorage = SnugFileSystemChunkStorage(baseURL: storageURL)
        _ = SnugArchiver(
            chunkStorage: customStorage,
            hashAlgorithm: "sha256"
        )
        
        // hashAlgorithm is private, verify archiver was created
    }
    
    func testInitWithStorageProvider() async throws {
        // Note: SnugArchiver doesn't have a storageProvider initializer
        // It uses storageURL and checks config for custom providers
        // This test verifies the storageURL initializer works
        let archiver = try await SnugArchiver(
            storageURL: storageURL,
            hashAlgorithm: "sha256"
        )
        
        XCTAssertNotNil(archiver.chunkStorage)
    }
    
    func testInitWithProviderIdentifier() async throws {
        // Note: SnugArchiver doesn't have a providerIdentifier initializer
        // It uses storageURL and checks config for custom providers
        // This test verifies the storageURL initializer works
        let archiver = try await SnugArchiver(
            storageURL: storageURL,
            hashAlgorithm: "sha256"
        )
        
        XCTAssertNotNil(archiver.chunkStorage)
    }
    
    // MARK: - Disk Image Detection Tests
    // Note: File type detection is now handled by FileTypeDetector core type
    // See FileTypeDetectorTests.swift for comprehensive tests
    
    // MARK: - Archive Creation Tests
    
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
        
        let stats = try archiver.createArchive(
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
        
        let stats = try archiver.createArchive(
            from: testDir,
            outputURL: outputURL,
            verbose: false
        )
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
        XCTAssertGreaterThan(stats.fileCount, 0)
        
        // Verify that the chunk was stored with disk-image type
        // Read the archive and check metadata
        let parser = SnugParser()
        let archive = try parser.parseArchive(from: outputURL)
        
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
    
    // MARK: - Metadata Consistency Tests
    
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
        let stats = try archiver.createArchive(
            from: testDir,
            outputURL: outputURL,
            verbose: false
        )
        
        XCTAssertGreaterThan(stats.fileCount, 0)
        
        // Verify metadata structure matches ChunkMetadata
        let parser = SnugParser()
        let archive = try parser.parseArchive(from: outputURL)
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

// MARK: - SnugExtractor Tests

final class SnugExtractorTests: XCTestCase {
    var tempDirectory: URL!
    var storageURL: URL!
    
    override func setUp() async throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SnugExtractorTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        
        storageURL = tempDirectory.appendingPathComponent("storage")
        try FileManager.default.createDirectory(at: storageURL, withIntermediateDirectories: true)
    }
    
    override func tearDown() async throws {
        if let tempDirectory = tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
    }
    
    func testInitWithStorageURL() async throws {
        let extractor = try await SnugExtractor(storageURL: storageURL)
        XCTAssertNotNil(extractor.chunkStorage)
    }
    
    func testInitWithCustomChunkStorage() async throws {
        let customStorage = SnugFileSystemChunkStorage(baseURL: storageURL)
        let extractor = SnugExtractor(chunkStorage: customStorage)
        XCTAssertNotNil(extractor.chunkStorage)
    }
    
    func testInitWithStorageProvider() async throws {
        let provider = FileSystemChunkStorageProvider()
        let config = ["baseURL": storageURL.path] as [String: Any]
        
        let extractor = try await SnugExtractor(
            storageProvider: provider,
            storageConfiguration: config
        )
        XCTAssertNotNil(extractor.chunkStorage)
    }
    
    func testInitWithProviderIdentifier() async throws {
        await ChunkStorageProviderRegistry.shared.register(FileSystemChunkStorageProvider())
        
        let config = ["baseURL": storageURL.path] as [String: Any]
        let extractor = try await SnugExtractor(
            providerIdentifier: "filesystem",
            storageConfiguration: config
        )
        XCTAssertNotNil(extractor.chunkStorage)
    }
    
    // MARK: - Special File Tests
    
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
        _ = try archiver.createArchive(
            from: tempDirectory,
            outputURL: outputURL,
            verbose: false,
            embedSystemFiles: false
        )
        
        // Parse archive to check entries
        let parser = SnugParser()
        let archive = try parser.parseArchive(from: outputURL)
        
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
        _ = try archiver.createArchive(
            from: tempDirectory,
            outputURL: outputURL,
            verbose: false,
            embedSystemFiles: false
        )
        
        // Parse archive to check entries
        let parser = SnugParser()
        let archive = try parser.parseArchive(from: outputURL)
        
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
            throw XCTSkip("Cannot create FIFO on this system (may require specific permissions)")
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
        _ = try archiver.createArchive(
            from: tempDirectory,
            outputURL: outputURL,
            verbose: false,
            embedSystemFiles: true
        )
        
        // Parse archive to check entries
        let parser = SnugParser()
        let archive = try parser.parseArchive(from: outputURL)
        
        // FIFO should be included when embedSystemFiles is true
        let fifoEntry = archive.entries.first { $0.path == "test_fifo" }
        XCTAssertNotNil(fifoEntry, "FIFO should be included when embedSystemFiles is true")
        XCTAssertEqual(fifoEntry?.type, "fifo", "FIFO should have type 'fifo'")
        XCTAssertNil(fifoEntry?.hash, "Special files should not have hash")
        XCTAssertNil(fifoEntry?.size, "Special files should not have size")
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
        
        // Get file attributes before archiving
        let resourceValues = try fifoPath.resourceValues(forKeys: [.contentModificationDateKey, .creationDateKey])
        let expectedModified = resourceValues.contentModificationDate
        let expectedCreated = resourceValues.creationDate
        
        let archiver = try await SnugArchiver(
            storageURL: storageURL,
            hashAlgorithm: "sha256"
        )
        
        let outputURL = tempDirectory.appendingPathComponent("archive.snug")
        _ = try archiver.createArchive(
            from: tempDirectory,
            outputURL: outputURL,
            verbose: false,
            embedSystemFiles: true
        )
        
        // Parse archive to check entries
        let parser = SnugParser()
        let archive = try parser.parseArchive(from: outputURL)
        
        let fifoEntry = archive.entries.first { $0.path == "test_fifo" }
        XCTAssertNotNil(fifoEntry, "FIFO should be included")
        
        // Verify metadata is preserved (dates may be slightly different due to timing)
        if let expectedModified = expectedModified, let actualModified = fifoEntry?.modified {
            let timeDiff = abs(actualModified.timeIntervalSince(expectedModified))
            XCTAssertLessThan(timeDiff, 1.0, "Modification date should be preserved (within 1 second)")
        }
        
        if let expectedCreated = expectedCreated, let actualCreated = fifoEntry?.created {
            let timeDiff = abs(actualCreated.timeIntervalSince(expectedCreated))
            XCTAssertLessThan(timeDiff, 1.0, "Creation date should be preserved (within 1 second)")
        }
    }
    
    func testMultipleSpecialFilesHandled() async throws {
        // Create multiple FIFOs
        let fifo1 = tempDirectory.appendingPathComponent("fifo1")
        let fifo2 = tempDirectory.appendingPathComponent("fifo2")
        
        guard mkfifo(fifo1.path, 0o644) == 0 && mkfifo(fifo2.path, 0o644) == 0 else {
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
        _ = try archiver.createArchive(
            from: tempDirectory,
            outputURL: outputURL,
            verbose: false,
            embedSystemFiles: true
        )
        
        // Parse archive to check entries
        let parser = SnugParser()
        let archive = try parser.parseArchive(from: outputURL)
        
        // Both FIFOs should be included
        let fifo1Entry = archive.entries.first { $0.path == "fifo1" }
        let fifo2Entry = archive.entries.first { $0.path == "fifo2" }
        
        XCTAssertNotNil(fifo1Entry, "First FIFO should be included")
        XCTAssertNotNil(fifo2Entry, "Second FIFO should be included")
        XCTAssertEqual(fifo1Entry?.type, "fifo")
        XCTAssertEqual(fifo2Entry?.type, "fifo")
    }
    
    func testSpecialFilesWithRegularFiles() async throws {
        // Create mix of regular files and special files
        let regularFile = tempDirectory.appendingPathComponent("regular.txt")
        try "content".write(to: regularFile, atomically: true, encoding: .utf8)
        
        let fifoPath = tempDirectory.appendingPathComponent("test_fifo")
        guard mkfifo(fifoPath.path, 0o644) == 0 else {
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
        _ = try archiver.createArchive(
            from: tempDirectory,
            outputURL: outputURL,
            verbose: false,
            embedSystemFiles: true
        )
        
        // Parse archive to check entries
        let parser = SnugParser()
        let archive = try parser.parseArchive(from: outputURL)
        
        // Both should be included
        let regularEntry = archive.entries.first { $0.path == "regular.txt" }
        let fifoEntry = archive.entries.first { $0.path == "test_fifo" }
        
        XCTAssertNotNil(regularEntry, "Regular file should be included")
        XCTAssertNotNil(fifoEntry, "FIFO should be included")
        XCTAssertEqual(regularEntry?.type, "file")
        XCTAssertEqual(fifoEntry?.type, "fifo")
    }
}

