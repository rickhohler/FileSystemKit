// FileSystemKit Tests
// SnugExtractor Tests

import XCTest
@testable import FileSystemKit

final class SnugExtractorTests: SnugArchiverTestBase {
    
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
}

