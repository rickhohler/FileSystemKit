// FileSystemKit Core Library
// Chunk Validator Protocol
//
// Validation framework for chunk storage operations.
// Provides pre/post operation validation to ensure data integrity
// and catch errors early.

import Foundation

/// Validation result for chunk operations.
///
/// `ChunkValidationResult` provides detailed information about validation outcomes,
/// including whether validation passed, any errors encountered, and optional warnings.
///
/// ## Usage
///
/// Check validation result:
/// ```swift
/// let result = validator.validateWrite(data, identifier: identifier, metadata: metadata)
/// if !result.isValid {
///     for error in result.errors {
///         print("Validation error: \(error)")
///     }
///     throw ChunkStorageError.metadataValidationFailed(
///         result.errors.map { $0.description },
///         identifier: identifier
///     )
/// }
///
/// if !result.warnings.isEmpty {
///     for warning in result.warnings {
///         print("Warning: \(warning)")
///     }
/// }
/// ```
///
/// ## See Also
///
/// - ``ChunkValidator`` - Validation protocol
/// - ``ChunkStorageError`` - Error types
public struct ChunkValidationResult: Sendable {
    /// Whether validation passed.
    ///
    /// `true` if validation succeeded with no errors, `false` if validation
    /// failed with one or more errors.
    public let isValid: Bool
    
    /// Validation errors (if any).
    ///
    /// Contains all errors encountered during validation. If this array is
    /// non-empty, ``isValid`` will be `false`.
    public let errors: [ChunkStorageError]
    
    /// Validation warnings (non-fatal issues).
    ///
    /// Contains warnings about potential issues that don't prevent validation
    /// from passing. Warnings don't affect ``isValid``.
    public let warnings: [String]
    
    /// Create a validation result.
    ///
    /// - Parameters:
    ///   - isValid: Whether validation passed
    ///   - errors: Validation errors (if any)
    ///   - warnings: Validation warnings (non-fatal issues)
    public init(isValid: Bool, errors: [ChunkStorageError] = [], warnings: [String] = []) {
        self.isValid = isValid
        self.errors = errors
        self.warnings = warnings
    }
    
    /// Create validation result from single error.
    ///
    /// Convenience method for creating an invalid validation result with a
    /// single error.
    ///
    /// - Parameter error: The validation error
    /// - Returns: An invalid validation result containing the error
    public static func invalid(_ error: ChunkStorageError) -> ChunkValidationResult {
        return ChunkValidationResult(isValid: false, errors: [error])
    }
    
    /// Create validation result from multiple errors.
    ///
    /// Convenience method for creating an invalid validation result with
    /// multiple errors.
    ///
    /// - Parameter errors: Array of validation errors
    /// - Returns: An invalid validation result containing all errors
    public static func invalid(_ errors: [ChunkStorageError]) -> ChunkValidationResult {
        return ChunkValidationResult(isValid: false, errors: errors)
    }
    
    /// Create valid validation result with optional warnings.
    ///
    /// Convenience method for creating a valid validation result, optionally
    /// with warnings.
    ///
    /// - Parameter warnings: Optional array of warnings
    /// - Returns: A valid validation result with optional warnings
    public static func valid(warnings: [String] = []) -> ChunkValidationResult {
        return ChunkValidationResult(isValid: true, warnings: warnings)
    }
}

/// Protocol for validating chunks before operations.
///
/// `ChunkValidator` provides validation hooks for chunk storage operations,
/// enabling clients to enforce data integrity, size limits, and format requirements.
///
/// ## Usage
///
/// Use default validator:
/// ```swift
/// let validator = DefaultChunkValidator(verifyHash: true, minSize: 100, maxSize: 10_000_000)
/// let result = validator.validateWrite(data, identifier: identifier, metadata: metadata)
/// ```
///
/// Create custom validator:
/// ```swift
/// struct CustomValidator: ChunkValidator {
///     func validateWrite(_ data: Data, identifier: ChunkIdentifier, metadata: ChunkMetadata?) -> ChunkValidationResult {
///         // Custom validation logic
///     }
///     // ... implement other methods
/// }
/// ```
///
/// ## See Also
///
/// - ``DefaultChunkValidator`` - Default implementation
/// - ``ChunkValidationResult`` - Validation result
/// - ``ChunkStorageError`` - Error types
public protocol ChunkValidator: Sendable {
    /// Validate chunk data before write
    /// - Parameters:
    ///   - data: Chunk data to validate
    ///   - identifier: Chunk identifier
    ///   - metadata: Optional chunk metadata
    /// - Returns: Validation result
    func validateWrite(_ data: Data, identifier: ChunkIdentifier, metadata: ChunkMetadata?) -> ChunkValidationResult
    
    /// Validate chunk data after read
    /// - Parameters:
    ///   - data: Chunk data to validate
    ///   - identifier: Chunk identifier
    /// - Returns: Validation result
    func validateRead(_ data: Data, identifier: ChunkIdentifier) -> ChunkValidationResult
    
    /// Validate chunk identifier
    /// - Parameter identifier: Chunk identifier to validate
    /// - Returns: Validation result
    func validateIdentifier(_ identifier: ChunkIdentifier) -> ChunkValidationResult
}

/// Default chunk validator implementation.
///
/// `DefaultChunkValidator` provides comprehensive validation including:
/// - Hash verification (ensures data matches identifier)
/// - Size validation (min/max size checks)
/// - Identifier format validation
/// - Metadata consistency checks
///
/// ## Usage
///
/// Create validator with default settings:
/// ```swift
/// let validator = DefaultChunkValidator()
/// ```
///
/// Create validator with custom settings:
/// ```swift
/// let validator = DefaultChunkValidator(
///     verifyHash: true,
///     minSize: 100,
///     maxSize: 10_000_000,
///     allowedHashAlgorithms: ["sha256"]
/// )
/// ```
///
/// ## See Also
///
/// - ``ChunkValidator`` - Validation protocol
/// - ``HashComputation`` - Hash computation utilities
public struct DefaultChunkValidator: ChunkValidator {
    private let verifyHash: Bool
    private let minSize: Int64?
    private let maxSize: Int64?
    private let allowedHashAlgorithms: Set<String>
    
    /// Create default chunk validator
    /// - Parameters:
    ///   - verifyHash: Whether to verify hash matches data (default: true)
    ///   - minSize: Minimum allowed chunk size in bytes (default: nil, no minimum)
    ///   - maxSize: Maximum allowed chunk size in bytes (default: nil, no maximum)
    ///   - allowedHashAlgorithms: Set of allowed hash algorithms (default: ["sha256"])
    public init(
        verifyHash: Bool = true,
        minSize: Int64? = nil,
        maxSize: Int64? = nil,
        allowedHashAlgorithms: Set<String> = ["sha256"]
    ) {
        self.verifyHash = verifyHash
        self.minSize = minSize
        self.maxSize = maxSize
        self.allowedHashAlgorithms = allowedHashAlgorithms
    }
    
    /// Validate chunk data before write operation.
    ///
    /// Performs comprehensive validation including:
    /// - Identifier format and algorithm validation
    /// - Data size validation (min/max limits if configured)
    /// - Hash verification (if enabled) to ensure data matches identifier
    /// - Metadata consistency checks
    ///
    /// - Parameters:
    ///   - data: Chunk data to validate
    ///   - identifier: Chunk identifier
    ///   - metadata: Optional chunk metadata
    /// - Returns: Validation result with errors and warnings
    public func validateWrite(_ data: Data, identifier: ChunkIdentifier, metadata: ChunkMetadata?) -> ChunkValidationResult {
        var errors: [ChunkStorageError] = []
        var warnings: [String] = []
        
        // Validate identifier
        let idValidation = validateIdentifier(identifier)
        if !idValidation.isValid {
            errors.append(contentsOf: idValidation.errors)
        }
        warnings.append(contentsOf: idValidation.warnings)
        
        // Validate data size
        let dataSize = Int64(data.count)
        if let minSize = minSize, dataSize < minSize {
            errors.append(.invalidDataSize(expected: minSize, actual: dataSize, identifier: identifier))
        }
        if let maxSize = maxSize, dataSize > maxSize {
            errors.append(.invalidDataSize(expected: maxSize, actual: dataSize, identifier: identifier))
        }
        
        // Validate hash matches data
        if verifyHash {
            do {
                let algorithm = identifier.metadata?.hashAlgorithm ?? "sha256"
                let computedHex = try HashComputation.computeHashHex(data: data, algorithm: algorithm)
                
                if computedHex != identifier.id {
                    errors.append(.hashMismatch(
                        expected: identifier.id,
                        actual: computedHex,
                        identifier: identifier
                    ))
                }
            } catch {
                errors.append(.custom("Failed to compute hash for validation", underlying: error))
            }
        }
        
        // Validate metadata size matches data size
        if let metadataSize = metadata?.size, metadataSize != dataSize {
            warnings.append("Metadata size (\(metadataSize)) doesn't match data size (\(dataSize))")
        }
        
        return ChunkValidationResult(isValid: errors.isEmpty, errors: errors, warnings: warnings)
    }
    
    /// Validate chunk data after read operation.
    ///
    /// Performs validation including:
    /// - Identifier format validation
    /// - Hash verification (if enabled) to detect data corruption
    /// - Metadata consistency checks
    ///
    /// - Parameters:
    ///   - data: Chunk data to validate
    ///   - identifier: Chunk identifier
    /// - Returns: Validation result with errors and warnings
    public func validateRead(_ data: Data, identifier: ChunkIdentifier) -> ChunkValidationResult {
        var errors: [ChunkStorageError] = []
        var warnings: [String] = []
        
        // Validate identifier
        let idValidation = validateIdentifier(identifier)
        if !idValidation.isValid {
            errors.append(contentsOf: idValidation.errors)
        }
        
        // Verify hash matches data
        if verifyHash {
            do {
                let algorithm = identifier.metadata?.hashAlgorithm ?? "sha256"
                let computedHex = try HashComputation.computeHashHex(data: data, algorithm: algorithm)
                
                if computedHex != identifier.id {
                    errors.append(.hashMismatch(
                        expected: identifier.id,
                        actual: computedHex,
                        identifier: identifier
                    ))
                    errors.append(.corruptedData(identifier, reason: "Hash mismatch"))
                }
            } catch {
                errors.append(.custom("Failed to verify hash", underlying: error))
            }
        }
        
        // Validate size matches metadata
        let dataSize = Int64(data.count)
        if let metadataSize = identifier.metadata?.size, metadataSize != dataSize {
            warnings.append("Data size (\(dataSize)) doesn't match metadata size (\(metadataSize))")
        }
        
        return ChunkValidationResult(isValid: errors.isEmpty, errors: errors, warnings: warnings)
    }
    
    /// Validate chunk identifier format and algorithm.
    ///
    /// Validates:
    /// - Hash format (hex string, expected length)
    /// - Hex character validation
    /// - Hash algorithm (must be in allowed algorithms list)
    ///
    /// - Parameter identifier: Chunk identifier to validate
    /// - Returns: Validation result with errors and warnings
    public func validateIdentifier(_ identifier: ChunkIdentifier) -> ChunkValidationResult {
        var errors: [ChunkStorageError] = []
        var warnings: [String] = []
        
        // Validate hash format (hex string, 64 chars for SHA256)
        let hash = identifier.id
        if hash.isEmpty {
            errors.append(.invalidIdentifier(identifier, reason: "Hash is empty"))
        }
        
        if hash.count != 64 {
            warnings.append("Hash length (\(hash.count)) is not standard SHA256 length (64)")
        }
        
        // Validate hex characters
        if !hash.allSatisfy({ $0.isHexDigit }) {
            errors.append(.invalidIdentifier(identifier, reason: "Hash contains non-hex characters"))
        }
        
        // Validate hash algorithm
        let algorithm = identifier.metadata?.hashAlgorithm ?? "sha256"
        if !allowedHashAlgorithms.contains(algorithm.lowercased()) {
            errors.append(.invalidHashAlgorithm(algorithm, identifier: identifier))
        }
        
        return ChunkValidationResult(isValid: errors.isEmpty, errors: errors, warnings: warnings)
    }
}

// MARK: - Character Extension

private extension Character {
    var isHexDigit: Bool {
        return ("0"..."9").contains(self) || ("a"..."f").contains(self) || ("A"..."F").contains(self)
    }
}

