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
///
/// `FileSystemComponent` implements the Composite Pattern, allowing files and directories
/// to be treated uniformly. This enables recursive traversal and uniform operations
/// across the file system hierarchy.
///
/// ## Overview
///
/// File system components can be either:
/// - **Files** (`FileSystemEntry`) - Leaf nodes containing file data
/// - **Folders** (`FileSystemFolder`) - Composite nodes containing other components
///
/// ## Usage
///
/// Traverse a file system hierarchy:
/// ```swift
/// let rootFolder: FileSystemFolder = // ... obtained from parser
///
/// // Get all components recursively
/// let allComponents = rootFolder.traverse()
///
/// for component in allComponents {
///     print("\(component.name): \(component.size) bytes")
/// }
/// ```
///
/// Access parent folder:
/// ```swift
/// let file: FileSystemComponent = // ... a file or folder
///
/// if let parent = file.parent {
///     print("Parent: \(parent.name)")
/// }
/// ```
///
/// ## Design Principles
///
/// - **Metadata-First**: Components always have metadata (name, size, dates) available
/// - **Lazy Content**: File content is loaded on-demand, not during parsing
/// - **Uniform Interface**: Files and folders share the same protocol interface
///
/// ## See Also
///
/// - ``FileSystemEntry`` - File implementation
/// - ``FileSystemFolder`` - Folder implementation
/// - [Composite Pattern (Wikipedia)](https://en.wikipedia.org/wiki/Composite_pattern) - Design pattern for tree structures
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

/// Describes the physical location of file data within a disk image.
///
/// `FileLocation` provides precise information about where file content is stored,
/// including track/sector information (for vintage formats) and byte offsets.
///
/// ## Usage
///
/// Create a file location:
/// ```swift
/// let location = FileLocation(
///     track: 0,
///     sector: 5,
///     offset: 1024,
///     length: 512
/// )
/// ```
///
/// For modern formats without track/sector:
/// ```swift
/// let location = FileLocation(
///     offset: 2048,
///     length: 1024
/// )
/// ```
///
/// ## Properties
///
/// - `track` - Track number (for vintage disk formats, nil for modern formats)
/// - `sector` - Sector number (for vintage disk formats, nil for modern formats)
/// - `offset` - Byte offset from start of disk image
/// - `length` - Length of file data in bytes
///
/// ## See Also
///
/// - ``FileSystemEntry`` - Uses FileLocation to store file data location
/// - [Disk Sector (Wikipedia)](https://en.wikipedia.org/wiki/Disk_sector) - Information about disk sectors
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

/// Cryptographic hash for file content verification and identification.
///
/// `FileHash` represents a cryptographic hash of file content, supporting multiple
/// hash algorithms. It's used for content-addressable storage and integrity verification.
///
/// ## Usage
///
/// Create a hash from data:
/// ```swift
/// let data = "Hello, World!".data(using: .utf8)!
/// let hash = FileHash(algorithm: .sha256, value: sha256Hash(data))
///
/// print("Hash: \(hash.hexString)")
/// print("Identifier: \(hash.identifier)")
/// ```
///
/// Compare hashes:
/// ```swift
/// let hash1 = FileHash(algorithm: .sha256, value: data1)
/// let hash2 = FileHash(algorithm: .sha256, value: data2)
///
/// if hash1 == hash2 {
///     print("Files are identical")
/// }
/// ```
///
/// Use in content-addressable storage:
/// ```swift
/// let hash = FileHash(algorithm: .sha256, value: fileDataHash)
/// let storagePath = "\(hash.algorithm.rawValue)/\(hash.hexString.prefix(2))/\(hash.hexString)"
/// ```
///
/// ## Properties
///
/// - `algorithm` - Hash algorithm used (sha256, sha1, md5)
/// - `value` - Raw hash bytes
/// - `hexString` - Hexadecimal string representation
/// - `identifier` - Standard format: "sha256:abc123..."
///
/// ## Supported Algorithms
///
/// - `.sha256` - SHA-256 (recommended, secure)
/// - `.sha1` - SHA-1 (faster, less secure)
/// - `.md5` - MD5 (fastest, not cryptographically secure)
///
/// ## See Also
///
/// - ``FileSystemEntry`` - Files can have associated hashes
/// - [Cryptographic Hash Function (Wikipedia)](https://en.wikipedia.org/wiki/Cryptographic_hash_function) - Overview of hash functions
/// - [SHA-2 (Wikipedia)](https://en.wikipedia.org/wiki/SHA-2) - SHA-256 algorithm details
/// - [MD5 (Wikipedia)](https://en.wikipedia.org/wiki/MD5) - MD5 algorithm details
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

/// Metadata describing a file system entry (file or directory).
///
/// `FileSystemEntryMetadata` separates metadata from file content, enabling
/// fast parsing of file systems without loading all file data. This metadata
/// is always loaded during parsing, while file content is loaded on-demand.
///
/// ## Usage
///
/// Create metadata for a file:
/// ```swift
/// let metadata = FileSystemEntryMetadata(
///     name: "document.txt",
///     size: 1024,
///     location: FileLocation(offset: 2048, length: 1024),
///     modificationDate: Date()
/// )
/// ```
///
/// Include hash information:
/// ```swift
/// let hash = FileHash(algorithm: .sha256, value: hashData)
/// let metadata = FileSystemEntryMetadata(
///     name: "file.dat",
///     size: 512,
///     hashes: [.sha256: hash]
/// )
/// ```
///
/// Access metadata properties:
/// ```swift
/// let entry: FileSystemEntry = // ... obtained from parser
///
/// print("Name: \(entry.metadata.name)")
/// print("Size: \(entry.metadata.size) bytes")
/// print("Modified: \(entry.metadata.modificationDate ?? Date())")
///
/// if let location = entry.metadata.location {
///     print("Location: offset \(location.offset), length \(location.length)")
/// }
/// ```
///
/// ## Properties
///
/// - `name` - File or directory name
/// - `size` - File size in bytes (0 for directories)
/// - `location` - Physical location on disk (track, sector, offset, length)
/// - `modificationDate` - Last modification date
/// - `hashes` - Content hashes (SHA-256, SHA-1, MD5)
/// - `specialFileType` - Type for special files (block device, socket, etc.)
///
/// ## Design Benefits
///
/// - **Fast Parsing**: Only metadata loaded during parsing
/// - **Memory Efficient**: Content loaded only when accessed
/// - **Integrity Verification**: Hashes enable content verification
/// - **Location Tracking**: Enables on-demand content loading
///
/// ## See Also
///
/// - ``FileSystemEntry`` - Uses this metadata
/// - ``FileLocation`` - Physical location information
/// - ``FileHash`` - Content hash information
public struct FileSystemEntryMetadata: Codable {
    /// File name
    public let name: String
    
    /// File size in bytes
    public let size: Int
    
    /// Modification date, if available
    public let modificationDate: Date?
    
    /// Detected file type category, if available
    public var fileType: FileTypeCategory?
    
    /// Generated UTI for this file type (lazy-computed, cached here)
    /// Uses FileTypeUTIRegistry to generate UTIs based on file type category and context
    public var fileTypeUTI: String? {
        guard let fileType = fileType else {
            return nil
        }
        
        // Extract file system context from attributes if available
        let fileSystemFormat: FileSystemFormat? = {
            if let formatString = attributes["fileSystemFormat"] as? String {
                return FileSystemFormat(rawValue: formatString)
            }
            return nil
        }()
        
        let fileSystemVersion = attributes["fileSystemVersion"] as? String
        
        // Extract file extension from name
        let fileExtension = (name as NSString).pathExtension.lowercased()
        let ext = fileExtension.isEmpty ? nil : fileExtension
        
        return FileTypeUTIRegistry.shared.generateUTI(
            for: fileType,
            fileSystemFormat: fileSystemFormat,
            fileSystemVersion: fileSystemVersion,
            fileExtension: ext
        )
    }
    
    /// Special file type information (for block devices, character devices, sockets, FIFOs)
    /// Use `SpecialFileType` from Core/SpecialFileType.swift to detect and store special file types
    public var specialFileType: String?
    
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
        specialFileType: String? = nil,
        attributes: [String: Any] = [:],
        location: FileLocation? = nil,
        hashes: [HashAlgorithm: FileHash] = [:]
    ) {
        self.name = name
        self.size = size
        self.modificationDate = modificationDate
        self.fileType = fileType
        self.specialFileType = specialFileType
        self.attributes = attributes
        self.location = location
        self.hashes = hashes
    }
    
    // Custom Codable implementation for attributes (Dictionary with Any values)
    enum CodingKeys: String, CodingKey {
        case name, size, modificationDate, fileType, specialFileType, location, hashes
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        size = try container.decode(Int.self, forKey: .size)
        modificationDate = try container.decodeIfPresent(Date.self, forKey: .modificationDate)
        fileType = try container.decodeIfPresent(FileTypeCategory.self, forKey: .fileType)
        specialFileType = try container.decodeIfPresent(String.self, forKey: .specialFileType)
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
        try container.encodeIfPresent(specialFileType, forKey: .specialFileType)
        try container.encodeIfPresent(location, forKey: .location)
        try container.encode(hashes, forKey: .hashes)
        // Attributes not encoded (Any type not Codable)
    }
}

// MARK: - FileSystemEntry

/// Represents a file entry that can be a physical file or a data stream.
/// For directories, use FileSystemFolder instead.
/// Implements lazy loading: metadata is always loaded, content is loaded on demand.
/// 
/// **Data Sources:**
/// - Physical files on disk (via `readData(from: RawDiskData)` legacy method)
/// - Data streams from any source (via `chunkIdentifier` and `toChunk()` method)
///   - Network streams
///   - Memory buffers
///   - Cloud storage
///   - Any custom ChunkStorage implementation
/// 
/// **Special Files:** FileSystemEntry can represent special files (block devices, character devices,
/// sockets, FIFOs) when `metadata.specialFileType` is set. Use `SpecialFileType` from
/// Core/SpecialFileType.swift to detect special files and set the type string.
/// 
/// **Architecture:** FileSystemEntry stores metadata and a reference to data (`chunkIdentifier`).
/// The actual data access is handled by `Chunk` via `toChunk()`, which works with any ChunkStorage
/// implementation (file system, network, cloud, memory, etc.).
///
/// ## Overview
///
/// `FileSystemEntry` represents a single file in a parsed file system. It implements
/// the Composite Pattern as a leaf node, containing file metadata and providing
/// on-demand access to file content.
///
/// ## Usage
///
/// Access file metadata:
/// ```swift
/// let file: FileSystemEntry = // ... obtained from parser
///
/// print("Name: \(file.name)")
/// print("Size: \(file.size) bytes")
/// print("Modified: \(file.modificationDate ?? Date())")
/// ```
///
/// Read file content (lazy-loaded):
/// ```swift
/// let file: FileSystemEntry = // ... obtained from parser
/// let diskData: RawDiskData = // ... from disk image adapter
///
/// // Load file content on-demand
/// let content = try file.readData(from: diskData)
/// print("Content: \(content.count) bytes")
/// ```
///
/// Generate file hash:
/// ```swift
/// let file: FileSystemEntry = // ... obtained from parser
///
/// // Generate SHA-256 hash (cached after first call)
/// let hash = try file.generateHash(algorithm: .sha256)
/// print("Hash: \(hash.hexString)")
/// ```
///
/// Access via chunk storage:
/// ```swift
/// let file: FileSystemEntry = // ... obtained from parser
/// let chunkStorage: ChunkStorage = // ... storage provider
///
/// if let chunk = try await file.toChunk(storage: chunkStorage) {
///     let data = try await chunk.readFull()
///     print("Read \(data.count) bytes from storage")
/// }
/// ```
///
/// ## Properties
///
/// - `metadata` - File metadata (name, size, location, dates, hashes)
/// - `chunkIdentifier` - Reference to content-addressable storage chunk
/// - `name` - File name (from metadata)
/// - `size` - File size in bytes (from metadata)
/// - `modificationDate` - Last modification date (from metadata)
/// - `specialFileType` - Type for special files (block device, socket, etc.)
/// - `isSpecialFile` - Whether this is a special file
/// - `parent` - Parent folder (weak reference)
///
/// ## Design Principles
///
/// - **Metadata-First**: Metadata always available, content loaded on-demand
/// - **Lazy Loading**: File content loaded only when `readData()` is called
/// - **Content-Addressable**: Can reference content via `chunkIdentifier`
/// - **Caching**: Content cached after first read for performance
///
/// ## See Also
///
/// - ``FileSystemComponent`` - Base protocol
/// - ``FileSystemEntryMetadata`` - Metadata structure
/// - ``FileSystemFolder`` - Folder implementation
/// - ``ChunkStorage`` - Content storage protocol
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
    
    /// Special file type string, if this is a special file (block device, character device, socket, FIFO)
    /// Returns nil for regular files
    public var specialFileType: String? { metadata.specialFileType }
    
    /// True if this is a special file (block device, character device, socket, or FIFO)
    public var isSpecialFile: Bool { metadata.specialFileType != nil }
    
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
    
    /// Create a Chunk from this entry's chunk identifier for data access.
    /// 
    /// This method enables accessing the entry's data as a stream from any storage backend:
    /// - Physical files (FileSystemChunkStorage)
    /// - Network streams (custom ChunkStorage)
    /// - Cloud storage (CloudKitChunkStorage, S3ChunkStorage, etc.)
    /// - Memory buffers (custom ChunkStorage)
    /// - Any other ChunkStorage implementation
    /// 
    /// - Parameters:
    ///   - storage: ChunkStorage to use for accessing chunk data (can be any implementation)
    ///   - accessPattern: Access pattern for caching (default: onDemand)
    /// - Returns: Chunk instance if chunkIdentifier is available, nil otherwise
    /// - Note: Use this method for accessing data streams. For physical files on disk images,
    ///   use the legacy `readData(from: RawDiskData)` method.
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
        // Use FileSystemKit's core HashComputation for unified implementation
        let hashData = try HashComputation.computeHash(data: data, algorithm: algorithm)
        return FileHash(algorithm: algorithm, value: hashData)
    }
}

// MARK: - FileSystemFolder

/// Represents a folder/directory structure in a parsed file system.
///
/// `FileSystemFolder` implements the Composite Pattern, allowing it to contain
/// both files (`FileSystemEntry`) and subfolders (`FileSystemFolder`). This
/// enables uniform traversal and operations across the file system hierarchy.
///
/// ## Overview
///
/// Folders are composite nodes that can contain:
/// - Files (`FileSystemEntry`) - Leaf nodes
/// - Subfolders (`FileSystemFolder`) - Nested composite nodes
///
/// ## Usage
///
/// Navigate folder hierarchy:
/// ```swift
/// let rootFolder: FileSystemFolder = // ... obtained from parser
///
/// // Get files in root
/// let files = rootFolder.getFiles()
/// for file in files {
///     print("File: \(file.name)")
/// }
///
/// // Get subfolders
/// let folders = rootFolder.getFolders()
/// for folder in folders {
///     print("Folder: \(folder.name)")
/// }
/// ```
///
/// Traverse recursively:
/// ```swift
/// // Get all components recursively
/// let allComponents = rootFolder.traverse()
///
/// for component in allComponents {
///     print("\(component.name): \(component.size) bytes")
/// }
/// ```
///
/// Find specific file:
/// ```swift
/// // Find file in current folder
/// if let file = rootFolder.findChild(named: "document.txt") as? FileSystemEntry {
///     print("Found: \(file.name)")
/// }
/// ```
///
/// Navigate to subfolder:
/// ```swift
/// if let subfolder = rootFolder.findChild(named: "Documents") as? FileSystemFolder {
///     let documents = subfolder.getFiles()
///     print("Found \(documents.count) files in Documents")
/// }
/// ```
///
/// Access parent folder:
/// ```swift
/// let file: FileSystemEntry = // ... a file
///
/// if let parent = file.parent {
///     print("File is in: \(parent.name)")
/// }
/// ```
///
/// ## Properties
///
/// - `name` - Folder name
/// - `size` - Total size of all children (computed)
/// - `modificationDate` - Modification date if available
/// - `parent` - Parent folder (weak reference)
/// - `children` - Array of child components (files and subfolders)
///
/// ## Design Principles
///
/// - **Composite Pattern**: Folders can contain files and other folders
/// - **Uniform Interface**: Files and folders share `FileSystemComponent` protocol
/// - **Hierarchical Structure**: Parent-child relationships enable navigation
/// - **Size Aggregation**: Folder size is sum of all children
///
/// ## See Also
///
/// - ``FileSystemComponent`` - Base protocol
/// - ``FileSystemEntry`` - File implementation
/// - [Composite Pattern (Wikipedia)](https://en.wikipedia.org/wiki/Composite_pattern) - Design pattern for tree structures
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
    /// - Returns: Array of FileSystemEntry objects in this directory
    public func getFiles() -> [FileSystemEntry] {
        return children.compactMap { $0 as? FileSystemEntry }
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
            if let file = child as? FileSystemEntry {
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
    /// - Returns: FileSystemEntry at the specified path, or nil if not found
    /// - Note: Path can be absolute (starting with "/") or relative
    public func getFile(at path: String) -> FileSystemEntry? {
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

/// Deprecated: Use `FileSystemEntry` instead.
/// This typealias is provided for backward compatibility and will be removed in a future major version.
@available(*, deprecated, renamed: "FileSystemEntry", message: "Use FileSystemEntry instead to avoid naming conflicts")
public typealias File = FileSystemEntry

/// Deprecated: Use `FileSystemEntryMetadata` instead.
/// This typealias is provided for backward compatibility and will be removed in a future major version.
@available(*, deprecated, renamed: "FileSystemEntryMetadata", message: "Use FileSystemEntryMetadata instead to avoid naming conflicts")
public typealias FileMetadata = FileSystemEntryMetadata

