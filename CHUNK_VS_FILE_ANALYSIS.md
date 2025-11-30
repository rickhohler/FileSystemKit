# Chunk vs File Architecture Analysis

## Executive Summary

**Recommendation: Adopt Chunk-based APIs for data access operations while keeping File for metadata and structure.**

Using `Chunk` instead of `File` for data access operations provides significant architectural benefits:
- **Stream-based operations** instead of file-system dependencies
- **Storage abstraction** (works with ChunkStorage, not just RawDiskData)
- **Better scalability** for cloud/remote storage
- **Unified interface** for local files, disk images, and streams

## Current Architecture

### File (FileSystemComponent)
```swift
public class File: FileSystemComponent {
    let metadata: FileMetadata  // Always loaded
    private var _data: Data?    // Lazy-loaded
    private weak var _cachedDiskData: RawDiskData?  // Disk image dependency
    
    func readData(from diskData: RawDiskData) throws -> Data
    func readData() throws -> Data  // Requires cached RawDiskData
}
```

**Characteristics:**
- ✅ Rich metadata (name, size, dates, location, hashes)
- ✅ File system structure (parent folder, hierarchy)
- ❌ Tightly coupled to `RawDiskData` (disk image format)
- ❌ Requires disk image to be loaded/mapped
- ❌ Not suitable for streaming or remote storage

### Chunk
```swift
public struct Chunk: Sendable {
    let storage: any ChunkStorage      // Abstract storage
    let identifier: ChunkIdentifier    // Content-addressable ID
    let accessPattern: AccessPattern   // Caching strategy
    let totalSize: Int
    
    mutating func read(range: Range<Int>) async throws -> Data
    mutating func readFull() async throws -> Data
    mutating func readMagicNumber(maxBytes: Int) async throws -> Data
}
```

**Characteristics:**
- ✅ Storage abstraction (works with any ChunkStorage)
- ✅ Streaming support (range-based reads)
- ✅ Lazy loading with caching strategies
- ✅ Content-addressable (hash-based deduplication)
- ✅ Async/await support
- ❌ No file system metadata (name, dates, hierarchy)
- ❌ No file system structure (parent folders)

## Use Case Analysis

### Current File Usage Patterns

1. **FileSystemStrategy.readFile()**
   ```swift
   func readFile(_ file: File, chunkStorage: ChunkStorage, identifier: ChunkIdentifier) async throws -> Data
   ```
   - Takes `File` for metadata but uses `ChunkStorage` for actual data
   - **Issue**: File requires RawDiskData, but we're using ChunkStorage
   - **Solution**: Use Chunk directly

2. **File.readData()**
   ```swift
   func readData(from diskData: RawDiskData) throws -> Data
   ```
   - Requires entire disk image to be loaded
   - **Issue**: Doesn't work with ChunkStorage or streaming
   - **Solution**: Create Chunk from File metadata

3. **File.generateHash()**
   ```swift
   func generateHash(algorithm: HashAlgorithm) throws -> FileHash
   ```
   - Needs file content to compute hash
   - **Issue**: Requires RawDiskData
   - **Solution**: Use Chunk for content access

## Recommended Architecture

### Hybrid Approach: File for Structure, Chunk for Data

**Principle**: Separate concerns - File handles metadata/structure, Chunk handles data access.

#### 1. File as Metadata Container
```swift
public class File: FileSystemComponent {
    let metadata: FileMetadata
    let chunkIdentifier: ChunkIdentifier?  // Reference to chunk storage
    
    // Remove RawDiskData dependency
    // Remove readData() methods that require RawDiskData
}
```

#### 2. Chunk for Data Access
```swift
// All data access operations use Chunk
func readFile(_ chunk: Chunk) async throws -> Data
func generateHash(_ chunk: Chunk, algorithm: HashAlgorithm) async throws -> FileHash
func detectFileType(_ chunk: Chunk) async throws -> FileTypeInfo
```

#### 3. Conversion Between File and Chunk
```swift
extension File {
    /// Create a Chunk from this File's chunk identifier
    func toChunk(storage: ChunkStorage, accessPattern: AccessPattern = .onDemand) async throws -> Chunk {
        guard let identifier = chunkIdentifier else {
            throw FileSystemError.chunkIdentifierNotAvailable
        }
        return try await Chunk.builder()
            .storage(storage)
            .identifier(identifier)
            .accessPattern(accessPattern)
            .build()
    }
}

extension Chunk {
    /// Create a File from this Chunk's metadata
    func toFile(metadata: FileMetadata) -> File {
        return File(metadata: metadata, chunkIdentifier: identifier)
    }
}
```

## Migration Strategy

### Phase 1: Add Chunk Support to File
1. Add `chunkIdentifier: ChunkIdentifier?` to File
2. Add `toChunk()` method to File
3. Keep existing `readData()` methods for backward compatibility
4. Mark as deprecated

### Phase 2: Update APIs to Accept Chunk
1. Update `FileSystemStrategy.readFile()` to accept `Chunk` instead of `File`
2. Create new `readFile(_ chunk: Chunk)` methods
3. Keep old methods for backward compatibility

### Phase 3: Remove RawDiskData Dependency
1. Remove `readData(from: RawDiskData)` from File
2. Update all callers to use Chunk-based APIs
3. Remove RawDiskData from File class

## Benefits of Chunk-Based Architecture

### 1. Storage Abstraction
```swift
// Works with any storage backend
let chunk = try await Chunk.builder()
    .storage(cloudStorage)  // or localStorage, or remoteStorage
    .identifier(identifier)
    .build()
```

### 2. Streaming Support
```swift
// Read only what you need
let header = try await chunk.readHeader(maxBytes: 512)
let magic = try await chunk.readMagicNumber(maxBytes: 16)
```

### 3. Better Performance
```swift
// Optimize for access pattern
let chunk = try await Chunk.builder()
    .storage(storage)
    .identifier(identifier)
    .accessPattern(.magicNumber(maxBytes: 16))  // Only load 16 bytes
    .build()
```

### 4. Unified Interface
```swift
// Same API for local files, disk images, and streams
func processChunk(_ chunk: Chunk) async throws {
    let data = try await chunk.readFull()
    // Process data...
}
```

## Specific Recommendations

### 1. FileSystemStrategy Protocol
**Current:**
```swift
func readFile(_ file: File, chunkStorage: ChunkStorage, identifier: ChunkIdentifier) async throws -> Data
```

**Recommended:**
```swift
func readFile(_ chunk: Chunk) async throws -> Data
```

**Rationale**: File is only needed for metadata (name, location). Chunk already has identifier and storage reference.

### 2. File Type Detection
**Current:**
```swift
FileTypeDetector.detect(for url: URL, data: Data) -> FileTypeInfo
```

**Recommended:**
```swift
FileTypeDetector.detect(_ chunk: Chunk) async throws -> FileTypeInfo
```

**Rationale**: Works with any data source, not just local files.

### 3. Hash Generation
**Current:**
```swift
file.generateHash(algorithm: HashAlgorithm) throws -> FileHash
```

**Recommended:**
```swift
func generateHash(_ chunk: Chunk, algorithm: HashAlgorithm) async throws -> FileHash
```

**Rationale**: Can hash streams without loading entire file.

### 4. Compression Operations
**Current:**
```swift
CompressionAdapter.decompress(data: Data) throws -> Data
```

**Recommended:**
```swift
CompressionAdapter.decompress(_ chunk: Chunk) async throws -> Chunk
```

**Rationale**: Can decompress streams without loading entire file.

## Implementation Example

### Before (File-based)
```swift
// Requires RawDiskData
let file: File = ...
let diskData: RawDiskData = ...
let data = try file.readData(from: diskData)
let hash = try file.generateHash()
```

### After (Chunk-based)
```swift
// Works with any storage
let file: File = ...
let chunk = try await file.toChunk(storage: chunkStorage)
let data = try await chunk.readFull()
let hash = try await generateHash(chunk, algorithm: .sha256)
```

## Compatibility Considerations

### Backward Compatibility
- Keep File class for metadata and structure
- Keep existing File APIs (mark as deprecated)
- Provide migration path via `toChunk()` method

### Performance Impact
- Chunk-based APIs are async (better for I/O)
- Chunk supports streaming (better memory usage)
- Chunk supports caching strategies (better performance)

## Conclusion

**Recommendation: Adopt Chunk-based APIs for all data access operations.**

**Key Points:**
1. ✅ Use `File` for metadata and file system structure
2. ✅ Use `Chunk` for all data access operations
3. ✅ Provide conversion methods between File and Chunk
4. ✅ Keep backward compatibility during migration
5. ✅ Enable streaming and remote storage support

This architecture provides:
- **Flexibility**: Works with any storage backend
- **Performance**: Streaming and caching support
- **Scalability**: Suitable for cloud/remote storage
- **Unified API**: Same interface for all data sources

