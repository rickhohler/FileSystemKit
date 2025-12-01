// FileSystemKit Tests
// FileHashCache validation tests (file modification, size changes, algorithm mismatch)

import XCTest
@testable import FileSystemKit
import Foundation

final class FileHashCacheValidationTests: FileHashCacheTestBase {
    
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
}

