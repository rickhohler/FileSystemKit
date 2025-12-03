# Changelog

All notable changes to FileSystemKit will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Placeholder for future changes

## [1.7.0] - 2025-12-03

### Added
- **File Type Metadata**: Enhanced file type detection and metadata support
  - `FileTypeMetadata` for structured file type information
  - `FileTypeMetadataExamples` with comprehensive examples
  - Support for ambiguous file extensions and format detection
- **Vendor Protocol**: Vendor identification support
  - `VendorProtocol` for vendor identification
  - Integration with disk image adapters
- **Enhanced Disk Image Adapters**: Improved disk image handling
  - Enhanced `DiskImageAdapter` with vendor information support
  - Updated `DiskImageFormat` with additional formats
  - Enhanced `RawDiskData` with improved sector handling
- **Pipeline Enhancements**: Improved pipeline processing
  - Enhanced `Pipeline` with better error handling
  - Improved chunk storage provider integration
- **Documentation**: Comprehensive documentation additions
  - CHUNK_STORAGE_CLIENT_USAGE.md: Client usage guide
  - FILE_TYPE_METADATA.md: File type metadata guide
  - FILE_TYPE_METADATA_AMBIGUOUS_EXTENSIONS.md: Ambiguous extensions handling
  - FILE_TYPE_METADATA_DESIGN.md: Design documentation
  - VENDOR_PROTOCOL.md: Vendor protocol documentation
  - VENDOR_CLIENT_IMPLEMENTATION.md: Client implementation guide
  - VENDOR_USAGE_EXAMPLES.md: Usage examples

### Changed
- Enhanced `SnugConfig` and `SnugStorage` with improved configuration options
- Improved `ChunkStorageProvider` integration

## [1.6.0] - 2025-12-02

### Added
- **Composable Chunk Storage Architecture**: New composable protocols that extend the existing `ChunkStorage` protocol
  - `ChunkStorageOrganization` protocol for storage path organization strategies
  - `ChunkStorageRetrieval` protocol for read/write operations
  - `ChunkStorageExistence` protocol for efficient existence checks
  - `ChunkStorageComposable` protocol that composes the above protocols
  - `ChunkStorage+Default` extension providing convenience methods
- **Storage Organization Strategies**: Implementations for organizing chunk storage
  - `GitStyleOrganization` - Git-style hash-based directory structure (default, depth 1-4)
  - `FlatOrganization` - Flat directory structure with all chunks in single directory
- **File System Implementations**: Concrete implementations for local file system
  - `FileSystemRetrieval` - Local file system read/write operations with metadata support
  - `FileSystemExistence` - Optimized existence checks for file system
  - `ComposableFileSystemChunkStorage` - Complete file system-based chunk storage solution
- **Comprehensive Test Suite**: Unit tests for all new protocols and implementations
  - `GitStyleOrganizationTests` - Tests for Git-style organization strategy
  - `FlatOrganizationTests` - Tests for flat organization strategy
  - `ChunkStorageRetrievalTests` - Tests for retrieval operations
  - `ChunkStorageExistenceTests` - Tests for existence checks
  - `ComposableFileSystemChunkStorageBasicTests` - Basic initialization and organization tests
  - `ComposableFileSystemChunkStorageOperationsTests` - Read/write/update/delete operations tests

### Changed
- **Enhanced Architecture**: Added composable protocols alongside existing `ChunkStorage` protocol
  - New `ChunkStorageComposable` protocol extends `ChunkStorage` for composable architecture
  - New `ChunkStorageOrganization` protocol for configurable storage organization strategies
  - New `ChunkStorageRetrieval` protocol for composable read/write operations
  - New `ChunkStorageExistence` protocol for optimized existence checks
  - Existing `ChunkStorage` protocol and implementations remain unchanged and fully backward compatible

### Notes
- **Backward Compatibility**: All existing `ChunkStorage` implementations continue to work unchanged
- **Optional Migration**: Clients can optionally adopt the new composable architecture for enhanced flexibility
- **New Implementation**: `ComposableFileSystemChunkStorage` provides a new implementation option alongside existing `FileSystemChunkStorage`

## [1.5.2] - 2025-12-01

### Fixed
- Removed invalid `.documentation` product declaration from Package.swift (DocC is built into Swift and doesn't require a product declaration)

## [1.5.1] - 2025-12-01

### Added
- **Comprehensive DocC Documentation**: Enhanced documentation with detailed overviews and usage examples
  - Added comprehensive project overview to main documentation page
  - Added usage examples to all prominent types (ArchiveContract, ChunkStorage, FileSystemComponent, etc.)
  - Added Wikipedia references for key concepts (content-addressable storage, file systems, disk images, etc.)
  - Enhanced documentation for FileSystemEntry, FileSystemFolder, FileSystemEntryMetadata
  - Added documentation for RawDiskData, DiskGeometry, TrackData, SectorData, FluxData
  - Added documentation for FileSystemStrategy, FileSystemFormat, ChunkStorage types
  - Added comprehensive usage examples throughout the API
- **Documentation Improvements**: 
  - Enhanced main FileSystemKit.md with project purpose, architecture, and use cases
  - Added three-layer architecture diagram
  - Added performance characteristics section
  - Added integration information with RetroboxFS
  - Added external resources section with Wikipedia links

### Changed
- Updated GettingStarted.md to reference version 1.5.0

## [1.5.0] - 2025-12-01

### Added
- **DocC Documentation Support**: Added Swift DocC documentation generation
  - Created `Documentation.docc/` catalog with overview and getting started guide
  - Added `scripts/generate-docs.sh` for automated documentation generation
  - Documentation generated to `Documentation/` directory (gitignored)
- **API Protocol Extensions**: Added convenience methods via protocol extensions
  - `createArchive(from:outputURL:)` - Convenience method with default options
  - `extractArchive(from:to:)` - Convenience method with default options
  - `validateArchive(at:)` - Convenience method with default options
  - `contents(of:)` - Convenience method with default options
- **Type Conformance Enhancements**: Added protocol conformance to result types
  - `ArchiveResult`, `ExtractResult`, `ValidationResult` now conform to `CustomStringConvertible`
  - `ArchiveListing` and `ArchiveListingEntry` now conform to `CustomStringConvertible`
- **Static Convenience Properties**: Added static properties for common option configurations
  - `ArchiveOptions.default`, `.verbose`, `.minimal`
  - `ExtractOptions.default`, `.preservePermissions`, `.overwrite`
  - `ValidateOptions.default`, `.strict`, `.quick`
  - `ListOptions.default`, `.detailed`, `.summary`

### Changed
- **API Method Naming**: Improved method names to align with Apple API Design Guidelines
  - `listArchive(_:options:)` → `contents(of:options:)` (aligns with `FileManager.contentsOfDirectory(at:)`)
  - `parseArchive(_:)` → `loadMetadata(from:)` (clearer intent)
  - `validateArchive(_:options:)` → `validateArchive(at:options:)` (better parameter labeling)
- **Enhanced Documentation**: Comprehensive API documentation improvements
  - Added detailed error documentation specifying exact error types and conditions
  - Enhanced parameter and return type documentation
  - Added usage examples to all public methods
  - Improved documentation formatting and clarity
- **Discardable Results**: Added `@discardableResult` to `createArchive` and `extractArchive` methods

### Fixed
- Updated all internal implementations to use new method names
- Updated test files to use new API method names
- Fixed method call sites in `ArchiveFacade` implementation

## [1.4.0] - 2025-12-01

### Added
- **DirectoryParser Refactoring**: Broke out `DirectoryParser.swift` (658 lines) into 8 focused files
  - `DirectoryEntry.swift` - Entry struct and conversion methods
  - `DirectoryParserOptions.swift` - Configuration options
  - `DirectoryParserDelegate.swift` - Delegate protocol
  - `IgnoreMatcher.swift` - Ignore pattern matcher protocol
  - `DirectoryParserError.swift` - Error types
  - `DirectoryParser.swift` - Main parser implementation
  - `Helpers/EntryProcessor.swift` - Entry processing logic
  - `FileSystemBuilderDelegate.swift` - FileSystem builder delegate
- **DirectoryParser Test Refactoring**: Refactored `DirectoryParserTests.swift` (205 lines) into 6 focused test files
  - `DirectoryEntryTests.swift` - DirectoryEntry tests
  - `DirectoryParserOptionsTests.swift` - Options tests
  - `DirectoryParserBasicTests.swift` - Basic parsing tests
  - `DirectoryParserEdgeCaseTests.swift` - Edge cases (ignore patterns, hidden files, base path)
  - `DirectoryParserErrorTests.swift` - Error tests
  - `Helpers/DirectoryParserTestBase.swift` - Shared test base and helpers
- **Compression Adapter Test Refactoring**: Refactored `CompressionAdapterTests.swift` (370 lines) into 7 focused test files
- **SnugArchiver Test Refactoring**: Refactored `SnugArchiverTests.swift` (517 lines) into 5 focused test files
- **FileHashCache Test Refactoring**: Refactored `FileHashCacheTests.swift` (451 lines) into 6 focused test files
- **FileSystemComponent Test Refactoring**: Refactored `FileSystemComponentTests.swift` (306 lines) into 3 focused test files
- **RawDiskData Test Refactoring**: Refactored `RawDiskDataTests.swift` (349 lines) into 3 focused test files
- **SnugConfig Test Refactoring**: Refactored `SnugConfigTests.swift` (405 lines) into 4 focused test files
- **SnugMirroredStorage Test Refactoring**: Refactored `SnugMirroredStorageTests.swift` (332 lines) into 3 focused test files
- **DiskImageAdapter Test Refactoring**: Refactored `DiskImageAdapterTests.swift` (552 lines) into 7 focused test files

### Changed
- **Hash Computation Consolidation**: Unified hash computation implementations (Issue #130)
  - Created `FileSystemKit/Core/HashComputation.swift` as unified implementation
  - Migrated all call sites to use unified implementation
  - Removed ~200-300 lines of duplicate code
- **Compression Adapter Refactoring**: Broke out `CompressionAdapter.swift` (2,389 lines) into 15 focused files
  - Core types moved to `Core/` subdirectory
  - Individual adapters moved to `Adapters/` subdirectory
  - Shared LZW helpers moved to `Adapters/Helpers/`
- **SnugArchiver Refactoring**: Broke out `SnugArchiver.swift` (903 lines) into 5 focused files
  - `SnugArchiver.swift` - Main class with initialization and createArchive
  - `Processing/DirectoryProcessor.swift` - Directory traversal and file processing
  - `Utilities/ProgressReporter.swift` - Progress reporting
  - `Utilities/SnugHashComputation.swift` - Hash computation wrapper
  - `Utilities/CompressionHelpers.swift` - Compression utilities

### Fixed
- Fixed build issues with duplicate file names (`HashComputation.swift` → `SnugHashComputation.swift`)
- Fixed async context issues in `DirectoryProcessor` and `ArchiveFacade`
- Fixed test files to use `await` for async `createArchive` calls
- Fixed `ArchiveFacade` duplicate code and missing imports
- Fixed enumerator iteration in async contexts

## [1.3.2] - 2025-12-01

### Added
- **DirectoryParser Refactoring**: Broke out `DirectoryParser.swift` (658 lines) into 8 focused files
  - `DirectoryEntry.swift` - Entry struct and conversion methods
  - `DirectoryParserOptions.swift` - Configuration options
  - `DirectoryParserDelegate.swift` - Delegate protocol
  - `IgnoreMatcher.swift` - Ignore pattern matcher protocol
  - `DirectoryParserError.swift` - Error types
  - `DirectoryParser.swift` - Main parser implementation
  - `Helpers/EntryProcessor.swift` - Entry processing logic
  - `FileSystemBuilderDelegate.swift` - FileSystem builder delegate
- **DirectoryParser Test Refactoring**: Refactored `DirectoryParserTests.swift` (205 lines) into 6 focused test files
  - `DirectoryEntryTests.swift` - DirectoryEntry tests
  - `DirectoryParserOptionsTests.swift` - Options tests
  - `DirectoryParserBasicTests.swift` - Basic parsing tests
  - `DirectoryParserEdgeCaseTests.swift` - Edge cases (ignore patterns, hidden files, base path)
  - `DirectoryParserErrorTests.swift` - Error tests
  - `Helpers/DirectoryParserTestBase.swift` - Shared test base and helpers

### Changed
- **Hash Computation Consolidation**: Unified hash computation implementations (Issue #130)
  - Created `FileSystemKit/Core/HashComputation.swift` as unified implementation
  - Migrated all call sites to use unified implementation
  - Removed ~200-300 lines of duplicate code
- **Compression Adapter Refactoring**: Broke out `CompressionAdapter.swift` (2,389 lines) into 15 focused files
  - Core types moved to `Core/` subdirectory
  - Individual adapters moved to `Adapters/` subdirectory
  - Shared LZW helpers moved to `Adapters/Helpers/`
- **SnugArchiver Refactoring**: Broke out `SnugArchiver.swift` (903 lines) into 5 focused files
  - `SnugArchiver.swift` - Main class with initialization and createArchive
  - `Processing/DirectoryProcessor.swift` - Directory traversal and file processing
  - `Utilities/ProgressReporter.swift` - Progress reporting
  - `Utilities/SnugHashComputation.swift` - Hash computation wrapper
  - `Utilities/CompressionHelpers.swift` - Compression utilities

### Fixed
- Fixed build issues with duplicate file names (`HashComputation.swift` → `SnugHashComputation.swift`)
- Fixed async context issues in `DirectoryProcessor` and `ArchiveFacade`
- Fixed test files to use `await` for async `createArchive` calls
- Fixed `ArchiveFacade` duplicate code and missing imports

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


