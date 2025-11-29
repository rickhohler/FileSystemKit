# FileSystemKit

## Badges

[![Codecov](https://codecov.io/gh/rickhohler/FileSystemKit/branch/main/graph/badge.svg)](https://codecov.io/gh/rickhohler/FileSystemKit)
[![GitHub Actions](https://github.com/rickhohler/FileSystemKit/workflows/Unit%20Tests/badge.svg)](https://github.com/rickhohler/FileSystemKit/actions/workflows/tests.yml)

A Swift package providing modern file system and disk image format support. FileSystemKit serves as the foundation for file system operations, handling modern formats (post-2000) and providing core types that can be extended by other packages like RetroboxFS for vintage file systems.

## Features

- **Modern File System Support**: ISO9660, FAT32, NTFS, exFAT, and more
- **Disk Image Formats**: DMG, ISO, VHD, IMG, and raw sector dumps
- **Compression Handling**: Transparent decompression of compressed disk images (.gz, .zip, .tar, .arc, .archiveorg)
- **Pipeline Architecture**: Extensible pipeline system for processing disk images
- **Core Types**: Foundation types for disk data, file systems, and metadata
- **File Extension Registry**: Centralized file extension management
- **Chunk Storage**: Efficient binary data storage abstraction
- **Metadata Storage**: Metadata storage abstraction for disk image information

## Architecture

FileSystemKit implements a three-layer architecture:

1. **Layer 1: Compression Wrapper Layer** - Handles compressed/archived disk images
2. **Layer 2: Modern Disk Image Format Layer** - Extracts raw disk data from modern formats
3. **Layer 3: File System Strategy Layer** - Parses file system structures

## Supported Formats

### Disk Image Formats (Layer 2)
- DMG (macOS disk images)
- ISO 9660 (CD-ROM/DVD-ROM images)
- VHD (Virtual Hard Disk)
- IMG/IMA (Raw disk images)
- Raw sector dumps

### Compression Formats (Layer 1)
- Gzip (.gz, .gzip)
- ZIP (.zip)
- TAR (.tar)
- ARC (.arc, .ark)
- Toast (.toast)
- StuffIt (.sit, .sitx)
- ShrinkIt (.shk, .sdk)
- Archive.org (.archiveorg) - Directory structures containing disk images

### File System Formats (Layer 3)
- ISO 9660 (CD-ROM/DVD-ROM file systems)
- FAT32 (Modern FAT32 support)
- NTFS (Future)
- exFAT (Future)

## Installation

### Swift Package Manager

Add FileSystemKit to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/rickhohler/FileSystemKit.git", from: "1.0.0")
]
```

Then add it to your target dependencies:

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "FileSystemKit", package: "FileSystemKit")
    ]
)
```

## Usage

### Basic Usage

```swift
import FileSystemKit

// Detect disk image format
let adapter = DiskImageAdapterRegistry.shared.findAdapter(forExtension: "dmg")
if let adapter = adapter {
    // Read disk image
    let chunkStorage = FileSystemChunkStorage(baseURL: tempDirectory)
    let identifier = ChunkIdentifier(id: "disk-image-id")
    let diskData = try await adapter.read(chunkStorage: chunkStorage, identifier: identifier)
    
    // Access disk data
    print("Disk size: \(diskData.totalSize) bytes")
    print("Sectors: \(diskData.sectors?.count ?? 0)")
}
```

### Compression Handling

```swift
import FileSystemKit

// Decompress a compressed disk image
let registry = CompressionAdapterRegistry.shared
if let adapter = registry.findAdapter(for: compressedURL) {
    let decompressedURL = try adapter.decompress(url: compressedURL)
    // Process decompressed disk image
}
```

### Pipeline Processing

```swift
import FileSystemKit

// Create a pipeline for processing disk images
let pipeline = PipelineFactory.createFileListingPipeline()
let context = PipelineContext(
    diskImageURL: diskImageURL,
    chunkStorage: chunkStorage,
    metadataStorage: metadataStorage
)

let result = try await pipeline.execute(context: context)
if case .fileListing(let listing) = result {
    print("Found \(listing.totalFiles) files")
}
```

### File Extension Registry

```swift
import FileSystemKit

// Register file extensions
let registry = await FileExtensionRegistry.shared
await registry.register(
    fileExtension: "dmg",
    type: "disk-image",
    category: "mac"
)

// Look up by extension
if let type = await registry.type(forExtension: "dmg") {
    print("Type: \(type)")
}
```

## Relationship to RetroboxFS

FileSystemKit provides the foundation for modern file system operations. RetroboxFS extends FileSystemKit to support vintage file systems (pre-2000) such as:

- Apple II (DOS 3.3, ProDOS)
- Commodore 64 (1541, 1581)
- Atari 8-bit
- MS-DOS/PC-DOS (FAT12/16)
- And more vintage formats

RetroboxFS depends on FileSystemKit and uses its core types, compression adapters, and pipeline architecture.

## Design Principles

1. **Modern First**: FileSystemKit focuses on formats still in use after 2000
2. **Extensible**: Core types and protocols designed for extension
3. **Type Safe**: Strong typing throughout the API
4. **Async/Await**: Modern Swift concurrency support
5. **Testable**: Comprehensive test coverage with mock implementations

## Requirements

- Swift 6.0+
- macOS 12.0+ / iOS 15.0+ / tvOS 15.0+ / watchOS 8.0+

## Contributing

Contributions are welcome! Please see our contributing guidelines for details.

## License

MIT License - see LICENSE file for details.

## Related Projects

- [RetroboxFS](https://github.com/rickhohler/RetroboxFS) - Vintage file system support built on FileSystemKit
- [InventoryKit](https://github.com/rickhohler/InventoryKit) - Digital asset inventory management

