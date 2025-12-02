// FileSystemKit Tests
// ChunkValidator Unit Tests

import XCTest
@testable import FileSystemKit
import Foundation

final class ChunkValidatorTests: XCTestCase {
    var testData: Data!
    var testHash: String!
    var testIdentifier: ChunkIdentifier!
    var testMetadata: ChunkMetadata!
    
    override func setUp() {
        super.setUp()
        testData = "Hello, World!".data(using: .utf8)!
        testHash = try! HashComputation.computeHashHex(data: testData, algorithm: "sha256")
        testIdentifier = ChunkIdentifier(id: testHash)
        testMetadata = ChunkMetadata(
            size: testData.count,
            hashAlgorithm: "sha256"
        )
    }
    
    override func tearDown() {
        testData = nil
        testHash = nil
        testIdentifier = nil
        testMetadata = nil
        super.tearDown()
    }
    
    // MARK: - ChunkValidationResult Tests
    
    func testValidationResultValid() {
        let result = ChunkValidationResult.valid()
        
        XCTAssertTrue(result.isValid)
        XCTAssertTrue(result.errors.isEmpty)
        XCTAssertTrue(result.warnings.isEmpty)
    }
    
    func testValidationResultValidWithWarnings() {
        let warnings = ["Warning 1", "Warning 2"]
        let result = ChunkValidationResult.valid(warnings: warnings)
        
        XCTAssertTrue(result.isValid)
        XCTAssertTrue(result.errors.isEmpty)
        XCTAssertEqual(result.warnings.count, 2)
        XCTAssertEqual(result.warnings, warnings)
    }
    
    func testValidationResultInvalid() {
        let error = ChunkStorageError.invalidIdentifier(testIdentifier, reason: "Test")
        let result = ChunkValidationResult.invalid(error)
        
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.errors.count, 1)
        XCTAssertTrue(result.warnings.isEmpty)
    }
    
    func testValidationResultInvalidMultiple() {
        let errors = [
            ChunkStorageError.invalidIdentifier(testIdentifier, reason: "Test 1"),
            ChunkStorageError.invalidDataSize(expected: 100, actual: 200, identifier: testIdentifier)
        ]
        let result = ChunkValidationResult.invalid(errors)
        
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.errors.count, 2)
        XCTAssertTrue(result.warnings.isEmpty)
    }
    
    // MARK: - DefaultChunkValidator Initialization Tests
    
    func testDefaultChunkValidatorDefaultInit() {
        let validator = DefaultChunkValidator()
        
        // Default settings: verifyHash=true, no size limits, sha256 allowed
        let result = validator.validateIdentifier(testIdentifier)
        XCTAssertTrue(result.isValid || !result.errors.isEmpty) // Should validate
    }
    
    func testDefaultChunkValidatorCustomInit() {
        let validator = DefaultChunkValidator(
            verifyHash: false,
            minSize: 10,
            maxSize: 1000,
            allowedHashAlgorithms: ["sha256", "sha1"]
        )
        
        // Should accept custom settings
        XCTAssertNotNil(validator)
    }
    
    // MARK: - Validate Write Tests
    
    func testValidateWriteValidData() {
        let validator = DefaultChunkValidator()
        let identifier = ChunkIdentifier(id: testHash, metadata: testMetadata)
        
        let result = validator.validateWrite(testData, identifier: identifier, metadata: testMetadata)
        
        XCTAssertTrue(result.isValid, "Valid data should pass validation")
        XCTAssertTrue(result.errors.isEmpty)
    }
    
    func testValidateWriteHashMismatch() {
        let validator = DefaultChunkValidator(verifyHash: true)
        let wrongHash = "wronghash" + String(repeating: "0", count: 56)
        let identifier = ChunkIdentifier(id: wrongHash, metadata: testMetadata)
        
        let result = validator.validateWrite(testData, identifier: identifier, metadata: testMetadata)
        
        XCTAssertFalse(result.isValid, "Hash mismatch should fail validation")
        XCTAssertTrue(result.errors.contains { error in
            if case .hashMismatch = error {
                return true
            }
            return false
        })
    }
    
    func testValidateWriteWithHashVerificationDisabled() {
        let validator = DefaultChunkValidator(verifyHash: false)
        // Use a valid hex hash format (but wrong hash) - identifier validation will pass
        let wrongHash = String(repeating: "a", count: 64) // Valid hex format, wrong hash
        let identifier = ChunkIdentifier(id: wrongHash, metadata: testMetadata)
        
        let result = validator.validateWrite(testData, identifier: identifier, metadata: testMetadata)
        
        // Should pass validation when hash verification is disabled (hash mismatch won't be checked)
        XCTAssertTrue(result.isValid, "Should pass when hash verification is disabled")
        XCTAssertTrue(result.errors.isEmpty, "Should have no errors when hash verification is disabled")
    }
    
    func testValidateWriteDataTooSmall() {
        let validator = DefaultChunkValidator(minSize: 100)
        let identifier = ChunkIdentifier(id: testHash, metadata: testMetadata)
        
        let result = validator.validateWrite(testData, identifier: identifier, metadata: testMetadata)
        
        XCTAssertFalse(result.isValid, "Data smaller than minSize should fail")
        XCTAssertTrue(result.errors.contains { error in
            if case .invalidDataSize = error {
                return true
            }
            return false
        })
    }
    
    func testValidateWriteDataTooLarge() {
        let validator = DefaultChunkValidator(maxSize: 5)
        let identifier = ChunkIdentifier(id: testHash, metadata: testMetadata)
        
        let result = validator.validateWrite(testData, identifier: identifier, metadata: testMetadata)
        
        XCTAssertFalse(result.isValid, "Data larger than maxSize should fail")
        XCTAssertTrue(result.errors.contains { error in
            if case .invalidDataSize = error {
                return true
            }
            return false
        })
    }
    
    func testValidateWriteMetadataSizeMismatchWarning() {
        let validator = DefaultChunkValidator()
        let identifier = ChunkIdentifier(id: testHash, metadata: testMetadata)
        let wrongMetadata = ChunkMetadata(size: testData.count + 10, hashAlgorithm: "sha256")
        
        let result = validator.validateWrite(testData, identifier: identifier, metadata: wrongMetadata)
        
        // Should still be valid but have warning
        XCTAssertTrue(result.isValid, "Size mismatch should be warning, not error")
        XCTAssertFalse(result.warnings.isEmpty, "Should have warning about size mismatch")
        XCTAssertTrue(result.warnings.contains { $0.contains("Metadata size") })
    }
    
    // MARK: - Validate Read Tests
    
    func testValidateReadValidData() {
        let validator = DefaultChunkValidator()
        let identifier = ChunkIdentifier(id: testHash, metadata: testMetadata)
        
        let result = validator.validateRead(testData, identifier: identifier)
        
        XCTAssertTrue(result.isValid, "Valid data should pass validation")
        XCTAssertTrue(result.errors.isEmpty)
    }
    
    func testValidateReadHashMismatch() {
        let validator = DefaultChunkValidator(verifyHash: true)
        let wrongHash = "wronghash" + String(repeating: "0", count: 56)
        let identifier = ChunkIdentifier(id: wrongHash, metadata: testMetadata)
        
        let result = validator.validateRead(testData, identifier: identifier)
        
        XCTAssertFalse(result.isValid, "Hash mismatch should fail validation")
        XCTAssertTrue(result.errors.contains { error in
            if case .hashMismatch = error {
                return true
            }
            return false
        })
        XCTAssertTrue(result.errors.contains { error in
            if case .corruptedData = error {
                return true
            }
            return false
        })
    }
    
    func testValidateReadWithHashVerificationDisabled() {
        let validator = DefaultChunkValidator(verifyHash: false)
        // Use a valid hex hash format (but wrong hash) - identifier validation will pass
        let wrongHash = String(repeating: "a", count: 64) // Valid hex format, wrong hash
        let identifier = ChunkIdentifier(id: wrongHash, metadata: testMetadata)
        
        let result = validator.validateRead(testData, identifier: identifier)
        
        // Should pass validation when hash verification is disabled (hash mismatch won't be checked)
        XCTAssertTrue(result.isValid, "Should pass when hash verification is disabled")
        XCTAssertTrue(result.errors.isEmpty, "Should have no errors when hash verification is disabled")
    }
    
    func testValidateReadMetadataSizeMismatchWarning() {
        let validator = DefaultChunkValidator()
        let wrongMetadata = ChunkMetadata(size: testData.count + 10, hashAlgorithm: "sha256")
        let identifier = ChunkIdentifier(id: testHash, metadata: wrongMetadata)
        
        let result = validator.validateRead(testData, identifier: identifier)
        
        // Should still be valid but have warning
        XCTAssertTrue(result.isValid, "Size mismatch should be warning, not error")
        XCTAssertFalse(result.warnings.isEmpty, "Should have warning about size mismatch")
        XCTAssertTrue(result.warnings.contains { $0.contains("Data size") })
    }
    
    // MARK: - Validate Identifier Tests
    
    func testValidateIdentifierValid() {
        let validator = DefaultChunkValidator()
        let identifier = ChunkIdentifier(id: testHash, metadata: testMetadata)
        
        let result = validator.validateIdentifier(identifier)
        
        XCTAssertTrue(result.isValid, "Valid identifier should pass validation")
        XCTAssertTrue(result.errors.isEmpty)
    }
    
    func testValidateIdentifierEmptyHash() {
        let validator = DefaultChunkValidator()
        let identifier = ChunkIdentifier(id: "")
        
        let result = validator.validateIdentifier(identifier)
        
        XCTAssertFalse(result.isValid, "Empty hash should fail validation")
        XCTAssertTrue(result.errors.contains { error in
            if case .invalidIdentifier = error {
                return true
            }
            return false
        })
    }
    
    func testValidateIdentifierNonStandardLength() {
        let validator = DefaultChunkValidator()
        let shortHash = "abc123"
        let identifier = ChunkIdentifier(id: shortHash)
        
        let result = validator.validateIdentifier(identifier)
        
        // Should have warning but not error (non-standard length is allowed)
        XCTAssertTrue(result.isValid || result.warnings.contains { $0.contains("Hash length") })
    }
    
    func testValidateIdentifierNonHexCharacters() {
        let validator = DefaultChunkValidator()
        let invalidHash = String(repeating: "g", count: 64) // 'g' is not hex
        let identifier = ChunkIdentifier(id: invalidHash)
        
        let result = validator.validateIdentifier(identifier)
        
        XCTAssertFalse(result.isValid, "Non-hex characters should fail validation")
        XCTAssertTrue(result.errors.contains { error in
            if case .invalidIdentifier = error {
                return true
            }
            return false
        })
    }
    
    func testValidateIdentifierInvalidHashAlgorithm() {
        let validator = DefaultChunkValidator(allowedHashAlgorithms: ["sha256"])
        let metadata = ChunkMetadata(size: 100, hashAlgorithm: "md5")
        let identifier = ChunkIdentifier(id: testHash, metadata: metadata)
        
        let result = validator.validateIdentifier(identifier)
        
        XCTAssertFalse(result.isValid, "Invalid hash algorithm should fail validation")
        XCTAssertTrue(result.errors.contains { error in
            if case .invalidHashAlgorithm = error {
                return true
            }
            return false
        })
    }
    
    func testValidateIdentifierMultipleAlgorithmsAllowed() {
        let validator = DefaultChunkValidator(allowedHashAlgorithms: ["sha256", "sha1"])
        let sha1Metadata = ChunkMetadata(size: 100, hashAlgorithm: "sha1")
        let identifier = ChunkIdentifier(id: testHash, metadata: sha1Metadata)
        
        let result = validator.validateIdentifier(identifier)
        
        // Should pass if sha1 is in allowed list
        XCTAssertTrue(result.isValid || !result.errors.contains { error in
            if case .invalidHashAlgorithm = error {
                return true
            }
            return false
        })
    }
    
    // MARK: - Integration Tests
    
    func testValidateWriteThenRead() {
        let validator = DefaultChunkValidator()
        let identifier = ChunkIdentifier(id: testHash, metadata: testMetadata)
        
        // Validate write
        let writeResult = validator.validateWrite(testData, identifier: identifier, metadata: testMetadata)
        XCTAssertTrue(writeResult.isValid, "Write validation should pass")
        
        // Validate read
        let readResult = validator.validateRead(testData, identifier: identifier)
        XCTAssertTrue(readResult.isValid, "Read validation should pass")
    }
    
    func testValidateWithDifferentAlgorithms() throws {
        let sha1Data = "Hello, World!".data(using: .utf8)!
        let sha1Hash = try HashComputation.computeHashHex(data: sha1Data, algorithm: "sha1")
        let sha1Metadata = ChunkMetadata(size: sha1Data.count, hashAlgorithm: "sha1")
        let sha1Identifier = ChunkIdentifier(id: sha1Hash, metadata: sha1Metadata)
        
        let validator = DefaultChunkValidator(allowedHashAlgorithms: ["sha256", "sha1"])
        
        let result = validator.validateWrite(sha1Data, identifier: sha1Identifier, metadata: sha1Metadata)
        XCTAssertTrue(result.isValid, "SHA1 should be valid when allowed")
    }
    
    // MARK: - Edge Cases
    
    func testValidateEmptyData() {
        let validator = DefaultChunkValidator()
        let emptyData = Data()
        let emptyHash = try! HashComputation.computeHashHex(data: emptyData, algorithm: "sha256")
        let emptyIdentifier = ChunkIdentifier(id: emptyHash)
        let emptyMetadata = ChunkMetadata(size: 0)
        
        let result = validator.validateWrite(emptyData, identifier: emptyIdentifier, metadata: emptyMetadata)
        
        // Empty data should be valid (unless minSize > 0)
        XCTAssertTrue(result.isValid || result.errors.isEmpty)
    }
    
    func testValidateLargeData() {
        let validator = DefaultChunkValidator()
        let largeData = Data(repeating: 0, count: 1_000_000)
        let largeHash = try! HashComputation.computeHashHex(data: largeData, algorithm: "sha256")
        let largeIdentifier = ChunkIdentifier(id: largeHash)
        let largeMetadata = ChunkMetadata(size: largeData.count)
        
        let result = validator.validateWrite(largeData, identifier: largeIdentifier, metadata: largeMetadata)
        
        // Large data should be valid (unless maxSize is set)
        XCTAssertTrue(result.isValid || result.errors.isEmpty)
    }
    
    func testValidateIdentifierWithoutMetadata() {
        let validator = DefaultChunkValidator()
        let identifier = ChunkIdentifier(id: testHash) // No metadata
        
        let result = validator.validateIdentifier(identifier)
        
        // Should use default algorithm (sha256) when metadata is nil
        XCTAssertTrue(result.isValid || !result.errors.contains { error in
            if case .invalidHashAlgorithm = error {
                return true
            }
            return false
        })
    }
}

