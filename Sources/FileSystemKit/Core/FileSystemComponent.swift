// FileSystemKit Core Library
// File System Component Protocol and Implementations
//
// This file implements the Composite Pattern for file system hierarchy:
// - FileSystemComponent: Base protocol for files and directories
// - File: Leaf node with lazy-loaded content
// - FileSystemFolder: Composite node containing other components
//
// Critical Design: Metadata vs Content Separation
// - Metadata is always loaded (lightweight)
// - Content is lazy-loaded (only when accessed via readData())

import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif
#if canImport(CommonCrypto)
import CommonCrypto
#endif

// MARK: - FileSystemComponent Protocol

/// Base protocol for file system components (files and folders).
/// Implements the Composite Pattern to treat files and directories uniformly.
public protocol FileSystemComponent: AnyObject {
    /// Name of the file or directory
    var name: String { get }
    
    /// Size in bytes (for files) or total size of children (for directories)
    var size: Int { get }
    
    /// Modification date, if available
    var modificationDate: Date? { get }
    
    /// Parent folder, if any
    var parent: FileSystemFolder? { get set }
    
    /// Traverse this component and all children (for folders)
    func traverse() -> [FileSystemComponent]
}

// MARK: - FileLocation

/// Describes where file data is stored in a disk image
public struct FileLocation: Codable, Equatable {
    /// Track number (if applicable)
    public let track: Int?
    
    /// Sector number (if applicable)
    public let sector: Int?
    
    /// Byte offset in disk image
    public let offset: Int
    
    /// Length in bytes
    public let length: Int
    
    public init(track: Int? = nil, sector: Int? = nil, offset: Int, length: Int) {
        self.track = track
        self.sector = sector
        self.offset = offset
        self.length = length
    }
}

// MARK: - FileHash

/// Cryptographic hash for a file
public struct FileHash: Hashable, Codable {
    /// Hash algorithm used
    public let algorithm: HashAlgorithm
    
    /// Raw hash bytes
    public let value: Data
    
    /// Hex string representation (for display/API)
    public var hexString: String {
        value.map { String(format: "%02x", $0) }.joined()
    }
    
    /// Standard identifier format: "sha256:abc123..."
    public var identifier: String {
        "\(algorithm.rawValue):\(hexString)"
    }
    
    public init(algorithm: HashAlgorithm, value: Data) {
        self.algorithm = algorithm
        self.value = value
    }
    
    // Hashable conformance
    public func hash(into hasher: inout Hasher) {
        hasher.combine(algorithm)
        hasher.combine(value)
    }
    
    // Equatable conformance
    public static func == (lhs: FileHash, rhs: FileHash) -> Bool {
        lhs.algorithm == rhs.algorithm && lhs.value == rhs.value
    }
}

// MARK: - FileSystemEntryMetadata

/// Metadata for a file system entry (file or directory)
/// Separated from file content for efficient batch processing
public struct FileSystemEntryMetadata: Codable {
    /// File name
    public let name: String
    
    /// File size in bytes
    public let size: Int
    
    /// Modification date, if available
    public let modificationDate: Date?
    
    /// Detected file type category, if available
    public var fileType: FileTypeCategory?
    
    /// Additional attributes (system-specific)
    public var attributes: [String: Any]
    
    /// Location of file data in disk image (optional - not all entries have disk image location)
    public let location: FileLocation?
    
    /// Hashes for this file (lazy-computed, cached here)
    public var hashes: [HashAlgorithm: FileHash]
    
    public init(
        name: String,
        size: Int,
        modificationDate: Date? = nil,
        fileType: FileTypeCategory? = nil,
        attributes: [String: Any] = [:],
        location: FileLocation? = nil,
        hashes: [HashAlgorithm: FileHash] = [:]
    ) {
        self.name = name
        self.size = size
        self.modificationDate = modificationDate
        self.fileType = fileType
        self.attributes = attributes
        self.location = location
        self.hashes = hashes
    }
    
    // Custom Codable implementation for attributes (Dictionary with Any values)
    enum CodingKeys: String, CodingKey {
        case name, size, modificationDate, fileType, location, hashes
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        size = try container.decode(Int.self, forKey: .size)
        modificationDate = try container.decodeIfPresent(Date.self, forKey: .modificationDate)
        fileType = try container.decodeIfPresent(FileTypeCategory.self, forKey: .fileType)
        location = try container.decodeIfPresent(FileLocation.self, forKey: .location)
        hashes = try container.decode([HashAlgorithm: FileHash].self, forKey: .hashes)
        attributes = [:] // Attributes not encoded (Any type not Codable)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(size, forKey: .size)
        try container.encodeIfPresent(modificationDate, forKey: .modificationDate)
        try container.encodeIfPresent(fileType, forKey: .fileType)
        try container.encodeIfPresent(location, forKey: .location)
        try container.encode(hashes, forKey: .hashes)
        // Attributes not encoded (Any type not Codable)
    }
}

// MARK: - FileSystemEntry

/// Represents a file entry in a file system.
/// For directories, use FileSystemFolder instead.
/// Implements lazy loading: metadata is always loaded, content is loaded on demand.
public class FileSystemEntry: FileSystemComponent {
    /// Entry metadata (always loaded, lightweight)
    public let metadata: FileSystemEntryMetadata
    
    /// Reference to the chunk containing file data (if applicable)
    /// This links the file system entry to its binary data in ChunkStorage
    public let chunkIdentifier: ChunkIdentifier?
    
    /// File name (from metadata)
    public var name: String { metadata.name }
    
    /// File size (from metadata)
    public var size: Int { metadata.size }
    
    /// Modification date (from metadata)
    public var modificationDate: Date? { metadata.modificationDate }
    
    /// Parent folder
    public weak var parent: FileSystemFolder?
    
    /// File content (lazy-loaded, only when accessed)
    private var _data: Data?
    
    /// Cached raw disk data (for reading file content)
    private weak var _cachedDiskData: RawDiskData?
    
    /// Initialize a file system entry with metadata
    /// - Parameters:
    ///   - metadata: Entry metadata (always loaded)
    ///   - chunkIdentifier: Optional reference to chunk containing file data
    public init(metadata: FileSystemEntryMetadata, chunkIdentifier: ChunkIdentifier? = nil) {
        self.metadata = metadata
        self.chunkIdentifier = chunkIdentifier
    }
    
    /// Read file content (lazy-loaded).
    /// Loads content from disk data if not already cached.
    /// - Parameter diskData: Raw disk data containing file content
    /// - Returns: File content as Data
    /// - Throws: Error if file cannot be read
    public func readData(from diskData: RawDiskData) throws -> Data {
        // Cache disk data for later use
        _cachedDiskData = diskData
        
        // If already loaded, return cached data
        if let data = _data {
            return data
        }
        
        // Load data from disk based on location
        guard let location = metadata.location else {
            throw FileSystemError.diskDataNotAvailable
        }
        let data = try diskData.readData(at: location.offset, length: location.length)
        
        // Cache loaded data
        _data = data
        
        return data
    }
    
    /// Read file content using cached disk data (if available).
    /// - Returns: File content as Data
    /// - Throws: Error if file cannot be read or disk data not available
    public func readData() throws -> Data {
        guard let diskData = _cachedDiskData else {
            throw FileSystemError.diskDataNotAvailable
        }
        return try readData(from: diskData)
    }
    
    /// Generate hash for file content (default: SHA-256).
    /// Hash is cached in metadata for future use.
    /// - Parameter algorithm: Hash algorithm to use (default: SHA-256)
    /// - Returns: File hash
    /// - Throws: Error if hash cannot be generated
    public func generateHash(algorithm: HashAlgorithm = .sha256) throws -> FileHash {
        // Check if hash already computed and cached
        if let cachedHash = metadata.hashes[algorithm] {
            return cachedHash
        }
        
        // Load file data if not already loaded
        let data: Data
        if let cachedData = _data {
            data = cachedData
        } else if let diskData = _cachedDiskData {
            data = try readData(from: diskData)
        } else {
            throw FileSystemError.diskDataNotAvailable
        }
        
        // Generate hash
        let hash = try computeHash(data: data, algorithm: algorithm)
        
        // Cache hash in metadata (note: metadata is let, so we'd need to make hashes mutable)
        // For now, return hash (caching will be handled at a higher level)
        
        return hash
    }
    
    /// Traverse this file (returns just itself)
    public func traverse() -> [FileSystemComponent] {
        return [self]
    }
    
    /// Create a Chunk from this entry's chunk identifier
    /// - Parameters:
    ///   - storage: ChunkStorage to use for accessing chunk data
    ///   - accessPattern: Access pattern for caching (default: onDemand)
    /// - Returns: Chunk instance if chunkIdentifier is available, nil otherwise
    public func toChunk(storage: any ChunkStorage, accessPattern: AccessPattern = .onDemand) async throws -> Chunk? {
        guard let identifier = chunkIdentifier else {
            return nil
        }
        return try await Chunk.builder()
            .storage(storage)
            .identifier(identifier)
            .accessPattern(accessPattern)
            .build()
    }
    
    // MARK: - Private Helpers
    
    private func computeHash(data: Data, algorithm: HashAlgorithm) throws -> FileHash {
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
            // CRC32 not in CryptoKit, use simple implementation
            return FileHash(algorithm: .crc32, value: computeCRC32(data: data))
        }
        
        return FileHash(algorithm: algorithm, value: Data(digest))
        #elseif canImport(CommonCrypto)
        // Fallback: Use CommonCrypto (available on Apple platforms)
        switch algorithm {
        case .sha256:
            var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
            data.withUnsafeBytes { bytes in
                _ = CC_SHA256(bytes.baseAddress, CC_LONG(data.count), &digest)
            }
            return FileHash(algorithm: .sha256, value: Data(digest))
        case .sha1:
            var digest = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
            data.withUnsafeBytes { bytes in
                _ = CC_SHA1(bytes.baseAddress, CC_LONG(data.count), &digest)
            }
            return FileHash(algorithm: .sha1, value: Data(digest))
        case .md5:
            #if canImport(CryptoKit)
            // Use CryptoKit's Insecure.MD5 - explicitly marked as insecure for legacy compatibility
            let digest = Insecure.MD5.hash(data: data)
            return FileHash(algorithm: .md5, value: Data(digest))
            #elseif canImport(CommonCrypto)
            // Fallback: Use CommonCrypto (deprecated but kept for legacy compatibility)
            // MD5 is intentionally kept for legacy compatibility (companion files, existing checksums)
            // Note: CC_MD5 deprecation warning is intentional - MD5 is read-only legacy support
            var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
            data.withUnsafeBytes { bytes in
                digest.withUnsafeMutableBytes { digestBytes in
                    // Using deprecated CC_MD5 intentionally for legacy compatibility
                    _ = CC_MD5(bytes.baseAddress, CC_LONG(data.count), digestBytes.baseAddress)
                }
            }
            return FileHash(algorithm: .md5, value: Data(digest))
            #else
            throw FileSystemError.hashNotImplemented(algorithm: .md5)
            #endif
        case .crc32:
            return FileHash(algorithm: .crc32, value: computeCRC32(data: data))
        }
        #else
        throw FileSystemError.hashNotImplemented(algorithm: nil)
        #endif
    }
    
    private func computeCRC32(data: Data) -> Data {
        // Simple CRC32 implementation
        var crc: UInt32 = 0xFFFFFFFF
        let polynomial: UInt32 = 0xEDB88320
        
        var table: [UInt32] = Array(repeating: 0, count: 256)
        for i in 0..<256 {
            var value = UInt32(i)
            for _ in 0..<8 {
                value = (value & 1) != 0 ? (value >> 1) ^ polynomial : value >> 1
            }
            table[i] = value
        }
        
        for byte in data {
            let index = Int((crc ^ UInt32(byte)) & 0xFF)
            crc = (crc >> 8) ^ table[index]
        }
        
        crc ^= 0xFFFFFFFF
        return withUnsafeBytes(of: crc.bigEndian) { Data($0) }
    }
}

// MARK: - FileSystemFolder

/// Represents a folder/directory structure in a parsed file system.
/// Implements Composite Pattern: can contain files and subfolders.
/// 
/// Note: Named `FileSystemFolder` to avoid confusion with file system directory paths.
public class FileSystemFolder: FileSystemComponent {
    /// Folder name
    public let name: String
    
    /// Total size of all children
    public var size: Int {
        children.reduce(0) { $0 + $1.size }
    }
    
    /// Modification date, if available
    public let modificationDate: Date?
    
    /// Parent folder
    public weak var parent: FileSystemFolder?
    
    /// Child components (files and subfolders)
    public private(set) var children: [FileSystemComponent] = []
    
    /// Initialize a folder
    /// - Parameters:
    ///   - name: Folder name
    ///   - modificationDate: Modification date, if available
    public init(name: String, modificationDate: Date? = nil) {
        self.name = name
        self.modificationDate = modificationDate
    }
    
    /// Add a child component (file or subdirectory)
    /// - Parameter component: Component to add
    public func addChild(_ component: FileSystemComponent) {
        component.parent = self
        children.append(component)
    }
    
    /// Remove a child component
    /// - Parameter component: Component to remove
    public func removeChild(_ component: FileSystemComponent) {
        children.removeAll { $0 === component }
        component.parent = nil
    }
    
    /// Find a child component by name
    /// - Parameter name: Name to search for
    /// - Returns: Found component, or nil if not found
    public func findChild(named name: String) -> FileSystemComponent? {
        return children.first { $0.name == name }
    }
    
    /// Traverse this directory and all children recursively
    /// - Returns: Array of all components (this directory and all descendants)
    public func traverse() -> [FileSystemComponent] {
        var result: [FileSystemComponent] = [self]
        for child in children {
            result.append(contentsOf: child.traverse())
        }
        return result
    }
}

// MARK: - FileSystemFolder Navigation Extensions

extension FileSystemFolder {
    /// Get all files in this directory (non-recursive)
    /// - Returns: Array of File objects in this directory
    public func getFiles() -> [File] {
        return children.compactMap { $0 as? File }
    }
    
    /// Get all subfolders in this folder (non-recursive)
    /// - Returns: Array of FileSystemFolder objects in this folder
    public func getFolders() -> [FileSystemFolder] {
        return children.compactMap { $0 as? FileSystemFolder }
    }
    
    /// Get all files and folders in this folder (non-recursive)
    /// - Returns: Tuple containing files and folders
    public func getContents() -> (files: [FileSystemEntry], folders: [FileSystemFolder]) {
        var files: [FileSystemEntry] = []
        var folders: [FileSystemFolder] = []
        
        for child in children {
            if let file = child as? File {
                files.append(file)
            } else if let folder = child as? FileSystemFolder {
                folders.append(folder)
            }
        }
        
        return (files: files, folders: folders)
    }
    
    /// Find a file by name in this directory
    /// - Parameter name: File name to search for
    /// - Returns: Found File, or nil if not found
    public func getFile(named name: String) -> FileSystemEntry? {
        return findChild(named: name) as? FileSystemEntry
    }
    
    /// Find a folder by name in this folder
    /// - Parameter name: Folder name to search for
    /// - Returns: Found FileSystemFolder, or nil if not found
    public func getFolder(named name: String) -> FileSystemFolder? {
        return findChild(named: name) as? FileSystemFolder
    }
    
    /// Navigate to a folder by path
    /// - Parameter path: Path string (e.g., "folder1/folder2" or "/folder1/folder2")
    /// - Returns: FileSystemFolder at the specified path, or nil if not found
    /// - Note: Path can be absolute (starting with "/") or relative
    public func navigate(to path: String) -> FileSystemFolder? {
        let components = path.split(separator: "/").map(String.init)
        
        // Handle absolute paths (start from root)
        var currentFolder: FileSystemFolder? = self
        if path.hasPrefix("/") {
            // Find root folder
            var root = self
            while let parent = root.parent {
                root = parent
            }
            currentFolder = root
        }
        
        // Navigate through path components
        for component in components {
            guard component != "", component != "." else {
                continue
            }
            
            if component == ".." {
                currentFolder = currentFolder?.parent
            } else {
                currentFolder = currentFolder?.getFolder(named: component)
            }
            
            guard currentFolder != nil else {
                return nil
            }
        }
        
        return currentFolder
    }
    
    /// Get a file by path
    /// - Parameter path: Path string (e.g., "folder/file.txt" or "/folder/file.txt")
    /// - Returns: File at the specified path, or nil if not found
    /// - Note: Path can be absolute (starting with "/") or relative
    public func getFile(at path: String) -> File? {
        let components = path.split(separator: "/").map(String.init)
        guard !components.isEmpty else {
            return nil
        }
        
        let fileName = components.last!
        let folderPath = components.dropLast().joined(separator: "/")
        
        // Navigate to folder
        let targetFolder: FileSystemFolder?
        if folderPath.isEmpty {
            targetFolder = self
        } else {
            targetFolder = navigate(to: folderPath)
        }
        
        return targetFolder?.getFile(named: fileName)
    }
    
    /// Check if this is the root folder
    /// - Returns: true if this folder has no parent
    public var isRoot: Bool {
        return parent == nil
    }
    
    /// Get the root folder
    /// - Returns: The root folder (topmost parent)
    public var root: FileSystemFolder {
        var current = self
        while let parent = current.parent {
            current = parent
        }
        return current
    }
    
    /// Get the full path of this folder
    /// - Returns: Path string from root to this folder (e.g., "/folder1/folder2")
    public var path: String {
        var components: [String] = []
        var current: FileSystemFolder? = self
        
        while let folder = current, !folder.isRoot {
            components.insert(folder.name, at: 0)
            current = folder.parent
        }
        
        return "/" + components.joined(separator: "/")
    }
}

// MARK: - Backward Compatibility Typealiases

/// Backward compatibility: File is now FileSystemEntry
/// Use FileSystemEntry in new code
@available(*, deprecated, renamed: "FileSystemEntry", message: "Use FileSystemEntry instead to avoid naming conflicts")
public typealias File = FileSystemEntry

/// Backward compatibility: FileMetadata is now FileSystemEntryMetadata
/// Use FileSystemEntryMetadata in new code
@available(*, deprecated, renamed: "FileSystemEntryMetadata", message: "Use FileSystemEntryMetadata instead for clarity")
public typealias FileMetadata = FileSystemEntryMetadata

