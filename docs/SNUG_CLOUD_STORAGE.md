# Snug Archive Cloud Storage Support

## Overview

Snug archives support custom storage providers through the `ChunkStorageProvider` protocol, enabling cloud storage backends like CloudKit, iCloud Drive, S3, and others.

## Architecture Overview

- **`snug` CLI Tool**: Uses local file system storage and `SnugConfig` for storage locations. Always uses file system-based storage.
- **Retrobox Project**: Implements custom `ChunkStorageProvider` protocols to store chunks in cloud storage (CloudKit, iCloud Drive, etc.).

## Architecture

```
SnugArchiver
    └── ChunkStorage (protocol)
        ├── SnugFileSystemChunkStorage (default - file system)
        ├── CloudKitChunkStorage (client implementation)
        ├── iCloudDriveChunkStorage (client implementation)
        └── S3ChunkStorage (client implementation)
```

## Usage Methods

### CLI Tool (`snug` command)

The `snug` CLI tool **always uses local file system storage** and reads storage locations from `SnugConfig`:

```bash
# Uses ~/.snug or SNUG_STORAGE environment variable
snug archive /path/to/directory

# Uses specified storage directory
snug archive /path/to/directory --storage /custom/storage/path
```

The CLI tool does not support cloud storage providers. It uses `SnugFileSystemChunkStorage` exclusively.

### Method 1: Direct Provider Initialization (Retrobox Project)

```swift
import FileSystemKit

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

### Method 2: Registered Provider by Identifier (Retrobox Project)

```swift
import FileSystemKit

// Register custom provider
await ChunkStorageProviderRegistry.shared.register(CloudKitChunkStorageProvider())

// Create archiver using registered provider
let archiver = try await SnugArchiver(
    providerIdentifier: "cloudkit",
    storageConfiguration: ["containerID": "iCloud.com.example.app"],
    hashAlgorithm: "sha256"
)

// Use archiver normally
try await archiver.createArchive(from: sourceURL, to: archiveURL)
```

### Method 3: Configuration File (Retrobox Project)

**Note**: The `snug` CLI tool ignores `storageProviderIdentifier` in config and always uses file system storage.

For Retrobox project, configure storage provider in `~/.snug/config.yaml`:

```yaml
storageProviderIdentifier: "cloudkit"
storageProviderConfiguration:
  containerID: "iCloud.com.example.app"
  database: "private"
defaultHashAlgorithm: "sha256"
```

Then use the default initializer:

```swift
let archiver = try await SnugArchiver(
    storageURL: storageURL,  // Used as fallback if provider fails
    hashAlgorithm: "sha256"
)
// Automatically uses CloudKit provider from config
```

## Example: CloudKit Storage Provider

```swift
import Foundation
import CloudKit
import FileSystemKit

/// CloudKit-based chunk storage provider for Snug archives
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
        _ = try await database.save(record)
        
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

/// iCloud Drive-based chunk storage provider for Snug archives
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
        
        // Use SnugFileSystemChunkStorage with iCloud Drive URL
        return SnugFileSystemChunkStorage(baseURL: baseURL)
    }
}
```

## Configuration File Example

`~/.snug/config.yaml`:

```yaml
# Use CloudKit for storage
storageProviderIdentifier: "cloudkit"
storageProviderConfiguration:
  containerID: "iCloud.com.example.app"
  database: "private"

# Or use iCloud Drive
# storageProviderIdentifier: "iclouddrive"
# storageProviderConfiguration:
#   containerID: "iCloud.com.example.app"

# Default hash algorithm
defaultHashAlgorithm: "sha256"

# Storage locations (for file system fallback or mirroring)
storageLocations:
  - path: "~/.snug"
    volumeType: "primary"
    label: "Local Storage"
```

## SnugExtractor Support

`SnugExtractor` also supports custom storage providers:

```swift
// Using provider directly
let cloudKitProvider = CloudKitChunkStorageProvider()
let extractor = try await SnugExtractor(
    storageProvider: cloudKitProvider,
    storageConfiguration: nil
)

// Using registered provider
let extractor = try await SnugExtractor(
    providerIdentifier: "cloudkit",
    storageConfiguration: ["containerID": "iCloud.com.example.app"]
)

// Using config file (automatic)
let extractor = try await SnugExtractor(storageURL: storageURL)
```

## Benefits

1. **Cloud Storage**: Store Snug archives in CloudKit, iCloud Drive, S3, etc.
2. **Automatic Sync**: Cloud storage providers handle sync automatically
3. **Scalability**: Cloud storage scales better than local file systems
4. **Backup**: Cloud storage provides built-in backup and redundancy
5. **Cross-Platform**: Access archives from multiple devices

## See Also

- `CUSTOM_STORAGE_PROVIDERS.md` - Detailed guide for implementing custom storage providers
- `ChunkStorageProvider` protocol documentation
- `SnugArchiver` API reference

