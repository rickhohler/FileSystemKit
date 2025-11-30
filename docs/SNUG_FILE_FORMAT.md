# Snug File Format Specification

## Overview

**Snug** (Small, Network-optimized, Unified Grouping) is a content-addressable archive format that stores directory structures and file metadata but references file content by hash instead of embedding it.

## File Format

### Extension
- **`.snug`** - Standard extension for Snug archives

### Structure
```
archive.snug
├── Compression Layer (gzip/deflate)
│   └── YAML Document (uncompressed)
│       ├── Format Header
│       ├── Hash Registry (anchors)
│       ├── Metadata Templates (anchors)
│       └── Archive Entries (aliases)
```

### Compression

Snug files are **compressed YAML documents**:
- **Algorithm**: gzip/deflate (standard compression)
- **Rationale**: 
  - YAML files can be verbose, especially with deep nesting
  - Compression makes Snug archives even smaller
  - Aligns with "Small" in "Small, Network-optimized, Unified Grouping"
  - Transparent to users via `CompressionAdapter` protocol

### Processing Flow

```
1. User opens: archive.snug
   ↓
2. SnugCompressionAdapter.decompress()
   → Decompresses gzip/deflate
   → Returns: archive.yaml (temporary file)
   ↓
3. YAMLDecoder.parse()
   → Parses YAML document
   → Returns: SnugArchive structure
   ↓
4. SnugExtractionStage.extract()
   → Resolves hashes via ChunkStorage
   → Creates directory structure
   → Extracts files by hash lookup
   ↓
5. Result: Extracted files and directories
```

## YAML Document Structure

### Format Header

```yaml
format: snug
version: 1
hashAlgorithm: sha256  # sha256, sha1, md5, etc.
```

### Hash Registry (Anchors)

Define file content once, reference many times:

```yaml
hashes:
  # Hash value as key, anchor for reuse
  a1b2c3d4e5f6: &hash_abc123
    hash: "a1b2c3d4e5f6..."
    size: 1024
    algorithm: sha256
  
  def456ghi789: &hash_def456
    hash: "def456ghi789..."
    size: 2048
    algorithm: sha256
```

### Metadata Templates (Anchors)

Define common metadata once:

```yaml
metadata: &defaults
  owner: "developer"
  group: "developers"
  filePerms: "0644"
  dirPerms: "0755"
```

### Archive Entries (Aliases)

Reference hashes and metadata:

```yaml
entries:
  # Directory entry
  - type: directory
    path: "project"
    permissions: *defaults.dirPerms
    <<: *defaults
  
  # File entry with hash reference
  - type: file
    path: "project/file1.txt"
    hash: "a1b2c3d4e5f6"
    <<: *hash_abc123  # Reference hash definition
    permissions: *defaults.filePerms
    <<: *defaults
  
  # Same file content, different path (deduplication!)
  - type: file
    path: "project/backup/file1.txt"
    hash: "a1b2c3d4e5f6"  # Same hash
    <<: *hash_abc123      # Same content!
    permissions: *defaults.filePerms
    <<: *defaults
```

## Complete Example

### Uncompressed YAML (before compression)

```yaml
format: snug
version: 1
hashAlgorithm: sha256

# Hash registry - define once
hashes:
  a1b2c3d4e5f6: &lib_hash
    hash: "a1b2c3d4e5f6..."
    size: 50000
    algorithm: sha256
  
  b2c3d4e5f6a1: &config_hash
    hash: "b2c3d4e5f6a1..."
    size: 1024
    algorithm: sha256

# Metadata templates
defaults: &defaults
  owner: "developer"
  group: "developers"
  filePerms: "0644"
  dirPerms: "0755"

# Archive entries
entries:
  - type: directory
    path: "myapp"
    permissions: *defaults.dirPerms
    <<: *defaults
  
  - type: directory
    path: "myapp/src"
    permissions: *defaults.dirPerms
    <<: *defaults
  
  - type: file
    path: "myapp/src/libs/common.so"
    hash: "a1b2c3d4e5f6"
    <<: *lib_hash
    permissions: *defaults.filePerms
    <<: *defaults
    modified: "2024-01-01T10:00:00Z"
  
  - type: file
    path: "myapp/backup/libs/common.so"
    hash: "a1b2c3d4e5f6"  # Same hash!
    <<: *lib_hash         # Same content!
    permissions: *defaults.filePerms
    <<: *defaults
    modified: "2024-01-01T10:00:00Z"
```

### Compressed File (archive.snug)

The YAML above is compressed using gzip/deflate to create `archive.snug`.

## Implementation

### SnugCompressionAdapter

```swift
public struct SnugCompressionAdapter: CompressionAdapter {
    public static var format: CompressionFormat { .snug }
    
    public static var supportedExtensions: [String] { [".snug"] }
    
    public static func canHandle(url: URL) -> Bool {
        url.pathExtension.lowercased() == "snug"
    }
    
    public static func isCompressed(url: URL) -> Bool {
        canHandle(url: url)
    }
    
    public static func decompress(url: URL) throws -> URL {
        // 1. Read compressed data
        let compressedData = try Data(contentsOf: url)
        
        // 2. Decompress gzip/deflate
        let decompressedData = try decompressGzip(data: compressedData)
        
        // 3. Create temporary YAML file
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("yaml")
        
        try decompressedData.write(to: tempURL)
        return tempURL
    }
    
    public static func compress(data: Data, to url: URL) throws {
        // 1. Compress YAML data with gzip/deflate
        let compressedData = try compressGzip(data: data)
        
        // 2. Write compressed file
        try compressedData.write(to: url)
    }
}
```

### YAML Parsing

```swift
import Yams

// After decompression, parse YAML
let yamlData = try Data(contentsOf: decompressedYAMLURL)
let decoder = YAMLDecoder()
let archive = try decoder.decode(SnugArchive.self, from: yamlData)
```

### Hash Resolution

```swift
// Resolve hashes via ChunkStorage
for entry in archive.entries {
    if let hash = entry.hash {
        // Look up file content by hash
        let chunkHandle = try chunkStorage.getHandle(for: ChunkIdentifier(hash: hash))
        let fileData = try chunkHandle.read()
        
        // Create file at path
        let fileURL = baseURL.appendingPathComponent(entry.path)
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try fileData.write(to: fileURL)
    }
}
```

## Benefits

### 1. Small Archives
- **Compression**: YAML compressed with gzip/deflate
- **Deduplication**: Same hash referenced multiple times
- **No Embedded Data**: Only metadata and hash references

### 2. Network-Optimized
- **Small Transfer Size**: Compressed metadata only
- **Deduplication**: Common files already exist at destination
- **Efficient**: Only transfer what's missing

### 3. Unified Grouping
- **Single Archive**: One `.snug` file contains entire structure
- **Consistent Format**: YAML with anchors/aliases
- **Portable**: Standard compression and YAML parsing

## File Size Comparison

### Example: Archive with 1000 files, 100MB total

**Traditional ZIP:**
- Size: ~100MB (compressed file data)

**Snug Archive:**
- YAML metadata: ~50KB (uncompressed)
- Compressed YAML: ~10KB (gzip)
- **Total: ~10KB** (99.99% smaller!)

**With Deduplication:**
- If 500 files are duplicates (same hash):
- YAML metadata: ~30KB (uncompressed)
- Compressed YAML: ~6KB (gzip)
- **Total: ~6KB** (99.994% smaller!)

## Conclusion

**Snug file format:**
- ✅ **Extension**: `.snug`
- ✅ **Structure**: Compressed YAML document (gzip/deflate)
- ✅ **Content**: YAML with anchors/aliases for deduplication
- ✅ **Processing**: Decompress → Parse YAML → Resolve hashes → Extract files
- ✅ **Benefits**: Small, network-optimized, unified grouping

The compressed YAML format makes Snug archives extremely small while maintaining human-readability and supporting powerful deduplication through YAML anchors/aliases.

