// FileSystemKit - Batch Operations for Chunk Storage
// High-performance batch operations for millions of files

import Foundation

/// Batch operations extension for ChunkStorage
public extension ChunkStorage {
    /// Write multiple chunks in a batch
    /// - Parameters:
    ///   - chunks: Array of (data, identifier, metadata) tuples
    ///   - batchSize: Number of chunks to process concurrently (default: 100)
    /// - Returns: Array of chunk identifiers
    /// - Throws: Error if any write fails
    func writeChunksBatch(
        _ chunks: [(Data, ChunkIdentifier, ChunkMetadata?)],
        batchSize: Int = 100
    ) async throws -> [ChunkIdentifier] {
        var results: [ChunkIdentifier] = []
        results.reserveCapacity(chunks.count)
        
        // Process in batches to limit memory and concurrency
        for batch in chunks.chunked(into: batchSize) {
            try await withThrowingTaskGroup(of: ChunkIdentifier.self) { group in
                for (data, identifier, metadata) in batch {
                    group.addTask {
                        try await self.writeChunk(data, identifier: identifier, metadata: metadata)
                    }
                }
                
                var batchResults: [ChunkIdentifier] = []
                batchResults.reserveCapacity(batch.count)
                
                for try await result in group {
                    batchResults.append(result)
                }
                
                results.append(contentsOf: batchResults)
            }
        }
        
        return results
    }
    
    /// Read multiple chunks in a batch
    /// - Parameters:
    ///   - identifiers: Array of chunk identifiers to read
    ///   - batchSize: Number of chunks to process concurrently (default: 100)
    /// - Returns: Dictionary mapping identifiers to data (nil if not found)
    /// - Throws: Error if any read fails
    func readChunksBatch(
        _ identifiers: [ChunkIdentifier],
        batchSize: Int = 100
    ) async throws -> [ChunkIdentifier: Data?] {
        var results: [ChunkIdentifier: Data?] = [:]
        results.reserveCapacity(identifiers.count)
        
        // Process in batches
        for batch in identifiers.chunked(into: batchSize) {
            try await withThrowingTaskGroup(of: (ChunkIdentifier, Data?).self) { group in
                for identifier in batch {
                    group.addTask {
                        let data = try await self.readChunk(identifier)
                        return (identifier, data)
                    }
                }
                
                for try await (identifier, data) in group {
                    results[identifier] = data
                }
            }
        }
        
        return results
    }
    
    /// Check existence of multiple chunks in a batch
    /// - Parameters:
    ///   - identifiers: Array of chunk identifiers to check
    ///   - batchSize: Number of chunks to process concurrently (default: 100)
    /// - Returns: Dictionary mapping identifiers to existence boolean
    /// - Throws: Error if any check fails
    func chunkExistsBatch(
        _ identifiers: [ChunkIdentifier],
        batchSize: Int = 100
    ) async throws -> [ChunkIdentifier: Bool] {
        var results: [ChunkIdentifier: Bool] = [:]
        results.reserveCapacity(identifiers.count)
        
        // Process in batches
        for batch in identifiers.chunked(into: batchSize) {
            try await withThrowingTaskGroup(of: (ChunkIdentifier, Bool).self) { group in
                for identifier in batch {
                    group.addTask {
                        let exists = try await self.chunkExists(identifier)
                        return (identifier, exists)
                    }
                }
                
                for try await (identifier, exists) in group {
                    results[identifier] = exists
                }
            }
        }
        
        return results
    }
    
    /// Delete multiple chunks in a batch
    /// - Parameters:
    ///   - identifiers: Array of chunk identifiers to delete
    ///   - batchSize: Number of chunks to process concurrently (default: 100)
    /// - Throws: Error if any deletion fails
    func deleteChunksBatch(
        _ identifiers: [ChunkIdentifier],
        batchSize: Int = 100
    ) async throws {
        // Process in batches
        for batch in identifiers.chunked(into: batchSize) {
            try await withThrowingTaskGroup(of: Void.self) { group in
                for identifier in batch {
                    group.addTask {
                        try await self.deleteChunk(identifier)
                    }
                }
                
                try await group.waitForAll()
            }
        }
    }
}

/// Helper extension for chunking arrays
private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

