// FileSystemKit - Chunk Metadata Index
// Fast metadata lookups and queries for millions of files
// Uses file-based index (can be upgraded to SQLite later)

import Foundation

/// Metadata index for fast lookups and queries
/// Currently uses file-based storage, can be upgraded to SQLite for better performance
public actor ChunkMetadataIndex {
    private let indexURL: URL
    private var index: [String: ChunkMetadata] = [:]
    private var pathIndex: [String: Set<String>] = [:] // path -> Set of hashes
    private var sizeIndex: [Int: Set<String>] = [:] // size -> Set of hashes
    private var contentTypeIndex: [String: Set<String>] = [:] // contentType -> Set of hashes
    private var isLoaded = false
    
    /// Initialize metadata index
    /// - Parameter indexURL: URL where index file should be stored
    public init(indexURL: URL) {
        self.indexURL = indexURL
        
        // Load index asynchronously
        Task {
            await loadIndex()
        }
    }
    
    /// Get metadata for a chunk identifier
    /// - Parameter identifier: Chunk identifier
    /// - Returns: Metadata if found, nil otherwise
    public func getMetadata(for identifier: ChunkIdentifier) async -> ChunkMetadata? {
        await ensureLoaded()
        return index[identifier.id]
    }
    
    /// Get metadata for a hash
    /// - Parameter hash: Hash string
    /// - Returns: Metadata if found, nil otherwise
    public func getMetadata(for hash: String) async -> ChunkMetadata? {
        await ensureLoaded()
        return index[hash]
    }
    
    /// Query chunks by original path
    /// - Parameter path: Original file path
    /// - Returns: Array of chunk identifiers matching the path
    public func query(by path: String) async -> [ChunkIdentifier] {
        await ensureLoaded()
        guard let hashes = pathIndex[path] else {
            return []
        }
        return hashes.compactMap { hash in
            guard let metadata = index[hash] else {
                return nil
            }
            return ChunkIdentifier(id: hash, metadata: metadata)
        }
    }
    
    /// Query chunks by path prefix
    /// - Parameter pathPrefix: Path prefix to match
    /// - Returns: Array of chunk identifiers matching the prefix
    public func query(byPathPrefix pathPrefix: String) async -> [ChunkIdentifier] {
        await ensureLoaded()
        var results: [ChunkIdentifier] = []
        
        for (path, hashes) in pathIndex {
            if path.hasPrefix(pathPrefix) {
                for hash in hashes {
                    if let metadata = index[hash] {
                        results.append(ChunkIdentifier(id: hash, metadata: metadata))
                    }
                }
            }
        }
        
        return results
    }
    
    /// Query chunks by size range
    /// - Parameter range: Size range (inclusive)
    /// - Returns: Array of chunk identifiers within the size range
    public func query(bySize range: Range<Int>) async -> [ChunkIdentifier] {
        await ensureLoaded()
        var results: [ChunkIdentifier] = []
        
        for (size, hashes) in sizeIndex {
            if range.contains(size) {
                for hash in hashes {
                    if let metadata = index[hash] {
                        results.append(ChunkIdentifier(id: hash, metadata: metadata))
                    }
                }
            }
        }
        
        return results
    }
    
    /// Query chunks by content type
    /// - Parameter contentType: Content type/MIME type
    /// - Returns: Array of chunk identifiers with matching content type
    public func query(byContentType contentType: String) async -> [ChunkIdentifier] {
        await ensureLoaded()
        guard let hashes = contentTypeIndex[contentType] else {
            return []
        }
        return hashes.compactMap { hash in
            guard let metadata = index[hash] else {
                return nil
            }
            return ChunkIdentifier(id: hash, metadata: metadata)
        }
    }
    
    /// Add or update metadata in index
    /// - Parameters:
    ///   - identifier: Chunk identifier
    ///   - metadata: Chunk metadata
    public func addMetadata(_ identifier: ChunkIdentifier, metadata: ChunkMetadata) async {
        await ensureLoaded()
        
        let hash = identifier.id
        
        // Remove old entries from indexes
        if let oldMetadata = index[hash] {
            removeFromIndexes(hash: hash, metadata: oldMetadata)
        }
        
        // Add to main index
        index[hash] = metadata
        
        // Add to path index
        if let paths = metadata.originalPaths {
            for path in paths {
                if pathIndex[path] == nil {
                    pathIndex[path] = Set<String>()
                }
                pathIndex[path]?.insert(hash)
            }
        }
        
        // Add to size index
        if sizeIndex[metadata.size] == nil {
            sizeIndex[metadata.size] = Set<String>()
        }
        sizeIndex[metadata.size]?.insert(hash)
        
        // Add to content type index
        if let contentType = metadata.contentType {
            if contentTypeIndex[contentType] == nil {
                contentTypeIndex[contentType] = Set<String>()
            }
            contentTypeIndex[contentType]?.insert(hash)
        }
    }
    
    /// Remove metadata from index
    /// - Parameter identifier: Chunk identifier to remove
    public func removeMetadata(_ identifier: ChunkIdentifier) async {
        await ensureLoaded()
        
        let hash = identifier.id
        guard let metadata = index[hash] else {
            return
        }
        
        removeFromIndexes(hash: hash, metadata: metadata)
        index.removeValue(forKey: hash)
    }
    
    /// Save index to disk
    public func saveIndex() async throws {
        await ensureLoaded()
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        let indexData = try encoder.encode(index)
        try indexData.write(to: indexURL, options: [.atomic])
    }
    
    /// Load index from disk
    private func loadIndex() async {
        guard !isLoaded else {
            return
        }
        
        guard FileManager.default.fileExists(atPath: indexURL.path) else {
            isLoaded = true
            return
        }
        
        do {
            let indexData = try Data(contentsOf: indexURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let loadedIndex = try decoder.decode([String: ChunkMetadata].self, from: indexData)
            
            // Rebuild indexes
            for (hash, metadata) in loadedIndex {
                index[hash] = metadata
                
                // Rebuild path index
                if let paths = metadata.originalPaths {
                    for path in paths {
                        if pathIndex[path] == nil {
                            pathIndex[path] = Set<String>()
                        }
                        pathIndex[path]?.insert(hash)
                    }
                }
                
                // Rebuild size index
                if sizeIndex[metadata.size] == nil {
                    sizeIndex[metadata.size] = Set<String>()
                }
                sizeIndex[metadata.size]?.insert(hash)
                
                // Rebuild content type index
                if let contentType = metadata.contentType {
                    if contentTypeIndex[contentType] == nil {
                        contentTypeIndex[contentType] = Set<String>()
                    }
                    contentTypeIndex[contentType]?.insert(hash)
                }
            }
            
            isLoaded = true
        } catch {
            // If index file is corrupted, start fresh
            index.removeAll()
            pathIndex.removeAll()
            sizeIndex.removeAll()
            contentTypeIndex.removeAll()
            isLoaded = true
        }
    }
    
    /// Ensure index is loaded
    private func ensureLoaded() async {
        if !isLoaded {
            await loadIndex()
        }
    }
    
    /// Remove entry from all indexes
    private func removeFromIndexes(hash: String, metadata: ChunkMetadata) {
        // Remove from path index
        if let paths = metadata.originalPaths {
            for path in paths {
                pathIndex[path]?.remove(hash)
                if pathIndex[path]?.isEmpty == true {
                    pathIndex.removeValue(forKey: path)
                }
            }
        }
        
        // Remove from size index
        sizeIndex[metadata.size]?.remove(hash)
        if sizeIndex[metadata.size]?.isEmpty == true {
            sizeIndex.removeValue(forKey: metadata.size)
        }
        
        // Remove from content type index
        if let contentType = metadata.contentType {
            contentTypeIndex[contentType]?.remove(hash)
            if contentTypeIndex[contentType]?.isEmpty == true {
                contentTypeIndex.removeValue(forKey: contentType)
            }
        }
    }
    
    /// Get index statistics
    public func getStats() async -> (totalEntries: Int, pathIndexSize: Int, sizeIndexSize: Int, contentTypeIndexSize: Int) {
        await ensureLoaded()
        return (
            totalEntries: index.count,
            pathIndexSize: pathIndex.count,
            sizeIndexSize: sizeIndex.count,
            contentTypeIndexSize: contentTypeIndex.count
        )
    }
}

