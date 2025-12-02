// FileSystemKit Tests
// Basic unit tests for ComposableFileSystemChunkStorage implementation

import XCTest
@testable import FileSystemKit

final class ComposableFileSystemChunkStorageBasicTests: XCTestCase {
    var tempDirectory: URL!
    
    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("composable-storage-basic-test-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        tempDirectory = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testComposableFileSystemChunkStorageDefaultInit() {
        let storage = ComposableFileSystemChunkStorage(baseURL: tempDirectory)
        
        XCTAssertEqual(storage.organization.name, "git-style")
        XCTAssertNotNil(storage.retrieval)
        XCTAssertNotNil(storage.existence)
    }
    
    func testComposableFileSystemChunkStorageCustomOrganization() {
        let flatOrg = FlatOrganization()
        let storage = ComposableFileSystemChunkStorage(baseURL: tempDirectory, organization: flatOrg)
        
        XCTAssertEqual(storage.organization.name, "flat")
        XCTAssertNotNil(storage.retrieval)
        XCTAssertNotNil(storage.existence)
    }
    
    func testComposableFileSystemChunkStorageConformsToChunkStorageComposable() {
        let storage = ComposableFileSystemChunkStorage(baseURL: tempDirectory)
        
        // If this compiles, conformance is correct
        let _: ChunkStorageComposable = storage
        let _: ChunkStorage = storage
    }
    
    // MARK: - Organization Strategy Tests
    
    func testStorageUsesGitStyleOrganization() async throws {
        let storage = ComposableFileSystemChunkStorage(baseURL: tempDirectory)
        let testData = Data([0x01])
        let hash = "a1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456"
        let identifier = ChunkIdentifier(id: hash)
        
        _ = try await storage.writeChunk(testData, identifier: identifier, metadata: nil)
        
        // Verify Git-style path was created
        let path = storage.organization.storagePath(for: identifier)
        let fileURL = tempDirectory.appendingPathComponent(path)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
        XCTAssertTrue(path.hasPrefix("a1/b2/"))
    }
    
    func testStorageUsesFlatOrganization() async throws {
        let flatOrg = FlatOrganization()
        let storage = ComposableFileSystemChunkStorage(baseURL: tempDirectory, organization: flatOrg)
        let testData = Data([0x01])
        let hash = "a1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456"
        let identifier = ChunkIdentifier(id: hash)
        
        _ = try await storage.writeChunk(testData, identifier: identifier, metadata: nil)
        
        // Verify flat path was created
        let path = storage.organization.storagePath(for: identifier)
        let fileURL = tempDirectory.appendingPathComponent(path)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
        XCTAssertEqual(path, hash)
    }
}

