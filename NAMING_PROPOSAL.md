# File Naming Proposal

## Problem Statement

1. **`File` is too generic** - May clash with Foundation.File or other IO packages
2. **Confusion between `FileMetadata` and `ChunkMetadata`** - Both represent metadata but for different purposes
3. **Need clear relationship** - How does a file system entry relate to its chunk data?

## Current Structure

### FileMetadata (File System Entry Metadata)
```swift
public struct FileMetadata {
    let name: String
    let size: Int
    let modificationDate: Date?
    let fileType: FileTypeCategory?
    let attributes: [String: Any]
    let location: FileLocation  // Disk image location (track, sector, offset, length)
    let hashes: [HashAlgorithm: FileHash]
}
```
**Purpose**: Metadata for a file system entry (name, location in disk image, etc.)

### ChunkMetadata (Binary Chunk Metadata)
```swift
public struct ChunkMetadata {
    let size: Int
    let contentHash: String?
    let hashAlgorithm: String?
    let contentType: String?
    let chunkType: String?
    let originalFilename: String?
    let originalPaths: [String]?
    let created: Date?
    let modified: Date?
    let compression: CompressionInfo?
}
```
**Purpose**: Metadata for a binary chunk stored in ChunkStorage (content-addressable)

### File (File System Component)
```swift
public class File: FileSystemComponent {
    let metadata: FileMetadata
    weak var parent: FileSystemFolder?
    // Can read from RawDiskData
}
```
**Purpose**: Represents a file in a file system hierarchy

## Proposed Naming Scheme

### Option 1: FileSystemEntry (Recommended)

**Rename `File` → `FileSystemEntry`**

```swift
/// Represents an entry in a file system (file or directory)
public class FileSystemEntry: FileSystemComponent {
    /// Entry metadata (name, location, etc.)
    public let metadata: FileSystemEntryMetadata
    
    /// Reference to the chunk containing file data (if applicable)
    public let chunkIdentifier: ChunkIdentifier?
    
    /// Parent folder in file system hierarchy
    public weak var parent: FileSystemFolder?
}

/// Metadata for a file system entry
public struct FileSystemEntryMetadata: Codable {
    /// Entry name
    public let name: String
    
    /// Entry size in bytes
    public let size: Int
    
    /// Modification date
    public let modificationDate: Date?
    
    /// File type category
    public let fileType: FileTypeCategory?
    
    /// Additional attributes
    public let attributes: [String: Any]
    
    /// Location in disk image (if applicable)
    public let location: FileLocation?
    
    /// Content hashes
    public let hashes: [HashAlgorithm: FileHash]
}
```

**Benefits:**
- ✅ Clear that it's a file system entry (not a generic file)
- ✅ Avoids naming conflicts
- ✅ `FileSystemEntryMetadata` clearly different from `ChunkMetadata`
- ✅ Can reference `ChunkIdentifier` for chunk-based storage

### Option 2: FileEntry (Shorter Alternative)

**Rename `File` → `FileEntry`**

```swift
public class FileEntry: FileSystemComponent {
    public let metadata: FileEntryMetadata
    public let chunkIdentifier: ChunkIdentifier?
    public weak var parent: FileSystemFolder?
}
```

**Benefits:**
- ✅ Shorter name
- ✅ Still avoids conflicts
- ❌ Less descriptive than `FileSystemEntry`

### Option 3: Keep File, Use Typealias

**Keep `File` but add typealias for clarity**

```swift
public class File: FileSystemComponent { ... }

// Typealias for clarity
public typealias FileSystemEntry = File
```

**Benefits:**
- ✅ No breaking changes
- ✅ Can use clearer name in new code
- ❌ Doesn't solve naming conflict issue

## Relationship Between Types

### Clear Separation of Concerns

```
FileSystemEntry (FileSystemComponent)
├── FileSystemEntryMetadata
│   ├── name, size, dates
│   ├── location: FileLocation (disk image location)
│   └── hashes: [HashAlgorithm: FileHash]
│
└── chunkIdentifier: ChunkIdentifier?
    └── ChunkMetadata
        ├── size, contentHash
        ├── contentType, chunkType
        └── originalFilename, originalPaths

Chunk (data access)
├── storage: ChunkStorage
├── identifier: ChunkIdentifier
└── accessPattern: AccessPattern
```

### Key Relationships

1. **FileSystemEntry** = File system structure + metadata
2. **ChunkMetadata** = Metadata about binary data in ChunkStorage
3. **Chunk** = Access to binary data via ChunkStorage
4. **FileSystemEntry.chunkIdentifier** = Link to Chunk data

## Recommended Approach

### Step 1: Rename File → FileSystemEntry

```swift
// Old
public class File: FileSystemComponent { ... }

// New
public class FileSystemEntry: FileSystemComponent {
    public let metadata: FileSystemEntryMetadata
    public let chunkIdentifier: ChunkIdentifier?
    public weak var parent: FileSystemFolder?
}
```

### Step 2: Rename FileMetadata → FileSystemEntryMetadata

```swift
// Old
public struct FileMetadata { ... }

// New
public struct FileSystemEntryMetadata {
    // Same fields, but clearer purpose
    public let name: String
    public let size: Int
    public let location: FileLocation?  // Make optional (not all entries have disk image location)
    // ...
}
```

### Step 3: Keep ChunkMetadata Separate

```swift
// Keep as-is - it's for chunk storage metadata
public struct ChunkMetadata {
    // Metadata about binary chunk in ChunkStorage
    // Different purpose than FileSystemEntryMetadata
}
```

### Step 4: Add chunkIdentifier to FileSystemEntry

```swift
public class FileSystemEntry: FileSystemComponent {
    public let metadata: FileSystemEntryMetadata
    public let chunkIdentifier: ChunkIdentifier?  // Link to chunk data
    
    /// Create a Chunk from this entry's chunk identifier
    public func toChunk(storage: ChunkStorage, accessPattern: AccessPattern = .onDemand) async throws -> Chunk? {
        guard let identifier = chunkIdentifier else { return nil }
        return try await Chunk.builder()
            .storage(storage)
            .identifier(identifier)
            .accessPattern(accessPattern)
            .build()
    }
}
```

## Migration Path

### Phase 1: Add New Types (Non-Breaking)

```swift
// Add new types alongside old ones
public typealias FileSystemEntry = File
public typealias FileSystemEntryMetadata = FileMetadata

// Add chunkIdentifier to File
extension File {
    public var chunkIdentifier: ChunkIdentifier? { ... }
}
```

### Phase 2: Update APIs (Deprecate Old Names)

```swift
@available(*, deprecated, renamed: "FileSystemEntry")
public typealias File = FileSystemEntry

@available(*, deprecated, renamed: "FileSystemEntryMetadata")
public typealias FileMetadata = FileSystemEntryMetadata
```

### Phase 3: Remove Old Names (Breaking Change)

```swift
// Remove typealiases, use new names everywhere
public class FileSystemEntry: FileSystemComponent { ... }
public struct FileSystemEntryMetadata: Codable { ... }
```

## Summary

**Recommended Naming:**
- `File` → `FileSystemEntry` (class)
- `FileMetadata` → `FileSystemEntryMetadata` (struct)
- `ChunkMetadata` → Keep as-is (different purpose)
- Add `chunkIdentifier: ChunkIdentifier?` to `FileSystemEntry`

**Key Distinctions:**
- **FileSystemEntry**: File system structure + entry metadata
- **FileSystemEntryMetadata**: Metadata about file system entry (name, location in disk image)
- **ChunkMetadata**: Metadata about binary chunk in ChunkStorage (content-addressable)
- **Chunk**: Access to binary data via ChunkStorage

This provides:
- ✅ Clear naming (no conflicts)
- ✅ Clear separation of concerns
- ✅ Link between file system entries and chunk data
- ✅ Backward compatibility during migration

