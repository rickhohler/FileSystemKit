// FileSystemKit Core Library
// Git-Style Hash-Based Organization Strategy
//
// This file implements a Git-style hash-based organization strategy for chunks.
// Organizes chunks into directories based on first characters of hash.

import Foundation

/// Git-style hash-based organization strategy.
///
/// `GitStyleOrganization` organizes chunks into directories based on the first
/// characters of the hash, similar to how Git stores objects. This provides
/// efficient directory structure for large numbers of chunks.
///
/// ## Overview
///
/// The organization strategy:
/// - Creates directory structure from hash prefix
/// - Example: hash `"a1b2c3d4e5f6..."` → path `"a1/b2/a1b2c3d4e5f6..."`
/// - Configurable directory depth (1-4 levels)
/// - Prevents too many files in a single directory
///
/// ## Usage
///
/// Create with default depth (2 levels):
/// ```swift
/// let organization = GitStyleOrganization()
/// let identifier = ChunkIdentifier(id: "a1b2c3d4e5f6...")
/// let path = organization.storagePath(for: identifier)
/// // Returns: "a1/b2/a1b2c3d4e5f6..."
/// ```
///
/// Create with custom depth:
/// ```swift
/// let organization = GitStyleOrganization(directoryDepth: 3)
/// let identifier = ChunkIdentifier(id: "a1b2c3d4e5f6...")
/// let path = organization.storagePath(for: identifier)
/// // Returns: "a1/b2/c3/a1b2c3d4e5f6..."
/// ```
///
/// Parse identifier from path:
/// ```swift
/// let path = "a1/b2/a1b2c3d4e5f6..."
/// if let identifier = organization.identifier(from: path) {
///     print("Identifier: \(identifier.id)")
/// }
/// ```
///
/// ## Directory Depth
///
/// - **Depth 1**: `"a1/hash..."` - 256 directories
/// - **Depth 2**: `"a1/b2/hash..."` - 65,536 directories (default)
/// - **Depth 3**: `"a1/b2/c3/hash..."` - 16,777,216 directories
/// - **Depth 4**: `"a1/b2/c3/d4/hash..."` - 4,294,967,296 directories
///
/// Choose depth based on expected number of chunks:
/// - < 10,000 chunks: Depth 1
/// - 10,000 - 1,000,000 chunks: Depth 2 (recommended)
/// - 1,000,000+ chunks: Depth 3 or 4
///
/// ## See Also
///
/// - ``ChunkStorageOrganization`` - Organization protocol
/// - ``FlatOrganization`` - Flat organization alternative
/// - [Git Internals - Objects](https://git-scm.com/book/en/v2/Git-Internals-Git-Objects) - Git's object storage
public struct GitStyleOrganization: ChunkStorageOrganization {
    /// Organization strategy name.
    public let name = "git-style"
    
    /// Organization strategy description.
    public let description = "Git-style hash-based directory organization"
    
    /// Directory depth (1-4 levels).
    private let directoryDepth: Int
    
    /// Create Git-style organization with specified directory depth.
    ///
    /// - Parameter directoryDepth: Number of directory levels (1-4, default: 2)
    public init(directoryDepth: Int = 2) {
        // Limit to 1-4 levels for safety
        self.directoryDepth = min(max(directoryDepth, 1), 4)
    }
    
    /// Generate storage path for a chunk identifier.
    ///
    /// Creates directory structure from hash prefix:
    /// - Depth 2: `"a1/b2/a1b2c3d4..."`
    /// - Depth 3: `"a1/b2/c3/a1b2c3d4..."`
    ///
    /// - Parameter identifier: Chunk identifier
    /// - Returns: Storage path with directory structure
    public func storagePath(for identifier: ChunkIdentifier) -> String {
        let hash = identifier.id
        var components: [String] = []
        var index = hash.startIndex
        
        // Extract directory components from hash prefix
        for _ in 0..<directoryDepth {
            guard index < hash.endIndex,
                  let nextIndex = hash.index(index, offsetBy: 2, limitedBy: hash.endIndex) else {
                break
            }
            let component = String(hash[index..<nextIndex])
            components.append(component)
            index = nextIndex
        }
        
        // Combine directory path with full hash
        let directoryPath = components.joined(separator: "/")
        return "\(directoryPath)/\(hash)"
    }
    
    /// Parse chunk identifier from storage path.
    ///
    /// Extracts the hash from the path (last component after directory structure).
    ///
    /// - Parameter path: Storage path
    /// - Returns: Chunk identifier, or nil if path is invalid
    public func identifier(from path: String) -> ChunkIdentifier? {
        let components = path.split(separator: "/")
        guard let hashString = components.last,
              hashString.count >= 32 else {
            return nil
        }
        
        // Validate hex characters
        guard hashString.allSatisfy({ $0.isHexDigit }) else {
            return nil
        }
        
        // Create identifier with minimal metadata
        return ChunkIdentifier(
            id: String(hashString),
            metadata: ChunkMetadata(
                size: 0,
                contentHash: String(hashString),
                hashAlgorithm: "sha256"
            )
        )
    }
    
    /// Validate that a path is valid for this organization strategy.
    ///
    /// Checks if path can be parsed as a valid Git-style path.
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

