# FileSystemKit

## Badges

[![Codecov](https://codecov.io/gh/rickhohler/FileSystemKit/branch/main/graph/badge.svg)](https://codecov.io/gh/rickhohler/FileSystemKit)
[![GitHub Actions](https://github.com/rickhohler/FileSystemKit/workflows/Unit%20Tests/badge.svg)](https://github.com/rickhohler/FileSystemKit/actions/workflows/tests.yml)

A Swift package providing modern file system and disk image format support. FileSystemKit serves as the foundation for file system operations, handling modern formats (post-2000) and providing core types that can be extended by other packages for specialized file system support.

## Features

- **Modern File System Support**: ISO9660, FAT32, NTFS, exFAT, and more
- **Disk Image Formats**: DMG, ISO, VHD, IMG, and raw sector dumps
- **Compression Handling**: Transparent decompression of compressed disk images (.gz, .zip, .tar, .arc, .archiveorg)
- **Pipeline Architecture**: Extensible pipeline system for processing disk images
- **Core Types**: Foundation types for disk data, file systems, and metadata
- **File Extension Registry**: Centralized file extension management
- **Chunk Storage**: Efficient binary data storage abstraction
- **Metadata Storage**: Metadata storage abstraction for disk image information
- **Snug Archive Support**: Content-addressable archive format with metadata persistence
- **Multi-Storage Configuration**: Primary, secondary, glacier, and mirror storage volume types

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
- Snug (.snug) - Content-addressable archive format

### File System Formats (Layer 3)
- ISO 9660 (CD-ROM/DVD-ROM file systems)
- FAT32 (Modern FAT32 support)
- NTFS (Future)
- exFAT (Future)

## Roadmap

For information about future development plans, priorities, and milestones, see [ROADMAP.md](ROADMAP.md).

## Installation

### Swift Package Manager

Add FileSystemKit to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/rickhohler/FileSystemKit.git", from: "1.6.0")
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

## Extensibility

FileSystemKit is designed to be extended by other packages for specialized file system support. The core types, protocols, and architecture are all extensible:

- **Core Types**: `RawDiskData`, `DiskGeometry`, `FileSystemComponent`, `FileSystemEntry`, `FileSystemFolder` can be extended
- **Protocols**: `DiskImageAdapter`, `FileSystemStrategy`, `CompressionAdapter` can be implemented by other packages
- **Registries**: All registries support registration of custom adapters and strategies
- **Pipeline Architecture**: The pipeline system can be extended with custom stages

Other packages can depend on FileSystemKit and extend its functionality for specialized use cases.

## Design Principles

1. **Modern First**: FileSystemKit focuses on formats still in use after 2000
2. **Extensible**: Core types and protocols designed for extension
3. **Type Safe**: Strong typing throughout the API
4. **Async/Await**: Modern Swift concurrency support
5. **Testable**: Comprehensive test coverage with mock implementations

## Design Patterns

FileSystemKit uses [DesignAlgorithmsKit](https://github.com/rickhohler/DesignAlgorithmsKit) for common design patterns:

- **Registry Pattern**: All registries use `TypeRegistry` internally for type storage
- **Singleton Pattern**: Actor-based registries conform to `ActorSingleton` protocol  
- **Strategy Pattern**: `FileSystemStrategy` conforms to `Strategy` protocol

See [docs/REGISTRY_PATTERN.md](../docs/REGISTRY_PATTERN.md) for details.

## Requirements

- Swift 6.0+
- macOS 12.0+ / iOS 15.0+ / tvOS 15.0+ / watchOS 8.0+
- DesignAlgorithmsKit 1.0.3+

## Quick Start

```swift
import FileSystemKit

// Initialize FileSystemKit
// Compression adapters and disk image adapters are automatically registered

// Read a disk image
let url = URL(fileURLWithPath: "/path/to/image.dmg")
let adapter = DiskImageAdapterRegistry.shared.findAdapter(forExtension: "dmg")
if let adapter = adapter {
    let chunkStorage = FileSystemChunkStorage(baseURL: tempDirectory)
    let identifier = ChunkIdentifier(id: UUID().uuidString)
    let diskData = try await adapter.read(chunkStorage: chunkStorage, identifier: identifier)
    
    // Work with disk data
    print("Disk size: \(diskData.totalSize) bytes")
}
```

## Examples

### Reading a Compressed Disk Image

```swift
import FileSystemKit

let compressedURL = URL(fileURLWithPath: "/path/to/image.dmg.gz")

// Automatically detect and decompress
let registry = CompressionAdapterRegistry.shared
if let adapter = registry.findAdapter(for: compressedURL) {
    let decompressedURL = try adapter.decompress(url: compressedURL)
    // Process decompressed image
}
```

### Processing Files in a Disk Image

```swift
import FileSystemKit

// Create a file listing pipeline
let pipeline = PipelineFactory.createFileListingPipeline()
let context = PipelineContext(
    diskImageURL: diskImageURL,
    chunkStorage: chunkStorage,
    metadataStorage: metadataStorage
)

let result = try await pipeline.execute(context: context)
if case .fileListing(let listing) = result {
    for file in listing.files {
        print("\(file.path): \(file.size) bytes")
    }
}
```

### Working with File Systems

```swift
import FileSystemKit

// Detect file system format
let diskData: RawDiskData = // ... obtain disk data
if let format = FileSystemStrategyFactory.detectFormat(in: diskData) {
    print("Detected format: \(format)")
    
    // Create strategy and parse file system
    if let strategy = FileSystemStrategyFactory.createStrategy(for: format) {
        let rootFolder = try strategy.parse(diskData: diskData)
        // Navigate file system
        for fileEntry in rootFolder.getFiles() {
            print("File: \(fileEntry.name)")
            // Access file data via chunk if available
            if let chunk = try await fileEntry.toChunk(storage: chunkStorage) {
                let data = try await chunk.readFull()
                print("  Size: \(data.count) bytes")
            }
        }
    }
}
```

## Documentation

- **[Apple DocC Documentation](https://rickhohler.github.io/documentation/FileSystemKit/documentation/filesystemkit/)** - Complete API reference with interactive documentation for the latest release
- [API Documentation](https://github.com/rickhohler/FileSystemKit/wiki) - Detailed API reference (coming soon)
- [Architecture Guide](https://github.com/rickhohler/FileSystemKit/wiki/Architecture) - Understanding FileSystemKit's architecture
- [Contributing Guide](CONTRIBUTING.md) - How to contribute to FileSystemKit
- [Code of Conduct](CODE_OF_CONDUCT.md) - Community guidelines

## Contributing

**Note**: FileSystemKit is currently maintained internally and does not accept external code contributions or pull requests. However, we welcome and appreciate:

- **Bug reports** - Tracked via [GitHub Issues](https://github.com/rickhohler/FileSystemKit/issues)
- **Feature requests** - Tracked via [GitHub Issues](https://github.com/rickhohler/FileSystemKit/issues)
- **Documentation feedback** - Tracked via [GitHub Issues](https://github.com/rickhohler/FileSystemKit/issues)
- **Questions and discussions** - Tracked via [GitHub Issues](https://github.com/rickhohler/FileSystemKit/issues)

**All issues are tracked in GitHub Issues** - please use the [issue templates](https://github.com/rickhohler/FileSystemKit/issues/new/choose) when reporting bugs or requesting features.

While we don't accept pull requests, your feedback and bug reports are valuable and help improve FileSystemKit. Thank you for your interest and support!

## Security

For security vulnerabilities, please see our [Security Policy](SECURITY.md).

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Related Projects

- [InventoryKit](https://github.com/rickhohler/InventoryKit) - Digital asset inventory management

## Acknowledgments

FileSystemKit was created to provide a modern, extensible foundation for file system operations in Swift. Thank you to the open-source community for your feedback and support.

## Support

**All issues are tracked using GitHub Issues.** This is the primary system for:
- Bug reports
- Feature requests
- Questions and discussions
- Documentation improvements

- **Issues**: [GitHub Issues](https://github.com/rickhohler/FileSystemKit/issues) - Primary issue tracking system
- **Discussions**: [GitHub Discussions](https://github.com/rickhohler/FileSystemKit/discussions) - For general community discussions
- **Security**: See [SECURITY.md](SECURITY.md) for vulnerability reporting (use GitHub Security Advisories, not public issues)

### Reporting Issues

Before reporting an issue:
1. Search [existing issues](https://github.com/rickhohler/FileSystemKit/issues) to see if it's already reported
2. Use the appropriate [issue template](https://github.com/rickhohler/FileSystemKit/issues/new/choose)
3. Provide detailed information including Swift version, platform, and reproduction steps

