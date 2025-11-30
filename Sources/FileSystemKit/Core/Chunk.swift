// FileSystemKit Core Library
// Chunk Builder Pattern
//
// Represents a lazy-loaded binary chunk with a reference to underlying storage.
// Optimized to cache only what's needed in memory based on usage patterns.

import Foundation

/// Represents a lazy-loaded binary chunk with a reference to underlying storage
/// Optimized to cache only what's needed in memory based on usage patterns
///
/// **Design Pattern**: Builder Pattern for constructing chunks based on usage
/// **Memory Optimization**: Only loads required portions of the file into memory
///
/// ## Usage Examples
///
/// ```swift
/// // For magic number detection (only first 10 bytes)
/// let chunk = try await Chunk.builder()
///     .identifier(chunkIdentifier)
///     .storage(chunkStorage)
///     .accessPattern(.magicNumber(maxBytes: 10))
///     .build()
///
/// let magicBytes = chunk.cachedData // Only 10 bytes loaded
///
/// // For header reading (first 512 bytes)
/// let chunk = try await Chunk.builder()
///     .identifier(chunkIdentifier)
///     .storage(chunkStorage)
///     .accessPattern(.header(maxBytes: 512))
///     .build()
///
/// // For full file access
/// let chunk = try await Chunk.builder()
///     .identifier(chunkIdentifier)
///     .storage(chunkStorage)
///     .accessPattern(.full)
///     .build()
/// ```
public struct Chunk: Sendable {
    /// Reference to the underlying chunk storage
    public let storage: any ChunkStorage
    
    /// Identifier for this chunk
    public let identifier: ChunkIdentifier
    
    /// Access pattern that determines what's cached
    public let accessPattern: AccessPattern
    
    /// Cached data (only what's needed based on access pattern)
    private(set) var cachedData: Data?
    
    /// Total size of the chunk (from metadata)
    public let totalSize: Int
    
    /// Whether the full chunk is cached
    public var isFullyCached: Bool {
        guard let cached = cachedData else { return false }
        return cached.count >= totalSize
    }
    
    /// Current cached range
    public var cachedRange: Range<Int>? {
        guard let cached = cachedData else { return nil }
        return 0..<cached.count
    }
    
    init(
        storage: any ChunkStorage,
        identifier: ChunkIdentifier,
        accessPattern: AccessPattern,
        cachedData: Data?,
        totalSize: Int
    ) {
        self.storage = storage
        self.identifier = identifier
        self.accessPattern = accessPattern
        self.cachedData = cachedData
        self.totalSize = totalSize
    }
    
    // MARK: - Builder Pattern
    
    /// Create a new chunk builder
    public static func builder() -> ChunkBuilder {
        ChunkBuilder()
    }
    
    // MARK: - Data Access
    
    /// Get cached data (may be partial based on access pattern)
    public func getCachedData() -> Data? {
        return cachedData
    }
    
    /// Read data at a specific range (loads if not cached)
    public mutating func read(range: Range<Int>) async throws -> Data {
        // Check if range is already cached
        if let cached = cachedData,
           range.lowerBound >= 0,
           range.upperBound <= cached.count {
            return cached.subdata(in: range)
        }
        
        // Load the required range
        let length = range.upperBound - range.lowerBound
        guard let data = try await storage.readChunk(identifier, offset: range.lowerBound, length: length) else {
            throw ChunkError.readFailed
        }
        
        // Update cache based on access pattern
        updateCache(with: data, at: range.lowerBound)
        
        return data
    }
    
    /// Read full chunk (loads entire file if not cached)
    public mutating func readFull() async throws -> Data {
        if isFullyCached, let cached = cachedData {
            return cached
        }
        
        guard let data = try await storage.readChunk(identifier) else {
            throw ChunkError.readFailed
        }
        
        cachedData = data
        return data
    }
    
    /// Read magic number bytes (optimized for format detection)
    public mutating func readMagicNumber(maxBytes: Int = 16) async throws -> Data {
        let range = 0..<min(maxBytes, totalSize)
        return try await read(range: range)
    }
    
    /// Read header bytes (optimized for header parsing)
    public mutating func readHeader(maxBytes: Int = 512) async throws -> Data {
        let range = 0..<min(maxBytes, totalSize)
        return try await read(range: range)
    }
    
    /// Read tail bytes (for formats that store metadata at the end)
    public mutating func readTail(maxBytes: Int = 512) async throws -> Data {
        let tailBytes = min(maxBytes, totalSize)
        let start = max(0, totalSize - tailBytes)
        let range = start..<totalSize
        return try await read(range: range)
    }
    
    // MARK: - Cache Management
    
    /// Update cache with new data at offset
    private mutating func updateCache(with data: Data, at offset: Int) {
        guard let existing = cachedData else {
            cachedData = data
            return
        }
        
        // Merge with existing cache
        if offset == 0 {
            // Prepend or replace from start
            if data.count > existing.count {
                cachedData = data
            } else {
                // Merge: existing is larger, keep it
                cachedData = existing
            }
        } else if offset + data.count <= existing.count {
            // Data is within existing cache, no update needed
            return
        } else {
            // Extend cache
            var merged = existing
            let needed = offset + data.count - existing.count
            if needed > 0 {
                // Try to read the gap if possible, otherwise extend with zeros
                // For now, just extend existing cache
                if offset <= existing.count {
                    let newData = data.subdata(in: (existing.count - offset)..<data.count)
                    merged.append(newData)
                    cachedData = merged
                }
            }
        }
    }
    
    /// Clear cache (free memory)
    public mutating func clearCache() {
        cachedData = nil
    }
    
    /// Expand cache to include a range
    public mutating func expandCache(to range: Range<Int>) async throws {
        if let cached = cachedData,
           range.lowerBound >= 0,
           range.upperBound <= cached.count {
            return // Already cached
        }
        
        // Load the range
        _ = try await read(range: range)
    }
}

// MARK: - Access Pattern

/// Defines how a chunk should be accessed and cached
public enum AccessPattern: Sendable {
    /// Only load magic number bytes (for format detection)
    case magicNumber(maxBytes: Int)
    
    /// Load header bytes (for header parsing)
    case header(maxBytes: Int)
    
    /// Load tail bytes (for metadata at end of file)
    case tail(maxBytes: Int)
    
    /// Load specific range
    case range(Range<Int>)
    
    /// Load full chunk
    case full
    
    /// Custom access pattern (load on demand)
    case onDemand
    
    /// Initial bytes to load
    var initialBytes: Int? {
        switch self {
        case .magicNumber(let maxBytes):
            return maxBytes
        case .header(let maxBytes):
            return maxBytes
        case .tail:
            return nil // Tail requires knowing total size first
        case .range(let range):
            return range.upperBound - range.lowerBound
        case .full:
            return nil // Load all
        case .onDemand:
            return 0 // Load nothing initially
        }
    }
}

// MARK: - Chunk Builder

/// Builder for constructing Chunk instances with specific access patterns
public struct ChunkBuilder: Sendable {
    private var storage: (any ChunkStorage)?
    private var identifier: ChunkIdentifier?
    private var accessPattern: AccessPattern = .onDemand
    
    public init() {}
    
    /// Set the chunk storage
    public func storage(_ storage: any ChunkStorage) -> ChunkBuilder {
        var builder = self
        builder.storage = storage
        return builder
    }
    
    /// Set the chunk identifier
    public func identifier(_ identifier: ChunkIdentifier) -> ChunkBuilder {
        var builder = self
        builder.identifier = identifier
        return builder
    }
    
    /// Set access pattern for magic number detection
    public func accessPattern(_ pattern: AccessPattern) -> ChunkBuilder {
        var builder = self
        builder.accessPattern = pattern
        return builder
    }
    
    /// Convenience: Set magic number access pattern
    public func magicNumber(maxBytes: Int = 16) -> ChunkBuilder {
        accessPattern(.magicNumber(maxBytes: maxBytes))
    }
    
    /// Convenience: Set header access pattern
    public func header(maxBytes: Int = 512) -> ChunkBuilder {
        accessPattern(.header(maxBytes: maxBytes))
    }
    
    /// Convenience: Set tail access pattern
    public func tail(maxBytes: Int = 512) -> ChunkBuilder {
        accessPattern(.tail(maxBytes: maxBytes))
    }
    
    /// Convenience: Set range access pattern
    public func range(_ range: Range<Int>) -> ChunkBuilder {
        accessPattern(.range(range))
    }
    
    /// Convenience: Set full access pattern
    public func full() -> ChunkBuilder {
        accessPattern(.full)
    }
    
    /// Build the chunk (loads initial data based on access pattern)
    public func build() async throws -> Chunk {
        guard let storage = storage,
              let identifier = identifier else {
            throw ChunkError.invalidBuilder
        }
        
        // Get total size from metadata
        let totalSize = identifier.metadata?.size ?? 0
        
        // Load initial data based on access pattern
        var cachedData: Data?
        
        if case .range(let range) = accessPattern {
            // Load specific range
            let length = range.upperBound - range.lowerBound
            cachedData = try await storage.readChunk(identifier, offset: range.lowerBound, length: length)
        } else if let initialBytes = accessPattern.initialBytes, initialBytes > 0 {
            // Load initial bytes (for magicNumber, header patterns)
            cachedData = try await storage.readChunk(identifier, offset: 0, length: initialBytes)
        } else if case .full = accessPattern {
            // Load full chunk
            cachedData = try await storage.readChunk(identifier)
        } else if case .tail(let maxBytes) = accessPattern {
            // For tail, we need to know total size first
            // If we don't have it, we'll need to check metadata or read a small amount
            if totalSize > 0 {
                let start = max(0, totalSize - maxBytes)
                cachedData = try await storage.readChunk(identifier, offset: start, length: totalSize - start)
            }
        }
        
        return Chunk(
            storage: storage,
            identifier: identifier,
            accessPattern: accessPattern,
            cachedData: cachedData,
            totalSize: totalSize
        )
    }
}

// MARK: - Chunk Errors

public enum ChunkError: LocalizedError {
    case invalidBuilder
    case readFailed
    case invalidRange
    case storageUnavailable
    
    public var errorDescription: String? {
        switch self {
        case .invalidBuilder:
            return "Chunk builder is missing required parameters"
        case .readFailed:
            return "Failed to read chunk data"
        case .invalidRange:
            return "Invalid range specified"
        case .storageUnavailable:
            return "Chunk storage is not available"
        }
    }
}

