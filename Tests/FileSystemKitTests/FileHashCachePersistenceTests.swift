// FileSystemKit Tests
// FileHashCache persistence tests (save/load from disk)

import XCTest
@testable import FileSystemKit
import Foundation

final class FileHashCachePersistenceTests: FileHashCacheTestBase {
    
    // MARK: - Persistence Tests
    
    func testSaveCachePersistsToDisk() async throws {
        let testFile = tempDirectory.appendingPathComponent("test.txt")
        try "test content".write(to: testFile, atomically: true, encoding: .utf8)
        
        let attributes = try FileManager.default.attributesOfItem(atPath: testFile.path)
        let fileSize = attributes[.size] as! Int64
        let modificationTime = attributes[.modificationDate] as! Date
        
        await hashCache.setHash("persisted-hash", for: testFile, fileSize: fileSize, modificationTime: modificationTime)
        
        try await hashCache.saveCache()
        
        // Verify file exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: cacheFileURL.path), "Cache file should exist after save")
        
        // Verify file contains valid JSON
        let cacheData = try Data(contentsOf: cacheFileURL)
        let jsonObject = try JSONSerialization.jsonObject(with: cacheData)
        XCTAssertNotNil(jsonObject, "Cache file should contain valid JSON")
    }
    
    func testLoadCacheRestoresFromDisk() async throws {
        // Create and save cache
        let testFile = tempDirectory.appendingPathComponent("test.txt")
        try "test content".write(to: testFile, atomically: true, encoding: .utf8)
        
        let attributes = try FileManager.default.attributesOfItem(atPath: testFile.path)
        let fileSize = attributes[.size] as! Int64
        let modificationTime = attributes[.modificationDate] as! Date
        
        await hashCache.setHash("loaded-hash", for: testFile, fileSize: fileSize, modificationTime: modificationTime)
        try await hashCache.saveCache()
        
        // Create new cache instance (should load from disk)
        let loadedCache = FileHashCache(cacheFileURL: cacheFileURL, hashAlgorithm: "sha256", maxCacheSize: 100)
        
        // Wait for async load to complete
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        let loadedHash = await loadedCache.getHash(for: testFile)
        XCTAssertEqual(loadedHash, "loaded-hash", "Cache should restore hash from disk")
    }
    
    func testLoadCacheFiltersInvalidEntries() async throws {
        // Manually create cache file with invalid algorithm entry
        let invalidEntry = FileHashCacheEntry(
            path: "/invalid/path",
            hash: "hash",
            hashAlgorithm: "sha1", // Wrong algorithm
            fileSize: 100,
            modificationTime: Date()
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let cacheData = try encoder.encode(["key": invalidEntry])
        try cacheData.write(to: cacheFileURL)
        
        // Create cache with sha256 (should filter out sha1 entry)
        let loadedCache = FileHashCache(cacheFileURL: cacheFileURL, hashAlgorithm: "sha256", maxCacheSize: 100)
        
        // Wait for async load
        try await Task.sleep(nanoseconds: 200_000_000)
        
        let (count, _) = await loadedCache.getStats()
        XCTAssertEqual(count, 0, "Invalid entries should be filtered out")
    }
    
    func testLoadCacheHandlesCorruptedFile() async throws {
        // Create corrupted cache file
        try "invalid json content".write(to: cacheFileURL, atomically: true, encoding: .utf8)
        
        // Create cache (should handle corruption gracefully)
        let loadedCache = FileHashCache(cacheFileURL: cacheFileURL, hashAlgorithm: "sha256", maxCacheSize: 100)
        
        // Wait for async load
        try await Task.sleep(nanoseconds: 200_000_000)
        
        let (count, _) = await loadedCache.getStats()
        XCTAssertEqual(count, 0, "Cache should start fresh when file is corrupted")
    }
}

