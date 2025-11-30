# Custom Storage Providers for FileSystemKit

## Overview

FileSystemKit allows clients to implement custom storage backends for Snug archives. This enables integration with cloud storage services (CloudKit, iCloud Drive, S3, etc.) while maintaining the same API.

## Architecture

```
SnugArchiver
    └── ChunkStorage (protocol)
        ├── SnugFileSystemChunkStorage (default - file system)
        ├── CloudKitChunkStorage (client implementation)
        ├── iCloudDriveChunkStorage (client implementation)
        └── S3ChunkStorage (client implementation)
```

## Protocol: ChunkStorageProvider

Clients implement `ChunkStorageProvider` to provide custom storage backends:

```swift
public protocol ChunkStorageProvider: Sendable {
    func createChunkStorage(configuration: [String: Any]?) async throws -> any ChunkStorage
    var identifier: String { get }
    var displayName: String { get }
    var requiresConfiguration: Bool { get }
}
```

## Default Implementation: FileSystemChunkStorageProvider

FileSystemKit provides a default file system-based storage provider for unit tests and local storage:

```swift
let provider = FileSystemChunkStorageProvider()
let storage = try await provider.createChunkStorage(configuration: [
    "baseURL": "/path/to/storage"
])
```

## Example: CloudKit Storage Provider

```swift
import Foundation
import CloudKit
import FileSystemKit

/// CloudKit-based chunk storage provider
public struct CloudKitChunkStorageProvider: ChunkStorageProvider {
    public let identifier: String = "cloudkit"
    public let displayName: String = "CloudKit"
    public let requiresConfiguration: Bool = true
    
    private let container: CKContainer
    
    public init(container: CKContainer = .default()) {
        self.container = container
    }
    
    public func createChunkStorage(configuration: [String: Any]?) async throws -> any ChunkStorage {
        let database = container.privateCloudDatabase
        return CloudKitChunkStorage(container: container, database: database)
    }
}

/// CloudKit implementation of ChunkStorage
public actor CloudKitChunkStorage: ChunkStorage {
    private let container: CKContainer
    private let database: CKDatabase
    private let recordType = "SnugChunk"
    
    init(container: CKContainer, database: CKDatabase) {
        self.container = container
        self.database = database
    }
    
    public func writeChunk(_ data: Data, identifier: ChunkIdentifier, metadata: ChunkMetadata?) async throws -> ChunkIdentifier {
        let recordID = CKRecord.ID(recordName: identifier.id)
        let record = CKRecord(recordType: recordType, recordID: recordID)
        
        // Store data as CKAsset
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try data.write(to: tempURL)
        record["data"] = CKAsset(fileURL: tempURL)
        
        // Store metadata
        if let metadata = metadata {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            record["metadata"] = try encoder.encode(metadata)
        }
        
        // Save record
        let savedRecord = try await database.save(record)
        
        // Clean up temp file
        try? FileManager.default.removeItem(at: tempURL)
        
        return identifier
    }
    
    public func readChunk(_ identifier: ChunkIdentifier) async throws -> Data? {
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
    
    public func readChunk(_ identifier: ChunkIdentifier, offset: Int, length: Int) async throws -> Data? {
        guard let fullData = try await readChunk(identifier) else {
            return nil
        }
        
        guard offset >= 0 && offset < fullData.count else {
            return nil
        }
        
        let endIndex = min(offset + length, fullData.count)
        return fullData.subdata(in: offset..<endIndex)
    }
    
    public func updateChunk(_ data: Data, identifier: ChunkIdentifier, metadata: ChunkMetadata?) async throws -> ChunkIdentifier {
        return try await writeChunk(data, identifier: identifier, metadata: metadata)
    }
    
    public func deleteChunk(_ identifier: ChunkIdentifier) async throws {
        let recordID = CKRecord.ID(recordName: identifier.id)
        try await database.deleteRecord(withID: recordID)
    }
    
    public func chunkExists(_ identifier: ChunkIdentifier) async throws -> Bool {
        let recordID = CKRecord.ID(recordName: identifier.id)
        do {
            _ = try await database.record(for: recordID)
            return true
        } catch {
            if let ckError = error as? CKError,
               ckError.code == .unknownItem {
                return false
            }
            throw error
        }
    }
    
    public func chunkSize(_ identifier: ChunkIdentifier) async throws -> Int? {
        guard let data = try await readChunk(identifier) else {
            return nil
        }
        return data.count
    }
    
    public func chunkHandle(_ identifier: ChunkIdentifier) async throws -> ChunkHandle? {
        // CloudKit doesn't support file handles, return nil
        return nil
    }
}
```

## Example: iCloud Drive Storage Provider

```swift
import Foundation
import FileSystemKit

/// iCloud Drive-based chunk storage provider
public struct iCloudDriveChunkStorageProvider: ChunkStorageProvider {
    public let identifier: String = "iclouddrive"
    public let displayName: String = "iCloud Drive"
    public let requiresConfiguration: Bool = true
    
    public init() {}
    
    public func createChunkStorage(configuration: [String: Any]?) async throws -> any ChunkStorage {
        guard let config = configuration,
              let containerID = config["containerID"] as? String else {
            throw SnugError.storageError("iCloud Drive storage requires containerID in configuration", nil)
        }
        
        let containerURL = FileManager.default.url(
            forUbiquityContainerIdentifier: containerID
        )
        
        guard let baseURL = containerURL?.appendingPathComponent("SnugStorage") else {
            throw SnugError.storageError("iCloud Drive container not available", nil)
        }
        
        // Ensure directory exists
        try FileManager.default.createDirectory(
            at: baseURL,
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        return SnugFileSystemChunkStorage(baseURL: baseURL)
    }
}
```

## Using Custom Storage Providers

### Option 1: Direct Provider Initialization

```swift
// Create custom provider
let cloudKitProvider = CloudKitChunkStorageProvider(container: .default())

// Create archiver with custom storage
let archiver = try await SnugArchiver(
    storageProvider: cloudKitProvider,
    storageConfiguration: nil,
    hashAlgorithm: "sha256"
)

// Use archiver normally
try await archiver.createArchive(from: sourceURL, to: archiveURL)
```

### Option 2: Register Provider and Use Identifier

```swift
// Register custom provider
await ChunkStorageProviderRegistry.shared.register(CloudKitChunkStorageProvider())

// Create storage using registered provider
let storage = try await SnugStorage.createChunkStorage(
    providerIdentifier: "cloudkit",
    configuration: nil
)

// Create archiver with custom storage
let archiver = SnugArchiver(
    chunkStorage: storage,
    hashAlgorithm: "sha256"
)
```

### Option 3: Use Default File System Storage

```swift
// Default file system storage (for unit tests)
let archiver = try SnugArchiver(
    storageURL: storageURL,
    hashAlgorithm: "sha256"
)
```

## Configuration Dictionary

The `configuration` parameter is a flexible dictionary that allows providers to accept custom parameters:

```swift
// CloudKit example
let config: [String: Any] = [
    "container": CKContainer.default(),
    "database": "private"
]

// iCloud Drive example
let config: [String: Any] = [
    "containerID": "iCloud.com.example.app",
    "subdirectory": "SnugStorage"
]

// S3 example
let config: [String: Any] = [
    "bucket": "my-snug-storage",
    "region": "us-east-1",
    "accessKey": "...",
    "secretKey": "..."
]
```

## Best Practices

1. **Thread Safety**: Ensure your `ChunkStorage` implementation is thread-safe (use `actor` or locks)

2. **Error Handling**: Provide meaningful error messages that help diagnose storage issues

3. **Deduplication**: Respect content-addressable storage - if a chunk with the same hash exists, return the existing identifier

4. **Partial Reads**: Implement `readChunk(_:offset:length:)` efficiently for large files

5. **Metadata**: Store metadata alongside chunks when possible for faster queries

6. **Testing**: Use `FileSystemChunkStorageProvider` for unit tests

## Unit Testing

Use the default file system provider for unit tests:

```swift
func testArchiveCreation() async throws {
    let tempDir = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
    
    let provider = FileSystemChunkStorageProvider()
    let storage = try await provider.createChunkStorage(configuration: [
        "baseURL": tempDir.path
    ])
    
    let archiver = SnugArchiver(
        chunkStorage: storage,
        hashAlgorithm: "sha256"
    )
    
    // Test archiver operations...
}
```

## Migration from Default Storage

To migrate from default file system storage to a custom provider:

```swift
// Old code (file system)
let archiver = try SnugArchiver(
    storageURL: storageURL,
    hashAlgorithm: "sha256"
)

// New code (custom provider)
let provider = CloudKitChunkStorageProvider()
let archiver = try await SnugArchiver(
    storageProvider: provider,
    storageConfiguration: nil,
    hashAlgorithm: "sha256"
)
```

## See Also

- `ChunkStorage` protocol documentation
- `SnugArchiver` API reference
- `SnugStorage` helper functions

