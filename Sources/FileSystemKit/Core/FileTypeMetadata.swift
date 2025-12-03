// FileSystemKit Core Library
// File Type Metadata Protocol
//
// This file defines a protocol for file type metadata that provides industry-standard
// identification beyond file extensions. It supports:
// - UTI-style identifiers (reverse-DNS or hierarchical)
// - Version information
// - Human-readable names
// - MIME types (IANA media types)
// - Magic numbers (file signatures)
// - Industry-standard naming conventions
//
// This protocol can be adopted by file type systems (like RetroboxFS FileType) to
// provide standardized metadata for file type identification and classification.

import Foundation

// MARK: - FileTypeMetadata Protocol

/// Protocol for file type metadata providing industry-standard identification.
///
/// This protocol extends basic file type identification with standardized metadata
/// that follows industry conventions (UTI, MIME types, versioning). It enables
/// file types to be identified by:
/// - **Type Identifier**: UTI-style identifier (e.g., "com.apple.disk-image.prodos-order")
/// - **Short ID**: Abbreviated identifier (e.g., "apo")
/// - **Display Name**: Human-readable name (e.g., "Apple II Disk Image Prodos Order")
/// - **Version**: Format version information
/// - **MIME Type**: IANA media type (e.g., "application/x-apple-diskimage-prodos")
///
/// ## Usage
///
/// Adopt this protocol in your file type system:
/// ```swift
/// struct ProDOSDiskImageType: FileTypeMetadata {
///     var typeIdentifier: String { "com.apple.disk-image.prodos-order" }
///     var shortID: String { "apo" }
///     var displayName: String { "Apple II Disk Image Prodos Order" }
///     var version: FileTypeVersion? { FileTypeVersion(major: 1, minor: 0) }
///     var mimeType: String? { "application/x-apple-diskimage-prodos" }
///     // ... other properties
/// }
/// ```
///
/// Use with file type detection:
/// ```swift
/// let metadata = ProDOSDiskImageType().metadata
/// print("Type: \(metadata.displayName)")
/// print("ID: \(metadata.shortID)")
/// print("UTI: \(metadata.typeIdentifier)")
/// ```
///
/// ## Industry Standards
///
/// - **UTI (Uniform Type Identifier)**: Reverse-DNS naming (e.g., `com.apple.*`)
/// - **MIME Types**: IANA media type registry (e.g., `application/x-*`)
/// - **Versioning**: Semantic versioning (major.minor.patch)
///
/// ## See Also
///
/// - ``FileTypeVersion`` - Version information
/// - ``FileTypeMagicNumber`` - Magic number (file signature) support
/// - [UTI Documentation](https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/understanding_utis/)
/// - [IANA Media Types](https://www.iana.org/assignments/media-types/)
public protocol FileTypeMetadata: Sendable {
    /// Uniform Type Identifier (UTI) - reverse-DNS style identifier
    /// Example: "com.apple.disk-image.dsk.prodos" (DSK format containing ProDOS file system)
    /// Format: [reverse-DNS].[category].[layer2-format].[layer3-format]
    /// 
    /// **Layer 2 (Disk Image Format)**: Required - represents how the disk image is stored in the file
    ///   Examples: dsk, woz, 2mg, d64, atr
    /// 
    /// **Layer 3 (File System Format)**: Optional - represents the file system structure inside the disk image
    ///   Examples: dos33, prodos, sos, pascal
    ///   Omitted if file system is unknown, unformatted, or copy-protected
    /// 
    /// **Both layers are included** because the same disk image format can contain different file systems.
    /// For example, a `.dsk` file can contain DOS 3.3, ProDOS, or be unformatted.
    /// 
    /// Examples:
    /// - `com.apple.disk-image.dsk.dos33` - DSK format containing DOS 3.3
    /// - `com.apple.disk-image.dsk.prodos` - DSK format containing ProDOS
    /// - `com.apple.disk-image.woz.dos33` - WOZ format containing DOS 3.3
    /// - `com.apple.disk-image.dsk` - DSK format, unknown/unformatted file system
    var typeIdentifier: String { get }
    
    /// Short identifier for the file type (3-8 characters, lowercase)
    /// Example: "apo" for "Apple II Disk Image Prodos Order"
    /// Used for compact representation and database storage
    var shortID: String { get }
    
    /// Human-readable display name
    /// Example: "Apple II Disk Image Prodos Order"
    /// Should be descriptive and follow industry naming conventions
    var displayName: String { get }
    
    /// Version information for the file type format
    /// nil if versioning is not applicable
    var version: FileTypeVersion? { get }
    
    /// MIME type (IANA media type)
    /// Example: "application/x-apple-diskimage-prodos"
    /// nil if no MIME type is registered
    var mimeType: String? { get }
    
    /// File extensions associated with this type
    /// Extensions should be lowercase, without leading dots
    /// Example: ["po", "prodos"]
    var extensions: [String] { get }
    
    /// Magic numbers (file signatures) for detection
    /// Primary method for file type identification
    var magicNumbers: [FileTypeMagicNumber] { get }
    
    /// Category classification
    /// Example: .diskImage, .archive, .document
    var category: FileTypeMetadataCategory { get }
    
    /// Vendor name - the company or organization that created/introduced the format
    /// Example: "Apple Computer", "Commodore Business Machines", "Microsoft"
    /// nil if vendor is unknown or not applicable
    var vendor: String? { get }
    
    /// Inception date - when the file format was created/introduced
    /// nil if the date is unknown
    var inceptionDate: Date? { get }
    
    /// Reference URLs - links to documentation, Wikipedia pages, specifications, etc.
    /// Can include multiple references (Wikipedia, official specs, implementation guides, etc.)
    /// Empty array if no references are available
    var references: [URL] { get }
    
    /// Additional metadata dictionary
    /// Can include vendor, specification URL, etc.
    var additionalMetadata: [String: String] { get }
}

// MARK: - FileTypeVersion

/// Version information for a file type format.
///
/// Uses semantic versioning (major.minor.patch) to track format versions.
/// This enables detection of format variants and compatibility checking.
///
/// ## Usage
///
/// Create a version:
/// ```swift
/// let version = FileTypeVersion(major: 1, minor: 2, patch: 3)
/// print(version.description) // "1.2.3"
/// ```
///
/// Compare versions:
/// ```swift
/// let v1 = FileTypeVersion(major: 1, minor: 0)
/// let v2 = FileTypeVersion(major: 1, minor: 1)
/// if v2 > v1 {
///     print("v2 is newer")
/// }
/// ```
public struct FileTypeVersion: Codable, Equatable, Comparable, Sendable {
    /// Major version number (incompatible changes)
    public let major: Int
    
    /// Minor version number (backward-compatible additions)
    public let minor: Int
    
    /// Patch version number (bug fixes)
    public let patch: Int
    
    /// Create a version
    /// - Parameters:
    ///   - major: Major version number
    ///   - minor: Minor version number (default: 0)
    ///   - patch: Patch version number (default: 0)
    public init(major: Int, minor: Int = 0, patch: Int = 0) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }
    
    /// String representation (e.g., "1.2.3")
    public var description: String {
        if patch == 0 {
            return "\(major).\(minor)"
        }
        return "\(major).\(minor).\(patch)"
    }
    
    // MARK: - Comparable
    
    public static func < (lhs: FileTypeVersion, rhs: FileTypeVersion) -> Bool {
        if lhs.major != rhs.major {
            return lhs.major < rhs.major
        }
        if lhs.minor != rhs.minor {
            return lhs.minor < rhs.minor
        }
        return lhs.patch < rhs.patch
    }
}

// MARK: - FileTypeMagicNumber

/// Magic number (file signature) for file type detection.
///
/// Magic numbers are byte sequences at specific offsets in a file that uniquely
/// identify the file type. This is more reliable than file extensions.
///
/// ## Usage
///
/// Create a magic number:
/// ```swift
/// // Check first 4 bytes
/// let magic = FileTypeMagicNumber(
///     offset: 0,
///     bytes: [0x50, 0x52, 0x4F, 0x44] // "PROD"
/// )
/// ```
///
/// Check if data matches:
/// ```swift
/// let data = Data([0x50, 0x52, 0x4F, 0x44, ...])
/// if magic.matches(data: data) {
///     print("File matches ProDOS format")
/// }
/// ```
public struct FileTypeMagicNumber: Codable, Equatable, Sendable {
    /// Byte offset where magic number appears (typically 0)
    public let offset: Int
    
    /// Magic number bytes
    public let bytes: [UInt8]
    
    /// Optional mask for partial matching (1 = must match, 0 = don't care)
    /// nil means all bytes must match exactly
    public let mask: [UInt8]?
    
    /// Create a magic number
    /// - Parameters:
    ///   - offset: Byte offset where magic number appears
    ///   - bytes: Magic number bytes
    ///   - mask: Optional mask for partial matching
    public init(offset: Int = 0, bytes: [UInt8], mask: [UInt8]? = nil) {
        self.offset = offset
        self.bytes = bytes
        self.mask = mask
    }
    
    /// Check if data matches this magic number
    /// - Parameter data: File data to check
    /// - Returns: true if data matches magic number
    public func matches(data: Data) -> Bool {
        guard data.count >= offset + bytes.count else {
            return false
        }
        
        let relevantData = data.subdata(in: offset..<(offset + bytes.count))
        
        if let mask = mask {
            // Partial matching with mask
            guard mask.count == bytes.count else {
                return false
            }
            for i in 0..<bytes.count {
                if mask[i] == 1 {
                    if relevantData[i] != bytes[i] {
                        return false
                    }
                }
            }
            return true
        } else {
            // Exact matching
            return relevantData.elementsEqual(bytes)
        }
    }
}

// MARK: - FileTypeMetadataCategory

/// Category classification for file type metadata.
///
/// Provides high-level categorization for file types to enable filtering
/// and organization. This is distinct from `FileTypeCategory` which is used
/// for basic file content classification (text, binary, etc.).
public enum FileTypeMetadataCategory: String, Codable, Sendable {
    /// Disk image formats
    case diskImage = "disk-image"
    
    /// Archive/compression formats
    case archive = "archive"
    
    /// Document formats
    case document = "document"
    
    /// Executable/binary formats
    case executable = "executable"
    
    /// Media formats (audio/video/image)
    case media = "media"
    
    /// Data/database formats
    case data = "data"
    
    /// System/configuration formats
    case system = "system"
    
    /// Unknown/other formats
    case unknown = "unknown"
}

// MARK: - FileTypeMetadata Default Implementation

public extension FileTypeMetadata {
    /// Default implementation: no vendor name
    var vendor: String? {
        return nil
    }
    
    /// Default implementation: no inception date
    var inceptionDate: Date? {
        return nil
    }
    
    /// Default implementation: no reference URLs
    var references: [URL] {
        return []
    }
    
    /// Default implementation: empty additional metadata
    var additionalMetadata: [String: String] {
        return [:]
    }
    
    /// Full type identifier with version (if applicable)
    /// Example: "com.apple.disk-image.prodos-order-v1.0"
    var fullTypeIdentifier: String {
        if let version = version {
            return "\(typeIdentifier)-v\(version.description)"
        }
        return typeIdentifier
    }
    
    /// Check if this metadata matches a given file extension
    /// - Parameter extension: File extension (with or without leading dot)
    /// - Returns: true if extension matches
    func matches(extension: String) -> Bool {
        let normalizedExt = `extension`.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
        return extensions.contains(normalizedExt)
    }
    
    /// Check if this metadata matches file data (via magic numbers)
    /// - Parameter data: File data to check
    /// - Returns: true if magic numbers match
    func matches(data: Data) -> Bool {
        return magicNumbers.contains { $0.matches(data: data) }
    }
}

// MARK: - FileTypeMetadata Registry

/// Registry for file type metadata discovery.
///
/// Provides a centralized registry for looking up file types by various
/// identifiers (type identifier, short ID, extension, magic number).
public actor FileTypeMetadataRegistry {
    /// Shared singleton instance (lazy initialization to avoid static initialization order issues)
    // Protected by lock, so marked as nonisolated(unsafe) for concurrency safety
    nonisolated(unsafe) private static var _shared: FileTypeMetadataRegistry?
    nonisolated private static let lock = NSLock()
    
    /// Shared singleton instance (lazy)
    public static var shared: FileTypeMetadataRegistry {
        lock.lock()
        defer { lock.unlock() }
        if _shared == nil {
            _shared = FileTypeMetadataRegistry()
        }
        return _shared!
    }
    
    /// Registered metadata (typeIdentifier -> metadata)
    private var byTypeIdentifier: [String: any FileTypeMetadata] = [:]
    
    /// Registered metadata (shortID -> metadata)
    private var byShortID: [String: any FileTypeMetadata] = [:]
    
    /// Registered metadata (extension -> [metadata])
    private var byExtension: [String: [any FileTypeMetadata]] = [:]
    
    /// Registered metadata (magic number signature -> [metadata])
    private var byMagicNumber: [String: [any FileTypeMetadata]] = [:]
    
    private init() {}
    
    /// Register file type metadata
    /// - Parameter metadata: Metadata to register
    public func register(_ metadata: any FileTypeMetadata) {
        // Register by type identifier
        byTypeIdentifier[metadata.typeIdentifier] = metadata
        
        // Register by short ID
        byShortID[metadata.shortID] = metadata
        
        // Register by extension
        for ext in metadata.extensions {
            let normalizedExt = ext.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
            if byExtension[normalizedExt] == nil {
                byExtension[normalizedExt] = []
            }
            byExtension[normalizedExt]?.append(metadata)
        }
        
        // Register by magic number
        for magicNumber in metadata.magicNumbers {
            let key = magicNumberSignatureKey(magicNumber)
            if byMagicNumber[key] == nil {
                byMagicNumber[key] = []
            }
            byMagicNumber[key]?.append(metadata)
        }
    }
    
    /// Find metadata by type identifier
    /// - Parameter typeIdentifier: Type identifier (UTI)
    /// - Returns: Matching metadata, or nil
    public func find(byTypeIdentifier typeIdentifier: String) -> (any FileTypeMetadata)? {
        return byTypeIdentifier[typeIdentifier]
    }
    
    /// Find metadata by short ID
    /// - Parameter shortID: Short identifier
    /// - Returns: Matching metadata, or nil
    public func find(byShortID shortID: String) -> (any FileTypeMetadata)? {
        return byShortID[shortID.lowercased()]
    }
    
    /// Find metadata by extension
    /// - Parameter extension: File extension
    /// - Returns: Array of matching metadata (may be multiple)
    public func find(byExtension extension: String) -> [any FileTypeMetadata] {
        let normalizedExt = `extension`.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
        return byExtension[normalizedExt] ?? []
    }
    
    /// Detect metadata from file data (using magic numbers)
    /// - Parameter data: File data
    /// - Returns: Matching metadata, or nil
    public func detect(from data: Data) -> (any FileTypeMetadata)? {
        // Check each registered metadata's magic numbers
        for (_, metadata) in byTypeIdentifier {
            if metadata.matches(data: data) {
                return metadata
            }
        }
        return nil
    }
    
    /// Detect metadata from file extension and data (combines both for disambiguation)
    /// 
    /// This method handles the common case where multiple file formats share the same extension.
    /// It first finds all metadata matching the extension, then uses magic numbers to disambiguate.
    ///
    /// - Parameters:
    ///   - extension: File extension (with or without leading dot)
    ///   - data: File data for magic number detection
    /// - Returns: Best matching metadata, or nil if no match
    /// 
    /// ## Example
    ///
    /// ```swift
    /// // .img extension can be disk image, raw image, etc.
    /// let data = try Data(contentsOf: fileURL)
    /// if let metadata = await registry.detect(extension: "img", data: data) {
    ///     print("Detected: \(metadata.displayName)")
    /// }
    /// ```
    public func detect(extension: String, data: Data) -> (any FileTypeMetadata)? {
        // First, find all metadata matching the extension
        let candidates = find(byExtension: `extension`)
        
        // If no candidates, return nil
        guard !candidates.isEmpty else {
            return nil
        }
        
        // If only one candidate, return it (even if magic numbers don't match)
        // This allows for formats without magic numbers
        if candidates.count == 1 {
            return candidates.first
        }
        
        // Multiple candidates: use magic numbers to disambiguate
        // Check each candidate's magic numbers
        for candidate in candidates {
            if candidate.matches(data: data) {
                return candidate
            }
        }
        
        // If no magic number match, return the first candidate
        // (fallback to extension-based detection)
        return candidates.first
    }
    
    /// Detect metadata from file URL and data (combines filename and magic numbers)
    ///
    /// This is a convenience method that extracts the extension from the URL
    /// and uses both extension and magic numbers for detection.
    ///
    /// - Parameters:
    ///   - url: File URL
    ///   - data: File data for magic number detection
    /// - Returns: Best matching metadata, or nil if no match
    public func detect(url: URL, data: Data) -> (any FileTypeMetadata)? {
        let fileExtension = url.pathExtension
        return detect(extension: fileExtension, data: data)
    }
    
    /// Get all registered metadata
    /// - Returns: Array of all registered metadata
    public func allMetadata() -> [any FileTypeMetadata] {
        return Array(byTypeIdentifier.values)
    }
    
    // MARK: - Private Helpers
    
    private func magicNumberSignatureKey(_ magicNumber: FileTypeMagicNumber) -> String {
        let bytesHex = magicNumber.bytes.map { String(format: "%02x", $0) }.joined()
        return "\(magicNumber.offset):\(bytesHex)"
    }
}

