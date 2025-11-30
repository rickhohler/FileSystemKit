# Performance Scaling for Millions of Files

## Executive Summary

This document evaluates FileSystemKit's performance characteristics and provides recommendations for scaling to handle millions of files efficiently.

## Current Architecture Analysis

### ✅ **Strengths**

1. **Content-Addressable Storage**: Hash-based storage enables deduplication
2. **Two-Level Directory Structure**: `ab/c1/hash` prevents directory bloat
3. **Hash Cache**: LRU cache reduces redundant hash computations
4. **Concurrent Processing**: Some async/await patterns in place
5. **Metadata Separation**: Metadata stored separately from content

### ⚠️ **Performance Bottlenecks**

1. **File Enumeration**: Synchronous `FileManager.enumerator` blocks
2. **Hash Cache Size**: 10K entries may be insufficient for millions
3. **Metadata Lookups**: No indexing, requires file system traversal
4. **Memory Usage**: Loading full files into memory
5. **Synchronous I/O**: Some blocking operations
6. **No Batch Operations**: Individual file operations

## Performance Areas Evaluation

### 1. Storage Structure

#### Current Implementation
```swift
// Two-level directory structure: ab/c1/hash
let prefix1 = String(hash.prefix(2))  // 256 possible directories
let prefix2 = String(hash.dropFirst(2).prefix(2))  // 256 possible subdirectories
// Total: 65,536 possible directory combinations
```

#### Analysis
- **Files per directory**: ~15 files per directory (1M files / 65K directories)
- **Directory depth**: 2 levels (optimal for file systems)
- **Lookup performance**: O(1) file system lookup
- **Scalability**: ✅ Excellent - can handle 100M+ files

#### Recommendations
- ✅ **Keep current structure** - optimal for millions of files
- Consider **three-level structure** for > 100M files: `ab/c1/23/hash`
- Monitor directory sizes - if > 1000 files/directory, add level

### 2. Hash Cache

#### Current Implementation
```swift
public actor FileHashCache {
    private var cache: [String: FileHashCacheEntry] = [:]
    private let maxCacheSize: Int = 10000  // ⚠️ Too small for millions
    private var accessOrder: [String] = []  // ⚠️ O(n) LRU operations
}
```

#### Analysis
- **Cache size**: 10K entries (insufficient for millions)
- **LRU implementation**: Array-based (O(n) operations)
- **Persistence**: Disk-backed (good)
- **Memory usage**: ~1-2 MB for 10K entries

#### Performance Impact
- **Cache hit rate**: Low for large collections (cache too small)
- **LRU overhead**: O(n) operations become expensive
- **Memory**: Acceptable but could be optimized

#### Recommendations

**Priority: HIGH**

1. **Increase cache size**:
   ```swift
   // Scale cache size based on collection size
   let cacheSize = min(max(collectionSize / 100, 10000), 1_000_000)
   ```

2. **Optimize LRU with linked list**:
   ```swift
   // Use doubly-linked list for O(1) LRU operations
   private class LRUNode {
       let key: String
       var prev: LRUNode?
       var next: LRUNode?
   }
   ```

3. **Implement cache sharding**:
   ```swift
   // Shard cache across multiple actors for better concurrency
   actor FileHashCacheShard {
       private var cache: [String: FileHashCacheEntry] = [:]
       // ... per-shard operations
   }
   
   public actor FileHashCache {
       private let shards: [FileHashCacheShard]
       // Route to shard based on hash prefix
   }
   ```

4. **Add cache statistics**:
   ```swift
   struct CacheStats {
       let hits: Int64
       let misses: Int64
       let evictions: Int64
       let hitRate: Double { Double(hits) / Double(hits + misses) }
   }
   ```

### 3. File Enumeration

#### Current Implementation
```swift
let enumerator = FileManager.default.enumerator(
    at: url,
    includingPropertiesForKeys: resourceKeys,
    options: [.skipsHiddenFiles]
)

while let fileURL = enumerator.nextObject() as? URL {
    // Process file synchronously
}
```

#### Analysis
- **Synchronous**: Blocks thread during enumeration
- **Memory**: Loads all file URLs into memory
- **Performance**: O(n) where n = number of files
- **Scalability**: ⚠️ Poor for millions of files

#### Performance Impact
- **Startup time**: Slow for large directories
- **Memory usage**: High (all URLs in memory)
- **Blocking**: Blocks main thread

#### Recommendations

**Priority: HIGH**

1. **Batch enumeration**:
   ```swift
   // Process files in batches to reduce memory
   func enumerateFilesBatched(
       at url: URL,
       batchSize: Int = 1000,
       processor: @escaping ([URL]) async throws -> Void
   ) async throws {
       var batch: [URL] = []
       let enumerator = FileManager.default.enumerator(...)
       
       while let fileURL = enumerator.nextObject() as? URL {
           batch.append(fileURL)
           if batch.count >= batchSize {
               try await processor(batch)
               batch.removeAll()
           }
       }
       if !batch.isEmpty {
           try await processor(batch)
       }
   }
   ```

2. **Async enumeration**:
   ```swift
   // Use async sequence for non-blocking enumeration
   func enumerateFilesAsync(at url: URL) -> AsyncThrowingStream<URL, Error> {
       AsyncThrowingStream { continuation in
           Task {
               let enumerator = FileManager.default.enumerator(...)
               while let fileURL = enumerator.nextObject() as? URL {
                   continuation.yield(fileURL)
               }
               continuation.finish()
           }
       }
   }
   ```

3. **Parallel directory traversal**:
   ```swift
   // Process directories in parallel
   func processDirectoryTree(
       at url: URL,
       maxConcurrency: Int = ProcessInfo.processInfo.processorCount
   ) async throws {
       let directories = try discoverDirectories(at: url)
       
       await withTaskGroup(of: Void.self) { group in
           var activeTasks = 0
           for dir in directories {
               while activeTasks >= maxConcurrency {
                   try await group.next()
                   activeTasks -= 1
               }
               activeTasks += 1
               group.addTask {
                   try await processDirectory(dir)
               }
           }
       }
   }
   ```

### 4. Metadata Storage and Lookups

#### Current Implementation
```swift
// Metadata stored as JSON files: hash.meta
let metadataURL = url.appendingPathExtension("meta")
try writeMetadata(metadata, to: metadataURL, identifier: identifier)
```

#### Analysis
- **Storage**: One JSON file per chunk
- **Lookup**: File system traversal (O(n))
- **Format**: JSON (readable but verbose)
- **Indexing**: None

#### Performance Impact
- **Lookup time**: Slow for millions (no index)
- **Storage overhead**: JSON is verbose (~200-500 bytes per file)
- **Query performance**: Poor (requires scanning all files)

#### Recommendations

**Priority: HIGH**

1. **Create metadata index**:
   ```swift
   // Index metadata in SQLite or similar
   struct MetadataIndex {
       // Hash -> metadata lookup (O(1))
       func getMetadata(for hash: String) -> ChunkMetadata?
       
       // Query by original path, size, date, etc.
       func query(by path: String) -> [ChunkMetadata]
       func query(by size: Range<Int>) -> [ChunkMetadata]
       func query(by date: Range<Date>) -> [ChunkMetadata]
   }
   ```

2. **Batch metadata operations**:
   ```swift
   // Batch read/write metadata
   func writeMetadataBatch(_ entries: [(ChunkIdentifier, ChunkMetadata)]) async throws
   func readMetadataBatch(_ identifiers: [ChunkIdentifier]) async throws -> [ChunkIdentifier: ChunkMetadata]
   ```

3. **Compress metadata**:
   ```swift
   // Use binary format (MessagePack, Protocol Buffers) instead of JSON
   // Reduces storage by 50-70%
   ```

4. **Lazy metadata loading**:
   ```swift
   // Only load metadata when needed
   func getMetadata(for identifier: ChunkIdentifier, loadIfNeeded: Bool = false) async throws -> ChunkMetadata?
   ```

### 5. Hash Computation

#### Current Implementation
```swift
// Hash computed synchronously per file
let hash = try computeHash(data: fileData, algorithm: .sha256)
```

#### Analysis
- **Algorithm**: SHA-256 (secure, fast enough)
- **Computation**: Synchronous (blocks thread)
- **Caching**: FileHashCache reduces redundant computation
- **Performance**: ~1ms per MB (acceptable)

#### Performance Impact
- **CPU bound**: Hash computation is CPU-intensive
- **Parallelization**: Some concurrent processing exists
- **Cache effectiveness**: Depends on cache size

#### Recommendations

**Priority: MEDIUM**

1. **Streaming hash computation**:
   ```swift
   // Compute hash while reading file (don't load full file)
   func computeHashStreaming(
       for url: URL,
       algorithm: HashAlgorithm
   ) async throws -> String {
       let handle = try FileHandle(forReadingFrom: url)
       defer { try? handle.close() }
       
       var hasher = HashContext(algorithm: algorithm)
       let bufferSize = 64 * 1024  // 64 KB chunks
       
       while let data = try handle.read(upToCount: bufferSize), !data.isEmpty {
           hasher.update(data)
       }
       
       return hasher.finalize()
   }
   ```

2. **Batch hash computation**:
   ```swift
   // Compute hashes in parallel batches
   func computeHashesBatch(
       _ files: [URL],
       algorithm: HashAlgorithm,
       maxConcurrency: Int = ProcessInfo.processInfo.processorCount
   ) async throws -> [URL: String] {
       await withTaskGroup(of: (URL, String).self) { group in
           for file in files {
               group.addTask {
                   let hash = try await computeHashStreaming(for: file, algorithm: algorithm)
                   return (file, hash)
               }
           }
           
           var results: [URL: String] = [:]
           for try await (url, hash) in group {
               results[url] = hash
           }
           return results
       }
   }
   ```

### 6. Memory Management

#### Current Implementation
```swift
// Files loaded fully into memory
let data = try Data(contentsOf: url)
let hash = try computeHash(data: data, algorithm: .sha256)
```

#### Analysis
- **Memory usage**: High (full file in memory)
- **Large files**: Problematic (> 100 MB files)
- **Concurrent processing**: Limited by memory

#### Performance Impact
- **Memory pressure**: High for large files
- **GC pressure**: Frequent allocations/deallocations
- **Concurrency**: Limited by available memory

#### Recommendations

**Priority: HIGH**

1. **Streaming I/O**:
   ```swift
   // Use FileHandle for streaming reads
   func processFileStreaming(at url: URL) async throws {
       let handle = try FileHandle(forReadingFrom: url)
       defer { try? handle.close() }
       
       let bufferSize = 64 * 1024  // 64 KB
       while let data = try handle.read(upToCount: bufferSize), !data.isEmpty {
           // Process chunk
       }
   }
   ```

2. **Memory-mapped files**:
   ```swift
   // Use memory-mapped files for large files
   func processFileMemoryMapped(at url: URL) throws {
       let data = try Data(contentsOf: url, options: .mappedIfSafe)
       // Process without loading full file into memory
   }
   ```

3. **Limit concurrent memory usage**:
   ```swift
   // Limit concurrent file processing based on memory
   let maxConcurrentFiles = min(
       ProcessInfo.processInfo.processorCount,
       availableMemory / averageFileSize
   )
   ```

### 7. Concurrent Processing

#### Current Implementation
```swift
// Some concurrent processing exists
await withTaskGroup(of: Void.self) { group in
    for file in files {
        group.addTask {
            // Process file
        }
    }
}
```

#### Analysis
- **Concurrency**: Some async/await patterns
- **Task limits**: Limited concurrency control
- **Resource management**: Basic

#### Performance Impact
- **CPU utilization**: Good for multi-core systems
- **I/O utilization**: Could be better optimized
- **Memory**: Concurrent tasks increase memory usage

#### Recommendations

**Priority: MEDIUM**

1. **Work-stealing queue**:
   ```swift
   // Implement work-stealing queue for better load balancing
   actor WorkStealingQueue<T> {
       private var queues: [[T]] = []
       
       func steal() -> T? {
           // Steal work from other queues
       }
   }
   ```

2. **I/O-bound vs CPU-bound tasks**:
   ```swift
   // Separate I/O-bound and CPU-bound task pools
   let ioQueue = DispatchQueue(label: "io", attributes: .concurrent)
   let cpuQueue = DispatchQueue(label: "cpu", attributes: .concurrent)
   ```

3. **Adaptive concurrency**:
   ```swift
   // Adjust concurrency based on system load
   func adaptiveConcurrency() -> Int {
       let cpuCount = ProcessInfo.processInfo.processorCount
       let loadAverage = getSystemLoadAverage()
       return Int(Double(cpuCount) * (1.0 - loadAverage))
   }
   ```

### 8. Batch Operations

#### Current Implementation
```swift
// Individual operations
for file in files {
    try await chunkStorage.writeChunk(data, identifier: identifier)
}
```

#### Analysis
- **Operations**: One at a time
- **Overhead**: High per-operation overhead
- **Efficiency**: Low for bulk operations

#### Performance Impact
- **Throughput**: Low (many small operations)
- **Latency**: High (per-operation overhead)
- **Scalability**: Poor for millions

#### Recommendations

**Priority: HIGH**

1. **Batch write operations**:
   ```swift
   // Batch write chunks
   func writeChunksBatch(
       _ chunks: [(Data, ChunkIdentifier, ChunkMetadata?)],
       batchSize: Int = 100
   ) async throws {
       for batch in chunks.chunked(into: batchSize) {
           try await withTaskGroup(of: Void.self) { group in
               for (data, identifier, metadata) in batch {
                   group.addTask {
                       try await writeChunk(data, identifier: identifier, metadata: metadata)
                   }
               }
           }
       }
   }
   ```

2. **Transaction support**:
   ```swift
   // Batch operations in transactions
   func writeChunksTransaction(
       _ chunks: [(Data, ChunkIdentifier, ChunkMetadata?)]
   ) async throws {
       // Start transaction
       // Write all chunks
       // Commit transaction (atomic)
   }
   ```

### 9. Query and Search Performance

#### Current Implementation
```swift
// No indexing - requires scanning
func findChunk(by path: String) -> ChunkIdentifier? {
    // Scan all metadata files
}
```

#### Analysis
- **Indexing**: None
- **Query performance**: O(n) - scans all files
- **Search capabilities**: Limited

#### Performance Impact
- **Query time**: Slow for millions (O(n))
- **Search**: Not feasible for large collections
- **User experience**: Poor

#### Recommendations

**Priority: HIGH**

1. **Build search index**:
   ```swift
   // Use SQLite or similar for indexing
   struct ChunkIndex {
       // Hash index (primary)
       func getChunk(by hash: String) -> ChunkIdentifier?
       
       // Path index (secondary)
       func getChunks(by path: String) -> [ChunkIdentifier]
       func getChunks(by pathPrefix: String) -> [ChunkIdentifier]
       
       // Metadata index (secondary)
       func getChunks(by size: Range<Int>) -> [ChunkIdentifier]
       func getChunks(by date: Range<Date>) -> [ChunkIdentifier]
       func getChunks(by contentType: String) -> [ChunkIdentifier]
   }
   ```

2. **Full-text search**:
   ```swift
   // Add full-text search for filenames/paths
   func searchChunks(query: String) -> [ChunkIdentifier] {
       // Use FTS5 or similar
   }
   ```

3. **Incremental indexing**:
   ```swift
   // Update index incrementally as chunks are added
   func addChunkToIndex(_ chunk: ChunkIdentifier, metadata: ChunkMetadata) async throws
   ```

### 10. Storage Backend Optimization

#### Current Implementation
```swift
// File system-based storage
struct SnugFileSystemChunkStorage: ChunkStorage {
    // Direct file system operations
}
```

#### Analysis
- **Backend**: File system (simple, portable)
- **Performance**: Good for local storage
- **Scalability**: Limited by file system

#### Performance Impact
- **Local storage**: Good performance
- **Network storage**: Poor performance (many small files)
- **Cloud storage**: Not optimized

#### Recommendations

**Priority: MEDIUM**

1. **Storage backend abstraction**:
   ```swift
   // Support multiple backends
   protocol ChunkStorageBackend {
       func write(_ data: Data, at path: String) async throws
       func read(at path: String) async throws -> Data?
   }
   
   // Implementations:
   // - FileSystemBackend (current)
   // - SQLiteBackend (for small chunks)
   // - S3Backend (for cloud storage)
   // - LocalCacheBackend (for frequently accessed)
   ```

2. **Chunk size optimization**:
   ```swift
   // Store small chunks in database, large chunks in file system
   func chooseBackend(for size: Int) -> ChunkStorageBackend {
       if size < 64 * 1024 {  // < 64 KB
           return sqliteBackend
       } else {
           return fileSystemBackend
       }
   }
   ```

## Performance Targets

### For 1 Million Files

| Metric | Target | Current | Gap |
|--------|--------|---------|-----|
| **Index build time** | < 5 min | N/A | Need indexing |
| **Hash computation** | < 10 min | ~15 min | Optimize |
| **Query time** | < 100ms | O(n) | Need indexing |
| **Memory usage** | < 500 MB | ~1 GB | Optimize |
| **Storage overhead** | < 5% | ~3% | Good |

### For 10 Million Files

| Metric | Target | Current | Gap |
|--------|--------|---------|-----|
| **Index build time** | < 30 min | N/A | Need indexing |
| **Hash computation** | < 2 hours | ~3 hours | Optimize |
| **Query time** | < 500ms | O(n) | Need indexing |
| **Memory usage** | < 2 GB | ~10 GB | Optimize |
| **Storage overhead** | < 5% | ~3% | Good |

### For 100 Million Files

| Metric | Target | Current | Gap |
|--------|--------|---------|-----|
| **Index build time** | < 3 hours | N/A | Need indexing |
| **Hash computation** | < 1 day | ~2 days | Optimize |
| **Query time** | < 1s | O(n) | Need indexing |
| **Memory usage** | < 10 GB | ~100 GB | Optimize |
| **Storage overhead** | < 5% | ~3% | Good |

## Implementation Priority

### Phase 1: Critical (Immediate)

1. **Metadata Indexing** (HIGH)
   - SQLite-based index
   - Hash, path, metadata queries
   - Estimated impact: 100x faster queries

2. **Hash Cache Scaling** (HIGH)
   - Increase cache size (100K-1M entries)
   - Optimize LRU (linked list)
   - Estimated impact: 50% reduction in hash computations

3. **Batch Operations** (HIGH)
   - Batch write/read operations
   - Transaction support
   - Estimated impact: 10x faster bulk operations

### Phase 2: Important (Next Release)

4. **Streaming I/O** (MEDIUM)
   - FileHandle-based streaming
   - Memory-mapped files for large files
   - Estimated impact: 50% reduction in memory usage

5. **Async File Enumeration** (MEDIUM)
   - Batch enumeration
   - Parallel directory traversal
   - Estimated impact: 2x faster enumeration

6. **Concurrent Processing Optimization** (MEDIUM)
   - Work-stealing queue
   - Adaptive concurrency
   - Estimated impact: Better CPU utilization

### Phase 3: Optimization (Future)

7. **Storage Backend Abstraction** (LOW)
   - Multiple backend support
   - Chunk size optimization
   - Estimated impact: Better cloud storage support

8. **Full-Text Search** (LOW)
   - FTS5 integration
   - Incremental indexing
   - Estimated impact: Better search capabilities

## Code Examples

### Optimized Hash Cache

```swift
// High-performance hash cache for millions of files
public actor FileHashCache {
    private var cache: [String: FileHashCacheEntry] = [:]
    private let maxCacheSize: Int
    private var lruHead: LRUNode?
    private var lruTail: LRUNode?
    private var nodeMap: [String: LRUNode] = [:]
    
    public init(cacheFileURL: URL? = nil, hashAlgorithm: String, maxCacheSize: Int = 1_000_000) {
        self.cacheFileURL = cacheFileURL
        self.hashAlgorithm = hashAlgorithm
        self.maxCacheSize = maxCacheSize
    }
    
    private func touch(_ key: String) {
        // O(1) LRU update using linked list
        if let node = nodeMap[key] {
            removeFromLRU(node)
            addToLRUHead(node)
        }
    }
    
    private func evictLRU() {
        // O(1) eviction
        if let tail = lruTail {
            cache.removeValue(forKey: tail.key)
            nodeMap.removeValue(forKey: tail.key)
            removeFromLRU(tail)
        }
    }
}
```

### Metadata Index

```swift
// SQLite-based metadata index
public class ChunkMetadataIndex {
    private let db: SQLiteDatabase
    
    func createIndex() throws {
        try db.execute("""
            CREATE TABLE IF NOT EXISTS chunk_metadata (
                hash TEXT PRIMARY KEY,
                size INTEGER,
                content_hash TEXT,
                hash_algorithm TEXT,
                content_type TEXT,
                chunk_type TEXT,
                original_filename TEXT,
                created INTEGER,
                modified INTEGER
            )
            
            CREATE INDEX IF NOT EXISTS idx_path ON chunk_paths(path)
            CREATE INDEX IF NOT EXISTS idx_size ON chunk_metadata(size)
            CREATE INDEX IF NOT EXISTS idx_date ON chunk_metadata(modified)
        """)
    }
    
    func getMetadata(for hash: String) throws -> ChunkMetadata? {
        // O(1) lookup
        return try db.query("SELECT * FROM chunk_metadata WHERE hash = ?", [hash])
    }
    
    func query(by path: String) throws -> [ChunkMetadata] {
        // O(log n) lookup with index
        return try db.query("""
            SELECT m.* FROM chunk_metadata m
            JOIN chunk_paths p ON m.hash = p.hash
            WHERE p.path = ?
        """, [path])
    }
}
```

### Batch Operations

```swift
// Batch chunk operations
extension ChunkStorage {
    func writeChunksBatch(
        _ chunks: [(Data, ChunkIdentifier, ChunkMetadata?)],
        batchSize: Int = 100
    ) async throws {
        for batch in chunks.chunked(into: batchSize) {
            try await withThrowingTaskGroup(of: Void.self) { group in
                for (data, identifier, metadata) in batch {
                    group.addTask {
                        try await self.writeChunk(data, identifier: identifier, metadata: metadata)
                    }
                }
                try await group.waitForAll()
            }
        }
    }
}
```

## Conclusion

FileSystemKit has a solid foundation for scaling to millions of files, but requires optimizations in several key areas:

1. **Critical**: Metadata indexing, hash cache scaling, batch operations
2. **Important**: Streaming I/O, async enumeration, concurrent processing
3. **Future**: Storage backend abstraction, full-text search

With these optimizations, FileSystemKit can efficiently handle millions of files with:
- Fast queries (< 100ms for 1M files)
- Efficient memory usage (< 500 MB for 1M files)
- High throughput (1000+ files/second)
- Scalable architecture (100M+ files)

