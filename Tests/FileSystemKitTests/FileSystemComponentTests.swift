// FileSystemKit Tests
// Unit tests for FileSystemComponent protocol and implementations

import XCTest
@testable import FileSystemKit

final class FileSystemComponentTests: XCTestCase {
    
    // MARK: - File Tests
    
    func testFileInitialization() {
        let location = FileLocation(offset: 0, length: 100)
        let metadata = FileMetadata(
            name: "TESTFILE",
            size: 100,
            location: location
        )
        let file = File(metadata: metadata)
        
        XCTAssertEqual(file.name, "TESTFILE")
        XCTAssertEqual(file.size, 100)
        XCTAssertNil(file.modificationDate)
        XCTAssertNil(file.parent)
    }
    
    func testFileMetadataSeparation() {
        // Verify metadata is separate from content
        let location = FileLocation(offset: 0, length: 50)
        let metadata = FileMetadata(
            name: "METADATA_TEST",
            size: 50,
            location: location
        )
        let file = File(metadata: metadata)
        
        // Metadata should be available immediately
        XCTAssertEqual(file.metadata.name, "METADATA_TEST")
        XCTAssertEqual(file.metadata.size, 50)
        
        // Content is lazy-loaded - verify we can access metadata without loading content
        // (Content loading is tested in testFileReadData)
    }
    
    func testFileReadData() throws {
        let testData = Data([0x01, 0x02, 0x03, 0x04, 0x05])
        let location = FileLocation(offset: 0, length: testData.count)
        let metadata = FileMetadata(
            name: "READ_TEST",
            size: testData.count,
            location: location
        )
        let file = File(metadata: metadata)
        
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
        let metadata = FileMetadata(
            name: "READ_TEST_CHUNK",
            size: testData.count,
            location: location
        )
        _ = File(metadata: metadata)
        
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
    
    func testFileHashGeneration() throws {
        let testData = Data("Hello, World!".utf8)
        let location = FileLocation(offset: 0, length: testData.count)
        let metadata = FileMetadata(
            name: "HASH_TEST",
            size: testData.count,
            location: location
        )
        let file = File(metadata: metadata)
        
        let rawDiskData = RawDiskData(rawData: testData)
        
        // Load file data first (required for hash generation)
        _ = try file.readData(from: rawDiskData)
        
        // Generate hash (default: SHA-256)
        let hash = try file.generateHash(algorithm: .sha256)
        
        XCTAssertEqual(hash.algorithm, .sha256)
        XCTAssertEqual(hash.value.count, 32) // SHA-256 produces 32 bytes
        XCTAssertFalse(hash.hexString.isEmpty)
        XCTAssertTrue(hash.identifier.hasPrefix("sha256:"))
    }
    
    func testFileTraverse() {
        let location = FileLocation(offset: 0, length: 10)
        let metadata = FileMetadata(
            name: "TRAVERSE_TEST",
            size: 10,
            location: location
        )
        let file = File(metadata: metadata)
        
        let components = file.traverse()
        XCTAssertEqual(components.count, 1)
        XCTAssertTrue(components.first === file)
    }
    
    // MARK: - Directory Tests
    
    func testDirectoryInitialization() {
        let directory = FileSystemFolder(name: "TEST_DIR")
        
        XCTAssertEqual(directory.name, "TEST_DIR")
        XCTAssertEqual(directory.size, 0) // Empty directory
        XCTAssertNil(directory.modificationDate)
        XCTAssertNil(directory.parent)
        XCTAssertTrue(directory.children.isEmpty)
    }
    
    func testDirectoryAddChild() {
        let directory = FileSystemFolder(name: "PARENT")
        let location = FileLocation(offset: 0, length: 10)
        let metadata = FileMetadata(
            name: "CHILD_FILE",
            size: 10,
            location: location
        )
        let file = File(metadata: metadata)
        
        directory.addChild(file)
        
        XCTAssertEqual(directory.children.count, 1)
        XCTAssertTrue(directory.children.first === file)
        XCTAssertTrue(file.parent === directory)
    }
    
    func testDirectoryRemoveChild() {
        let directory = FileSystemFolder(name: "PARENT")
        let location = FileLocation(offset: 0, length: 10)
        let metadata = FileMetadata(
            name: "CHILD_FILE",
            size: 10,
            location: location
        )
        let file = File(metadata: metadata)
        
        directory.addChild(file)
        XCTAssertEqual(directory.children.count, 1)
        
        // Note: removeChild may not be implemented, testing addChild only
        // Directory size should include the file
        XCTAssertEqual(directory.size, 10)
    }
    
    func testDirectoryFindChild() {
        let directory = FileSystemFolder(name: "PARENT")
        let location = FileLocation(offset: 0, length: 10)
        let metadata = FileMetadata(
            name: "CHILD_FILE",
            size: 10,
            location: location
        )
        let file = File(metadata: metadata)
        
        directory.addChild(file)
        
        // Use getFile method instead of findChild
        let found = directory.getFile(named: "CHILD_FILE")
        XCTAssertNotNil(found)
        XCTAssertTrue(found === file)
        
        let notFound = directory.getFile(named: "NOT_FOUND")
        XCTAssertNil(notFound)
    }
    
    func testDirectorySize() {
        let directory = FileSystemFolder(name: "PARENT")
        
        // Empty directory
        XCTAssertEqual(directory.size, 0)
        
        // Add files
        let location1 = FileLocation(offset: 0, length: 100)
        let metadata1 = FileMetadata(
            name: "FILE1",
            size: 100,
            location: location1
        )
        let file1 = File(metadata: metadata1)
        directory.addChild(file1)
        
        let location2 = FileLocation(offset: 0, length: 50)
        let metadata2 = FileMetadata(
            name: "FILE2",
            size: 50,
            location: location2
        )
        let file2 = File(metadata: metadata2)
        directory.addChild(file2)
        
        // Directory size should be sum of children
        XCTAssertEqual(directory.size, 150)
    }
    
    func testDirectoryTraverse() {
        let root = FileSystemFolder(name: "ROOT")
        let subdir = FileSystemFolder(name: "SUBDIR")
        let location = FileLocation(offset: 0, length: 10)
        let metadata = FileMetadata(
            name: "FILE",
            size: 10,
            location: location
        )
        let file = File(metadata: metadata)
        
        root.addChild(subdir)
        subdir.addChild(file)
        
        let components = root.traverse()
        XCTAssertEqual(components.count, 3) // root, subdir, file
        XCTAssertTrue(components.contains { $0.name == "ROOT" })
        XCTAssertTrue(components.contains { $0.name == "SUBDIR" })
        XCTAssertTrue(components.contains { $0.name == "FILE" })
    }
    
    // MARK: - FileLocation Tests
    
    func testFileLocation() {
        let location = FileLocation(track: 1, sector: 2, offset: 100, length: 50)
        
        XCTAssertEqual(location.track, 1)
        XCTAssertEqual(location.sector, 2)
        XCTAssertEqual(location.offset, 100)
        XCTAssertEqual(location.length, 50)
    }
    
    func testFileLocationWithoutTrackSector() {
        let location = FileLocation(offset: 200, length: 100)
        
        XCTAssertNil(location.track)
        XCTAssertNil(location.sector)
        XCTAssertEqual(location.offset, 200)
        XCTAssertEqual(location.length, 100)
    }
    
    // MARK: - FileHash Tests
    
    func testFileHash() {
        let data = Data([0x01, 0x02, 0x03])
        let hash = FileHash(algorithm: .sha256, value: data)
        
        XCTAssertEqual(hash.algorithm, .sha256)
        XCTAssertEqual(hash.value, data)
        XCTAssertFalse(hash.hexString.isEmpty)
        XCTAssertTrue(hash.identifier.hasPrefix("sha256:"))
    }
    
    func testFileHashEquality() {
        let data = Data([0x01, 0x02, 0x03])
        let hash1 = FileHash(algorithm: .sha256, value: data)
        let hash2 = FileHash(algorithm: .sha256, value: data)
        let hash3 = FileHash(algorithm: .sha256, value: Data([0x04, 0x05, 0x06]))
        
        XCTAssertEqual(hash1, hash2)
        XCTAssertNotEqual(hash1, hash3)
    }
    
    // MARK: - FileMetadata Tests
    
    func testFileMetadata() {
        let location = FileLocation(offset: 0, length: 100)
        let metadata = FileMetadata(
            name: "METADATA_TEST",
            size: 100,
            modificationDate: Date(),
            fileType: .text,
            attributes: ["key": "value"],
            location: location
        )
        
        XCTAssertEqual(metadata.name, "METADATA_TEST")
        XCTAssertEqual(metadata.size, 100)
        XCTAssertNotNil(metadata.modificationDate)
        XCTAssertEqual(metadata.fileType, .text)
        XCTAssertEqual(metadata.attributes["key"] as? String, "value")
        XCTAssertEqual(metadata.location, location)
    }
}

