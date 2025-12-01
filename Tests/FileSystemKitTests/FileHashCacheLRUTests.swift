// FileSystemKit Tests
// FileHashCache LRU eviction tests

import XCTest
@testable import FileSystemKit
import Foundation

final class FileHashCacheLRUTests: FileHashCacheTestBase {
    
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
}

