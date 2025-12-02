// FileSystemKit Core Library
// Chunk Storage Errors
//
// Comprehensive error types for chunk storage operations.
// Provides specific error cases for different failure modes to enable
// better error handling and recovery strategies.

import Foundation

/// Comprehensive error types for chunk storage operations.
///
/// `ChunkStorageError` provides specific error cases for different failure modes,
/// enabling clients to handle errors appropriately and provide better user feedback.
///
/// ## Usage
///
/// Handle specific error cases:
/// ```swift
/// do {
///     let data = try await storage.readChunk(identifier)
/// } catch ChunkStorageError.chunkNotFound(let identifier) {
///     print("Chunk not found: \(identifier.id)")
/// } catch ChunkStorageError.hashMismatch(let expected, let actual, let identifier) {
///     print("Hash mismatch for \(identifier.id): expected \(expected), got \(actual)")
/// } catch ChunkStorageError.readFailed(let identifier, let underlying) {
///     print("Read failed for \(identifier.id): \(underlying.localizedDescription)")
/// } catch {
///     print("Unexpected error: \(error)")
/// }
/// ```
///
/// Access underlying errors:
/// ```swift
/// if let underlying = error.underlyingError {
///     // Handle underlying error
/// }
/// ```
///
/// ## Error Categories
///
/// - **Organization Errors**: Invalid identifiers, paths, path generation failures
/// - **Retrieval Errors**: Read/write/delete failures, not found, insufficient space
/// - **Integrity Errors**: Hash mismatches, corrupted data, invalid metadata
/// - **Concurrency Errors**: Concurrent modifications, lock timeouts
/// - **Validation Errors**: Invalid data size, hash algorithm, metadata validation
/// - **Resource Errors**: Storage unavailable, quota exceeded, permission denied
///
/// ## See Also
///
/// - ``ChunkStorage`` - Storage protocol
/// - ``ChunkValidator`` - Validation protocol
/// - ``ChunkIdentifier`` - Chunk identifier
public enum ChunkStorageError: Error, Sendable, CustomStringConvertible {
    // MARK: - Organization Errors
    
    /// Invalid chunk identifier
    case invalidIdentifier(ChunkIdentifier, reason: String)
    
    /// Invalid storage path
    case invalidPath(String, reason: String)
    
    /// Failed to generate storage path from identifier
    case pathGenerationFailed(ChunkIdentifier, underlying: Error?)
    
    // MARK: - Retrieval Errors
    
    /// Chunk not found in storage
    case chunkNotFound(ChunkIdentifier)
    
    /// Failed to read chunk
    case readFailed(ChunkIdentifier, underlying: Error)
    
    /// Failed to write chunk
    case writeFailed(ChunkIdentifier, underlying: Error)
    
    /// Failed to delete chunk
    case deleteFailed(ChunkIdentifier, underlying: Error)
    
    /// Insufficient storage space
    case insufficientSpace(required: Int64, available: Int64)
    
    // MARK: - Integrity Errors
    
    /// Hash mismatch - data doesn't match expected hash
    case hashMismatch(expected: String, actual: String, identifier: ChunkIdentifier)
    
    /// Chunk data is corrupted
    case corruptedData(ChunkIdentifier, reason: String)
    
    /// Invalid chunk metadata
    case invalidMetadata(ChunkIdentifier, reason: String)
    
    // MARK: - Concurrency Errors
    
    /// Concurrent modification detected
    case concurrentModification(ChunkIdentifier)
    
    /// Lock timeout - operation timed out waiting for lock
    case lockTimeout(ChunkIdentifier, timeout: TimeInterval)
    
    // MARK: - Validation Errors
    
    /// Invalid data size
    case invalidDataSize(expected: Int64, actual: Int64, identifier: ChunkIdentifier)
    
    /// Invalid hash algorithm
    case invalidHashAlgorithm(String, identifier: ChunkIdentifier)
    
    /// Metadata validation failed
    case metadataValidationFailed([String], identifier: ChunkIdentifier)
    
    // MARK: - Resource Errors
    
    /// Storage backend unavailable
    case storageUnavailable(reason: String)
    
    /// Storage quota exceeded
    case quotaExceeded(used: Int64, limit: Int64)
    
    /// Permission denied
    case permissionDenied(operation: String, path: String)
    
    // MARK: - Custom Errors
    
    /// Custom error with message and underlying error
    case custom(String, underlying: Error?)
    
    // MARK: - CustomStringConvertible
    
    /// Human-readable error description.
    ///
    /// Provides a detailed description of the error including context such as
    /// chunk identifiers, paths, and underlying error messages.
    ///
    /// - Returns: A human-readable string describing the error
    public var description: String {
        switch self {
        case .invalidIdentifier(let identifier, let reason):
            return "Invalid chunk identifier \(identifier.id): \(reason)"
        case .invalidPath(let path, let reason):
            return "Invalid storage path '\(path)': \(reason)"
        case .pathGenerationFailed(let identifier, let underlying):
            return "Failed to generate path for \(identifier.id): \(underlying?.localizedDescription ?? "unknown error")"
        case .chunkNotFound(let identifier):
            return "Chunk not found: \(identifier.id)"
        case .readFailed(let identifier, let underlying):
            return "Failed to read chunk \(identifier.id): \(underlying.localizedDescription)"
        case .writeFailed(let identifier, let underlying):
            return "Failed to write chunk \(identifier.id): \(underlying.localizedDescription)"
        case .deleteFailed(let identifier, let underlying):
            return "Failed to delete chunk \(identifier.id): \(underlying.localizedDescription)"
        case .insufficientSpace(let required, let available):
            return "Insufficient space: required \(required) bytes, available \(available) bytes"
        case .hashMismatch(let expected, let actual, let identifier):
            return "Hash mismatch for \(identifier.id): expected \(expected), got \(actual)"
        case .corruptedData(let identifier, let reason):
            return "Corrupted data for \(identifier.id): \(reason)"
        case .invalidMetadata(let identifier, let reason):
            return "Invalid metadata for \(identifier.id): \(reason)"
        case .concurrentModification(let identifier):
            return "Concurrent modification detected for \(identifier.id)"
        case .lockTimeout(let identifier, let timeout):
            return "Lock timeout for \(identifier.id) after \(timeout)s"
        case .invalidDataSize(let expected, let actual, let identifier):
            return "Invalid data size for \(identifier.id): expected \(expected), got \(actual)"
        case .invalidHashAlgorithm(let algorithm, let identifier):
            return "Invalid hash algorithm '\(algorithm)' for \(identifier.id)"
        case .metadataValidationFailed(let errors, let identifier):
            return "Metadata validation failed for \(identifier.id): \(errors.joined(separator: ", "))"
        case .storageUnavailable(let reason):
            return "Storage unavailable: \(reason)"
        case .quotaExceeded(let used, let limit):
            return "Quota exceeded: used \(used) bytes, limit \(limit) bytes"
        case .permissionDenied(let operation, let path):
            return "Permission denied for \(operation) at '\(path)'"
        case .custom(let message, let underlying):
            return "\(message)\(underlying.map { ": \($0.localizedDescription)" } ?? "")"
        }
    }
    
    /// Underlying error if available.
    ///
    /// Some error cases wrap underlying errors from lower-level operations.
    /// This property provides access to the original error for debugging and
    /// error chaining.
    ///
    /// Available for:
    /// - ``pathGenerationFailed(_:underlying:)``
    /// - ``readFailed(_:underlying:)``
    /// - ``writeFailed(_:underlying:)``
    /// - ``deleteFailed(_:underlying:)``
    /// - ``custom(_:underlying:)``
    ///
    /// - Returns: The underlying error, or `nil` if no underlying error exists
    public var underlyingError: Error? {
        switch self {
        case .pathGenerationFailed(_, let underlying):
            return underlying
        case .readFailed(_, let underlying),
             .writeFailed(_, let underlying),
             .deleteFailed(_, let underlying):
            return underlying
        case .custom(_, let underlying):
            return underlying
        default:
            return nil
        }
    }
    
    /// Localized error description for user-facing messages.
    ///
    /// Returns the same value as ``description``, providing a consistent
    /// interface for displaying errors to users.
    ///
    /// - Returns: A localized, user-friendly error description
    public var localizedDescription: String {
        return description
    }
}

