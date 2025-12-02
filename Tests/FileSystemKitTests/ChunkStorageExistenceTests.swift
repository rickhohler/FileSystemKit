// FileSystemKit Tests
// Unit tests for ChunkStorageExistence protocol and implementations

import XCTest
@testable import FileSystemKit

final class ChunkStorageExistenceTests: XCTestCase {
    var tempDirectory: URL!
    var organization: ChunkStorageOrganization!
    
    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("chunk-existence-test-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        organization = GitStyleOrganization(directoryDepth: 2)
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        tempDirectory = nil
        organization = nil
        super.tearDown()
    }
    
    // MARK: - FileSystemExistence Tests
    
    func testFileSystemExistenceChunkExists() async throws {
        let existence = FileSystemExistence(organization: organization, baseURL: tempDirectory)
        let hash = "a1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456"
        let identifier = ChunkIdentifier(id: hash)
        
        // Should not exist initially
        let existsBefore = await existence.chunkExists(identifier: identifier)
        XCTAssertFalse(existsBefore)
        
        // Create the chunk file
        let path = organization.storagePath(for: identifier)
        let fileURL = tempDirectory.appendingPathComponent(path)
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data([0x01, 0x02]).write(to: fileURL)
        
        // Should exist now
        let existsAfter = await existence.chunkExists(identifier: identifier)
        XCTAssertTrue(existsAfter)
    }
    
    func testFileSystemExistenceChunkExistsBatch() async throws {
        let existence = FileSystemExistence(organization: organization, baseURL: tempDirectory)
        
        let hash1 = "a1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456"
        let hash2 = "b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef12345678"
        let hash3 = "c3d4e5f6789012345678901234567890abcdef1234567890abcdef1234567890"
        
        let identifier1 = ChunkIdentifier(id: hash1)
        let identifier2 = ChunkIdentifier(id: hash2)
        let identifier3 = ChunkIdentifier(id: hash3)
        
        // Create only first two chunks
        let path1 = organization.storagePath(for: identifier1)
        let path2 = organization.storagePath(for: identifier2)
        
        let fileURL1 = tempDirectory.appendingPathComponent(path1)
        let fileURL2 = tempDirectory.appendingPathComponent(path2)
        
        try FileManager.default.createDirectory(
            at: fileURL1.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: fileURL2.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        
        try Data([0x01]).write(to: fileURL1)
        try Data([0x02]).write(to: fileURL2)
        
        // Batch check existence
        let results = await existence.chunkExists(identifiers: [identifier1, identifier2, identifier3])
        
        XCTAssertEqual(results.count, 3)
        XCTAssertTrue(results[identifier1] ?? false)
        XCTAssertTrue(results[identifier2] ?? false)
        XCTAssertFalse(results[identifier3] ?? false)
    }
    
    func testFileSystemExistenceChunkExistsBatchEmpty() async {
        let existence = FileSystemExistence(organization: organization, baseURL: tempDirectory)
        
        let results = await existence.chunkExists(identifiers: [])
        
        XCTAssertEqual(results.count, 0)
    }
    
    func testFileSystemExistenceChunkExistsWithFlatOrganization() async throws {
        let flatOrg = FlatOrganization()
        let existence = FileSystemExistence(organization: flatOrg, baseURL: tempDirectory)
        let hash = "a1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456"
        let identifier = ChunkIdentifier(id: hash)
        
        // Create chunk file (flat path)
        let path = flatOrg.storagePath(for: identifier)
        let fileURL = tempDirectory.appendingPathComponent(path)
        try Data([0x03]).write(to: fileURL)
        
        // Should exist
        let exists = await existence.chunkExists(identifier: identifier)
        XCTAssertTrue(exists)
    }
    
    // MARK: - Protocol Conformance Tests
    
    func testFileSystemExistenceSendable() {
        let existence = FileSystemExistence(organization: organization, baseURL: tempDirectory)
        // If this compiles, Sendable conformance is correct
        let _: ChunkStorageExistence = existence
    }
}

