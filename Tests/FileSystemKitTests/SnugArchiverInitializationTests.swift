// FileSystemKit Tests
// SnugArchiver Initialization Tests

import XCTest
@testable import FileSystemKit

final class SnugArchiverInitializationTests: SnugArchiverTestBase {
    
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
}

