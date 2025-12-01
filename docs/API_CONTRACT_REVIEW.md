# FileSystemKit API Contract Review

**Date:** 2025-01-XX  
**Status:** Comprehensive Review Complete

## Executive Summary

FileSystemKit implements a facade pattern to provide a stable API contract while allowing internal implementations to evolve. This document provides a comprehensive review of the current API contract status, identifies public types and their purposes, and documents recommendations for maintaining API stability.

## 1. Contract Architecture

### 1.1 Archive Contract

**Location:** `Sources/FileSystemKit/Contracts/ArchiveContract.swift`

The `ArchiveContract` protocol defines the stable API for archive operations:

```swift
public protocol ArchiveContract: Sendable {
    func createArchive(from: URL, outputURL: URL, options: ArchiveOptions) async throws -> ArchiveResult
    func extractArchive(from: URL, to: URL, options: ExtractOptions) async throws -> ExtractResult
    func validateArchive(_ archiveURL: URL, options: ValidateOptions) async throws -> ValidationResult
    func listArchive(_ archiveURL: URL, options: ListOptions) async throws -> ArchiveListing
}
```

**Status:** ✅ Complete and stable

**Contract Types:**
- `ArchiveOptions` - Options for archive creation
- `ExtractOptions` - Options for archive extraction
- `ValidateOptions` - Options for archive validation
- `ListOptions` - Options for archive listing
- `ArchiveResult` - Result of archive creation
- `ExtractResult` - Result of archive extraction
- `ValidationResult` - Result of archive validation
- `ArchiveListing` - Archive file listing
- `ArchiveListingEntry` - Single entry in archive listing

### 1.2 Archive Facade

**Location:** `Sources/FileSystemKit/Contracts/ArchiveFacade.swift`

The `FileSystemKitArchiveFacade` struct implements `ArchiveContract` and delegates to internal implementations:

```swift
public struct FileSystemKitArchiveFacade: ArchiveContract {
    public init(storageURL: URL, hashAlgorithm: String = "sha256")
    // Implements all ArchiveContract methods
}
```

**Status:** ✅ Complete and stable

**Internal Delegates:**
- `SnugArchiver` (internal) - Archive creation
- `SnugExtractor` (internal) - Archive extraction
- `SnugValidator` (internal) - Archive validation
- `SnugParser` (public → should be internal) - Archive parsing

## 2. Public Type Classification

### 2.1 Contract Types (Stable API)

These types are part of the stable API contract and should not change without version bumps:

| Type | Location | Purpose | Status |
|------|----------|---------|--------|
| `ArchiveContract` | Contracts/ArchiveContract.swift | Protocol defining archive operations | ✅ Stable |
| `FileSystemKitArchiveFacade` | Contracts/ArchiveFacade.swift | Facade implementation | ✅ Stable |
| `ArchiveOptions` | Contracts/ArchiveContract.swift | Archive creation options | ✅ Stable |
| `ExtractOptions` | Contracts/ArchiveContract.swift | Extraction options | ✅ Stable |
| `ValidateOptions` | Contracts/ArchiveContract.swift | Validation options | ✅ Stable |
| `ListOptions` | Contracts/ArchiveContract.swift | Listing options | ✅ Stable |
| `ArchiveResult` | Contracts/ArchiveContract.swift | Archive creation result | ✅ Stable |
| `ExtractResult` | Contracts/ArchiveContract.swift | Extraction result | ✅ Stable |
| `ValidationResult` | Contracts/ArchiveContract.swift | Validation result | ✅ Stable |
| `ArchiveListing` | Contracts/ArchiveContract.swift | Archive listing | ✅ Stable |
| `ArchiveListingEntry` | Contracts/ArchiveContract.swift | Listing entry | ✅ Stable |

### 2.2 Core Utility Types (Public Utilities)

These types are public utilities that may be used by clients but are not part of the contract:

| Type | Location | Purpose | Status |
|------|----------|---------|--------|
| `FileSystemComponent` | Core/FileSystemComponent.swift | File system component protocol | ✅ Utility |
| `FileSystemFolder` | Core/FileSystemComponent.swift | Folder implementation | ✅ Utility |
| `File` | Core/FileSystemComponent.swift | File implementation | ✅ Utility |
| `FileLocation` | Core/FileSystemComponent.swift | File location metadata | ✅ Utility |
| `FileHash` | Core/FileSystemComponent.swift | File hash metadata | ✅ Utility |
| `FileSystemFormat` | Core/FileSystemFormat.swift | File system format enum | ✅ Utility |
| `FileSystemStrategy` | FileSystems/FileSystemStrategy.swift | File system strategy protocol | ✅ Utility |
| `RawDiskData` | Core/RawDiskData.swift | Raw disk data wrapper | ✅ Utility |
| `ChunkStorage` | Core/ChunkStorage.swift | Chunk storage protocol | ✅ Utility |
| `ChunkIdentifier` | Core/Chunk.swift | Chunk identifier | ✅ Utility |
| `DirectoryParser` | Core/DirectoryParser/DirectoryParser.swift | Directory parser utility | ✅ Utility |
| `FileSystemError` | Core/Errors.swift | Error types | ✅ Utility |
| `HashAlgorithm` | Core/HashAlgorithm.swift | Hash algorithm enum | ✅ Utility |
| `HashComputation` | Core/HashComputation.swift | Hash computation utility | ✅ Utility |
| `CompressionAdapter` | Compression/Core/CompressionAdapter.swift | Compression adapter protocol | ✅ Utility |
| `CompressionFormat` | Compression/Core/CompressionFormat.swift | Compression format enum | ✅ Utility |

### 2.3 SNUG-Specific Types (Public but Not Contract)

These types are public but specific to SNUG archive format. They may be used by clients but are not part of the stable contract:

| Type | Location | Purpose | Status | Recommendation |
|------|----------|---------|--------|----------------|
| `SnugParser` | Snug/SnugParser.swift | SNUG archive parser | ⚠️ Public | Should be internal |
| `SnugArchive` | Snug/SnugModels.swift | SNUG archive data model | ✅ Public | Keep public (used by contract) |
| `ArchiveEntry` | Snug/SnugModels.swift | Archive entry model | ✅ Public | Keep public (used by contract) |
| `HashDefinition` | Snug/SnugModels.swift | Hash definition model | ✅ Public | Keep public (used by contract) |
| `MetadataTemplate` | Snug/SnugModels.swift | Metadata template | ✅ Public | Keep public (used by contract) |
| `SnugError` | Snug/SnugError.swift | SNUG-specific errors | ✅ Public | Keep public (error types) |
| `SnugConfig` | Snug/SnugConfig.swift | SNUG configuration | ✅ Public | Keep public (CLI needs) |
| `SnugStorage` | Snug/SnugStorage.swift | SNUG storage utilities | ✅ Public | Keep public (CLI needs) |
| `SnugProgress` | Snug/SnugProgress.swift | Progress reporting | ✅ Public | Keep public (callbacks) |
| `SnugArchiveStats` | Snug/SnugArchiveStats.swift | Archive statistics | ✅ Public | Keep public (results) |
| `SnugIgnoreMatcher` | Snug/SnugIgnore.swift | Ignore pattern matcher | ✅ Public | Keep public (utilities) |
| `ChunkStorageProvider` | Snug/ChunkStorageProvider.swift | Chunk storage provider protocol | ✅ Public | Keep public (extensibility) |
| `SnugMirroredChunkStorage` | Snug/SnugMirroredStorage.swift | Mirrored storage | ✅ Public | Keep public (utilities) |

### 2.4 Internal Types (Correctly Hidden)

These types are correctly marked as internal:

| Type | Location | Purpose | Status |
|------|----------|---------|--------|
| `SnugArchiver` | Snug/SnugArchiver.swift | Archive creation implementation | ✅ Internal |
| `SnugExtractor` | Snug/SnugExtractor.swift | Archive extraction implementation | ✅ Internal |
| `SnugValidator` | Snug/SnugValidator.swift | Archive validation implementation | ✅ Internal |

## 3. Issues and Recommendations

### 3.1 Critical Issues

#### Issue 1: SnugParser is Public
**Severity:** Medium  
**Impact:** CLI commands directly use `SnugParser`, breaking encapsulation

**Current State:**
- `SnugParser` is public
- CLI commands (`InfoCommand`, `ListCommand`, `ExtractCommand`, `ValidateCommand`, `StorageCleanCommand`) use it directly
- Should be internal and accessed via facade

**Recommendation:**
1. Add `parseArchive` method to `ArchiveContract`
2. Implement in `FileSystemKitArchiveFacade`
3. Make `SnugParser` internal
4. Update CLI commands to use facade

**Status:** 🔄 In Progress

### 3.2 Recommendations

#### Recommendation 1: Document Public Types
**Priority:** High  
**Action:** Create public API documentation clearly separating:
- Contract types (stable, versioned)
- Utility types (public but may evolve)
- SNUG-specific types (public but format-specific)

**Status:** ✅ Complete (this document)

#### Recommendation 2: Add Parse Method to Contract
**Priority:** High  
**Action:** Add `parseArchive` method to `ArchiveContract` for archive inspection without extraction

**Status:** 🔄 In Progress

#### Recommendation 3: Version Contract Types
**Priority:** Medium  
**Action:** Consider versioning contract types (e.g., `ArchiveContractV1`, `ArchiveContractV2`) for future evolution

**Status:** 📋 Future Consideration

## 4. API Stability Guarantees

### 4.1 Contract Stability

**Guaranteed Stable:**
- `ArchiveContract` protocol and all its methods
- All contract types (`ArchiveOptions`, `ArchiveResult`, etc.)
- `FileSystemKitArchiveFacade` public interface

**May Evolve:**
- Internal implementations (`SnugArchiver`, `SnugExtractor`, `SnugValidator`)
- Utility types (may add features but maintain backward compatibility)
- SNUG-specific types (may evolve with format changes)

### 4.2 Versioning Strategy

**Current:** Single contract version  
**Future:** Consider versioned contracts for major changes

**Breaking Changes:**
- Require major version bump
- Must maintain backward compatibility for at least one major version
- Deprecation warnings before removal

## 5. Testing Strategy

### 5.1 Contract Tests

**Location:** `Tests/FileSystemKitTests/`

**Current State:**
- Tests use `@testable import` to access internal types
- Tests directly use `SnugArchiver`, `SnugExtractor`, `SnugValidator`
- This is acceptable for unit testing

**Recommendation:**
- Add integration tests using only public facade
- Keep unit tests using `@testable` for implementation testing

### 5.2 Contract Validation

**Required:**
- All contract methods must have tests
- Tests should validate contract behavior, not implementation
- Integration tests should use facade only

## 6. Migration Guide

### 6.1 For Clients Using SnugParser

**Before:**
```swift
let parser = SnugParser()
let archive = try parser.parseArchive(from: archiveURL)
```

**After:**
```swift
let facade = FileSystemKitArchiveFacade(storageURL: storageURL)
let listing = try await facade.listArchive(archiveURL, options: ListOptions(includeMetadata: true))
// Or use parseArchive method when added to contract
```

### 6.2 For Clients Using Internal Types

**Before:**
```swift
let archiver = try await SnugArchiver(storageURL: storageURL, hashAlgorithm: "sha256")
```

**After:**
```swift
let facade = FileSystemKitArchiveFacade(storageURL: storageURL, hashAlgorithm: "sha256")
let result = try await facade.createArchive(from: sourceURL, outputURL: outputURL, options: ArchiveOptions())
```

## 7. Conclusion

### 7.1 Current Status

✅ **Strengths:**
- Clear contract definition (`ArchiveContract`)
- Facade implementation (`FileSystemKitArchiveFacade`)
- Internal implementations properly hidden
- Comprehensive contract types

⚠️ **Areas for Improvement:**
- `SnugParser` should be internal
- CLI commands should use facade
- Need parse method in contract

### 7.2 Next Steps

1. ✅ Create comprehensive API contract review document
2. 🔄 Make `SnugParser` internal and update CLI
3. ✅ Document public types and their purposes
4. 📋 Add parse method to contract (if needed)
5. 📋 Create migration guide for clients

### 7.3 Long-Term Goals

- Maintain stable API contract
- Allow internal implementation evolution
- Provide clear migration paths
- Document all public APIs
- Version contracts for major changes

---

**Document Version:** 1.0  
**Last Updated:** 2025-01-XX  
**Next Review:** After SnugParser migration

