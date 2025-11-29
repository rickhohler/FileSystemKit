# SNUG Format - Deep Nested Directory Support

## Overview

The SNUG YAML format **fully supports deep nested directory structures** with no practical depth limit. This document demonstrates how deep nesting works and best practices.

## How Deep Nesting Works

### Path-Based Entries (Recommended)

SNUG uses **path strings** for entries, which naturally supports unlimited depth:

```yaml
entries:
  # Any depth - just use path strings
  - type: directory
    path: "level1/level2/level3/level4/level5/level6/level7/level8"
  
  - type: file
    path: "level1/level2/level3/level4/level5/level6/level7/level8/file.txt"
    hash: "abc123..."
```

**Advantages:**
- ✅ No depth limit (path strings can be arbitrarily long)
- ✅ Simple to parse and validate
- ✅ Efficient for large archives
- ✅ Natural deduplication support

### Directory Creation Order

When extracting, directories are created automatically based on path components:

```yaml
entries:
  # File in deep path - parent directories created automatically
  - type: file
    path: "a/b/c/d/e/f/g/h/file.txt"
    hash: "abc123..."
```

**Extraction process:**
1. Parse path: `"a/b/c/d/e/f/g/h/file.txt"`
2. Create directories: `a/`, `a/b/`, `a/b/c/`, ... `a/b/c/d/e/f/g/h/`
3. Extract file: `a/b/c/d/e/f/g/h/file.txt`

### Explicit Directory Entries

You can also explicitly define directories (useful for empty directories or setting permissions):

```yaml
entries:
  # Explicit directory entries
  - type: directory
    path: "project/src/components"
    permissions: "0755"
  
  - type: directory
    path: "project/src/components/ui"
    permissions: "0755"
  
  # File in nested directory
  - type: file
    path: "project/src/components/ui/button.swift"
    hash: "abc123..."
```

## Deep Nesting Examples

### Example 1: Very Deep Structure

```yaml
format: snug
version: 1
hashAlgorithm: sha256

hashes:
  lib: &lib_hash
    hash: "a1b2c3d4e5f6..."
    size: 50000

entries:
  # 10 levels deep!
  - type: directory
    path: "project/src/components/ui/widgets/forms/inputs/text/validators/parsers"
    permissions: "0755"
  
  - type: file
    path: "project/src/components/ui/widgets/forms/inputs/text/validators/parsers/json_parser.swift"
    <<: *lib_hash
    permissions: "0644"
```

### Example 2: Multiple Deep Paths with Deduplication

```yaml
format: snug
version: 1
hashAlgorithm: sha256

hashes:
  common_util: &util_hash
    hash: "abc123..."
    size: 10240

entries:
  # Deep path 1
  - type: file
    path: "app/src/utils/helpers/validation/parsers/json_parser.swift"
    <<: *util_hash
    permissions: "0644"
  
  # Deep path 2 (same file content!)
  - type: file
    path: "app/tests/unit/utils/helpers/validation/parsers/json_parser.swift"
    <<: *util_hash  # Same hash - deduplication!
    permissions: "0644"
  
  # Deep path 3 (same file content again!)
  - type: file
    path: "app/backup/2024-01-01/src/utils/helpers/validation/parsers/json_parser.swift"
    <<: *util_hash  # Same hash - deduplication!
    permissions: "0644"
```

### Example 3: Complex Real-World Structure

```yaml
format: snug
version: 1
hashAlgorithm: sha256

hashes:
  config: &config_hash
    hash: "config123..."
    size: 2048
  lib: &lib_hash
    hash: "lib456..."
    size: 50000

defaults: &defaults
  owner: "developer"
  group: "developers"
  filePerms: "0644"
  dirPerms: "0755"

entries:
  # Root
  - type: directory
    path: "myapp"
    permissions: *defaults.dirPerms
    <<: *defaults
  
  # Source structure (deep)
  - type: directory
    path: "myapp/src"
    permissions: *defaults.dirPerms
  
  - type: directory
    path: "myapp/src/app"
    permissions: *defaults.dirPerms
  
  - type: directory
    path: "myapp/src/app/features"
    permissions: *defaults.dirPerms
  
  - type: directory
    path: "myapp/src/app/features/user-management"
    permissions: *defaults.dirPerms
  
  - type: directory
    path: "myapp/src/app/features/user-management/components"
    permissions: *defaults.dirPerms
  
  - type: directory
    path: "myapp/src/app/features/user-management/components/forms"
    permissions: *defaults.dirPerms
  
  - type: file
    path: "myapp/src/app/features/user-management/components/forms/user_form.swift"
    <<: *lib_hash
    permissions: *defaults.filePerms
    <<: *defaults
  
  # Config structure (different deep path)
  - type: directory
    path: "myapp/config"
    permissions: *defaults.dirPerms
  
  - type: directory
    path: "myapp/config/environments"
    permissions: *defaults.dirPerms
  
  - type: directory
    path: "myapp/config/environments/development"
    permissions: *defaults.dirPerms
  
  - type: directory
    path: "myapp/config/environments/development/database"
    permissions: *defaults.dirPerms
  
  - type: file
    path: "myapp/config/environments/development/database/connection.json"
    <<: *config_hash
    permissions: *defaults.filePerms
    <<: *defaults
  
  # Same config, staging environment (deduplication!)
  - type: directory
    path: "myapp/config/environments/staging"
    permissions: *defaults.dirPerms
  
  - type: directory
    path: "myapp/config/environments/staging/database"
    permissions: *defaults.dirPerms
  
  - type: file
    path: "myapp/config/environments/staging/database/connection.json"
    <<: *config_hash  # Same hash - same content!
    permissions: *defaults.filePerms
    <<: *defaults
```

## Implementation Considerations

### Path Parsing

```swift
// Parse path and create directory structure
func createDirectoryStructure(for path: String, baseURL: URL) throws {
    let components = path.split(separator: "/").dropLast()  // Remove filename
    var currentURL = baseURL
    
    for component in components {
        currentURL = currentURL.appendingPathComponent(String(component))
        try FileManager.default.createDirectory(
            at: currentURL,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }
}
```

### Directory Ordering

Entries should be ordered to ensure parent directories are created before children:

```swift
// Sort entries: directories first, then files
// Within each group, sort by path depth (shallow to deep)
let sortedEntries = entries.sorted { entry1, entry2 in
    // Directories before files
    if entry1.type == .directory && entry2.type == .file {
        return true
    }
    if entry1.type == .file && entry2.type == .directory {
        return false
    }
    // Same type: sort by path depth
    let depth1 = entry1.path.split(separator: "/").count
    let depth2 = entry2.path.split(separator: "/").count
    return depth1 < depth2
}
```

### Path Validation

```swift
// Validate paths
func validatePath(_ path: String) -> Bool {
    // Check for invalid characters
    let invalidChars = CharacterSet(charactersIn: "<>:\"|?*")
    guard path.rangeOfCharacter(from: invalidChars) == nil else {
        return false
    }
    
    // Check for absolute paths (should be relative)
    guard !path.hasPrefix("/") else {
        return false
    }
    
    // Check for path traversal (security)
    guard !path.contains("..") else {
        return false
    }
    
    return true
}
```

## Best Practices

### 1. Explicit Directory Entries

For empty directories or special permissions, define explicitly:

```yaml
entries:
  - type: directory
    path: "project/empty_dir"
    permissions: "0755"
```

### 2. Use Templates for Deep Structures

```yaml
# Template for deep nested directories
deep_dir_template: &deep_dir
  type: directory
  permissions: "0755"
  owner: "developer"
  group: "developers"

entries:
  - <<: *deep_dir
    path: "a/b/c/d/e/f"
  - <<: *deep_dir
    path: "a/b/c/d/e/g"
  - <<: *deep_dir
    path: "x/y/z"
```

### 3. Group Related Deep Paths

```yaml
# Group by feature/component
entries:
  # Feature A deep structure
  - type: directory
    path: "app/features/feature-a/components/ui/widgets"
  - type: file
    path: "app/features/feature-a/components/ui/widgets/button.swift"
    hash: "abc123..."
  
  # Feature B deep structure
  - type: directory
    path: "app/features/feature-b/components/ui/widgets"
  - type: file
    path: "app/features/feature-b/components/ui/widgets/button.swift"
    hash: "abc123..."  # Same hash - deduplication!
```

## Limitations

### Path Length

- **OS Limits**: File systems have maximum path length limits
  - macOS: 1024 characters
  - Linux: 4096 characters
  - Windows: 260 characters (can be extended)

- **Recommendation**: Keep paths under 512 characters for portability

### Performance

- **Large Archives**: Very deep structures with many entries may take longer to parse
- **Recommendation**: Consider batching or streaming for archives with >10,000 entries

## Conclusion

**Yes, SNUG format fully supports deep nested directory structures!**

- ✅ **No depth limit** - path strings support arbitrary depth
- ✅ **Automatic directory creation** - parent directories created automatically
- ✅ **Deduplication** - same file content can appear at different deep paths
- ✅ **Efficient** - path-based entries are simple and fast to process
- ✅ **Flexible** - supports both explicit directory entries and automatic creation

The format is designed to handle real-world scenarios with deeply nested directory structures while maintaining efficiency and deduplication capabilities.

