# Facade Pattern Design for FileSystemKit

## Overview

This document proposes implementing a Facade Pattern to encapsulate FileSystemKit's implementation details from client applications. This allows us to evolve the internal implementation without breaking client code.

## Problem Statement

Currently, client applications directly use concrete classes:
- `SnugArchiver`, `SnugExtractor`, `SnugValidator`
- `FileSystemStrategy` implementations
- `ChunkStorage` implementations
- Pipeline stages and factories

This tight coupling means:
- Internal refactoring requires updating all clients
- Implementation changes can break client code
- Difficult to add new features or optimize without client changes
- Hard to provide different implementations (e.g., optimized vs. standard)

## Solution: Facade Pattern

### Architecture

```
Client Applications (snug CLI, RetroboxFS, etc.)
         ↓
    Facade Layer (Public API)
         ↓
    Implementation Layer (Internal)
```

### Proposed Facades

#### 1. ArchiveFacade
Encapsulates archive operations (create, extract, validate, list)

```swift
public protocol ArchiveFacade {
    func createArchive(
        from sourceURL: URL,
        outputURL: URL,
        options: ArchiveOptions
    ) async throws -> ArchiveResult
    
    func extractArchive(
        from archiveURL: URL,
        to outputURL: URL,
        options: ExtractOptions
    ) async throws -> ExtractResult
    
    func validateArchive(
        _ archiveURL: URL,
        options: ValidateOptions
    ) async throws -> ValidationResult
    
    func listArchive(
        _ archiveURL: URL,
        options: ListOptions
    ) async throws -> ArchiveListing
}

public struct ArchiveOptions {
    let hashAlgorithm: String
    let verbose: Bool
    let followSymlinks: Bool
    let preserveSymlinks: Bool
    let embedSystemFiles: Bool
    // ... other options
}
```

#### 2. FileSystemFacade
Encapsulates file system operations (parse, read, write)

```swift
public protocol FileSystemFacade {
    func parseFileSystem(
        from diskImageURL: URL,
        format: FileSystemFormat?
    ) async throws -> FileSystemStructure
    
    func readFile(
        _ file: FileReference,
        from diskImageURL: URL
    ) async throws -> Data
    
    func listFiles(
        in diskImageURL: URL,
        format: FileSystemFormat?
    ) async throws -> [FileInfo]
}
```

#### 3. PipelineFacade
Encapsulates pipeline operations (execute, configure)

```swift
public protocol PipelineFacade {
    func execute(
        pipeline: PipelineType,
        inputURL: URL,
        options: PipelineOptions
    ) async throws -> PipelineResult
    
    func registerCustomStage(
        _ stage: PipelineStage,
        for pipeline: PipelineType
    )
}
```

### Benefits

1. **Stability**: Public API remains stable while internal implementation evolves
2. **Flexibility**: Can swap implementations (e.g., optimized vs. standard)
3. **Testability**: Easy to mock facades for testing
4. **Versioning**: Can provide multiple facade versions for backward compatibility
5. **Performance**: Can optimize internals without client changes

### Implementation Strategy

#### Phase 1: Create Facade Protocols
- Define facade protocols with stable APIs
- Keep existing concrete classes as internal implementations
- Create facade implementations that delegate to concrete classes

#### Phase 2: Migrate Clients
- Update client applications to use facades
- Provide deprecation warnings for direct class usage
- Maintain backward compatibility during transition

#### Phase 3: Optimize Internals
- Refactor internal implementations freely
- Add new features behind facade
- Optimize performance without breaking clients

### Example: ArchiveFacade Implementation

```swift
// Public facade
public struct FileSystemKitArchiveFacade: ArchiveFacade {
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
        return try await implementation.createArchive(
            from: sourceURL,
            outputURL: outputURL,
            options: options
        )
    }
}

// Internal implementation (can change freely)
internal protocol ArchiveImplementation {
    func createArchive(
        from sourceURL: URL,
        outputURL: URL,
        options: ArchiveOptions
    ) async throws -> ArchiveResult
}

internal class SnugArchiveImplementation: ArchiveImplementation {
    private let archiver: SnugArchiver
    
    // Internal implementation details can change
    func createArchive(...) async throws -> ArchiveResult {
        // Delegate to SnugArchiver
    }
}
```

### Migration Path

1. **Add facades alongside existing APIs** (non-breaking)
2. **Update documentation** to recommend facades
3. **Deprecate direct class usage** with migration guides
4. **Gradually migrate clients** to use facades
5. **Eventually remove direct access** (major version bump)

### Considerations

- **Performance**: Facade adds one indirection layer (minimal overhead)
- **Complexity**: Additional abstraction layer (but improves maintainability)
- **Backward Compatibility**: Keep existing APIs during transition period
- **Testing**: Facades make testing easier (can mock entire facade)

## Recommendation

**Yes, implement Facade Pattern** for the following reasons:

1. **FileSystemKit is a library** - stability is critical for clients
2. **Active development** - we're constantly improving internals
3. **Multiple clients** - snug CLI, RetroboxFS, future applications
4. **Performance optimization** - need flexibility to optimize without breaking changes
5. **Future-proofing** - allows adding new features cleanly

The Facade Pattern will provide the stability and flexibility needed for a production-ready library while allowing internal improvements to continue.

