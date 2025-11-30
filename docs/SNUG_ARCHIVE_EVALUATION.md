# Snug Archive Format Evaluation

## Overview

Snug (Small, Network-optimized, Unified Grouping) is a content-addressable archive format that stores directory structures and file metadata but references file content by hash instead of embedding it.

## Use Case

- **Small Archives**: Archives are tiny because they only contain metadata and hash references
- **Deduplication**: Multiple archives can reference the same file content (by hash)
- **Transfer Efficiency**: Only transfer metadata when files already exist at destination
- **Content-Addressable Storage**: Files are stored by hash in a separate storage system

## Proposed Format

### Current Proposal
```
<<file hash>>:<<original file name>>:<<timestamp>>:<<permissions>>
```

### Issues with Current Format

1. **No Escaping**: Colons (`:`) in filenames break parsing
2. **No Hash Algorithm**: Can't specify which hash algorithm (SHA256, MD5, etc.)
3. **Timestamp Format**: Not specified (Unix timestamp? ISO8601? String?)
4. **Permissions Format**: Not specified (Unix octal? String? Decimal?)
5. **Directory vs File**: No way to distinguish directories from files
6. **Symlinks/Hard Links**: No support for links
7. **File Size**: Missing (useful for validation)
8. **Path Separator**: No way to handle nested directories
9. **Metadata**: No way to store extended attributes, ownership, etc.

## Recommended Format

### Option 1: JSON-Based Format (Recommended)

```json
{
  "format": "snug",
  "version": 1,
  "hashAlgorithm": "sha256",
  "entries": [
    {
      "type": "file",
      "path": "path/to/file.txt",
      "hash": "a1b2c3d4e5f6...",
      "size": 1024,
      "permissions": "0644",
      "owner": "user",
      "group": "group",
      "modified": "2024-01-01T12:00:00Z",
      "created": "2024-01-01T12:00:00Z"
    },
    {
      "type": "directory",
      "path": "path/to/dir",
      "permissions": "0755",
      "owner": "user",
      "group": "group",
      "modified": "2024-01-01T12:00:00Z"
    },
    {
      "type": "symlink",
      "path": "path/to/link",
      "target": "../target",
      "permissions": "0777"
    }
  ]
}
```

**Advantages:**
- ✅ Extensible (can add fields without breaking parsing)
- ✅ Handles special characters in paths
- ✅ Clear structure
- ✅ Supports all file types
- ✅ Human-readable
- ✅ Easy to validate

**Disadvantages:**
- ❌ Larger than binary format (but still tiny compared to embedded files)
- ❌ Requires JSON parsing

### Option 2: Binary Format with TLV (Type-Length-Value)

```
[Magic: "SNUG"] [Version: 1 byte] [HashAlgorithm: 1 byte] [EntryCount: 4 bytes]
[Entry 1: Type(1) | PathLen(2) | Path | HashLen(1) | Hash | Size(8) | Perms(4) | ...]
[Entry 2: ...]
...
```

**Advantages:**
- ✅ Very compact
- ✅ Fast parsing
- ✅ Binary-safe

**Disadvantages:**
- ❌ Not human-readable
- ❌ Harder to debug
- ❌ Less extensible

### Option 3: Enhanced Text Format (Compromise)

```
#SNUG v1 sha256
F path/to/file.txt a1b2c3d4e5f6... 1024 0644 user:group 1704110400 1704110400
D path/to/dir 0755 user:group 1704110400
L path/to/link ../target 0777 user:group 1704110400
```

**Format:**
- Line 1: Header `#SNUG v<version> <hashAlgorithm>`
- Subsequent lines: `<Type> <Path> <Hash> <Size> <Permissions> <Owner:Group> <Modified> <Created>`
- Type: `F`=file, `D`=directory, `L`=symlink, `H`=hardlink
- Path: Escaped (backslash escapes special chars)
- Hash: Hex-encoded hash value
- Size: Decimal bytes (0 for directories)
- Permissions: Octal (e.g., 0644)
- Owner:Group: Colon-separated
- Timestamps: Unix epoch seconds

**Advantages:**
- ✅ More compact than JSON
- ✅ Human-readable
- ✅ Easy to parse line-by-line
- ✅ Handles special characters with escaping

**Disadvantages:**
- ❌ Requires escaping logic
- ❌ Less extensible than JSON

## Recommended: Compressed YAML Format with Anchors/Aliases

**File Format:**
- **Extension**: `.snug`
- **Structure**: Compressed YAML document (gzip/deflate compression)
- **Content**: YAML archive structure with anchors/aliases for deduplication

**Rationale:**
1. **Compression**: YAML files can be verbose - compressing makes Snug archives even smaller
2. **Deduplication**: YAML anchors (`&anchor`) and aliases (`*alias`) enable true deduplication - define hash once, reference many times
3. **Readability**: More human-readable than JSON (when decompressed)
4. **Comments**: Supports comments for documentation
5. **Reusability**: Similar to GraphQL schema patterns - define once, reuse across structure
6. **Size**: Compressed YAML is more compact than JSON when deduplication is used
7. **Perfect for Snug**: Core Snug feature is deduplication - YAML naturally supports this
8. **Architecture Fit**: Fits perfectly into CompressionAdapter pattern - decompress, then parse YAML

**File Structure:**
```
archive.snug (compressed YAML)
  ↓ decompress
archive.yaml (YAML document)
  ↓ parse
Archive structure (entries, hashes, metadata)
  ↓ resolve hashes via ChunkStorage
Extracted files and directories
```

**See `SNUG_YAML_FORMAT.md` for detailed YAML format specification with examples.**

## Architecture Integration

### Where Snug Fits

Snug should be implemented as a **CompressionAdapter** (even though it's not compression) because:
- Similar to ZIP/TAR in purpose (archiving)
- Uses same interface pattern
- Can be chained in pipelines
- Handles directory structures

### Implementation Components

1. **SnugCompressionAdapter**: Implements `CompressionAdapter` protocol
   - `decompress()`: Extracts directory structure and resolves hash references
   - `compress()`: Creates Snug archive from directory structure

2. **SnugArchiveParser**: Parses Snug format
   - Reads JSON structure
   - Validates format version
   - Extracts entries

3. **HashResolver**: Resolves hash references to file content
   - Interface: `(hash: String, algorithm: HashAlgorithm) -> Data?`
   - Implementation: Uses `ChunkStorage` or file system hash lookup

4. **SnugExtractionStage**: Pipeline stage for Snug extraction
   - Resolves hash references
   - Creates directory structure
   - Extracts files from hash storage

### Integration Points

- **ChunkStorage**: Can be used as hash storage backend
- **HashAlgorithm**: Uses existing hash algorithm support
- **Pipeline**: Can be chained with other pipelines
- **FileSystemComponent**: Extracted structure uses existing file system types

## Example Snug Archive

```json
{
  "format": "snug",
  "version": 1,
  "hashAlgorithm": "sha256",
  "entries": [
    {
      "type": "directory",
      "path": "project",
      "permissions": "0755",
      "modified": "2024-01-01T12:00:00Z"
    },
    {
      "type": "file",
      "path": "project/README.md",
      "hash": "a1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456",
      "size": 1024,
      "permissions": "0644",
      "modified": "2024-01-01T12:00:00Z"
    },
    {
      "type": "file",
      "path": "project/main.swift",
      "hash": "b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef1234567",
      "size": 2048,
      "permissions": "0644",
      "modified": "2024-01-01T12:30:00Z"
    }
  ]
}
```

## Hash Resolution Strategy

### Option 1: ChunkStorage Backend
```swift
// Use ChunkStorage to resolve hashes
let chunkStorage: ChunkStorage = ...
let hash = DiskImageHash(algorithm: .sha256, value: hashData)
let identifier = ChunkIdentifier(id: hash.hexString)
let data = try await chunkStorage.readChunk(identifier, offset: 0, length: nil)
```

### Option 2: File System Hash Directory
```
/hash-storage/
  /a1/
    /b2c3d4e5f6...  (full hash as filename)
  /b2/
    /c3d4e5f6...
```

### Option 3: Database/Index
- SQLite database mapping hash → file path
- Fast lookup for hash resolution

## Implementation Priority

**High** - This is a novel and useful archive format that:
- Enables efficient deduplication
- Reduces transfer sizes
- Integrates well with content-addressable storage
- Fits naturally into existing architecture

## Questions to Resolve

1. **Hash Storage**: Where/how are hash values resolved? (ChunkStorage? File system? Database?)
2. **Hash Algorithm**: Single algorithm or multiple? (Recommend: SHA256 as default, support others)
3. **Compression**: Should Snug archives themselves be compressible? (e.g., .snug.gz)
4. **Nested Archives**: Can Snug archives reference other Snug archives?
5. **Error Handling**: What happens when hash can't be resolved? (Skip file? Error? Partial extraction?)

