# FileSystemKit API Contract Design

## Overview

FileSystemKit's public API must be a **stable contract** that client applications can depend on. The internal implementation can evolve freely as long as:
1. The API contract remains stable
2. Comprehensive unit tests validate behavior
3. Backward compatibility is maintained

## Design Principles

### 1. API as Contract
- **Public APIs are contracts** - breaking changes require major version bumps
- **Internal implementation is free to evolve** - refactor, optimize, rewrite
- **Tests validate the contract** - not implementation details

### 2. Facade Pattern for Stability
- **Facades provide stable interfaces** - hide implementation complexity
- **Multiple implementations possible** - optimized, standard, experimental
- **Versioning support** - can provide v1, v2 facades simultaneously

### 3. Protocol-Oriented Design
- **Protocols define contracts** - not concrete types
- **Concrete types are internal** - clients depend on protocols
- **Easy to mock** - protocols enable testing

## API Contract Structure

### Core Contracts

#### 1. ArchiveContract
```swift
/// Stable contract for archive operations
/// Implementation can change, but this contract remains stable
public protocol ArchiveContract {
    /// Create archive from directory
    func createArchive(
        from sourceURL: URL,
        outputURL: URL,
        options: ArchiveOptions
    ) async throws -> ArchiveResult
    
    /// Extract archive to directory
    func extractArchive(
        from archiveURL: URL,
        to outputURL: URL,
        options: ExtractOptions
    ) async throws -> ExtractResult
    
    /// Validate archive integrity
    func validateArchive(
        _ archiveURL: URL,
        options: ValidateOptions
    ) async throws -> ValidationResult
    
    /// List archive contents
    func listArchive(
        _ archiveURL: URL,
        options: ListOptions
    ) async throws -> ArchiveListing
}

/// Options for archive operations (stable contract)
public struct ArchiveOptions: Sendable {
    public let hashAlgorithm: String
    public let verbose: Bool
    public let followSymlinks: Bool
    public let preserveSymlinks: Bool
    public let embedSystemFiles: Bool
    public let skipPermissionErrors: Bool
    
    public init(
        hashAlgorithm: String = "sha256",
        verbose: Bool = false,
        followSymlinks: Bool = false,
        preserveSymlinks: Bool = false,
        embedSystemFiles: Bool = false,
        skipPermissionErrors: Bool = false
    ) {
        self.hashAlgorithm = hashAlgorithm
        self.verbose = verbose
        self.followSymlinks = followSymlinks
        self.preserveSymlinks = preserveSymlinks
        self.embedSystemFiles = embedSystemFiles
        self.skipPermissionErrors = skipPermissionErrors
    }
}
```

#### 2. FileSystemContract
```swift
/// Stable contract for file system operations
public protocol FileSystemContract {
    /// Parse file system from disk image
    func parseFileSystem(
        from diskImageURL: URL,
        format: FileSystemFormat?
    ) async throws -> FileSystemStructure
    
    /// Read file content
    func readFile(
        _ file: FileReference,
        from diskImageURL: URL
    ) async throws -> Data
    
    /// List files in disk image
    func listFiles(
        in diskImageURL: URL,
        format: FileSystemFormat?
    ) async throws -> [FileInfo]
}
```

#### 3. PipelineContract
```swift
/// Stable contract for pipeline operations
public protocol PipelineContract {
    /// Execute pipeline on input
    func execute(
        pipeline: PipelineType,
        inputURL: URL,
        options: PipelineOptions
    ) async throws -> PipelineResult
    
    /// Register custom pipeline stage
    func registerStage(
        _ stage: PipelineStage,
        for pipeline: PipelineType
    )
}
```

## Implementation Strategy

### Phase 1: Define Contracts (Current)
1. Create protocol definitions for all public APIs
2. Define option structs and result types
3. Document contract guarantees

### Phase 2: Implement Facades
1. Create facade implementations that delegate to internal classes
2. Keep existing classes as internal implementations
3. Provide factory methods for creating facades

### Phase 3: Migrate Clients
1. Update client applications to use facades
2. Deprecate direct class access
3. Maintain backward compatibility during transition

### Phase 4: Evolve Implementation
1. Refactor internal implementations freely
2. Optimize performance without breaking contracts
3. Add new features through contract extensions

## Contract Guarantees

### ArchiveContract Guarantees
- **Idempotency**: Multiple calls with same inputs produce same results
- **Thread Safety**: Safe to call from multiple threads concurrently
- **Error Handling**: All errors are typed and documented
- **Progress Reporting**: Optional progress callbacks supported

### FileSystemContract Guarantees
- **Lazy Loading**: File content loaded only when requested
- **Metadata First**: File listings return metadata without loading content
- **Format Detection**: Automatic format detection with optional override
- **Error Recovery**: Graceful handling of corrupt/invalid formats

## Versioning Strategy

### Major Versions (Breaking Changes)
- Contract changes that break backward compatibility
- Removal of deprecated APIs
- Significant architectural changes

### Minor Versions (New Features)
- New contract methods (backward compatible)
- New options/parameters (with defaults)
- Performance improvements

### Patch Versions (Bug Fixes)
- Bug fixes within contract
- Performance optimizations
- Internal refactoring

## Testing Strategy

### Contract Tests
- **Test the contract, not implementation**
- Validate all contract guarantees
- Test error conditions
- Test edge cases

### Integration Tests
- Test facade → implementation → storage
- Test real-world scenarios
- Test performance characteristics

### Compatibility Tests
- Test backward compatibility
- Test version migration paths
- Test deprecated API behavior

## Example: ArchiveContract Implementation

```swift
// Public contract (stable)
public protocol ArchiveContract {
    func createArchive(
        from sourceURL: URL,
        outputURL: URL,
        options: ArchiveOptions
    ) async throws -> ArchiveResult
}

// Facade implementation (can change internally)
public struct FileSystemKitArchiveFacade: ArchiveContract {
    private let implementation: ArchiveImplementation
    
    public init(storageURL: URL, hashAlgorithm: String) async throws {
        // Can swap implementations here
        self.implementation = try await SnugArchiveImplementation(
            storageURL: storageURL,
            hashAlgorithm: hashAlgorithm
        )
    }
    
    public func createArchive(
        from sourceURL: URL,
        outputURL: URL,
        options: ArchiveOptions
    ) async throws -> ArchiveResult {
        // Delegate to implementation
        return try await implementation.createArchive(
            from: sourceURL,
            outputURL: outputURL,
            options: options
        )
    }
}

// Internal implementation (can evolve freely)
internal protocol ArchiveImplementation {
    func createArchive(
        from sourceURL: URL,
        outputURL: URL,
        options: ArchiveOptions
    ) async throws -> ArchiveResult
}

internal class SnugArchiveImplementation: ArchiveImplementation {
    private let archiver: SnugArchiver
    
    // Internal implementation can change
    func createArchive(...) async throws -> ArchiveResult {
        // Current implementation delegates to SnugArchiver
        // Future: Could use optimized implementation, different algorithm, etc.
    }
}
```

## Benefits

1. **Stability**: Clients depend on stable contracts
2. **Flexibility**: Implementation can evolve freely
3. **Testability**: Contracts are easy to mock and test
4. **Performance**: Can optimize without breaking clients
5. **Versioning**: Multiple contract versions supported

## Migration Path

1. **Add contracts alongside existing APIs** (non-breaking)
2. **Update documentation** to recommend contracts
3. **Deprecate direct class access** with migration guides
4. **Gradually migrate clients** to use contracts
5. **Eventually remove direct access** (major version bump)

## Conclusion

By treating APIs as contracts and using the Facade Pattern, FileSystemKit can:
- Provide stable interfaces for clients
- Evolve implementations freely
- Maintain backward compatibility
- Enable performance optimizations
- Support multiple implementation strategies

This approach ensures FileSystemKit remains a reliable foundation while continuing to improve internally.

