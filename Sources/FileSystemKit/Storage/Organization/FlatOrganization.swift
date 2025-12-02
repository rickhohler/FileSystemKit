// FileSystemKit Core Library
// Flat Organization Strategy
//
// This file implements a flat organization strategy where all chunks are stored
// in a single directory. Suitable for small collections.

import Foundation

/// Flat organization strategy - all chunks in single directory.
///
/// `FlatOrganization` stores all chunks in a single directory without any
/// subdirectory structure. This is suitable for small collections (< 10,000 chunks)
/// where directory structure overhead is not needed.
///
/// ## Overview
///
/// The organization strategy:
/// - Stores all chunks in a single directory
/// - Uses hash as filename directly
/// - Simple and straightforward
/// - Best for small collections
///
/// ## Usage
///
/// Create flat organization:
/// ```swift
/// let organization = FlatOrganization()
/// let identifier = ChunkIdentifier(id: "a1b2c3d4e5f6...")
/// let path = organization.storagePath(for: identifier)
/// // Returns: "a1b2c3d4e5f6..."
/// ```
///
/// Parse identifier from path:
/// ```swift
/// let path = "a1b2c3d4e5f6..."
/// if let identifier = organization.identifier(from: path) {
///     print("Identifier: \(identifier.id)")
/// }
/// ```
///
/// ## When to Use
///
/// Use `FlatOrganization` when:
/// - You have a small number of chunks (< 10,000)
/// - Simplicity is preferred over performance
/// - Testing or development scenarios
///
/// Use `GitStyleOrganization` when:
/// - You have many chunks (> 10,000)
/// - Performance is important
/// - Production scenarios
///
/// ## See Also
///
/// - ``ChunkStorageOrganization`` - Organization protocol
/// - ``GitStyleOrganization`` - Git-style organization alternative
public struct FlatOrganization: ChunkStorageOrganization {
    /// Organization strategy name.
    public let name = "flat"
    
    /// Organization strategy description.
    public let description = "Flat organization - all chunks in single directory"
    
    /// Create flat organization.
    public init() {}
    
    /// Generate storage path for a chunk identifier.
    ///
    /// Returns the hash directly as the path (no directory structure).
    ///
    /// - Parameter identifier: Chunk identifier
    /// - Returns: Storage path (just the hash)
    public func storagePath(for identifier: ChunkIdentifier) -> String {
        return identifier.id
    }
    
    /// Parse chunk identifier from storage path.
    ///
    /// Validates that path is a valid hex hash string.
    ///
    /// - Parameter path: Storage path
    /// - Returns: Chunk identifier, or nil if path is invalid
    public func identifier(from path: String) -> ChunkIdentifier? {
        // Validate hex characters and minimum length
        guard path.allSatisfy({ $0.isHexDigit }),
              path.count >= 32 else {
            return nil
        }
        
        // Create identifier with minimal metadata
        return ChunkIdentifier(
            id: path,
            metadata: ChunkMetadata(
                size: 0,
                contentHash: path,
                hashAlgorithm: "sha256"
            )
        )
    }
    
    /// Validate that a path is valid for this organization strategy.
    ///
    /// Checks if path is a valid hex hash string.
    ///
    /// - Parameter path: Storage path to validate
    /// - Returns: True if path is valid
    public func isValidPath(_ path: String) -> Bool {
        return identifier(from: path) != nil
    }
}

// MARK: - Helper Extensions

private extension Character {
    /// Check if character is a hexadecimal digit.
    var isHexDigit: Bool {
        return ("0"..."9").contains(self) || ("a"..."f").contains(self) || ("A"..."F").contains(self)
    }
}

