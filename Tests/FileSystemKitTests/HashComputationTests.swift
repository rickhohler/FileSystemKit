// FileSystemKit Tests
// HashComputation Unit Tests

import XCTest
@testable import FileSystemKit
import Foundation

final class HashComputationTests: XCTestCase {
    
    // MARK: - Data Return Type Tests
    
    func testComputeHashSHA256ReturnsData() throws {
        let testData = "Hello, World!".data(using: .utf8)!
        let hash = try HashComputation.computeHash(data: testData, algorithm: .sha256)
        
        XCTAssertEqual(hash.count, 32, "SHA256 should return 32 bytes")
        XCTAssertFalse(hash.isEmpty, "Hash should not be empty")
    }
    
    func testComputeHashSHA1ReturnsData() throws {
        let testData = "Hello, World!".data(using: .utf8)!
        let hash = try HashComputation.computeHash(data: testData, algorithm: .sha1)
        
        XCTAssertEqual(hash.count, 20, "SHA1 should return 20 bytes")
        XCTAssertFalse(hash.isEmpty, "Hash should not be empty")
    }
    
    func testComputeHashMD5ReturnsData() throws {
        let testData = "Hello, World!".data(using: .utf8)!
        let hash = try HashComputation.computeHash(data: testData, algorithm: .md5)
        
        XCTAssertEqual(hash.count, 16, "MD5 should return 16 bytes")
        XCTAssertFalse(hash.isEmpty, "Hash should not be empty")
    }
    
    func testComputeHashCRC32ReturnsData() throws {
        let testData = "Hello, World!".data(using: .utf8)!
        let hash = try HashComputation.computeHash(data: testData, algorithm: .crc32)
        
        XCTAssertEqual(hash.count, 4, "CRC32 should return 4 bytes")
        XCTAssertFalse(hash.isEmpty, "Hash should not be empty")
    }
    
    // MARK: - Hex String Return Type Tests
    
    func testComputeHashHexSHA256ReturnsString() throws {
        let testData = "Hello, World!".data(using: .utf8)!
        let hash = try HashComputation.computeHashHex(data: testData, algorithm: .sha256)
        
        XCTAssertEqual(hash.count, 64, "SHA256 hex string should be 64 characters")
        XCTAssertTrue(hash.allSatisfy { $0.isHexDigit }, "Hash should contain only hex characters")
    }
    
    func testComputeHashHexSHA1ReturnsString() throws {
        let testData = "Hello, World!".data(using: .utf8)!
        let hash = try HashComputation.computeHashHex(data: testData, algorithm: .sha1)
        
        XCTAssertEqual(hash.count, 40, "SHA1 hex string should be 40 characters")
        XCTAssertTrue(hash.allSatisfy { $0.isHexDigit }, "Hash should contain only hex characters")
    }
    
    func testComputeHashHexMD5ReturnsString() throws {
        let testData = "Hello, World!".data(using: .utf8)!
        let hash = try HashComputation.computeHashHex(data: testData, algorithm: .md5)
        
        XCTAssertEqual(hash.count, 32, "MD5 hex string should be 32 characters")
        XCTAssertTrue(hash.allSatisfy { $0.isHexDigit }, "Hash should contain only hex characters")
    }
    
    func testComputeHashHexCRC32ReturnsString() throws {
        let testData = "Hello, World!".data(using: .utf8)!
        let hash = try HashComputation.computeHashHex(data: testData, algorithm: .crc32)
        
        XCTAssertEqual(hash.count, 8, "CRC32 hex string should be 8 characters")
        XCTAssertTrue(hash.allSatisfy { $0.isHexDigit }, "Hash should contain only hex characters")
    }
    
    // MARK: - String Algorithm Name Tests
    
    func testComputeHashHexWithStringAlgorithm() throws {
        let testData = "Hello, World!".data(using: .utf8)!
        
        let sha256Hash = try HashComputation.computeHashHex(data: testData, algorithm: "sha256")
        let sha1Hash = try HashComputation.computeHashHex(data: testData, algorithm: "sha1")
        let md5Hash = try HashComputation.computeHashHex(data: testData, algorithm: "md5")
        
        XCTAssertEqual(sha256Hash.count, 64, "SHA256 hex string should be 64 characters")
        XCTAssertEqual(sha1Hash.count, 40, "SHA1 hex string should be 40 characters")
        XCTAssertEqual(md5Hash.count, 32, "MD5 hex string should be 32 characters")
    }
    
    func testComputeHashHexWithStringAlgorithmCaseInsensitive() throws {
        let testData = "Hello, World!".data(using: .utf8)!
        
        let hash1 = try HashComputation.computeHashHex(data: testData, algorithm: "SHA256")
        let hash2 = try HashComputation.computeHashHex(data: testData, algorithm: "sha256")
        let hash3 = try HashComputation.computeHashHex(data: testData, algorithm: "Sha256")
        
        XCTAssertEqual(hash1, hash2, "Case should not matter")
        XCTAssertEqual(hash2, hash3, "Case should not matter")
    }
    
    func testComputeHashHexWithInvalidStringAlgorithm() throws {
        let testData = "Hello, World!".data(using: .utf8)!
        
        XCTAssertThrowsError(try HashComputation.computeHashHex(data: testData, algorithm: "invalid")) { error in
            XCTAssertTrue(error is FileSystemError, "Should throw FileSystemError")
        }
    }
    
    // MARK: - Consistency Tests
    
    func testComputeHashAndHexAreConsistent() throws {
        let testData = "Hello, World!".data(using: .utf8)!
        
        let hashData = try HashComputation.computeHash(data: testData, algorithm: .sha256)
        let hashHex = try HashComputation.computeHashHex(data: testData, algorithm: .sha256)
        
        // Convert hashData to hex string
        let hashDataHex = hashData.map { String(format: "%02x", $0) }.joined()
        
        XCTAssertEqual(hashHex, hashDataHex, "Hex string should match Data converted to hex")
    }
    
    func testComputeHashDeterministic() throws {
        let testData = "Hello, World!".data(using: .utf8)!
        
        let hash1 = try HashComputation.computeHashHex(data: testData, algorithm: .sha256)
        let hash2 = try HashComputation.computeHashHex(data: testData, algorithm: .sha256)
        
        XCTAssertEqual(hash1, hash2, "Hash should be deterministic")
    }
    
    // MARK: - CRC32 Tests
    
    func testComputeCRC32() {
        let testData = "Hello, World!".data(using: .utf8)!
        let crc32 = HashComputation.computeCRC32(data: testData)
        
        XCTAssertEqual(crc32.count, 4, "CRC32 should return 4 bytes")
    }
    
    func testComputeCRC32Deterministic() {
        let testData = "Hello, World!".data(using: .utf8)!
        
        let crc1 = HashComputation.computeCRC32(data: testData)
        let crc2 = HashComputation.computeCRC32(data: testData)
        
        XCTAssertEqual(crc1, crc2, "CRC32 should be deterministic")
    }
}

// MARK: - Helper Extensions

extension Character {
    var isHexDigit: Bool {
        return ("0"..."9").contains(self) || ("a"..."f").contains(self) || ("A"..."F").contains(self)
    }
}

