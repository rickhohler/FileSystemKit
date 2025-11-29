# Changelog

All notable changes to FileSystemKit will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Future enhancements and features

### Fixed
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

## [1.0.0] - 2025-11-29

### Added
- **SNUG Archive Implementation**: Complete content-addressable archive system
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

## [1.0.0] - 2025-11-28

### Added
- **Public Project Setup**: Complete documentation and templates for public release
  - Security policy (SECURITY.md)
  - GitHub issue templates (bug reports, feature requests)
  - Pull request template
  - Enhanced README with quick start and examples
  - Improved contributing guidelines

### Added
- **Initial Release**: Foundation library for modern file system operations
- **Core Types**: `RawDiskData`, `DiskGeometry`, `SectorData`, `TrackData`, `FluxData`
- **Storage Protocols**: `ChunkStorage` and `MetadataStorage` abstractions
- **File System Components**: `File`, `FileSystemFolder`, `FileMetadata`, `FileLocation`
- **Compression Layer**: Support for Gzip, ZIP, TAR, ARC, Toast, StuffIt, ShrinkIt, Archive.org
- **Disk Image Adapters**: DMG, ISO9660, VHD, IMG, Raw sector dump support
- **File System Strategies**: ISO9660 file system parser
- **Pipeline Architecture**: Extensible pipeline system for processing disk images
- **File Extension Registry**: Centralized file extension management
- **File Type System**: Basic file type categorization
- **Hash Algorithms**: SHA-256, SHA-1, MD5, CRC32 support
- **Error Handling**: Comprehensive error types for file system operations
- **Test Suite**: 102 unit tests covering core functionality
- **GitHub Actions**: CI/CD workflow with code coverage reporting
- **Documentation**: README, CHANGELOG, CONTRIBUTING, CODE_OF_CONDUCT

