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
public actor FileHashCache {
    private var cache: [String: FileHashCacheEntry] = [:]
    private let cacheFileURL: URL?
    private let hashAlgorithm: String
    private let maxCacheSize: Int
    private var accessOrder: [String] = [] // For LRU eviction
    
    /// Initialize cache
    /// - Parameters:
    ///   - cacheFileURL: Optional URL to persist cache to disk. If nil, cache is in-memory only.
    ///   - hashAlgorithm: Hash algorithm being used (sha256, sha1, md5)
    ///   - maxCacheSize: Maximum number of entries to keep in memory (default: 10000)
    public init(cacheFileURL: URL? = nil, hashAlgorithm: String, maxCacheSize: Int = 10000) {
        self.cacheFileURL = cacheFileURL
        self.hashAlgorithm = hashAlgorithm
        self.maxCacheSize = maxCacheSize
        
        // Load cache from disk if available
        if let cacheFileURL = cacheFileURL {
            Task {
                await loadCache()
            }
        }
    }
    
    /// Get cached hash for a file, or nil if not cached or invalid
    public func getHash(for url: URL) -> String? {
        let key = cacheKey(for: url)
        
        guard let entry = cache[key] else {
            return nil
        }
        
        // Validate cache entry
        guard entry.isValid(for: url, hashAlgorithm: hashAlgorithm) else {
            cache.removeValue(forKey: key)
            accessOrder.removeAll { $0 == key }
            return nil
        }
        
        // Update access order for LRU
        accessOrder.removeAll { $0 == key }
        accessOrder.append(key)
        
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
            accessOrder.removeAll { $0 == key }
        }
        
        cache[key] = entry
        accessOrder.append(key)
        
        // Evict oldest entries if over limit
        while cache.count > maxCacheSize {
            if let oldestKey = accessOrder.first {
                cache.removeValue(forKey: oldestKey)
                accessOrder.removeFirst()
            } else {
                break
            }
        }
    }
    
    /// Remove cache entry for a file
    public func removeHash(for url: URL) {
        let key = cacheKey(for: url)
        cache.removeValue(forKey: key)
        accessOrder.removeAll { $0 == key }
    }
    
    /// Clear all cache entries
    public func clear() {
        cache.removeAll()
        accessOrder.removeAll()
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
            
            // Filter out invalid entries (wrong algorithm, old files)
            var validCache: [String: FileHashCacheEntry] = [:]
            var validOrder: [String] = []
            
            for (key, entry) in loadedCache {
                // Only keep entries with matching hash algorithm
                if entry.hashAlgorithm == hashAlgorithm {
                    validCache[key] = entry
                    validOrder.append(key)
                }
            }
            
            cache = validCache
            accessOrder = validOrder
            
            // Trim to max size if needed
            while cache.count > maxCacheSize {
                if let oldestKey = accessOrder.first {
                    cache.removeValue(forKey: oldestKey)
                    accessOrder.removeFirst()
                } else {
                    break
                }
            }
        } catch {
            // If cache file is corrupted, start fresh
            cache.removeAll()
            accessOrder.removeAll()
        }
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

