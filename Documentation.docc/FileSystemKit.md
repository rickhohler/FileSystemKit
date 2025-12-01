# FileSystemKit

A comprehensive Swift library providing modern file system and disk image format support with content-addressable archive capabilities.

## Overview

FileSystemKit is a foundational Swift package designed to handle modern file systems (post-2000) and disk image formats. It serves as the core infrastructure for file system operations, providing extensible protocols and implementations that can be extended by other packages for specialized support (such as vintage file systems).

### Purpose

FileSystemKit addresses the need for a modern, type-safe, and extensible foundation for working with:
- **Modern File Systems**: ISO 9660, FAT32, NTFS, exFAT, and other formats still in use today
- **Disk Image Formats**: DMG, ISO, VHD, IMG, and raw sector dumps
- **Content-Addressable Archives**: The Snug archive format for efficient, deduplicated storage
- **Compression**: Transparent handling of compressed disk images and archives

### Key Design Principles

1. **Modern First**: Focuses on formats still in active use (post-2000)
2. **Extensible Architecture**: Core protocols designed for extension by specialized packages
3. **Type Safety**: Strong typing throughout the API with Swift 6 concurrency support
4. **Metadata-First Parsing**: Fast parsing by loading metadata before content
5. **Content-Addressable Storage**: Efficient deduplication and integrity verification
6. **Stable API Contracts**: Facade pattern ensures stable public APIs

### Three-Layer Architecture

FileSystemKit implements a layered architecture that handles nested file structures:

```
┌─────────────────────────────────────────┐
│ Layer 1: Compression Wrapper           │
│ Handles: .gz, .zip, .tar, .arc, etc.   │
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│ Layer 2: Disk Image Format             │
│ Handles: DMG, ISO, VHD, IMG, etc.      │
│ Output: RawDiskData                     │
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│ Layer 3: File System Strategy          │
│ Handles: ISO9660, FAT32, NTFS, etc.    │
│ Output: FileSystemFolder hierarchy      │
└─────────────────────────────────────────┘
```

### Core Capabilities

#### Archive Operations
- Create content-addressable archives with deduplication
- Extract archives with permission preservation
- Validate archive integrity
- List archive contents without extraction

#### File System Operations
- Parse file system structures from disk images
- Access files and directories with metadata
- Read file content on-demand (lazy loading)
- Support for multiple file system formats

#### Storage Management
- Content-addressable chunk storage
- Multiple storage backends (file system, cloud, etc.)
- Efficient deduplication
- Metadata persistence

### Use Cases

FileSystemKit is ideal for:
- **Archive Management**: Creating and managing content-addressable archives
- **Disk Image Processing**: Reading and processing modern disk image formats
- **File System Analysis**: Parsing and analyzing file system structures
- **Storage Optimization**: Deduplication and efficient storage
- **Foundation for Specialized Packages**: Extending to support vintage formats

### Integration with Other Packages

FileSystemKit is designed to work with specialized packages:

- **RetroboxFS**: Extends FileSystemKit to add vintage file system support (Apple II, Commodore 64, etc.)
- **Custom Implementations**: Other packages can extend FileSystemKit's protocols for specialized needs

### Performance Characteristics

- **Fast Parsing**: Metadata-first approach enables parsing thousands of files quickly
- **Memory Efficient**: Lazy loading prevents loading entire disk images into memory
- **Deduplication**: Content-addressable storage eliminates duplicate files
- **Concurrent**: Built with Swift 6 concurrency for modern async/await support

## Topics

### Getting Started

- <doc:GettingStarted>
- <doc:Installation>
- <doc:QuickStart>

### Archive Operations

- <doc:CreatingArchives>
- <doc:ExtractingArchives>
- <doc:ArchiveValidation>
- <doc:ArchiveListing>

### Snug Archive Format

- <doc:SnugFormat>
- <doc:ContentAddressableStorage>
- <doc:ArchiveMetadata>

### API Reference

- ``ArchiveContract``
- ``FileSystemKitArchiveFacade``
- ``ArchiveOptions``
- ``ExtractOptions``
- ``ValidationResult``

## Additional Resources

### External Documentation
- [Content-Addressable Storage (Wikipedia)](https://en.wikipedia.org/wiki/Content-addressable_storage) - Overview of content-addressable storage systems
- [Data Deduplication (Wikipedia)](https://en.wikipedia.org/wiki/Data_deduplication) - Techniques for eliminating duplicate data
- [File System (Wikipedia)](https://en.wikipedia.org/wiki/File_system) - General file system concepts
- [Disk Image (Wikipedia)](https://en.wikipedia.org/wiki/Disk_image) - Disk image format overview

### Related Projects
- [RetroboxFS](https://github.com/rickhohler/RetroboxFS) - Extends FileSystemKit with vintage file system support
- [Project Repository](https://github.com/rickhohler/FileSystemKit) - Source code and issue tracking

### Documentation
- [Apple DocC Documentation](https://rickhohler.github.io/documentation/FileSystemKit/documentation/filesystemkit/) - Complete interactive API reference

