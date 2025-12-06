//
//  UTI.swift
//  FileSystemKit
//
//  Uniform Type Identifier implementation with conformance hierarchy
//

import Foundation

/// Uniform Type Identifier (UTI) with hierarchical conformance
///
/// UTI provides a standardized way to identify file types using reverse-DNS notation.
/// Supports conformance relationships (e.g., `jpeg` conforms to `image` conforms to `data`).
///
/// ## Usage
///
/// Create a custom UTI:
/// ```swift
/// let myType = UTI(
///     identifier: "com.mycompany.custom-format",
///     conformsTo: [.data, .content],
///     description: "My Custom File Format"
/// )
/// ```
///
/// Check conformance:
/// ```swift
/// let jpeg = UTI.jpeg
/// if jpeg.conforms(to: .image) {
///     print("JPEG is an image type")
/// }
/// ```
public struct UTI: Hashable, Sendable, Codable {
    /// The reverse-DNS identifier
    /// Example: "com.apple.disk-image.dsk.dos33.v3.3"
    public let identifier: String
    
    /// UTIs this type conforms to (inheritance hierarchy)
    public let conformsTo: [UTI]
    
    /// Human-readable description
    public let description: String
    
    /// Create a new UTI
    /// - Parameters:
    ///   - identifier: Reverse-DNS identifier
    ///   - conformsTo: Parent UTIs (default: empty)
    ///   - description: Human-readable description (default: uses identifier)
    public init(
        identifier: String,
        conformsTo: [UTI] = [],
        description: String? = nil
    ) {
        self.identifier = identifier
        self.conformsTo = conformsTo
        self.description = description ?? identifier
    }
    
    /// Check if this UTI conforms to another UTI
    ///
    /// Uses recursive checking through the conformance hierarchy.
    ///
    /// - Parameter other: UTI to check conformance against
    /// - Returns: true if this UTI conforms to the other UTI
    public func conforms(to other: UTI) -> Bool {
        // Direct match
        if self == other {
            return true
        }
        
        // Check parents recursively
        return conformsTo.contains { $0.conforms(to: other) }
    }
    
    // MARK: - Hashable
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(identifier)
    }
    
    public static func == (lhs: UTI, rhs: UTI) -> Bool {
        lhs.identifier == rhs.identifier
    }
    
    // MARK: - Standard UTIs
    
    /// Base type for all data
    public static let data = UTI(
        identifier: "public.data",
        description: "Data"
    )
    
    /// Base type for content
    public static let content = UTI(
        identifier: "public.content",
        description: "Content"
    )
    
    /// Base type for items
    public static let item = UTI(
        identifier: "public.item",
        description: "Item"
    )
    
    // MARK: - Text Types
    
    /// Plain text
    public static let plainText = UTI(
        identifier: "public.plain-text",
        conformsTo: [.text, .content],
        description: "Plain Text"
    )
    
    /// Generic text
    public static let text = UTI(
        identifier: "public.text",
        conformsTo: [.content, .data],
        description: "Text"
    )
    
    // MARK: - Image Types
    
    /// Generic image
    public static let image = UTI(
        identifier: "public.image",
        conformsTo: [.data, .content],
        description: "Image"
    )
    
    /// JPEG image
    public static let jpeg = UTI(
        identifier: "public.jpeg",
        conformsTo: [.image],
        description: "JPEG Image"
    )
    
    /// PNG image
    public static let png = UTI(
        identifier: "public.png",
        conformsTo: [.image],
        description: "PNG Image"
    )
    
    // MARK: - Archive Types
    
    /// Generic archive
    public static let archive = UTI(
        identifier: "public.archive",
        conformsTo: [.data],
        description: "Archive"
    )
    
    /// ZIP archive
    public static let zip = UTI(
        identifier: "public.zip-archive",
        conformsTo: [.archive],
        description: "ZIP Archive"
    )
    
    // MARK: - Disk Image Types
    
    /// Generic disk image
    public static let diskImage = UTI(
        identifier: "public.disk-image",
        conformsTo: [.data],
        description: "Disk Image"
    )
    
    // MARK: - Vintage Computing Types
    
    /// BASIC program (generic)
    public static let basicProgram = UTI(
        identifier: "com.vintage.basic-program",
        conformsTo: [.text, .content],
        description: "BASIC Program"
    )
    
    /// Assembly language source
    public static let assemblySource = UTI(
        identifier: "com.vintage.assembly-source",
        conformsTo: [.text, .content],
        description: "Assembly Language Source"
    )
    
    /// Machine code executable
    public static let machineCode = UTI(
        identifier: "com.vintage.machine-code",
        conformsTo: [.data],
        description: "Machine Code"
    )
}

// MARK: - UTI Extensions

public extension UTI {
    /// Get all ancestors (types this UTI conforms to) recursively
    var ancestors: Set<UTI> {
        var result = Set<UTI>()
        var queue = conformsTo
        
        while !queue.isEmpty {
            let current = queue.removeFirst()
            if result.insert(current).inserted {
                queue.append(contentsOf: current.conformsTo)
            }
        }
        
        return result
    }
    
    /// Check if this is a base UTI (no parents)
    var isBase: Bool {
        conformsTo.isEmpty
    }
    
    /// Get conformance hierarchy as tree description
    var hierarchyDescription: String {
        var lines: [String] = [description]
        for parent in conformsTo {
            lines.append("  ↳ \(parent.hierarchyDescription)")
        }
        return lines.joined(separator: "\n")
    }
}
