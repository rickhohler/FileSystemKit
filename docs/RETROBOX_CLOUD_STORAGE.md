# Retrobox Cloud Storage Integration

## Overview

The Retrobox project uses Snug archives but implements custom storage providers to store chunks in cloud storage (CloudKit, iCloud Drive, etc.) instead of local file system storage.

## Architecture

```
Retrobox App
├── Implements ChunkStorageProvider
│   ├── CloudKitChunkStorageProvider
│   ├── iCloudDriveChunkStorageProvider
│   └── Custom storage backends
└── Uses SnugArchiver/SnugExtractor
    └── With custom ChunkStorageProvider
```

## Implementation Example

### 1. Create CloudKit Storage Provider

```swift
import Foundation
import CloudKit
import FileSystemKit

/// CloudKit-based chunk storage provider for Retrobox
public struct RetroboxCloudKitProvider: ChunkStorageProvider {
    public let identifier: String = "retrobox-cloudkit"
    public let displayName: String = "Retrobox CloudKit"
    public let requiresConfiguration: Bool = true
    
    private let container: CKContainer
    
    public init(container: CKContainer = .default()) {
        self.container = container
    }
    
    public func createChunkStorage(configuration: [String: Any]?) async throws -> any ChunkStorage {
        let database = container.privateCloudDatabase
        return RetroboxCloudKitChunkStorage(container: container, database: database)
    }
}

/// CloudKit implementation of ChunkStorage for Retrobox
public actor RetroboxCloudKitChunkStorage: ChunkStorage {
    private let container: CKContainer
    private let database: CKDatabase
    private let recordType = "RetroboxChunk"
    
    init(container: CKContainer, database: CKDatabase) {
        self.container = container
        self.database = database
    }
    
    // Implement all ChunkStorage methods...
    public func writeChunk(_ data: Data, identifier: ChunkIdentifier, metadata: ChunkMetadata?) async throws -> ChunkIdentifier {
        // Store chunk in CloudKit
        // ...
    }
    
    public func readChunk(_ identifier: ChunkIdentifier) async throws -> Data? {
        // Read chunk from CloudKit
        // ...
    }
    
    // ... other ChunkStorage methods
}
```

### 2. Register Provider and Use with SnugArchiver

```swift
import FileSystemKit

// Register the provider
await ChunkStorageProviderRegistry.shared.register(RetroboxCloudKitProvider())

// Create archiver with cloud storage
let archiver = try await SnugArchiver(
    providerIdentifier: "retrobox-cloudkit",
    storageConfiguration: nil,
    hashAlgorithm: "sha256"
)

// Use archiver normally - chunks will be stored in CloudKit
try await archiver.createArchive(from: sourceURL, to: archiveURL)
```

### 3. Use with SnugExtractor

```swift
// Register provider (if not already registered)
await ChunkStorageProviderRegistry.shared.register(RetroboxCloudKitProvider())

// Create extractor with cloud storage
let extractor = try await SnugExtractor(
    providerIdentifier: "retrobox-cloudkit",
    storageConfiguration: nil
)

// Extract archive - chunks will be read from CloudKit
try await extractor.extractArchive(from: archiveURL, to: outputURL, verbose: true)
```

## Integration with RetroboxFS

RetroboxFS extends FileSystemKit's `ChunkStorage` protocol:

```swift
import RetroboxFS
import FileSystemKit

/// RetroboxFS protocol that extends FileSystemKit.ChunkStorage
public protocol FSDigitalAssetProvider: FileSystemKit.ChunkStorage {
    var identifier: String { get }
}

/// Retrobox implementation using CloudKit
public struct RetroboxCloudKitDigitalAssetProvider: FSDigitalAssetProvider {
    public let identifier: String = "CloudKit"
    
    // Implement ChunkStorage methods (from FileSystemKit)
    // ...
}
```

## Benefits

1. **Cloud Storage**: Store Snug archive chunks in CloudKit, iCloud Drive, or other cloud services
2. **Automatic Sync**: Cloud storage providers handle sync across devices
3. **Scalability**: Cloud storage scales better than local file systems
4. **Backup**: Cloud storage provides built-in backup and redundancy
5. **Cross-Platform**: Access archives from multiple devices

## Differences from CLI Tool

| Feature | `snug` CLI Tool | Retrobox Project |
|---------|----------------|------------------|
| Storage | Local file system only | Custom cloud providers |
| Config | `SnugConfig` for storage locations | `ChunkStorageProvider` protocol |
| Usage | Command-line tool | Library integration |
| Provider Support | No (always file system) | Yes (CloudKit, iCloud Drive, etc.) |

## See Also

- `SNUG_CLOUD_STORAGE.md` - General cloud storage documentation
- `CUSTOM_STORAGE_PROVIDERS.md` - Guide for implementing custom storage providers
- `ChunkStorageProvider` protocol documentation
- `FSDigitalAssetProvider` protocol (RetroboxFS)

