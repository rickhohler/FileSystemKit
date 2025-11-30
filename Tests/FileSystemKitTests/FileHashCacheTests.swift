// FileSystemKit Tests
// Unit tests for FileHashCache: cache operations, persistence, LRU eviction, validation

import XCTest
@testable import FileSystemKit
import Foundation

final class FileHashCacheTests: XCTestCase {
    var tempDirectory: URL!
    var cacheFileURL: URL!
    var hashCache: FileHashCache!
    
    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("hashcache-test-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        cacheFileURL = tempDirectory.appendingPathComponent(".hashcache.json")
        hashCache = FileHashCache(cacheFileURL: cacheFileURL, hashAlgorithm: "sha256", maxCacheSize: 100)
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        tempDirectory = nil
        cacheFileURL = nil
        hashCache = nil
        super.tearDown()
    }
    
    // MARK: - Cache Get/Set Tests
    
    func testGetHashReturnsNilWhenNotCached() async throws {
        let testFile = tempDirectory.appendingPathComponent("test.txt")
        try "test content".write(to: testFile, atomically: true, encoding: .utf8)
        
        let hash = await hashCache.getHash(for: testFile)
        XCTAssertNil(hash, "Hash should be nil when not cached")
    }
    
    func testSetHashStoresHash() async throws {
        let testFile = tempDirectory.appendingPathComponent("test.txt")
        try "test content".write(to: testFile, atomically: true, encoding: .utf8)
        
        let attributes = try FileManager.default.attributesOfItem(atPath: testFile.path)
        let fileSize = attributes[.size] as! Int64
        let modificationTime = attributes[.modificationDate] as! Date
        
        let expectedHash = "abc123def456"
        await hashCache.setHash(expectedHash, for: testFile, fileSize: fileSize, modificationTime: modificationTime)
        
        let cachedHash = await hashCache.getHash(for: testFile)
        XCTAssertEqual(cachedHash, expectedHash, "Cached hash should match stored hash")
    }
    
    func testGetHashReturnsCachedValue() async throws {
        let testFile = tempDirectory.appendingPathComponent("test.txt")
        try "test content".write(to: testFile, atomically: true, encoding: .utf8)
        
        let attributes = try FileManager.default.attributesOfItem(atPath: testFile.path)
        let fileSize = attributes[.size] as! Int64
        let modificationTime = attributes[.modificationDate] as! Date
        
        let hash1 = "hash1"
        await hashCache.setHash(hash1, for: testFile, fileSize: fileSize, modificationTime: modificationTime)
        
        let retrievedHash = await hashCache.getHash(for: testFile)
        XCTAssertEqual(retrievedHash, hash1, "Retrieved hash should match stored hash")
    }
    
    // MARK: - Cache Validation Tests
    
    func testGetHashReturnsNilWhenFileModified() async throws {
        let testFile = tempDirectory.appendingPathComponent("test.txt")
        try "original content".write(to: testFile, atomically: true, encoding: .utf8)
        
        let attributes = try FileManager.default.attributesOfItem(atPath: testFile.path)
        let fileSize = attributes[.size] as! Int64
        let modificationTime = attributes[.modificationDate] as! Date
        
        await hashCache.setHash("original-hash", for: testFile, fileSize: fileSize, modificationTime: modificationTime)
        
        // Wait a bit to ensure modification time difference is > 1 second (cache validation tolerance)
        try await Task.sleep(nanoseconds: 1_100_000_000) // 1.1 seconds
        
        // Modify file (changes both content and modification time)
        try "modified content".write(to: testFile, atomically: true, encoding: .utf8)
        
        let cachedHash = await hashCache.getHash(for: testFile)
        XCTAssertNil(cachedHash, "Hash should be nil when file is modified")
    }
    
    func testGetHashReturnsNilWhenFileSizeChanged() async throws {
        let testFile = tempDirectory.appendingPathComponent("test.txt")
        try "content".write(to: testFile, atomically: true, encoding: .utf8)
        
        let attributes = try FileManager.default.attributesOfItem(atPath: testFile.path)
        let fileSize = attributes[.size] as! Int64
        let modificationTime = attributes[.modificationDate] as! Date
        
        await hashCache.setHash("hash", for: testFile, fileSize: fileSize, modificationTime: modificationTime)
        
        // Change file size
        try "much longer content that changes the file size".write(to: testFile, atomically: true, encoding: .utf8)
        
        let cachedHash = await hashCache.getHash(for: testFile)
        XCTAssertNil(cachedHash, "Hash should be nil when file size changes")
    }
    
    func testGetHashReturnsNilWhenHashAlgorithmMismatch() async throws {
        let testFile = tempDirectory.appendingPathComponent("test.txt")
        try "test content".write(to: testFile, atomically: true, encoding: .utf8)
        
        // Create cache with sha256
        let sha256Cache = FileHashCache(cacheFileURL: cacheFileURL, hashAlgorithm: "sha256", maxCacheSize: 100)
        
        let attributes = try FileManager.default.attributesOfItem(atPath: testFile.path)
        let fileSize = attributes[.size] as! Int64
        let modificationTime = attributes[.modificationDate] as! Date
        
        await sha256Cache.setHash("hash", for: testFile, fileSize: fileSize, modificationTime: modificationTime)
        
        // Create cache with sha1 - should not find sha256 entries
        let sha1Cache = FileHashCache(cacheFileURL: cacheFileURL, hashAlgorithm: "sha1", maxCacheSize: 100)
        
        // Wait for cache to load
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        let cachedHash = await sha1Cache.getHash(for: testFile)
        XCTAssertNil(cachedHash, "Hash should be nil when algorithm doesn't match")
    }
    
    // MARK: - LRU Eviction Tests
    
    func testLRUEvictionRemovesOldestEntries() async throws {
        // Create cache with small max size
        let smallCache = FileHashCache(cacheFileURL: nil, hashAlgorithm: "sha256", maxCacheSize: 3)
        
        // Create test files
        var testFiles: [URL] = []
        for i in 0..<5 {
            let testFile = tempDirectory.appendingPathComponent("test\(i).txt")
            try "content \(i)".write(to: testFile, atomically: true, encoding: .utf8)
            testFiles.append(testFile)
        }
        
        // Add files to cache (should evict oldest when exceeding max size)
        for (index, file) in testFiles.enumerated() {
            let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
            let fileSize = attributes[.size] as! Int64
            let modificationTime = attributes[.modificationDate] as! Date
            
            await smallCache.setHash("hash\(index)", for: file, fileSize: fileSize, modificationTime: modificationTime)
        }
        
        // First two files should be evicted (oldest)
        let hash0 = await smallCache.getHash(for: testFiles[0])
        let hash1 = await smallCache.getHash(for: testFiles[1])
        let hash2 = await smallCache.getHash(for: testFiles[2])
        let hash3 = await smallCache.getHash(for: testFiles[3])
        let hash4 = await smallCache.getHash(for: testFiles[4])
        
        XCTAssertNil(hash0, "Oldest entry should be evicted")
        XCTAssertNil(hash1, "Second oldest entry should be evicted")
        XCTAssertNotNil(hash2, "Recent entry should still be cached")
        XCTAssertNotNil(hash3, "Recent entry should still be cached")
        XCTAssertNotNil(hash4, "Most recent entry should still be cached")
    }
    
    func testLRUUpdatesAccessOrder() async throws {
        let testFile1 = tempDirectory.appendingPathComponent("test1.txt")
        let testFile2 = tempDirectory.appendingPathComponent("test2.txt")
        let testFile3 = tempDirectory.appendingPathComponent("test3.txt")
        
        try "content1".write(to: testFile1, atomically: true, encoding: .utf8)
        try "content2".write(to: testFile2, atomically: true, encoding: .utf8)
        try "content3".write(to: testFile3, atomically: true, encoding: .utf8)
        
        let smallCache = FileHashCache(cacheFileURL: nil, hashAlgorithm: "sha256", maxCacheSize: 2)
        
        // Add two files
        let attrs1 = try FileManager.default.attributesOfItem(atPath: testFile1.path)
        await smallCache.setHash("hash1", for: testFile1, fileSize: attrs1[.size] as! Int64, modificationTime: attrs1[.modificationDate] as! Date)
        
        let attrs2 = try FileManager.default.attributesOfItem(atPath: testFile2.path)
        await smallCache.setHash("hash2", for: testFile2, fileSize: attrs2[.size] as! Int64, modificationTime: attrs2[.modificationDate] as! Date)
        
        // Access first file (should update LRU order)
        _ = await smallCache.getHash(for: testFile1)
        
        // Add third file (should evict file2, not file1)
        let attrs3 = try FileManager.default.attributesOfItem(atPath: testFile3.path)
        await smallCache.setHash("hash3", for: testFile3, fileSize: attrs3[.size] as! Int64, modificationTime: attrs3[.modificationDate] as! Date)
        
        let hash1 = await smallCache.getHash(for: testFile1)
        let hash2 = await smallCache.getHash(for: testFile2)
        let hash3 = await smallCache.getHash(for: testFile3)
        
        XCTAssertNotNil(hash1, "Recently accessed file should not be evicted")
        XCTAssertNil(hash2, "Least recently accessed file should be evicted")
        XCTAssertNotNil(hash3, "New file should be cached")
    }
    
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
    
    // MARK: - computeHashSync Tests
    
    func testComputeHashSyncUsesCache() throws {
        let testFile = tempDirectory.appendingPathComponent("test.txt")
        try "test content".write(to: testFile, atomically: true, encoding: .utf8)
        
        let testData = try Data(contentsOf: testFile)
        
        // First call should compute and cache
        let hash1 = try hashCache.computeHashSync(for: testFile, data: testData, hashAlgorithm: "sha256")
        XCTAssertFalse(hash1.isEmpty, "Hash should be computed")
        
        // Second call should use cache
        let hash2 = try hashCache.computeHashSync(for: testFile, data: testData, hashAlgorithm: "sha256")
        XCTAssertEqual(hash1, hash2, "Hash should be same (from cache)")
    }
    
    func testComputeHashSyncThrowsForUnsupportedAlgorithm() throws {
        let testFile = tempDirectory.appendingPathComponent("test.txt")
        try "test content".write(to: testFile, atomically: true, encoding: .utf8)
        
        let testData = try Data(contentsOf: testFile)
        
        XCTAssertThrowsError(try hashCache.computeHashSync(for: testFile, data: testData, hashAlgorithm: "unsupported")) { error in
            XCTAssertTrue(error is SnugError, "Should throw SnugError for unsupported algorithm")
            if case SnugError.unsupportedHashAlgorithm(let algorithm) = error {
                XCTAssertEqual(algorithm, "unsupported")
            } else {
                XCTFail("Should throw unsupportedHashAlgorithm error")
            }
        }
    }
}

