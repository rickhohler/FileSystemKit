// FileSystemKit Core Library
// Compression Adapter Registry

import Foundation

/// Thread-safe registry for compression adapters
/// Uses NSLock for synchronization to support concurrent access
public final class CompressionAdapterRegistry: @unchecked Sendable {
    /// Shared singleton instance (lazy initialization to avoid static initialization order issues)
    // Protected by lock, so marked as nonisolated(unsafe) for concurrency safety
    nonisolated(unsafe) private static var _shared: CompressionAdapterRegistry?
    nonisolated private static let lock = NSLock()
    
    /// Shared singleton instance (lazy)
    public static var shared: CompressionAdapterRegistry {
        lock.lock()
        defer { lock.unlock() }
        if _shared == nil {
            _shared = CompressionAdapterRegistry()
        }
        return _shared!
    }
    
    /// Lock for thread-safe access
    private let lock = NSLock()
    
    /// Registered adapters (format -> adapter type)
    private var registeredAdapters: [CompressionFormat: CompressionAdapter.Type] = [:]
    
    private init() {
        // Private initializer for singleton
    }
    
    /// Register a compression adapter
    /// - Parameter adapterType: Adapter type to register
    /// Thread-safe: Can be called concurrently
    public func register<T: CompressionAdapter>(_ adapterType: T.Type) {
        lock.lock()
        defer { lock.unlock() }
        registeredAdapters[T.format] = adapterType
    }
    
    /// Find adapter for the given URL
    /// - Parameter url: URL to check
    /// - Returns: Adapter type that can handle the URL, or nil if none found
    /// Thread-safe: Can be called concurrently
    public func findAdapter(for url: URL) -> CompressionAdapter.Type? {
        lock.lock()
        defer { lock.unlock() }
        
        // Try each registered adapter
        for (_, adapterType) in registeredAdapters {
            if adapterType.canHandle(url: url) {
                return adapterType
            }
        }
        return nil
    }
    
    /// Find adapter for the given format
    /// - Parameter format: Compression format
    /// - Returns: Adapter type for the format, or nil if not registered
    /// Thread-safe: Can be called concurrently
    public func findAdapter(for format: CompressionFormat) -> CompressionAdapter.Type? {
        lock.lock()
        defer { lock.unlock() }
        return registeredAdapters[format]
    }
    
    /// Get all registered adapters
    /// - Returns: Array of registered adapter types
    /// Thread-safe: Can be called concurrently
    public func allAdapters() -> [CompressionAdapter.Type] {
        lock.lock()
        defer { lock.unlock() }
        return Array(registeredAdapters.values)
    }
    
    /// Clear all registered adapters (primarily for testing)
    /// Thread-safe: Can be called concurrently
    internal func clear() {
        lock.lock()
        defer { lock.unlock() }
        registeredAdapters.removeAll()
    }
}

