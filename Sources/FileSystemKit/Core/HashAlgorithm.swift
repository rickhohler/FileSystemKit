// FileSystemKit Core Library
// Hash Algorithm Types
//
// This file defines hash algorithm types used throughout FileSystemKit
//
// Hash Algorithm Policy:
// - SHA-256: Recommended default for new hash generation
// - SHA-1: Legacy support for existing systems
// - MD5: Read-only legacy support (validation against companion files, existing checksums)
// - CRC32: Fast checksum for quick integrity checks
//
// See docs/HASH_ALGORITHM_POLICY.md for detailed policy

import Foundation

/// Hash algorithms supported for file and disk image hashing
public enum HashAlgorithm: String, CaseIterable, Codable, Sendable {
    /// SHA-256: Recommended default for new hash generation (cryptographically secure)
    case sha256 = "sha256"
    
    /// SHA-1: Legacy support for existing systems (deprecated but collision-resistant)
    case sha1 = "sha1"
    
    /// MD5: Read-only legacy support for validation against companion files and existing checksums
    /// ⚠️ Do not use for new hash generation - use SHA-256 instead
    /// ✅ Supported for: reading companion checksum files (.md5, .md5sum), validating against existing MD5 hashes
    case md5 = "md5"
    
    /// CRC32: Fast checksum for quick integrity checks (not cryptographic)
    case crc32 = "crc32"
    
    public var displayName: String {
        rawValue.uppercased()
    }
    
    /// Whether this algorithm is recommended for new hash generation
    public var isRecommendedForNewHashes: Bool {
        switch self {
        case .sha256:
            return true
        case .sha1, .md5, .crc32:
            return false
        }
    }
    
    /// Whether this algorithm is suitable for read-only validation (companion files, existing checksums)
    public var isSuitableForValidation: Bool {
        // All algorithms can be used for validation
        return true
    }
    
    /// Hash size in bytes
    public var hashSize: Int {
        switch self {
        case .crc32:
            return 4
        case .md5:
            return 16
        case .sha1:
            return 20
        case .sha256:
            return 32
        }
    }
    
    /// Whether this algorithm is suitable for small files (< 1MB)
    /// All algorithms are fast enough for small files, but SHA-256 is recommended
    public var isSuitableForSmallFiles: Bool {
        // All algorithms are suitable, but SHA-256 is recommended
        return true
    }
    
    /// Recommended algorithm for small files
    public static var recommendedForSmallFiles: HashAlgorithm {
        return .sha256
    }
    
    /// Recommended algorithm for millions of files
    /// SHA-256 is recommended up to 100M files (3.2 GB storage overhead)
    /// For > 100M files, consider two-stage approach (CRC32 filter + SHA-256 verification)
    public static var recommendedForMillionsOfFiles: HashAlgorithm {
        return .sha256
    }
    
    /// Storage overhead in MB for N files
    public func storageOverheadMB(for fileCount: Int) -> Double {
        return (Double(hashSize) * Double(fileCount)) / (1024.0 * 1024.0)
    }
    
    /// Whether this algorithm is suitable for millions of files
    /// SHA-256 is suitable up to ~100M files (3.2 GB storage)
    /// CRC32 has high collision risk for millions of files
    public var isSuitableForMillionsOfFiles: Bool {
        switch self {
        case .sha256, .sha1:
            return true  // Secure, negligible collision risk
        case .md5:
            return true  // Negligible collision risk, but cryptographically broken
        case .crc32:
            return false  // High collision risk for millions of files
        }
    }
}

