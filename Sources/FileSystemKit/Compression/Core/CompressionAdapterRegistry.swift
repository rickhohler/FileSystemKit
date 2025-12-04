// FileSystemKit Core Library
// Compression Adapter Registry
//
// Design Pattern: Uses DesignAlgorithmsKit.TypeRegistry internally for type storage
// while maintaining domain-specific API for adapter discovery

import Foundation
import DesignAlgorithmsKit

/// Thread-safe registry for compression adapters
/// Uses NSLock for synchronization to support concurrent access
public final class CompressionAdapterRegistry: @unchecked Sendable {
    /// Lock for thread-safe initialization
    nonisolated private static let lock = NSLock()
    
    /// Shared singleton instance (lazy, thread-safe)
    /// Uses Static struct pattern to avoid static initialization order issues
    public static var shared: CompressionAdapterRegistry {
        lock.lock()
        defer { lock.unlock() }
        
        struct Static {
            nonisolated(unsafe) static var instance: CompressionAdapterRegistry?
        }
        
        if Static.instance == nil {
            Static.instance = CompressionAdapterRegistry()
        }
        
        return Static.instance!
    }
    
    /// Lock for thread-safe access
    private let lock = NSLock()
    
    /// TypeRegistry from DesignAlgorithmsKit for type storage
    private let typeRegistry = TypeRegistry.shared
    
    /// Registered adapters (format -> adapter type) - cached for fast lookup
    private var registeredAdapters: [CompressionFormat: CompressionAdapter.Type] = [:]
    
    private init() {
        // Private initializer for singleton
    }
    
    /// Register a compression adapter
    /// - Parameter adapterType: Adapter type to register
    /// Thread-safe: Can be called concurrently
    /// Uses DesignAlgorithmsKit.TypeRegistry internally for type storage
    public func register<T: CompressionAdapter>(_ adapterType: T.Type) {
        lock.lock()
        defer { lock.unlock() }
        
        // Register in TypeRegistry using format as key
        typeRegistry.register(adapterType, key: T.format.rawValue)
        
        // Cache for fast lookup
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
    /// Uses DesignAlgorithmsKit.TypeRegistry internally for type lookup
    public func findAdapter(for format: CompressionFormat) -> CompressionAdapter.Type? {
        lock.lock()
        defer { lock.unlock() }
        
        // Try cache first
        if let cached = registeredAdapters[format] {
            return cached
        }
        
        // Fallback to TypeRegistry lookup
        if let type = typeRegistry.find(for: format.rawValue) as? CompressionAdapter.Type {
            registeredAdapters[format] = type // Cache for next time
            return type
        }
        
        return nil
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

