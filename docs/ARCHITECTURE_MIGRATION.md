# Architecture Migration: FileSystemKit Foundation

## Overview

FileSystemKit serves as the foundation for file system operations, providing core protocols and base implementations. RetroboxFS extends FileSystemKit to add support for vintage file systems and disk images (pre-2000).

## Architecture Hierarchy

```
FileSystemKit (Foundation)
├── Core Protocols
│   ├── ChunkStorage (base protocol)
│   ├── ChunkIdentifier, ChunkMetadata
│   ├── FileSystemComponent, FileSystemEntry, FileSystemFolder
│   ├── FileSystemStrategy (base protocol)
│   └── RawDiskData, DiskImageHash, DiskImageMetadata
├── Core Implementations
│   ├── FileSystemChunkStorage (concrete implementation)
│   ├── Chunk (builder pattern for lazy loading)
│   └── ChunkStorageProvider (custom storage backends)
└── Modern File Systems (post-2000)
    ├── ISO9660
    ├── DMG
    └── [Future: NTFS, exFAT, etc.]

RetroboxFS (Vintage Extension)
├── Extends FileSystemKit Protocols
│   ├── FSDigitalAssetProvider: ChunkStorage (adds identifier)
│   └── MetadataStorage (vintage disk image metadata)
├── Vintage File Systems (pre-2000)
│   ├── Apple II (DOS 3.3, ProDOS)
│   ├── Commodore 64 (1541, 1581)
│   └── [Other vintage formats]
└── Vintage Disk Image Adapters
    ├── D64, D81 (Commodore)
    ├── NIB, HDV, 2MG (Apple II)
    └── [Other vintage formats]

Retrobox (Client Application)
└── Implements RetroboxFS Protocols
    ├── CloudKitDigitalAssetProvider: FSDigitalAssetProvider
    ├── iCloudDriveDigitalAssetProvider: FSDigitalAssetProvider
    └── Custom storage backends
```

## Migration Principles

### 1. FileSystemKit: Universal Foundation

**What belongs in FileSystemKit:**
- Core protocols (`ChunkStorage`, `FileSystemStrategy`)
- Base types (`ChunkIdentifier`, `ChunkMetadata`, `FileSystemComponent`)
- Concrete implementations (`FileSystemChunkStorage`, `Chunk`)
- Modern file systems (post-2000: ISO9660, DMG, NTFS, exFAT)
- Compression adapters (universal: Gzip, ZIP, TAR, etc.)

**Key Criterion**: If a technology is still used after 2000, it belongs in FileSystemKit.

### 2. RetroboxFS: Vintage Extension

**What belongs in RetroboxFS:**
- Protocols that extend FileSystemKit (`FSDigitalAssetProvider`, `MetadataStorage`)
- Vintage file systems (pre-2000: DOS 3.3, ProDOS, Commodore 1541, etc.)
- Vintage disk image adapters (D64, D81, NIB, HDV, 2MG, etc.)
- Vintage-specific metadata and search criteria

**Key Criterion**: If a technology is pre-2000 and no longer in common use, it belongs in RetroboxFS.

### 3. Protocol Extension Pattern

```swift
// FileSystemKit: Base protocol
public protocol ChunkStorage: Sendable {
    func writeChunk(_ data: Data, identifier: ChunkIdentifier, metadata: ChunkMetadata?) async throws -> ChunkIdentifier
    // ... other methods
}

// RetroboxFS: Extends base protocol for vintage disk images
public protocol FSDigitalAssetProvider: FileSystemKit.ChunkStorage {
    var identifier: String { get }  // RetroboxFS-specific addition
}

// Retrobox (client): Implements extended protocol
public struct CloudKitDigitalAssetProvider: FSDigitalAssetProvider {
    public let identifier: String = "CloudKit"
    // ... implements ChunkStorage methods
}
```

## Migration Status

### ✅ Completed

1. **Core Types Moved to FileSystemKit:**
   - `ChunkStorage` protocol
   - `ChunkIdentifier`, `ChunkMetadata`
   - `FileSystemComponent`, `FileSystemEntry`, `FileSystemFolder`
   - `FileSystemStrategy` protocol
   - `RawDiskData`, `DiskImageHash`, `DiskImageMetadata`
   - `FileSystemError`

2. **Core Implementations Moved to FileSystemKit:**
   - `FileSystemChunkStorage` (concrete implementation)
   - `Chunk`, `ChunkBuilder`, `AccessPattern` (builder pattern)
   - `ChunkStorageProvider` (custom storage backends)

3. **RetroboxFS Updated:**
   - Uses type aliases to FileSystemKit types
   - `FSDigitalAssetProvider` extends `FileSystemKit.ChunkStorage`
   - `MetadataStorage` protocol for vintage disk images

### 🔄 In Progress

- Update all RetroboxFS code to use FileSystemKit types
- Ensure vintage-specific code remains in RetroboxFS
- Create documentation for protocol extension pattern

### 📋 Remaining

- Move modern file system strategies to FileSystemKit (if any exist)
- Ensure RetroboxFS vintage adapters work with FileSystemKit base types
- Update Retrobox project to use RetroboxFS protocols

## Usage Examples

### Client Implementation (Retrobox Project)

```swift
import RetroboxFS
import FileSystemKit

// Implement RetroboxFS protocol that extends FileSystemKit
public struct CloudKitDigitalAssetProvider: FSDigitalAssetProvider {
    public let identifier: String = "CloudKit"
    
    // Implement ChunkStorage methods (from FileSystemKit)
    public func writeChunk(_ data: Data, identifier: ChunkIdentifier, metadata: ChunkMetadata?) async throws -> ChunkIdentifier {
        // Store vintage disk image in CloudKit
    }
    
    public func readChunk(_ identifier: ChunkIdentifier) async throws -> Data? {
        // Read vintage disk image from CloudKit
    }
    
    // ... implement other ChunkStorage methods
}
```

### Using Base Types from FileSystemKit

```swift
import FileSystemKit

// Use FileSystemKit's base implementation for unit tests
let storage = FileSystemChunkStorage(baseURL: testDirectory)

// Use FileSystemKit's Chunk builder
let chunk = try await Chunk.builder()
    .identifier(chunkIdentifier)
    .storage(storage)
    .accessPattern(.magicNumber(maxBytes: 16))
    .build()
```

## Benefits

1. **Clear Separation**: Modern vs vintage file systems clearly separated
2. **Reusability**: FileSystemKit can be used independently for modern file systems
3. **Extensibility**: RetroboxFS extends FileSystemKit without modifying base code
4. **Client Flexibility**: Retrobox project implements RetroboxFS protocols, which extend FileSystemKit

## See Also

- `CUSTOM_STORAGE_PROVIDERS.md` - Guide for implementing custom storage backends
- `PERFORMANCE_SCALING_MILLIONS.md` - Performance optimization guide

