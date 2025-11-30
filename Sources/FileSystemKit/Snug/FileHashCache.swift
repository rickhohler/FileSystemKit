// FileSystemKit - SNUG File Hash Cache
// Caches computed file hashes to avoid recomputation

import Foundation

/// Cache entry for a file hash
internal struct FileHashCacheEntry: Codable, Sendable {
    let path: String
    let hash: String
    let hashAlgorithm: String
    let fileSize: Int64
    let modificationTime: Date
    let cacheTime: Date
    
    init(path: String, hash: String, hashAlgorithm: String, fileSize: Int64, modificationTime: Date) {
        self.path = path
        self.hash = hash
        self.hashAlgorithm = hashAlgorithm
        self.fileSize = fileSize
        self.modificationTime = modificationTime
        self.cacheTime = Date()
    }
    
    /// Check if cache entry is still valid for a file
    func isValid(for url: URL, hashAlgorithm: String) -> Bool {
        guard self.hashAlgorithm == hashAlgorithm else {
            return false
        }
        
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let fileSize = attributes[.size] as? Int64,
              let modificationTime = attributes[.modificationDate] as? Date else {
            return false
        }
        
        return self.fileSize == fileSize && 
               abs(self.modificationTime.timeIntervalSince(modificationTime)) < 1.0 // 1 second tolerance
    }
}

/// Thread-safe file hash cache
/// Optimized for millions of files with scalable cache size and O(1) LRU operations
public actor FileHashCache {
    private var cache: [String: FileHashCacheEntry] = [:]
    private let cacheFileURL: URL?
    private let hashAlgorithm: String
    private let maxCacheSize: Int
    // Optimized LRU: Use linked list for O(1) operations instead of array O(n)
    private var lruHead: LRUNode?
    private var lruTail: LRUNode?
    private var nodeMap: [String: LRUNode] = [:]
    
    /// Cache statistics
    public struct CacheStats: Sendable {
        var hits: Int64 = 0
        var misses: Int64 = 0
        var evictions: Int64 = 0
        
        var hitRate: Double {
            let total = hits + misses
            return total > 0 ? Double(hits) / Double(total) : 0.0
        }
    }
    
    private var cacheStats = CacheStats()
    
    /// LRU node for O(1) cache operations
    private final class LRUNode: @unchecked Sendable {
        let key: String
        var prev: LRUNode?
        var next: LRUNode?
        
        init(key: String) {
            self.key = key
        }
    }
    
    /// Initialize cache
    /// - Parameters:
    ///   - cacheFileURL: Optional URL to persist cache to disk. If nil, cache is in-memory only.
    ///   - hashAlgorithm: Hash algorithm being used (sha256, sha1, md5)
    ///   - maxCacheSize: Maximum number of entries to keep in memory (default: 1,000,000 for millions of files)
    public init(cacheFileURL: URL? = nil, hashAlgorithm: String, maxCacheSize: Int = 1_000_000) {
        self.cacheFileURL = cacheFileURL
        self.hashAlgorithm = hashAlgorithm
        self.maxCacheSize = maxCacheSize
        
        // Load cache from disk if available
        if cacheFileURL != nil {
            Task {
                await loadCache()
            }
        }
    }
    
    /// Get cached hash for a file, or nil if not cached or invalid
    public func getHash(for url: URL) -> String? {
        let key = cacheKey(for: url)
        
        guard let entry = cache[key] else {
            cacheStats.misses += 1
            return nil
        }
        
        // Validate cache entry
        guard entry.isValid(for: url, hashAlgorithm: hashAlgorithm) else {
            cache.removeValue(forKey: key)
            removeFromLRU(key)
            cacheStats.misses += 1
            return nil
        }
        
        // Update LRU (O(1) operation using linked list)
        touch(key)
        cacheStats.hits += 1
        return entry.hash
    }
    
    /// Store hash in cache
    public func setHash(_ hash: String, for url: URL, fileSize: Int64, modificationTime: Date) {
        let key = cacheKey(for: url)
        
        let entry = FileHashCacheEntry(
            path: url.path,
            hash: hash,
            hashAlgorithm: hashAlgorithm,
            fileSize: fileSize,
            modificationTime: modificationTime
        )
        
        // Remove old entry if exists
        if cache[key] != nil {
            removeFromLRU(key)
        }
        
        cache[key] = entry
        addToLRUHead(key)
        
        // Evict oldest entries if over limit (O(1) per eviction)
        while cache.count > maxCacheSize {
            evictLRU()
            cacheStats.evictions += 1
        }
    }
    
    /// Remove cache entry for a file
    public func removeHash(for url: URL) {
        let key = cacheKey(for: url)
        cache.removeValue(forKey: key)
        removeFromLRU(key)
    }
    
    /// Clear all cache entries
    public func clear() {
        cache.removeAll()
        lruHead = nil
        lruTail = nil
        nodeMap.removeAll()
        cacheStats = CacheStats()
    }
    
    /// Get cache statistics
    public func getStats() -> (count: Int, maxSize: Int) {
        return (cache.count, maxCacheSize)
    }
    
    /// Save cache to disk
    public func saveCache() throws {
        guard let cacheFileURL = cacheFileURL else {
            return
        }
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        let cacheData = try encoder.encode(cache)
        try cacheData.write(to: cacheFileURL, options: [.atomic])
    }
    
    /// Load cache from disk
    private func loadCache() async {
        guard let cacheFileURL = cacheFileURL,
              FileManager.default.fileExists(atPath: cacheFileURL.path) else {
            return
        }
        
        do {
            let cacheData = try Data(contentsOf: cacheFileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let loadedCache = try decoder.decode([String: FileHashCacheEntry].self, from: cacheData)
            
            // Filter out invalid entries (wrong algorithm)
            var validCache: [String: FileHashCacheEntry] = [:]
            
            for (key, entry) in loadedCache {
                if entry.hashAlgorithm == hashAlgorithm {
                    validCache[key] = entry
                }
            }
            
            cache = validCache
            
            // Rebuild LRU structure (order by cacheTime)
            let sortedEntries = validCache.sorted { $0.value.cacheTime < $1.value.cacheTime }
            for (key, _) in sortedEntries {
                addToLRUHead(key)
            }
            
            // Trim to max size if needed
            while cache.count > maxCacheSize {
                evictLRU()
            }
        } catch {
            // If cache file is corrupted, start fresh
            cache.removeAll()
            lruHead = nil
            lruTail = nil
            nodeMap.removeAll()
        }
    }
    
    // MARK: - LRU Operations (O(1))
    
    /// Touch a key (move to head of LRU)
    private func touch(_ key: String) {
        if nodeMap[key] != nil {
            removeFromLRU(key)
            addToLRUHead(key)
        } else {
            addToLRUHead(key)
        }
    }
    
    /// Add key to head of LRU list
    private func addToLRUHead(_ key: String) {
        let node = LRUNode(key: key)
        nodeMap[key] = node
        
        if let head = lruHead {
            node.next = head
            head.prev = node
            lruHead = node
        } else {
            lruHead = node
            lruTail = node
        }
    }
    
    /// Remove key from LRU list
    private func removeFromLRU(_ key: String) {
        guard let node = nodeMap[key] else {
            return
        }
        
        if let prev = node.prev {
            prev.next = node.next
        } else {
            lruHead = node.next
        }
        
        if let next = node.next {
            next.prev = node.prev
        } else {
            lruTail = node.prev
        }
        
        nodeMap.removeValue(forKey: key)
    }
    
    /// Evict least recently used entry
    private func evictLRU() {
        guard let tail = lruTail else {
            return
        }
        
        cache.removeValue(forKey: tail.key)
        removeFromLRU(tail.key)
    }
    
    /// Generate cache key for a file URL
    private func cacheKey(for url: URL) -> String {
        // Use resolved path to handle symlinks consistently
        let resolvedPath = url.resolvingSymlinksInPath().path
        return resolvedPath
    }
}

/// Thread-safe holder for hash value
private final class HashHolder: @unchecked Sendable {
    var value: String? = nil
}

/// Extension to integrate hash cache with file processing
extension FileHashCache {
    /// Compute hash for a file, using cache if available
    /// This is a synchronous wrapper that checks cache first, then computes if needed
    public nonisolated func computeHashSync(for url: URL, data: Data, hashAlgorithm: String) throws -> String {
        // Check cache first (synchronous check using semaphore)
        let semaphore = DispatchSemaphore(value: 0)
        let hashHolder = HashHolder()
        
        Task {
            hashHolder.value = await getHash(for: url)
            semaphore.signal()
        }
        semaphore.wait()
        
        if let cachedHash = hashHolder.value {
            return cachedHash
        }
        
        // Compute hash
        let hash = try computeHash(data: data, algorithm: hashAlgorithm)
        
        // Get file metadata for caching
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        let fileSize = Int64(data.count)
        let modificationTime = attributes?[.modificationDate] as? Date ?? Date()
        
        // Store in cache (async, fire and forget)
        Task {
            await setHash(hash, for: url, fileSize: fileSize, modificationTime: modificationTime)
        }
        
        return hash
    }
    
    /// Compute hash for data using specified algorithm
    private nonisolated func computeHash(data: Data, algorithm: String) throws -> String {
        switch algorithm.lowercased() {
        case "sha256":
            return data.sha256().map { String(format: "%02x", $0) }.joined()
        case "sha1":
            return data.sha1().map { String(format: "%02x", $0) }.joined()
        case "md5":
            return data.md5().map { String(format: "%02x", $0) }.joined()
        default:
            throw SnugError.unsupportedHashAlgorithm(algorithm)
        }
    }
}

