// FileSystemKit Tests
// SnugMirroredStorage Edge Case Unit Tests

import XCTest
@testable import FileSystemKit
import Foundation

final class SnugMirroredStorageEdgeCaseTests: SnugMirroredStorageTestBase {
    
    // MARK: - Glacier Mirroring Error Handling Tests
    
    func testGlacierMirroringDoesNotFailOperation() async throws {
        // Create a glacier storage that will fail
        let failingGlacierDir = tempGlacierDir.appendingPathComponent("failing")
        // Don't create directory, so writes will fail
        
        let failingGlacierStorage = SnugFileSystemChunkStorage(baseURL: failingGlacierDir)
        
        let mirroredStorage = SnugMirroredChunkStorage(
            primaryStorage: primaryStorage,
            mirrorStorages: [],
            glacierStorages: [failingGlacierStorage],
            failOnPrimaryError: true
        )
        
        let testData = Data("Test data".utf8)
        let identifier = ChunkIdentifier(id: "testhash")
        let metadata = ChunkMetadata(
            size: testData.count,
            contentHash: "testhash",
            hashAlgorithm: "sha256"
        )
        
        // Should succeed even if glacier write fails
        _ = try await mirroredStorage.writeChunk(testData, identifier: identifier, metadata: metadata)
        
        // Primary should still have the data
        let primaryData = try await primaryStorage.readChunk(identifier)
        XCTAssertNotNil(primaryData)
        XCTAssertEqual(primaryData, testData)
    }
    
    // MARK: - Concurrent Operations Tests
    
    func testConcurrentWritesToMultipleStorages() async throws {
        let mirroredStorage = SnugMirroredChunkStorage(
            primaryStorage: primaryStorage,
            mirrorStorages: [mirrorStorage],
            glacierStorages: [glacierStorage],
            failOnPrimaryError: true
        )
        
        // Write multiple chunks concurrently
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask {
                    let testData = Data("Concurrent test \(i)".utf8)
                    let identifier = ChunkIdentifier(id: "concurrent\(i)")
                    let metadata = ChunkMetadata(
                        size: testData.count,
                        contentHash: "concurrent\(i)",
                        hashAlgorithm: "sha256"
                    )
                    _ = try? await mirroredStorage.writeChunk(testData, identifier: identifier, metadata: metadata)
                }
            }
        }
        
        // Verify all chunks exist in all storages
        for i in 0..<10 {
            let identifier = ChunkIdentifier(id: "concurrent\(i)")
            let primaryExists = try await primaryStorage.chunkExists(identifier)
            let mirrorExists = try await mirrorStorage.chunkExists(identifier)
            let glacierExists = try await glacierStorage.chunkExists(identifier)
            XCTAssertTrue(primaryExists)
            XCTAssertTrue(mirrorExists)
            XCTAssertTrue(glacierExists)
        }
    }
}

