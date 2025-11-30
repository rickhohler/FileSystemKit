# Concurrent File Processing Implementation Plan

## Current Bottlenecks

1. **Sequential File Processing**: Files are processed one at a time in a loop
2. **Synchronous I/O**: `Data(contentsOf:)` blocks threads
3. **Semaphore-based Async Wrapping**: Defeats the purpose of async/await
4. **No Batching**: Operations are not batched
5. **Memory Issues**: All file data loaded into memory at once

## Proposed Solution

### Architecture: Producer-Consumer Pattern with Bounded Concurrency

1. **Producer Phase**: Discover and queue files
2. **Consumer Phase**: Process files concurrently with TaskGroup
3. **Bounded Concurrency**: Limit concurrent operations to avoid overwhelming system
4. **Thread-Safe Accumulators**: Use actor/NSLock for result collection

### Implementation Steps

1. Create helper classes for thread-safe operations
2. Implement file discovery phase (producer)
3. Implement concurrent file processing (consumer)
4. Integrate with existing API

## Performance Improvements Expected

- **10-100x faster** for large directories (depending on CPU cores and I/O)
- **Better memory usage** through streaming for large files
- **Better CPU utilization** through parallel processing
- **Scalable** to millions of files

