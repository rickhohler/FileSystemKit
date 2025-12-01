// FileSystemKit Tests
// Basic FileHashCache tests (get/set operations)

import XCTest
@testable import FileSystemKit
import Foundation

final class FileHashCacheBasicTests: FileHashCacheTestBase {
    
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
}

