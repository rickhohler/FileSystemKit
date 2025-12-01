// FileSystemKit Tests
// FileHashCache operations tests (stats, remove, clear, concurrent access, computeHash)

import XCTest
@testable import FileSystemKit
import Foundation

final class FileHashCacheOperationsTests: FileHashCacheTestBase {
    
    // MARK: - Cache Statistics Tests
    
    func testGetStatsReturnsCorrectCount() async throws {
        let testFile1 = tempDirectory.appendingPathComponent("test1.txt")
        let testFile2 = tempDirectory.appendingPathComponent("test2.txt")
        
        try "content1".write(to: testFile1, atomically: true, encoding: .utf8)
        try "content2".write(to: testFile2, atomically: true, encoding: .utf8)
        
        let attrs1 = try FileManager.default.attributesOfItem(atPath: testFile1.path)
        await hashCache.setHash("hash1", for: testFile1, fileSize: attrs1[.size] as! Int64, modificationTime: attrs1[.modificationDate] as! Date)
        
        let attrs2 = try FileManager.default.attributesOfItem(atPath: testFile2.path)
        await hashCache.setHash("hash2", for: testFile2, fileSize: attrs2[.size] as! Int64, modificationTime: attrs2[.modificationDate] as! Date)
        
        let (count, maxSize) = await hashCache.getStats()
        XCTAssertEqual(count, 2, "Stats should reflect number of cached entries")
        XCTAssertEqual(maxSize, 100, "Stats should reflect max cache size")
    }
    
    // MARK: - Cache Operations Tests
    
    func testRemoveHashRemovesEntry() async throws {
        let testFile = tempDirectory.appendingPathComponent("test.txt")
        try "test content".write(to: testFile, atomically: true, encoding: .utf8)
        
        let attributes = try FileManager.default.attributesOfItem(atPath: testFile.path)
        let fileSize = attributes[.size] as! Int64
        let modificationTime = attributes[.modificationDate] as! Date
        
        await hashCache.setHash("hash", for: testFile, fileSize: fileSize, modificationTime: modificationTime)
        
        var hash = await hashCache.getHash(for: testFile)
        XCTAssertNotNil(hash, "Hash should be cached")
        
        await hashCache.removeHash(for: testFile)
        
        hash = await hashCache.getHash(for: testFile)
        XCTAssertNil(hash, "Hash should be nil after removal")
    }
    
    func testClearRemovesAllEntries() async throws {
        let testFile1 = tempDirectory.appendingPathComponent("test1.txt")
        let testFile2 = tempDirectory.appendingPathComponent("test2.txt")
        
        try "content1".write(to: testFile1, atomically: true, encoding: .utf8)
        try "content2".write(to: testFile2, atomically: true, encoding: .utf8)
        
        let attrs1 = try FileManager.default.attributesOfItem(atPath: testFile1.path)
        await hashCache.setHash("hash1", for: testFile1, fileSize: attrs1[.size] as! Int64, modificationTime: attrs1[.modificationDate] as! Date)
        
        let attrs2 = try FileManager.default.attributesOfItem(atPath: testFile2.path)
        await hashCache.setHash("hash2", for: testFile2, fileSize: attrs2[.size] as! Int64, modificationTime: attrs2[.modificationDate] as! Date)
        
        await hashCache.clear()
        
        let (count, _) = await hashCache.getStats()
        XCTAssertEqual(count, 0, "Cache should be empty after clear")
        
        let hash1 = await hashCache.getHash(for: testFile1)
        let hash2 = await hashCache.getHash(for: testFile2)
        XCTAssertNil(hash1, "Hash should be nil after clear")
        XCTAssertNil(hash2, "Hash should be nil after clear")
    }
    
    // MARK: - Concurrent Access Tests
    
    func testConcurrentSetHash() async throws {
        let testFiles = (0..<10).map { tempDirectory.appendingPathComponent("test\($0).txt") }
        
        // Create test files
        for file in testFiles {
            try "content".write(to: file, atomically: true, encoding: .utf8)
        }
        
        // Set hashes concurrently
        let cache = hashCache!
        await withTaskGroup(of: Void.self) { group in
            for (index, file) in testFiles.enumerated() {
                group.addTask { @Sendable in
                    let attributes = try? FileManager.default.attributesOfItem(atPath: file.path)
                    if let attrs = attributes {
                        let fileSize = attrs[.size] as! Int64
                        let modificationTime = attrs[.modificationDate] as! Date
                        await cache.setHash("hash\(index)", for: file, fileSize: fileSize, modificationTime: modificationTime)
                    }
                }
            }
        }
        
        // Verify all hashes are cached
        let (count, _) = await hashCache.getStats()
        XCTAssertEqual(count, 10, "All concurrent writes should succeed")
        
        for (index, file) in testFiles.enumerated() {
            let hash = await hashCache.getHash(for: file)
            XCTAssertEqual(hash, "hash\(index)", "Hash \(index) should be cached correctly")
        }
    }
    
    func testConcurrentGetHash() async throws {
        let testFile = tempDirectory.appendingPathComponent("test.txt")
        try "test content".write(to: testFile, atomically: true, encoding: .utf8)
        
        let attributes = try FileManager.default.attributesOfItem(atPath: testFile.path)
        let fileSize = attributes[.size] as! Int64
        let modificationTime = attributes[.modificationDate] as! Date
        
        await hashCache.setHash("concurrent-hash", for: testFile, fileSize: fileSize, modificationTime: modificationTime)
        
        // Read concurrently
        let cache = hashCache!
        var results: [String?] = []
        await withTaskGroup(of: String?.self) { group in
            for _ in 0..<10 {
                group.addTask { @Sendable in
                    await cache.getHash(for: testFile)
                }
            }
            
            for await result in group {
                results.append(result)
            }
        }
        
        // All reads should return the same hash
        for result in results {
            XCTAssertEqual(result, "concurrent-hash", "All concurrent reads should return same hash")
        }
    }
    
    // MARK: - computeHash Tests
    
    func testComputeHashSyncUsesCache() async throws {
        let testFile = tempDirectory.appendingPathComponent("test.txt")
        try "test content".write(to: testFile, atomically: true, encoding: .utf8)
        
        let testData = try Data(contentsOf: testFile)
        
        // First call should compute and cache
        let hash1 = try await hashCache.computeHash(for: testFile, data: testData, hashAlgorithm: "sha256")
        XCTAssertFalse(hash1.isEmpty, "Hash should be computed")
        
        // Second call should use cache
        let hash2 = try await hashCache.computeHash(for: testFile, data: testData, hashAlgorithm: "sha256")
        XCTAssertEqual(hash1, hash2, "Hash should be same (from cache)")
    }
    
    func testComputeHashSyncThrowsForUnsupportedAlgorithm() async throws {
        let testFile = tempDirectory.appendingPathComponent("test.txt")
        try "test content".write(to: testFile, atomically: true, encoding: .utf8)
        
        let testData = try Data(contentsOf: testFile)
        
        do {
            _ = try await hashCache.computeHash(for: testFile, data: testData, hashAlgorithm: "unsupported")
            XCTFail("Should throw error for unsupported algorithm")
        } catch {
            XCTAssertTrue(error is SnugError, "Should throw SnugError for unsupported algorithm")
            if case SnugError.unsupportedHashAlgorithm(let algorithm) = error {
                XCTAssertEqual(algorithm, "unsupported")
            } else {
                XCTFail("Should throw unsupportedHashAlgorithm error")
            }
        }
    }
}

