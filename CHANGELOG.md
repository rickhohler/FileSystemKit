# Changelog

All notable changes to FileSystemKit will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.3.2] - 2025-12-01

### Added
- Added `chunkStorage` and `chunkIdentifier` fields to `PipelineContext` to support the new `readFile(_:chunkStorage:identifier:)` API
- These fields enable stages like `GrepStage` to use the non-deprecated file reading method

## [1.3.1] - 2025-12-01

### Fixed
- Fixed `FileTypeDetector` bounds checking for ISO9660 detection (32768 vs 32769)
- Added extension-based fallback for small files that can't be detected by magic numbers
- Fixed `SnugError` warnings: removed unused `path` parameter in `brokenSymlink` recovery suggestion
- Fixed `SnugError` exhaustive switch statement by adding missing `notADirectory` case

## [1.3.0] - 2025-11-30

### Changed
- Renamed `File` → `FileSystemEntry` to avoid naming conflicts
  - `File` class renamed to `FileSystemEntry` (represents files only)
  - `FileMetadata` struct renamed to `FileSystemEntryMetadata`
  - Added `chunkIdentifier` property to `FileSystemEntry` for chunk-based storage
  - Added `toChunk()` method to convert `FileSystemEntry` to `Chunk`
  - Made `FileLocation` optional in `FileSystemEntryMetadata` (not all entries have disk image location)
  - Updated `FileSystemStrategy` protocol to use `FileSystemEntry`
  - **Backward compatible**: Deprecated typealiases `File` and `FileMetadata` are still available
  - Clarified that `FileSystemEntry` represents files only; directories use `FileSystemFolder`

### Added
- **Core Types**: New reusable core types for common file system operations
  - `SpecialFileType`: Special file detection (block devices, character devices, sockets, FIFOs)
  - `DirectoryParser`: Reusable directory parsing with delegate pattern
  - `FileMetadataCollector`: File system metadata collection utilities
  - `PathUtilities`: Path manipulation utilities (normalize, relativePath, isSystemFile, isHidden)
  - `FileTypeDetector`: File type detection (DMG, ISO, VHD, etc.)
  - `FileCounter`: File counting utilities for directory trees
- **Tests**: Comprehensive test coverage for core types
  - `ChunkTests`: Tests for Chunk lazy loading and builder pattern (moved from RetroboxFS)
  - `DirectoryParserTests`: Tests for directory parsing
  - `FileCounterTests`: Tests for file counting
  - `FileMetadataTests`: Tests for metadata collection
  - `FileTypeDetectorTests`: Tests for file type detection
  - `PathUtilitiesTests`: Tests for path utilities
- **Documentation**: Comprehensive architecture analysis documents
  - `docs/CHUNK_VS_FILE_ANALYSIS.md`: Analysis of Chunk vs FileSystemEntry architecture
  - `docs/NAMING_PROPOSAL.md`: Naming proposal for File → FileSystemEntry
  - `docs/FILESYSTEMENTRY_DIRECTORY_CLARIFICATION.md`: Clarification of FileSystemEntry vs FileSystemFolder
  - `docs/FILESYSTEMENTRY_DATA_SOURCES.md`: Documentation on FileSystemEntry supporting physical files and data streams

### Fixed
- Fixed all compiler warnings and errors across all projects
- Fixed `FileSystemError` enum case usage throughout codebase
- Fixed Sendable conformance issues in test code
- Fixed path normalization to preserve leading slashes for absolute paths
- Fixed relative path calculation to resolve symlinks for accurate paths

## [1.2.2] - 2025-11-30

### Added
- **ROADMAP.md**: Comprehensive roadmap outlining future development plans
  - Organized by priority levels (High/Medium/Low)
  - Development milestones and phases
  - Code quality standards (>90% coverage requirement)
  - Versioning strategy and release cadence
  - 32 issues documented across priority levels

### Documentation
- Added roadmap reference to README.md

## [1.2.1] - 2025-01-15

### Fixed
- Fixed all compiler warnings in codebase
  - Removed unused 'path' variables in embeddedFiles loops
  - Added explanatory comment for deprecated CC_MD5 usage
  - Refactored ternary operators to if-else to resolve "will never be executed" warnings
  - Removed unused volumeURL variable in SnugConfig
  - Changed var config to let config where not mutated
- Fixed GitHub Actions build failure
  - Removed reference to unimplemented processDirectoryConcurrent method
  - Reverted to using existing processDirectory method

## [1.2.0] - 2025-01-15

### Added
- **File Hash Cache**: High-performance caching system for computed file hashes
  - Thread-safe actor-based cache implementation
  - LRU eviction policy with configurable maximum size (default: 10,000 entries)
  - Automatic cache validation (checks file modification time, size, and algorithm)
  - Optional disk persistence (saves to `.hashcache.json` in storage directory)
  - Transparent integration with `SnugArchiver` - automatically enabled by default
  - Significant performance improvements for high-volume file operations
  - 10-100x faster for directories with many unchanged files
  - Especially beneficial for incremental archives and repeated operations

- **Performance Infrastructure**: Foundation for concurrent file processing
  - `FileProcessingQueue.swift`: Producer-consumer queue pattern infrastructure
  - `ResultAccumulator`: Thread-safe result collection for concurrent operations
  - `ProgressCounter`: Thread-safe progress tracking
  - Prepared for future concurrent processing implementation

### Changed
- `SnugArchiver` now uses hash cache by default (can be disabled via `enableHashCache` parameter)
- Hash computation now checks cache before computing, significantly improving performance

### Documentation
- Added `HASH_CACHE_IMPLEMENTATION.md`: Comprehensive documentation of hash cache features
- Added `PERFORMANCE_IMPROVEMENTS.md`: Performance improvement plans and architecture
- Added `CONCURRENT_PROCESSING.md`: Concurrent processing implementation plan

## [1.1.1] - 2025-11-29

### Fixed
- Fixed metadata merging logic to prevent duplicate path entries
- Removed redundant `originalFilename` insertion in `originalPaths` during metadata merging
- Fixed GitHub Actions workflow to use `macos-latest` for better compatibility
- All compilation errors resolved
- All unit tests passing (172 tests, 0 failures)

### Changed
- Updated GitHub Actions runner from `macos-15` to `macos-latest` for compatibility

## [1.1.0] - 2025-11-29

### Added
- **Storage Volume Types**: Enhanced storage configuration with volume type classification
  - `StorageVolumeType` enum: `primary`, `secondary`, `glacier`, `mirror`
  - Default priority values based on volume type
  - Volume type-based storage location management
  - Resolves storage organization and redundancy needs

- **Metadata Persistence**: Comprehensive metadata storage for hash-named files
  - `.meta` JSON files stored alongside hash-named files
  - Tracks original filenames, paths, creation/modification timestamps
  - Metadata merging on deduplication (combines original paths, preserves earliest created date, latest modified date)
  - `readMetadata()` method for retrieving stored metadata
  - Automatic metadata file cleanup on chunk deletion

- **Glacier Storage Mirroring**: Automatic mirroring to glacier/backup volumes
  - Glacier volumes always mirrored during archive creation
  - Asynchronous mirroring that doesn't block operations
  - Graceful handling of glacier storage failures
  - Multiple glacier storage location support

- **Enhanced Configuration Management**: Improved storage configuration system
  - Volume type-based storage location organization
  - Priority-based storage selection
  - Configuration validation with detailed error reporting
  - Storage speed classification (very-fast, fast, medium, slow, very-slow, unknown)

- **Comprehensive Unit Tests**: Complete test coverage for new features
  - `SnugStorageTests`: Metadata persistence and merging tests
  - `SnugConfigTests`: Volume type and configuration management tests
  - `SnugMirroredStorageTests`: Glacier mirroring and multi-storage operation tests

### Changed
- **ChunkMetadata**: Extended with timestamp and path tracking
  - Added `originalPaths` array to track all locations where content appears
  - Added `created` and `modified` Date fields
  - Enhanced metadata merging logic for deduplication scenarios

- **SnugFileSystemChunkStorage**: Enhanced with metadata persistence
  - Automatic `.meta` file creation/updating on chunk writes
  - Metadata merging when same hash is written multiple times
  - Metadata cleanup on chunk deletion

- **SnugMirroredChunkStorage**: Enhanced with glacier storage support
  - Separate glacier storage array for backup/archival volumes
  - Glacier writes happen asynchronously and don't fail operations
  - Improved read fallback order (primary → mirror → glacier)

### Fixed
- **Configuration Validation**: Improved error handling and reporting
  - Better distinction between required and optional storage locations
  - Clearer error messages for missing or unwritable storage

## [1.0.0] - 2025-11-29

### Added
- **Snug Archive Implementation**: Complete content-addressable archive system
  - `SnugArchive`, `HashDefinition`, `MetadataTemplate`, `ArchiveEntry` data models
  - `SnugArchiver` for creating archives from directories
  - `SnugExtractor` for extracting archives
  - `SnugParser` for parsing archive YAML
  - `SnugValidator` for validating archive integrity
  - `SnugStorage` for managing content-addressable storage
  - `SnugCompressionAdapter` for handling .snug file compression
  - Support for SHA256, SHA1, and MD5 hash algorithms
  - YAML-based archive format with gzip compression
  - Deep nested directory structure support
  - Hash deduplication support

- **Public Project Setup**: Complete documentation and templates for public release
  - Security policy (SECURITY.md)
  - GitHub issue templates (bug reports, feature requests, questions)
  - Pull request template
  - Enhanced README with quick start and examples
  - Improved contributing guidelines
  - Code of Conduct

- **Initial Release**: Foundation library for modern file system operations
  - Core Types: `RawDiskData`, `DiskGeometry`, `SectorData`, `TrackData`, `FluxData`
  - Storage Protocols: `ChunkStorage` and `MetadataStorage` abstractions
  - File System Components: `File`, `FileSystemFolder`, `FileMetadata`, `FileLocation`
  - Compression Layer: Support for Gzip, ZIP, TAR, ARC, Toast, StuffIt, ShrinkIt, Archive.org
  - Disk Image Adapters: DMG, ISO9660, VHD, IMG, Raw sector dump support
  - File System Strategies: ISO9660 file system parser
  - Pipeline Architecture: Extensible pipeline system for processing disk images
  - File Extension Registry: Centralized file extension management
  - File Type System: Basic file type categorization
  - Hash Algorithms: SHA-256, SHA-1, MD5, CRC32 support
  - Error Handling: Comprehensive error types for file system operations
  - Test Suite: 102 unit tests covering core functionality
  - GitHub Actions: CI/CD workflow with code coverage reporting
  - Documentation: README, CHANGELOG, CONTRIBUTING, CODE_OF_CONDUCT

### Fixed
- **GitHub Actions**: Fixed CI workflow issues
  - Changed Swift tools version from 6.2 to 6.0 to match CI environment
  - Improved test binary discovery with multiple fallback patterns
  - Enhanced coverage data finding logic with better error handling
  - Added debugging output for troubleshooting

- **GZIP Compression/Decompression**: Fixed GZIP format handling
  - Corrected GZIP header parsing in `GzipCompressionAdapter.decompress`
  - Added proper GZIP header and footer creation in `compressGzip`
  - Fixed misaligned pointer issues in compression pipeline tests
  - Note: Currently uses LZMA algorithm instead of DEFLATE (limitation for MVP)

- **FileSystemStrategyFactory**: Implemented strategy instance creation
  - Added `createStrategy(for:diskData:)` method for creating strategy instances with disk data
  - Added automatic registration of ISO9660FileSystemStrategy
  - Added `ensureInitialized()` to guarantee default strategies are registered
  - Resolves GitHub issue #3

- **Test Resources**: Verified and confirmed test resource files
  - All required test resource files are present and working correctly
  - DMG, ISO9660, VHD, and IMG test files contain proper format signatures
  - All disk image adapter tests passing with test resources
  - Resolves GitHub issue #5


