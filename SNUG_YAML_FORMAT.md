# SNUG Archive Format - Compressed YAML with Anchors/Aliases

## Overview

**SNUG File Format:**
- **Extension**: `.snug`
- **Structure**: Compressed YAML document (gzip/deflate compression)
- **Content**: YAML archive structure with anchors/aliases for deduplication

YAML format with anchors (`&anchor`) and aliases (`*alias`) allows defining file references and directory structures once and reusing them throughout the archive. This is perfect for SNUG archives where:
- Multiple entries may reference the same file hash (deduplication)
- Directory metadata can be shared
- Common metadata (owner, group, permissions) can be reused

**Compression Benefits:**
- YAML files can be verbose, especially with deep nesting
- Compressing the YAML makes SNUG archives even smaller
- Aligns with "Small" in "Small, Network-optimized, Unified Grouping"
- Transparent to users - `SnugCompressionAdapter` handles decompression

## YAML Anchors and Aliases

YAML supports defining reusable structures:

```yaml
# Define once
common_metadata: &common_meta
  owner: "user"
  group: "group"
  permissions: "0644"

# Reuse multiple times
file1:
  <<: *common_meta
  path: "file1.txt"
  hash: "abc123..."
```

## SNUG Format with YAML

### Example: SNUG Archive with Reusable References

```yaml
format: snug
version: 1
hashAlgorithm: sha256

# Define common file content (by hash) - can be referenced multiple times
fileContents: &contents
  hash_abc123: &file_abc123
    hash: "abc123def456..."
    size: 1024
    algorithm: sha256
  
  hash_def456: &file_def456
    hash: "def456ghi789..."
    size: 2048
    algorithm: sha256

# Define common metadata templates
metadata: &meta
  owner: "user"
  group: "group"
  defaultPermissions: "0644"
  defaultDirPermissions: "0755"

# Archive entries - can reference file contents and metadata
entries:
  # Directory entry
  - type: directory
    path: "project"
    permissions: *meta.defaultDirPermissions
    owner: *meta.owner
    group: *meta.group
    modified: "2024-01-01T12:00:00Z"
  
  # File entry referencing hash
  - type: file
    path: "project/README.md"
    content: *file_abc123  # Reference to hash definition
    permissions: *meta.defaultPermissions
    owner: *meta.owner
    group: *meta.group
    modified: "2024-01-01T12:00:00Z"
  
  # Another file with same content (deduplication!)
  - type: file
    path: "project/README_COPY.md"
    content: *file_abc123  # Same hash reference
    permissions: *meta.defaultPermissions
    modified: "2024-01-01T12:30:00Z"
  
  # File with different content
  - type: file
    path: "project/main.swift"
    content: *file_def456  # Different hash reference
    permissions: *meta.defaultPermissions
    modified: "2024-01-01T13:00:00Z"
```

### Compact Format (Inline References)

```yaml
format: snug
version: 1
hashAlgorithm: sha256

# Hash definitions (content-addressable)
hashes:
  abc123: &h_abc123
    hash: "abc123def456..."
    size: 1024
  def456: &h_def456
    hash: "def456ghi789..."
    size: 2048

# Metadata templates
meta: &m
  owner: "user"
  group: "group"

# Archive structure
entries:
  - type: directory
    path: "project"
    permissions: "0755"
    <<: *m
  
  - type: file
    path: "project/README.md"
    <<: *h_abc123  # Merge hash definition
    permissions: "0644"
    <<: *m  # Merge metadata
  
  - type: file
    path: "project/README_COPY.md"
    <<: *h_abc123  # Same hash, different path
    permissions: "0644"
    <<: *m
```

### Even More Compact (Direct Hash References)

```yaml
format: snug
version: 1
hashAlgorithm: sha256

# Hash registry (defines once, references many times)
hashes:
  abc123def456: &hash_abc123
    size: 1024
  def456ghi789: &hash_def456
    size: 2048

# Common metadata
defaults: &defaults
  owner: "user"
  group: "group"
  filePerms: "0644"
  dirPerms: "0755"

# Archive entries
entries:
  - type: directory
    path: "project"
    permissions: *defaults.dirPerms
    <<: *defaults
  
  - type: file
    path: "project/README.md"
    hash: "abc123def456"  # Reference hash string
    <<: *hash_abc123      # Merge hash metadata
    permissions: *defaults.filePerms
    <<: *defaults
  
  - type: file
    path: "project/README_COPY.md"
    hash: "abc123def456"  # Same hash!
    <<: *hash_abc123      # Same hash metadata
    permissions: *defaults.filePerms
    <<: *defaults
```

## Advantages of YAML Format

### 1. **Deduplication Support**
```yaml
# Define hash once
hashes:
  common_lib: &lib_hash
    hash: "abc123..."
    size: 50000

# Reference multiple times
entries:
  - type: file
    path: "app/libs/common.so"
    <<: *lib_hash
  - type: file
    path: "backup/libs/common.so"
    <<: *lib_hash  # Same content, different path!
```

### 2. **Metadata Templates**
```yaml
# Define permission sets
perms:
  executable: &exec_perm
    permissions: "0755"
  readonly: &read_perm
    permissions: "0644"

entries:
  - type: file
    path: "script.sh"
    <<: *exec_perm
  - type: file
    path: "data.txt"
    <<: *read_perm
```

### 3. **Directory Structure Reuse**
```yaml
# Define directory template
dir_template: &dir_template
  type: directory
  permissions: "0755"
  owner: "user"
  group: "group"

entries:
  - <<: *dir_template
    path: "src"
  - <<: *dir_template
    path: "src/utils"
  - <<: *dir_template
    path: "src/components"
```

### 4. **Complex Structures**
```yaml
# Define file with all metadata
file_template: &file_template
  type: file
  owner: "user"
  group: "group"
  permissions: "0644"
  modified: "2024-01-01T12:00:00Z"

# Hash definitions
hashes:
  config: &config_hash
    hash: "config123..."
    size: 512

# Use template + hash
entries:
  - <<: *file_template
    path: "config.json"
    <<: *config_hash
  - <<: *file_template
    path: "config.backup.json"
    <<: *config_hash  # Same file content!
```

## Comparison: YAML vs JSON

### YAML Advantages ✅

1. **Deduplication**: Anchors/aliases enable true deduplication
2. **Readability**: More human-readable than JSON
3. **Comments**: Supports comments (`# comment`)
4. **Multi-line strings**: Better for embedded content
5. **Less verbose**: No need for quotes in many cases
6. **Reusability**: Define once, reference many times

### YAML Disadvantages ❌

1. **Parsing complexity**: More complex parser than JSON
2. **Indentation-sensitive**: Can be error-prone
3. **Performance**: Generally slower to parse than JSON
4. **Library support**: Fewer libraries than JSON (though Swift has Yams)

### JSON Advantages ✅

1. **Universal support**: Every language has JSON support
2. **Performance**: Faster parsing
3. **Simplicity**: Simpler parser
4. **No indentation issues**: Less error-prone

### JSON Disadvantages ❌

1. **No deduplication**: Must repeat hash definitions
2. **Verbose**: More characters needed
3. **No comments**: Can't add explanatory comments
4. **Repetition**: Same hash must be defined multiple times

## Recommended: YAML Format

**Rationale:**
1. **Deduplication is core to SNUG**: YAML anchors/aliases enable true deduplication
2. **Readability**: Easier to read and understand archive structure
3. **Comments**: Can document why certain files share hashes
4. **Swift support**: `Yams` library provides excellent YAML support
5. **Size**: YAML can be more compact with deduplication

## Implementation Considerations

### File Format Structure

```
archive.snug (compressed YAML)
  ↓ SnugCompressionAdapter.decompress()
archive.yaml (decompressed YAML)
  ↓ YAMLDecoder.parse()
SnugArchive structure
  ↓ SnugExtractionStage.extract()
Files and directories (via ChunkStorage hash resolution)
```

### Compression

SNUG files use **gzip/deflate compression**:
- Standard compression algorithm (widely supported)
- Good compression ratio for text/YAML
- Fast decompression
- Transparent to users via `CompressionAdapter` protocol

### Swift YAML Library

Use `Yams` (Swift YAML library):
```swift
import Yams

// Decompress SNUG file first
let compressedData = try Data(contentsOf: snugURL)
let decompressedData = try decompressGzip(data: compressedData)

// Parse YAML
let decoder = YAMLDecoder()
let archive = try decoder.decode(SnugArchive.self, from: decompressedData)

// Encode YAML
let encoder = YAMLEncoder()
let yamlData = try encoder.encode(archive)

// Compress YAML
let compressedData = try compressGzip(data: yamlData)
try compressedData.write(to: snugURL)
```

### SNUG Archive Structure

```swift
public struct SnugArchive: Codable {
    public let format: String  // "snug"
    public let version: Int
    public let hashAlgorithm: String  // "sha256", "sha1", etc.
    
    // Hash definitions (content-addressable)
    public let hashes: [String: HashDefinition]?
    
    // Metadata templates
    public let metadata: MetadataTemplate?
    
    // Archive entries
    public let entries: [ArchiveEntry]
}

public struct HashDefinition: Codable {
    public let hash: String  // Hex-encoded hash
    public let size: Int
    public let algorithm: String?
}

public struct ArchiveEntry: Codable {
    public let type: EntryType  // file, directory, symlink
    public let path: String
    public let hash: String?  // Reference to hash
    public let size: Int?
    public let permissions: String?
    public let owner: String?
    public let group: String?
    public let modified: Date?
    public let created: Date?
    // ... other metadata
}
```

## Deep Nested Directory Structures

**Yes, the format fully supports deep nested directory structures!** YAML naturally handles arbitrary depth through path strings and can use anchors/aliases for directory templates.

### Example: Deeply Nested Structure

```yaml
format: snug
version: 1
hashAlgorithm: sha256

# Hash definitions
hashes:
  utils_lib: &utils_hash
    hash: "a1b2c3d4e5f6..."
    size: 50000
  config_file: &config_hash
    hash: "b2c3d4e5f6a1..."
    size: 1024

# Directory template (can be reused)
dir_template: &dir_template
  type: directory
  permissions: "0755"
  owner: "developer"
  group: "developers"

# File template
file_template: &file_template
  type: file
  permissions: "0644"
  owner: "developer"
  group: "developers"

# Deep nested structure
entries:
  # Root
  - <<: *dir_template
    path: "project"
  
  # Level 1
  - <<: *dir_template
    path: "project/src"
  
  # Level 2
  - <<: *dir_template
    path: "project/src/components"
  
  # Level 3
  - <<: *dir_template
    path: "project/src/components/ui"
  
  # Level 4
  - <<: *dir_template
    path: "project/src/components/ui/buttons"
  
  # Level 5 - deeply nested file
  - <<: *file_template
    path: "project/src/components/ui/buttons/primary.swift"
    <<: *utils_hash
    modified: "2024-01-01T10:00:00Z"
  
  # Another deep path
  - <<: *dir_template
    path: "project/src/utils/helpers/validation/parsers"
  
  - <<: *file_template
    path: "project/src/utils/helpers/validation/parsers/json_parser.swift"
    <<: *utils_hash
    modified: "2024-01-01T11:00:00Z"
  
  # Same file content, different deep path (deduplication!)
  - <<: *file_template
    path: "project/tests/unit/utils/helpers/validation/parsers/json_parser.swift"
    <<: *utils_hash  # Same hash, different location!
    modified: "2024-01-01T11:00:00Z"
```

### Path-Based Structure (No Depth Limit)

The format uses **path strings** for entries, which naturally supports unlimited depth:

```yaml
entries:
  # Any depth - just use path strings
  - type: directory
    path: "a/b/c/d/e/f/g/h/i/j/k"  # 11 levels deep!
  
  - type: file
    path: "a/b/c/d/e/f/g/h/i/j/k/file.txt"
    hash: "abc123..."
```

### Hierarchical Structure Alternative

For very deep structures, you can also use a hierarchical format:

```yaml
format: snug
version: 1
hashAlgorithm: sha256

# Hash registry
hashes:
  lib: &lib_hash
    hash: "abc123..."
    size: 50000

# Hierarchical structure (nested YAML maps)
structure:
  project: &project_root
    type: directory
    permissions: "0755"
    children:
      src: &src_dir
        type: directory
        permissions: "0755"
        children:
          components: &components_dir
            type: directory
            permissions: "0755"
            children:
              ui: &ui_dir
                type: directory
                permissions: "0755"
                children:
                  buttons: &buttons_dir
                    type: directory
                    permissions: "0755"
                    children:
                      primary.swift:
                        type: file
                        <<: *lib_hash
                        permissions: "0644"
                        modified: "2024-01-01T10:00:00Z"
```

**Note**: The flat `entries` array with path strings is recommended because:
- ✅ Simpler to parse
- ✅ Easier to validate
- ✅ More efficient for large archives
- ✅ Natural deduplication support
- ✅ No depth limitations

## Example: Real-World SNUG Archive with Deep Nesting

```yaml
format: snug
version: 1
hashAlgorithm: sha256

# Hash registry - define file content once
hashes:
  # Common library file (referenced by multiple paths)
  a1b2c3d4e5f6: &lib_hash
    size: 50000
    algorithm: sha256
  
  # Configuration file (shared across environments)
  b2c3d4e5f6a1: &config_hash
    size: 1024
    algorithm: sha256

# Common metadata
defaults: &defaults
  owner: "developer"
  group: "developers"
  filePerms: "0644"
  dirPerms: "0755"

# Archive structure with deep nesting
entries:
  # Root directory
  - type: directory
    path: "myapp"
    permissions: *defaults.dirPerms
    <<: *defaults
  
  # Deep nested source structure
  - type: directory
    path: "myapp/src"
    permissions: *defaults.dirPerms
    <<: *defaults
  
  - type: directory
    path: "myapp/src/components"
    permissions: *defaults.dirPerms
    <<: *defaults
  
  - type: directory
    path: "myapp/src/components/ui"
    permissions: *defaults.dirPerms
    <<: *defaults
  
  - type: directory
    path: "myapp/src/components/ui/widgets"
    permissions: *defaults.dirPerms
    <<: *defaults
  
  # Deeply nested file
  - type: file
    path: "myapp/src/components/ui/widgets/button.swift"
    hash: "a1b2c3d4e5f6"
    <<: *lib_hash
    permissions: *defaults.filePerms
    <<: *defaults
    modified: "2024-01-01T10:00:00Z"
  
  # Same file content, different deep path (deduplication!)
  - type: file
    path: "myapp/backup/src/components/ui/widgets/button.swift"
    hash: "a1b2c3d4e5f6"  # Same hash!
    <<: *lib_hash         # Same content!
    permissions: *defaults.filePerms
    <<: *defaults
    modified: "2024-01-01T10:00:00Z"
  
  # Very deep nested config
  - type: file
    path: "myapp/config/environments/development/database/connection.json"
    hash: "b2c3d4e5f6a1"
    <<: *config_hash
    permissions: *defaults.filePerms
    <<: *defaults
  
  # Same config, different deep path
  - type: file
    path: "myapp/config/environments/staging/database/connection.json"
    hash: "b2c3d4e5f6a1"  # Same hash!
    <<: *config_hash      # Same content!
    permissions: *defaults.filePerms
    <<: *defaults
```

## Benefits for SNUG

1. **True Deduplication**: Same hash defined once, referenced many times
2. **Smaller Archives**: No repetition of hash definitions
3. **Clear Intent**: Comments explain why files share hashes
4. **Maintainability**: Change hash definition once, affects all references
5. **Human-Readable**: Easy to inspect and understand archive structure

## Conclusion

**Compressed YAML with anchors/aliases is the recommended format for SNUG** because:
- ✅ **Compression**: Makes archives even smaller (aligns with "Small" in SNUG)
- ✅ **Deduplication**: Enables true deduplication (core SNUG feature)
- ✅ **Compact**: More compact than JSON (with deduplication + compression)
- ✅ **Human-readable**: When decompressed, easy to read and maintain
- ✅ **Comments**: Supports comments for documentation
- ✅ **GraphQL-like**: Similar to GraphQL schema patterns (as requested)
- ✅ **Architecture Fit**: Fits perfectly into `CompressionAdapter` pattern

**File Format:**
- Extension: `.snug`
- Content: Compressed YAML document (gzip/deflate)
- Structure: YAML with anchors/aliases for deduplication
- Processing: Decompress → Parse YAML → Resolve hashes → Extract files

The format naturally supports the SNUG use case where the same file content (hash) appears in multiple locations in the directory structure, and compression makes the archives even smaller for network transfer.

