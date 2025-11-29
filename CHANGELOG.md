# Changelog

All notable changes to FileSystemKit will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed
- **GitHub Actions**: Fixed CI workflow issues
  - Changed Swift tools version from 6.2 to 6.0 to match CI environment
  - Improved test binary discovery with multiple fallback patterns
  - Enhanced coverage data finding logic with better error handling
  - Added debugging output for troubleshooting

### Added
- Future enhancements and features

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

