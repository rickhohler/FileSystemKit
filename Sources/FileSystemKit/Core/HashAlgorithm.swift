// FileSystemKit Core Library
// Hash Algorithm Types
//
// This file defines hash algorithm types used throughout FileSystemKit

import Foundation

/// Hash algorithms supported for file and disk image hashing
public enum HashAlgorithm: String, CaseIterable, Codable, Sendable {
    case sha256 = "sha256"
    case sha1 = "sha1"
    case md5 = "md5"
    case crc32 = "crc32"
    
    public var displayName: String {
        rawValue.uppercased()
    }
}

