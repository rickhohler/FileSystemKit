# FileSystemEntry Data Sources

## Overview

`FileSystemEntry` can represent both **physical files** and **data streams** from any source. This flexibility enables unified handling of files, network streams, cloud storage, memory buffers, and other data sources.

## Architecture

### FileSystemEntry = Metadata + Data Reference

```swift
public class FileSystemEntry: FileSystemComponent {
    /// Entry metadata (always loaded, lightweight)
    public let metadata: FileSystemEntryMetadata
    
    /// Reference to the chunk containing file data (if applicable)
    /// This links the file system entry to its binary data in ChunkStorage
    public let chunkIdentifier: ChunkIdentifier?
    
    /// Convert to Chunk for data access
    func toChunk(storage: ChunkStorage) async throws -> Chunk?
}
```

**Key Design:**
- `FileSystemEntry` stores **metadata** (name, size, dates, etc.) and a **reference** to data (`chunkIdentifier`)
- The actual **data access** is handled by `Chunk`, which works with any `ChunkStorage` implementation
- This separation enables `FileSystemEntry` to represent data from any source

## Supported Data Sources

### 1. Physical Files on Disk

**Legacy Method (for disk images):**
```swift
let fileSystemEntry: FileSystemEntry = ...
let diskData: RawDiskData = ...
let data = try fileSystemEntry.readData(from: diskData)
```

**Chunk-based Method (for any storage):**
```swift
let fileSystemEntry: FileSystemEntry = ...
let storage = FileSystemChunkStorage(baseURL: fileSystemURL)
let chunk = try await fileSystemEntry.toChunk(storage: storage)
let data = try await chunk.readFull()
```

### 2. Network Streams

```swift
// Custom ChunkStorage for network streams
struct NetworkChunkStorage: ChunkStorage {
    func readChunk(_ identifier: ChunkIdentifier) async throws -> Data? {
        // Fetch from network using identifier
        return try await fetchFromNetwork(identifier.id)
    }
    // ... implement other methods
}

// Use with FileSystemEntry
let fileSystemEntry: FileSystemEntry = ...
let networkStorage = NetworkChunkStorage()
let chunk = try await fileSystemEntry.toChunk(storage: networkStorage)
let data = try await chunk.readFull()
```

### 3. Cloud Storage

```swift
// CloudKit ChunkStorage (example)
struct CloudKitChunkStorage: ChunkStorage {
    func readChunk(_ identifier: ChunkIdentifier) async throws -> Data? {
        // Fetch from CloudKit using identifier
        return try await cloudKit.fetch(identifier.id)
    }
    // ... implement other methods
}

// Use with FileSystemEntry
let fileSystemEntry: FileSystemEntry = ...
let cloudStorage = CloudKitChunkStorage()
let chunk = try await fileSystemEntry.toChunk(storage: cloudStorage)
let data = try await chunk.readFull()
```

### 4. Memory Buffers

```swift
// In-memory ChunkStorage
struct MemoryChunkStorage: ChunkStorage {
    private var storage: [String: Data] = [:]
    
    func readChunk(_ identifier: ChunkIdentifier) async throws -> Data? {
        return storage[identifier.id]
    }
    
    func writeChunk(_ data: Data, identifier: ChunkIdentifier, metadata: ChunkMetadata?) async throws -> ChunkIdentifier {
        storage[identifier.id] = data
        return identifier
    }
    // ... implement other methods
}

// Use with FileSystemEntry
let fileSystemEntry: FileSystemEntry = ...
let memoryStorage = MemoryChunkStorage()
let chunk = try await fileSystemEntry.toChunk(storage: memoryStorage)
let data = try await chunk.readFull()
```

### 5. Special Files

`FileSystemEntry` can also represent special files (block devices, character devices, sockets, FIFOs) when `metadata.specialFileType` is set:

```swift
let specialFileEntry = FileSystemEntry(
    metadata: FileSystemEntryMetadata(
        name: "/dev/null",
        size: 0,
        specialFileType: "character-device"
    ),
    chunkIdentifier: nil  // Special files don't have data chunks
)
```

## Unified API

The same `FileSystemEntry` API works for all data sources:

```swift
// Works the same way regardless of data source
func processFile(_ entry: FileSystemEntry, storage: ChunkStorage) async throws {
    guard let chunk = try await entry.toChunk(storage: storage) else {
        return  // No data available
    }
    
    // Access data using Chunk API (works for all sources)
    let header = try await chunk.readMagicNumber(maxBytes: 16)
    let fullData = try await chunk.readFull()
    // ... process data
}
```

## Benefits

1. **Unified Interface**: Same API for physical files, network streams, cloud storage, etc.
2. **Storage Abstraction**: Works with any `ChunkStorage` implementation
3. **Streaming Support**: `Chunk` supports range-based reads for efficient streaming
4. **Lazy Loading**: Data is loaded on-demand, not upfront
5. **Caching**: `Chunk` supports various caching strategies
6. **Content-Addressable**: `chunkIdentifier` enables deduplication and sharing

## Migration Path

### Legacy (Physical Files Only)
```swift
let fileSystemEntry: FileSystemEntry = ...
let diskData: RawDiskData = ...
let data = try fileSystemEntry.readData(from: diskData)
```

### Modern (Any Data Source)
```swift
let fileSystemEntry: FileSystemEntry = ...
let storage: ChunkStorage = ...  // Any implementation
let chunk = try await fileSystemEntry.toChunk(storage: storage)
let data = try await chunk.readFull()
```

## Conclusion

**Yes, `FileSystemEntry` can represent both physical files and data streams** because:

1. ✅ It stores metadata (applies to both)
2. ✅ It has a `chunkIdentifier` that points to data location
3. ✅ The `Chunk` abstraction can represent data from any source
4. ✅ The `toChunk()` method converts `FileSystemEntry` to `Chunk` for data access
5. ✅ Any `ChunkStorage` implementation can provide the data

This design enables `FileSystemEntry` to work seamlessly across all projects and tools, regardless of where the data is stored.

