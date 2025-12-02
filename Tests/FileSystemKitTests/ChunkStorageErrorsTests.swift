// FileSystemKit Tests
// ChunkStorageError Unit Tests

import XCTest
@testable import FileSystemKit
import Foundation

final class ChunkStorageErrorsTests: XCTestCase {
    
    // MARK: - Organization Errors
    
    func testInvalidIdentifierError() {
        let identifier = ChunkIdentifier(id: "test-id")
        let error = ChunkStorageError.invalidIdentifier(identifier, reason: "Hash is empty")
        
        XCTAssertTrue(error.description.contains("Invalid chunk identifier"))
        XCTAssertTrue(error.description.contains("test-id"))
        XCTAssertTrue(error.description.contains("Hash is empty"))
        XCTAssertNil(error.underlyingError)
    }
    
    func testInvalidPathError() {
        let error = ChunkStorageError.invalidPath("/invalid/path", reason: "Path contains invalid characters")
        
        XCTAssertTrue(error.description.contains("Invalid storage path"))
        XCTAssertTrue(error.description.contains("/invalid/path"))
        XCTAssertTrue(error.description.contains("Path contains invalid characters"))
        XCTAssertNil(error.underlyingError)
    }
    
    func testPathGenerationFailedError() {
        let identifier = ChunkIdentifier(id: "test-id")
        let underlying = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        let error = ChunkStorageError.pathGenerationFailed(identifier, underlying: underlying)
        
        XCTAssertTrue(error.description.contains("Failed to generate path"))
        XCTAssertTrue(error.description.contains("test-id"))
        XCTAssertNotNil(error.underlyingError)
        XCTAssertEqual((error.underlyingError as? NSError)?.code, 1)
    }
    
    func testPathGenerationFailedErrorWithoutUnderlying() {
        let identifier = ChunkIdentifier(id: "test-id")
        let error = ChunkStorageError.pathGenerationFailed(identifier, underlying: nil)
        
        XCTAssertTrue(error.description.contains("Failed to generate path"))
        XCTAssertTrue(error.description.contains("unknown error"))
        XCTAssertNil(error.underlyingError)
    }
    
    // MARK: - Retrieval Errors
    
    func testChunkNotFoundError() {
        let identifier = ChunkIdentifier(id: "missing-chunk-id")
        let error = ChunkStorageError.chunkNotFound(identifier)
        
        XCTAssertTrue(error.description.contains("Chunk not found"))
        XCTAssertTrue(error.description.contains("missing-chunk-id"))
        XCTAssertNil(error.underlyingError)
    }
    
    func testReadFailedError() {
        let identifier = ChunkIdentifier(id: "test-id")
        let underlying = NSError(domain: "test", code: 2, userInfo: [NSLocalizedDescriptionKey: "Read failed"])
        let error = ChunkStorageError.readFailed(identifier, underlying: underlying)
        
        XCTAssertTrue(error.description.contains("Failed to read chunk"))
        XCTAssertTrue(error.description.contains("test-id"))
        XCTAssertTrue(error.description.contains("Read failed"))
        XCTAssertNotNil(error.underlyingError)
    }
    
    func testWriteFailedError() {
        let identifier = ChunkIdentifier(id: "test-id")
        let underlying = NSError(domain: "test", code: 3, userInfo: [NSLocalizedDescriptionKey: "Write failed"])
        let error = ChunkStorageError.writeFailed(identifier, underlying: underlying)
        
        XCTAssertTrue(error.description.contains("Failed to write chunk"))
        XCTAssertTrue(error.description.contains("test-id"))
        XCTAssertTrue(error.description.contains("Write failed"))
        XCTAssertNotNil(error.underlyingError)
    }
    
    func testDeleteFailedError() {
        let identifier = ChunkIdentifier(id: "test-id")
        let underlying = NSError(domain: "test", code: 4, userInfo: [NSLocalizedDescriptionKey: "Delete failed"])
        let error = ChunkStorageError.deleteFailed(identifier, underlying: underlying)
        
        XCTAssertTrue(error.description.contains("Failed to delete chunk"))
        XCTAssertTrue(error.description.contains("test-id"))
        XCTAssertTrue(error.description.contains("Delete failed"))
        XCTAssertNotNil(error.underlyingError)
    }
    
    func testInsufficientSpaceError() {
        let error = ChunkStorageError.insufficientSpace(required: 1000, available: 500)
        
        XCTAssertTrue(error.description.contains("Insufficient space"))
        XCTAssertTrue(error.description.contains("1000"))
        XCTAssertTrue(error.description.contains("500"))
        XCTAssertNil(error.underlyingError)
    }
    
    // MARK: - Integrity Errors
    
    func testHashMismatchError() {
        let identifier = ChunkIdentifier(id: "expected-hash")
        let error = ChunkStorageError.hashMismatch(expected: "expected-hash", actual: "actual-hash", identifier: identifier)
        
        XCTAssertTrue(error.description.contains("Hash mismatch"))
        XCTAssertTrue(error.description.contains("expected-hash"))
        XCTAssertTrue(error.description.contains("actual-hash"))
        XCTAssertNil(error.underlyingError)
    }
    
    func testCorruptedDataError() {
        let identifier = ChunkIdentifier(id: "test-id")
        let error = ChunkStorageError.corruptedData(identifier, reason: "Data integrity check failed")
        
        XCTAssertTrue(error.description.contains("Corrupted data"))
        XCTAssertTrue(error.description.contains("test-id"))
        XCTAssertTrue(error.description.contains("Data integrity check failed"))
        XCTAssertNil(error.underlyingError)
    }
    
    func testInvalidMetadataError() {
        let identifier = ChunkIdentifier(id: "test-id")
        let error = ChunkStorageError.invalidMetadata(identifier, reason: "Missing required fields")
        
        XCTAssertTrue(error.description.contains("Invalid metadata"))
        XCTAssertTrue(error.description.contains("test-id"))
        XCTAssertTrue(error.description.contains("Missing required fields"))
        XCTAssertNil(error.underlyingError)
    }
    
    // MARK: - Concurrency Errors
    
    func testConcurrentModificationError() {
        let identifier = ChunkIdentifier(id: "test-id")
        let error = ChunkStorageError.concurrentModification(identifier)
        
        XCTAssertTrue(error.description.contains("Concurrent modification"))
        XCTAssertTrue(error.description.contains("test-id"))
        XCTAssertNil(error.underlyingError)
    }
    
    func testLockTimeoutError() {
        let identifier = ChunkIdentifier(id: "test-id")
        let error = ChunkStorageError.lockTimeout(identifier, timeout: 5.0)
        
        XCTAssertTrue(error.description.contains("Lock timeout"))
        XCTAssertTrue(error.description.contains("test-id"))
        XCTAssertTrue(error.description.contains("5.0"))
        XCTAssertNil(error.underlyingError)
    }
    
    // MARK: - Validation Errors
    
    func testInvalidDataSizeError() {
        let identifier = ChunkIdentifier(id: "test-id")
        let error = ChunkStorageError.invalidDataSize(expected: 100, actual: 200, identifier: identifier)
        
        XCTAssertTrue(error.description.contains("Invalid data size"))
        XCTAssertTrue(error.description.contains("test-id"))
        XCTAssertTrue(error.description.contains("100"))
        XCTAssertTrue(error.description.contains("200"))
        XCTAssertNil(error.underlyingError)
    }
    
    func testInvalidHashAlgorithmError() {
        let identifier = ChunkIdentifier(id: "test-id")
        let error = ChunkStorageError.invalidHashAlgorithm("md4", identifier: identifier)
        
        XCTAssertTrue(error.description.contains("Invalid hash algorithm"))
        XCTAssertTrue(error.description.contains("md4"))
        XCTAssertTrue(error.description.contains("test-id"))
        XCTAssertNil(error.underlyingError)
    }
    
    func testMetadataValidationFailedError() {
        let identifier = ChunkIdentifier(id: "test-id")
        let errors = ["Field1 is required", "Field2 is invalid"]
        let error = ChunkStorageError.metadataValidationFailed(errors, identifier: identifier)
        
        XCTAssertTrue(error.description.contains("Metadata validation failed"))
        XCTAssertTrue(error.description.contains("test-id"))
        XCTAssertTrue(error.description.contains("Field1 is required"))
        XCTAssertTrue(error.description.contains("Field2 is invalid"))
        XCTAssertNil(error.underlyingError)
    }
    
    // MARK: - Resource Errors
    
    func testStorageUnavailableError() {
        let error = ChunkStorageError.storageUnavailable(reason: "Backend service is down")
        
        XCTAssertTrue(error.description.contains("Storage unavailable"))
        XCTAssertTrue(error.description.contains("Backend service is down"))
        XCTAssertNil(error.underlyingError)
    }
    
    func testQuotaExceededError() {
        let error = ChunkStorageError.quotaExceeded(used: 9000, limit: 10000)
        
        XCTAssertTrue(error.description.contains("Quota exceeded"))
        XCTAssertTrue(error.description.contains("9000"))
        XCTAssertTrue(error.description.contains("10000"))
        XCTAssertNil(error.underlyingError)
    }
    
    func testPermissionDeniedError() {
        let error = ChunkStorageError.permissionDenied(operation: "write", path: "/restricted/path")
        
        XCTAssertTrue(error.description.contains("Permission denied"))
        XCTAssertTrue(error.description.contains("write"))
        XCTAssertTrue(error.description.contains("/restricted/path"))
        XCTAssertNil(error.underlyingError)
    }
    
    // MARK: - Custom Errors
    
    func testCustomError() {
        let underlying = NSError(domain: "test", code: 5, userInfo: [NSLocalizedDescriptionKey: "Custom underlying error"])
        let error = ChunkStorageError.custom("Custom error message", underlying: underlying)
        
        XCTAssertTrue(error.description.contains("Custom error message"))
        XCTAssertTrue(error.description.contains("Custom underlying error"))
        XCTAssertNotNil(error.underlyingError)
    }
    
    func testCustomErrorWithoutUnderlying() {
        let error = ChunkStorageError.custom("Custom error message", underlying: nil)
        
        XCTAssertTrue(error.description.contains("Custom error message"))
        XCTAssertNil(error.underlyingError)
    }
    
    // MARK: - Error Description Tests
    
    func testAllErrorsHaveDescriptions() {
        let identifier = ChunkIdentifier(id: "test-id")
        let underlying = NSError(domain: "test", code: 1)
        
        let errors: [ChunkStorageError] = [
            .invalidIdentifier(identifier, reason: "test"),
            .invalidPath("path", reason: "test"),
            .pathGenerationFailed(identifier, underlying: underlying),
            .chunkNotFound(identifier),
            .readFailed(identifier, underlying: underlying),
            .writeFailed(identifier, underlying: underlying),
            .deleteFailed(identifier, underlying: underlying),
            .insufficientSpace(required: 100, available: 50),
            .hashMismatch(expected: "exp", actual: "act", identifier: identifier),
            .corruptedData(identifier, reason: "test"),
            .invalidMetadata(identifier, reason: "test"),
            .concurrentModification(identifier),
            .lockTimeout(identifier, timeout: 1.0),
            .invalidDataSize(expected: 100, actual: 200, identifier: identifier),
            .invalidHashAlgorithm("alg", identifier: identifier),
            .metadataValidationFailed(["error"], identifier: identifier),
            .storageUnavailable(reason: "test"),
            .quotaExceeded(used: 100, limit: 200),
            .permissionDenied(operation: "op", path: "path"),
            .custom("test", underlying: underlying)
        ]
        
        for error in errors {
            let description = error.description
            XCTAssertFalse(description.isEmpty, "Error should have a description: \(error)")
            XCTAssertTrue(description.count > 10, "Description should be meaningful: \(description)")
        }
    }
    
    // MARK: - Underlying Error Tests
    
    func testUnderlyingErrorExtraction() {
        let identifier = ChunkIdentifier(id: "test-id")
        let underlying = NSError(domain: "test", code: 42)
        
        let errorsWithUnderlying: [ChunkStorageError] = [
            .pathGenerationFailed(identifier, underlying: underlying),
            .readFailed(identifier, underlying: underlying),
            .writeFailed(identifier, underlying: underlying),
            .deleteFailed(identifier, underlying: underlying),
            .custom("test", underlying: underlying)
        ]
        
        for error in errorsWithUnderlying {
            XCTAssertNotNil(error.underlyingError, "Error should have underlying error: \(error)")
            if let underlyingError = error.underlyingError as? NSError {
                XCTAssertEqual(underlyingError.code, 42)
            }
        }
        
        let errorsWithoutUnderlying: [ChunkStorageError] = [
            .invalidIdentifier(identifier, reason: "test"),
            .chunkNotFound(identifier),
            .insufficientSpace(required: 100, available: 50),
            .hashMismatch(expected: "exp", actual: "act", identifier: identifier)
        ]
        
        for error in errorsWithoutUnderlying {
            XCTAssertNil(error.underlyingError, "Error should not have underlying error: \(error)")
        }
    }
    
    // MARK: - Localized Description Tests
    
    func testLocalizedDescription() {
        let identifier = ChunkIdentifier(id: "test-id")
        let error = ChunkStorageError.chunkNotFound(identifier)
        
        XCTAssertEqual(error.localizedDescription, error.description)
        XCTAssertFalse(error.localizedDescription.isEmpty)
    }
}

