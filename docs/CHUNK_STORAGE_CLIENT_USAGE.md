# Chunk Storage Client Usage Guide

This guide shows how clients can use FileSystemKit's composable chunk storage architecture to implement custom storage backends.

## Overview

FileSystemKit 1.6.0 introduces a composable chunk storage architecture that allows clients to:
- Mix and match different organization strategies
- Use different retrieval implementations
- Add optional existence checking
- Wrap retrieval implementations with compression, caching, encryption, etc.

## Quick Start

### Using the Default Implementation

The simplest way to use chunk storage is with the provided `ComposableFileSystemChunkStorage`:

```swift
import FileSystemKit

// Create storage with default Git-style organization
let baseURL = URL(fileURLWithPath: "/path/to/storage")
let storage = ComposableFileSystemChunkStorage(baseURL: baseURL)

// Use it like any ChunkStorage
let identifier = ChunkIdentifier(id: "a1b2c3d4...")
try await storage.writeChunk(data, identifier: identifier, metadata: metadata)
let readData = try await storage.readChunk(identifier)
```

### Using Custom Organization

Choose a different organization strategy:

```swift
// Flat organization (all chunks in single directory)
let flatOrg = FlatOrganization()
let storage = ComposableFileSystemChunkStorage(
    baseURL: baseURL,
    organization: flatOrg
)

// Git-style with custom depth
let deepOrg = GitStyleOrganization(directoryDepth: 3)
let storage = ComposableFileSystemChunkStorage(
    baseURL: baseURL,
    organization: deepOrg
)
```

## Implementing Custom Storage

### Option 1: Implement ChunkStorageComposable

For maximum flexibility, implement `ChunkStorageComposable`:

```swift
import Foundation
import FileSystemKit

/// Custom CloudKit chunk storage implementation
public struct CloudKitChunkStorage: ChunkStorageComposable {
    public let organization: ChunkStorageOrganization
    public let retrieval: ChunkStorageRetrieval
    public let existence: ChunkStorageExistence?
    
    // Optional protocols (not implemented yet)
    public var export: ChunkStorageExport? { nil }
    public var `import`: ChunkStorageImport? { nil }
    public var sharing: ChunkStorageSharing? { nil }
    
    private let container: CKContainer
    private let database: CKDatabase
    
    public init(
        container: CKContainer,
        database: CKDatabase,
        organization: ChunkStorageOrganization = GitStyleOrganization()
    ) {
        self.container = container
        self.database = database
        self.organization = organization
        
        // Implement CloudKit-specific retrieval
        self.retrieval = CloudKitRetrieval(
            container: container,
            database: database,
            organization: organization
        )
        
        // Implement CloudKit-specific existence checking
        self.existence = CloudKitExistence(
            container: container,
            database: database,
            organization: organization
        )
    }
    
    // Implement required ChunkStorage methods
    // Default implementations are provided via ChunkStorage+Default
    // but you can override for custom behavior
}
```

### Option 2: Implement Individual Protocols

For fine-grained control, implement the individual protocols:

#### Custom Organization Strategy

```swift
import Foundation
import FileSystemKit

/// Custom organization strategy for CloudKit record IDs
public struct CloudKitOrganization: ChunkStorageOrganization {
    public let name = "cloudkit"
    public let description = "CloudKit record ID organization"
    
    public func storagePath(for identifier: ChunkIdentifier) -> String {
        // CloudKit uses record IDs like "Chunk_a1b2c3d4..."
        return "Chunk_\(identifier.id)"
    }
    
    public func identifier(from path: String) -> ChunkIdentifier? {
        guard path.hasPrefix("Chunk_") else { return nil }
        let hash = String(path.dropFirst(6))
        return ChunkIdentifier(id: hash)
    }
    
    public func isValidPath(_ path: String) -> Bool {
        return path.hasPrefix("Chunk_") && path.count > 6
    }
}
```

#### Custom Retrieval Implementation

```swift
import Foundation
import CloudKit
import FileSystemKit

/// CloudKit-based chunk retrieval
public struct CloudKitRetrieval: ChunkStorageRetrieval {
    private let container: CKContainer
    private let database: CKDatabase
    private let organization: ChunkStorageOrganization
    
    public init(
        container: CKContainer,
        database: CKDatabase,
        organization: ChunkStorageOrganization
    ) {
        self.container = container
        self.database = database
        self.organization = organization
    }
    
    public func readChunk(at path: String) async throws -> Data? {
        guard let identifier = organization.identifier(from: path) else {
            return nil
        }
        
        let recordID = CKRecord.ID(recordName: identifier.id)
        do {
            let record = try await database.record(for: recordID)
            guard let asset = record["data"] as? CKAsset else {
                return nil
            }
            return try Data(contentsOf: asset.fileURL!)
        } catch {
            if let ckError = error as? CKError,
               ckError.code == .unknownItem {
                return nil
            }
            throw error
        }
    }
    
    public func writeChunk(
        _ data: Data,
        at path: String,
        metadata: ChunkMetadata?
    ) async throws {
        guard let identifier = organization.identifier(from: path) else {
            throw ChunkStorageError.invalidPath(path)
        }
        
        let recordID = CKRecord.ID(recordName: identifier.id)
        let record = CKRecord(recordType: "Chunk", recordID: recordID)
        
        // Store data as CKAsset
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try data.write(to: tempURL)
        record["data"] = CKAsset(fileURL: tempURL)
        
        // Store metadata if provided
        if let metadata = metadata {
            let encoder = JSONEncoder()
            record["metadata"] = try encoder.encode(metadata)
        }
        
        try await database.save(record)
        try? FileManager.default.removeItem(at: tempURL)
    }
    
    public func chunkExists(at path: String) async -> Bool {
        guard let identifier = organization.identifier(from: path) else {
            return false
        }
        
        let recordID = CKRecord.ID(recordName: identifier.id)
        do {
            _ = try await database.record(for: recordID)
            return true
        } catch {
            return false
        }
    }
    
    public func deleteChunk(at path: String) async throws {
        guard let identifier = organization.identifier(from: path) else {
            throw ChunkStorageError.invalidPath(path)
        }
        
        let recordID = CKRecord.ID(recordName: identifier.id)
        try await database.deleteRecord(withID: recordID)
    }
}
```

#### Custom Existence Implementation

```swift
import Foundation
import CloudKit
import FileSystemKit

/// CloudKit-based existence checking
public struct CloudKitExistence: ChunkStorageExistence {
    private let container: CKContainer
    private let database: CKDatabase
    private let organization: ChunkStorageOrganization
    
    public init(
        container: CKContainer,
        database: CKDatabase,
        organization: ChunkStorageOrganization
    ) {
        self.container = container
        self.database = database
        self.organization = organization
    }
    
    public func chunkExists(identifier: ChunkIdentifier) async -> Bool {
        let recordID = CKRecord.ID(recordName: identifier.id)
        do {
            _ = try await database.record(for: recordID)
            return true
        } catch {
            return false
        }
    }
    
    public func chunkExists(identifiers: [ChunkIdentifier]) async -> [ChunkIdentifier: Bool] {
        let recordIDs = identifiers.map { CKRecord.ID(recordName: $0.id) }
        
        // Use CloudKit batch query for efficiency
        var results: [ChunkIdentifier: Bool] = [:]
        
        // Process in batches (CloudKit limit is 400)
        for batch in recordIDs.chunked(into: 400) {
            let query = CKQuery(recordType: "Chunk", predicate: NSPredicate(value: true))
            let operation = CKQueryOperation(query: query)
            
            var foundIDs: Set<String> = []
            operation.recordMatchedBlock = { recordID, result in
                if case .success = result {
                    foundIDs.insert(recordID.recordName)
                }
            }
            
            try? await database.fetch(with: operation)
            
            for identifier in identifiers {
                results[identifier] = foundIDs.contains(identifier.id)
            }
        }
        
        return results
    }
}
```

### Option 3: Wrap Existing Retrieval (Decorator Pattern)

Wrap an existing retrieval implementation to add functionality:

```swift
import Foundation
import FileSystemKit

/// Compression wrapper for chunk retrieval
public struct CompressedRetrieval: ChunkStorageRetrieval {
    private let wrapped: ChunkStorageRetrieval
    private let algorithm: CompressionAlgorithm
    
    public init(
        wrapped: ChunkStorageRetrieval,
        algorithm: CompressionAlgorithm = .zlib
    ) {
        self.wrapped = wrapped
        self.algorithm = algorithm
    }
    
    public func readChunk(at path: String) async throws -> Data? {
        guard let compressedData = try await wrapped.readChunk(at: path) else {
            return nil
        }
        return try compressedData.decompressed(using: algorithm)
    }
    
    public func writeChunk(
        _ data: Data,
        at path: String,
        metadata: ChunkMetadata?
    ) async throws {
        let compressedData = try data.compressed(using: algorithm)
        try await wrapped.writeChunk(compressedData, at: path, metadata: metadata)
    }
    
    public func chunkExists(at path: String) async -> Bool {
        return await wrapped.chunkExists(at: path)
    }
    
    public func deleteChunk(at path: String) async throws {
        try await wrapped.deleteChunk(at: path)
    }
}

/// Caching wrapper for chunk retrieval
public struct CachedRetrieval: ChunkStorageRetrieval {
    private let wrapped: ChunkStorageRetrieval
    private var cache: [String: Data] = [:]
    private let cacheLock = NSLock()
    
    public init(wrapped: ChunkStorageRetrieval) {
        self.wrapped = wrapped
    }
    
    public func readChunk(at path: String) async throws -> Data? {
        // Check cache first
        cacheLock.lock()
        defer { cacheLock.unlock() }
        
        if let cached = cache[path] {
            return cached
        }
        
        // Read from wrapped storage
        guard let data = try await wrapped.readChunk(at: path) else {
            return nil
        }
        
        // Cache it
        cache[path] = data
        return data
    }
    
    public func writeChunk(
        _ data: Data,
        at path: String,
        metadata: ChunkMetadata?
    ) async throws {
        // Write to wrapped storage
        try await wrapped.writeChunk(data, at: path, metadata: metadata)
        
        // Update cache
        cacheLock.lock()
        defer { cacheLock.unlock() }
        cache[path] = data
    }
    
    public func chunkExists(at path: String) async -> Bool {
        return await wrapped.chunkExists(at: path)
    }
    
    public func deleteChunk(at path: String) async throws {
        try await wrapped.deleteChunk(at: path)
        
        // Remove from cache
        cacheLock.lock()
        defer { cacheLock.unlock() }
        cache.removeValue(forKey: path)
    }
}
```

### Composing Custom Storage

Combine custom components:

```swift
// Create custom organization
let cloudKitOrg = CloudKitOrganization()

// Create base retrieval
let baseRetrieval = CloudKitRetrieval(
    container: container,
    database: database,
    organization: cloudKitOrg
)

// Wrap with compression
let compressedRetrieval = CompressedRetrieval(
    wrapped: baseRetrieval,
    algorithm: .zlib
)

// Wrap with caching
let cachedRetrieval = CachedRetrieval(wrapped: compressedRetrieval)

// Create existence checker
let existence = CloudKitExistence(
    container: container,
    database: database,
    organization: cloudKitOrg
)

// Compose into complete storage
let storage = CloudKitChunkStorage(
    container: container,
    database: database,
    organization: cloudKitOrg,
    retrieval: cachedRetrieval,
    existence: existence
)
```

## Complete Example: iCloud Drive Storage

```swift
import Foundation
import FileSystemKit

/// iCloud Drive chunk storage using composable architecture
public struct iCloudDriveChunkStorage: ChunkStorageComposable {
    public let organization: ChunkStorageOrganization
    public let retrieval: ChunkStorageRetrieval
    public let existence: ChunkStorageExistence?
    
    public var export: ChunkStorageExport? { nil }
    public var `import`: ChunkStorageImport? { nil }
    public var sharing: ChunkStorageSharing? { nil }
    
    private let baseURL: URL
    
    public init(containerID: String) throws {
        guard let containerURL = FileManager.default.url(
            forUbiquityContainerIdentifier: containerID
        ) else {
            throw ChunkStorageError.storageUnavailable(
                reason: "iCloud Drive container not available"
            )
        }
        
        self.baseURL = containerURL.appendingPathComponent("ChunkStorage")
        
        // Ensure directory exists
        try FileManager.default.createDirectory(
            at: baseURL,
            withIntermediateDirectories: true
        )
        
        // Use Git-style organization for iCloud Drive
        self.organization = GitStyleOrganization(directoryDepth: 2)
        
        // Use file system retrieval (iCloud Drive is a file system)
        self.retrieval = FileSystemRetrieval(baseURL: baseURL)
        
        // Use file system existence checking
        self.existence = FileSystemExistence(
            organization: organization,
            baseURL: baseURL
        )
    }
}

// Usage
let storage = try iCloudDriveChunkStorage(
    containerID: "iCloud.com.example.app"
)

let identifier = ChunkIdentifier(id: "a1b2c3d4...")
try await storage.writeChunk(data, identifier: identifier, metadata: metadata)
let exists = try await storage.chunkExists(identifier)
let readData = try await storage.readChunk(identifier)
```

## Best Practices

1. **Choose the Right Organization Strategy**
   - Use `GitStyleOrganization` for large collections (>10,000 chunks)
   - Use `FlatOrganization` for small collections (<10,000 chunks)
   - Implement custom organization for specialized backends (CloudKit, S3, etc.)

2. **Wrap Retrieval for Cross-Cutting Concerns**
   - Use decorator pattern for compression, caching, encryption
   - Keep wrappers focused on single responsibility
   - Compose multiple wrappers for complex behavior

3. **Implement Existence Checking**
   - Provides optimized existence checks
   - More efficient than reading chunk data
   - Essential for large storage backends

4. **Handle Errors Gracefully**
   - Return `nil` for missing chunks (not errors)
   - Throw errors for actual failures
   - Provide meaningful error messages

5. **Test Your Implementation**
   - Use `FileSystemRetrieval` for unit tests
   - Test with both `GitStyleOrganization` and `FlatOrganization`
   - Verify error handling and edge cases

## Migration from Old ChunkStorage

If you have existing `ChunkStorage` implementations:

```swift
// Old implementation
public struct MyOldStorage: ChunkStorage {
    // ... implementation
}

// New composable implementation
public struct MyNewStorage: ChunkStorageComposable {
    public let organization: ChunkStorageOrganization
    public let retrieval: ChunkStorageRetrieval
    public let existence: ChunkStorageExistence?
    
    // Extract organization logic into ChunkStorageOrganization
    // Extract read/write logic into ChunkStorageRetrieval
    // Extract existence checks into ChunkStorageExistence
}
```

## See Also

- ``ChunkStorageComposable`` - Composable storage protocol
- ``ChunkStorageOrganization`` - Organization protocol
- ``ChunkStorageRetrieval`` - Retrieval protocol
- ``ChunkStorageExistence`` - Existence checking protocol
- ``ComposableFileSystemChunkStorage`` - Default file system implementation
- ``GitStyleOrganization`` - Git-style organization strategy
- ``FlatOrganization`` - Flat organization strategy

