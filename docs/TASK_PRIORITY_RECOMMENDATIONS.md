# Task Priority (QoS) Recommendations

## Overview

While Swift concurrency automatically handles Quality of Service (QoS) classes, we can add explicit task priorities for critical operations to ensure optimal performance on Apple Silicon.

## Current State

- ✅ All operations use async/await
- ✅ No explicit task priorities set
- ✅ Swift concurrency handles QoS automatically

## Recommendations

### 1. User-Initiated Tasks (High Priority)

Use `.userInitiated` priority for operations that directly impact user experience:

**FileSystemKit:**
- `SnugArchiver.createArchive()` - User is waiting for archive creation
- `SnugExtractor.extractArchive()` - User is waiting for extraction
- `FileHashCache.computeHash()` - Critical for archive operations

**RetroboxFS:**
- `RetroboxFS.listFiles()` - User is viewing file list
- `RetroboxFS.extractFile()` - User is extracting a file
- `RetroboxFS.detectFormat()` - User is waiting for format detection

### 2. Utility Tasks (Background Priority)

Use `.utility` priority for long-running, non-critical operations:

**FileSystemKit:**
- Batch processing operations
- Background hash computation
- Cache maintenance

**RetroboxFS:**
- `RetroboxFS.processDirectory()` - Batch processing
- Background metadata extraction
- Tag resolution (non-blocking)

### 3. Implementation Example

```swift
// High-priority user operation
public func createArchive(...) async throws -> SnugArchiveStats {
    return try await Task(priority: .userInitiated) {
        // Archive creation logic
    }.value
}

// Background batch processing
public func processDirectory(...) async throws -> ProcessingResult {
    return try await Task(priority: .utility) {
        // Batch processing logic
    }.value
}
```

### 4. TaskGroup Priority

For concurrent operations, set priority on individual tasks:

```swift
await withTaskGroup(of: ResultType.self) { group in
    for item in items {
        group.addTask(priority: .userInitiated) {
            // Process item with high priority
        }
    }
}
```

## Benefits

1. **Performance Cores**: High-priority tasks directed to performance cores
2. **Efficiency Cores**: Background tasks use efficiency cores
3. **Better Responsiveness**: User-facing operations complete faster
4. **Battery Efficiency**: Background work doesn't compete with user tasks

## Implementation Priority

- **Low Priority**: Current automatic QoS is sufficient
- **Medium Priority**: Add explicit priorities if performance issues arise
- **High Priority**: Consider for user-facing operations if responsiveness is critical

## Conclusion

Explicit task priorities are optional but can improve performance for user-facing operations. The current implementation with automatic QoS is sufficient for most use cases.

