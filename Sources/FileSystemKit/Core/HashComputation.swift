// FileSystemKit Core Library
// Hash Computation Utilities
//
// Unified hash computation implementation for use across all FileSystemKit modules.
// This replaces duplicate implementations in RetroboxFS, SnugArchiver, FileHashCache,
// RawDiskData, and FileSystemComponent.
//
// Supports both Data and String (hex) return types for flexibility.

import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif
#if canImport(CommonCrypto)
import CommonCrypto
#endif

/// Unified hash computation utilities
public enum HashComputation {
    /// Compute hash and return as Data
    /// - Parameters:
    ///   - data: Data to hash
    ///   - algorithm: Hash algorithm to use
    /// - Returns: Hash as Data
    /// - Throws: FileSystemError if hashing fails or algorithm is unsupported
    public static func computeHash(data: Data, algorithm: HashAlgorithm) throws -> Data {
        #if canImport(CryptoKit)
        let digest: any Digest
        switch algorithm {
        case .sha256:
            digest = SHA256.hash(data: data)
        case .sha1:
            digest = Insecure.SHA1.hash(data: data)
        case .md5:
            digest = Insecure.MD5.hash(data: data)
        case .crc32:
            // CRC32 not in CryptoKit, use custom implementation
            return computeCRC32(data: data)
        }
        return Data(digest)
        #elseif canImport(CommonCrypto)
        switch algorithm {
        case .sha256:
            var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
            data.withUnsafeBytes { bytes in
                _ = CC_SHA256(bytes.baseAddress, CC_LONG(data.count), &digest)
            }
            return Data(digest)
        case .sha1:
            var digest = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
            data.withUnsafeBytes { bytes in
                _ = CC_SHA1(bytes.baseAddress, CC_LONG(data.count), &digest)
            }
            return Data(digest)
        case .md5:
            // Use CommonCrypto (deprecated but kept for legacy compatibility)
            // MD5 is intentionally kept for legacy compatibility (companion files, existing checksums)
            // See HASH_ALGORITHM_POLICY.md for details
            var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
            data.withUnsafeBytes { bytes in
                digest.withUnsafeMutableBytes { digestBytes in
                    // Using deprecated CC_MD5 intentionally for legacy compatibility
                    _ = CC_MD5(bytes.baseAddress, CC_LONG(data.count), digestBytes.baseAddress)
                }
            }
            return Data(digest)
        case .crc32:
            return computeCRC32(data: data)
        }
        #else
        throw FileSystemError.hashNotImplemented(algorithm: algorithm.rawValue)
        #endif
    }
    
    /// Compute hash and return as hex string (lowercase)
    /// - Parameters:
    ///   - data: Data to hash
    ///   - algorithm: Hash algorithm to use
    /// - Returns: Hash as hex string (lowercase, no separators)
    /// - Throws: FileSystemError if hashing fails or algorithm is unsupported
    public static func computeHashHex(data: Data, algorithm: HashAlgorithm) throws -> String {
        let hashData = try computeHash(data: data, algorithm: algorithm)
        return hashData.map { String(format: "%02x", $0) }.joined()
    }
    
    /// Compute hash and return as hex string (lowercase) from algorithm name string
    /// Convenience method for code that uses string-based algorithm names
    /// - Parameters:
    ///   - data: Data to hash
    ///   - algorithm: Hash algorithm name (e.g., "sha256", "sha1", "md5")
    /// - Returns: Hash as hex string (lowercase, no separators)
    /// - Throws: FileSystemError if hashing fails or algorithm is unsupported
    public static func computeHashHex(data: Data, algorithm: String) throws -> String {
        guard let hashAlgorithm = HashAlgorithm(rawValue: algorithm.lowercased()) else {
            throw FileSystemError.hashNotImplemented(algorithm: algorithm)
        }
        return try computeHashHex(data: data, algorithm: hashAlgorithm)
    }
    
    /// Compute CRC32 checksum
    /// - Parameter data: Data to checksum
    /// - Returns: CRC32 as Data (4 bytes, big-endian)
    public static func computeCRC32(data: Data) -> Data {
        var crc: UInt32 = 0xFFFFFFFF
        for byte in data {
            crc = crc32Table[Int((crc ^ UInt32(byte)) & 0xFF)] ^ (crc >> 8)
        }
        crc = crc ^ 0xFFFFFFFF
        return withUnsafeBytes(of: crc.bigEndian) { Data($0) }
    }
    
    // MARK: - Private Helpers
    
    /// CRC32 lookup table
    private static let crc32Table: [UInt32] = {
        var table: [UInt32] = []
        for i in 0..<256 {
            var crc = UInt32(i)
            for _ in 0..<8 {
                crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xEDB88320 : crc >> 1
            }
            table.append(crc)
        }
        return table
    }()
}

