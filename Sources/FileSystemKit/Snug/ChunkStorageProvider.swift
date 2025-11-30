// FileSystemKit - Chunk Storage Provider Protocol
// Allows clients to implement custom storage backends (CloudKit, iCloud Drive, S3, etc.)

import Foundation

/// Protocol for creating and configuring ChunkStorage instances
/// Clients implement this to provide custom storage backends
public protocol ChunkStorageProvider: Sendable {
    /// Create a ChunkStorage instance
    /// - Parameter configuration: Optional configuration dictionary for the storage backend
    /// - Returns: Configured ChunkStorage instance
    /// - Throws: Error if storage cannot be created
    func createChunkStorage(configuration: [String: Any]?) async throws -> any ChunkStorage
    
    /// Storage provider identifier (e.g., "filesystem", "cloudkit", "s3")
    var identifier: String { get }
    
    /// Human-readable name for the storage provider
    var displayName: String { get }
    
    /// Whether this provider requires additional configuration
    var requiresConfiguration: Bool { get }
}

/// Default file system-based storage provider
/// Used for unit tests and local file system storage
public struct FileSystemChunkStorageProvider: ChunkStorageProvider {
    public let identifier: String = "filesystem"
    public let displayName: String = "File System"
    public let requiresConfiguration: Bool = false
    
    public init() {}
    
    public func createChunkStorage(configuration: [String: Any]?) async throws -> any ChunkStorage {
        let baseURL: URL
        
        if let config = configuration,
           let path = config["baseURL"] as? String {
            baseURL = URL(fileURLWithPath: path)
        } else if let config = configuration,
                  let url = config["baseURL"] as? URL {
            baseURL = url
        } else {
            // Default to ~/.snug
            let homeDir = FileManager.default.homeDirectoryForCurrentUser
            baseURL = homeDir.appendingPathComponent(".snug")
        }
        
        // Ensure directory exists
        try FileManager.default.createDirectory(
            at: baseURL,
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        return SnugFileSystemChunkStorage(baseURL: baseURL)
    }
}

/// Registry for chunk storage providers
/// Allows clients to register custom storage providers
public actor ChunkStorageProviderRegistry {
    private var providers: [String: any ChunkStorageProvider] = [:]
    
    /// Shared singleton instance
    public static let shared = ChunkStorageProviderRegistry()
    
    private init() {
        // Register default file system provider asynchronously
        Task {
            await register(FileSystemChunkStorageProvider())
        }
    }
    
    /// Register a storage provider
    /// - Parameter provider: Storage provider to register
    public func register(_ provider: any ChunkStorageProvider) {
        providers[provider.identifier] = provider
    }
    
    /// Get a storage provider by identifier
    /// - Parameter identifier: Provider identifier
    /// - Returns: Storage provider if found, nil otherwise
    public func getProvider(identifier: String) -> (any ChunkStorageProvider)? {
        return providers[identifier]
    }
    
    /// List all registered providers
    /// - Returns: Array of provider identifiers
    public func listProviders() -> [String] {
        return Array(providers.keys)
    }
    
    /// Create storage instance using registered provider
    /// - Parameters:
    ///   - identifier: Provider identifier (defaults to "filesystem")
    ///   - configuration: Optional configuration dictionary
    /// - Returns: Configured ChunkStorage instance
    /// - Throws: Error if provider not found or creation fails
    /// - Note: Configuration dictionary should contain only Sendable values (String, Int, Double, Bool, URL, etc.)
    ///   The configuration is passed through actor boundaries, so values must be Sendable.
    nonisolated public func createStorage(
        identifier: String = "filesystem",
        configuration: [String: Any]? = nil
    ) async throws -> any ChunkStorage {
        // Access providers synchronously (safe since we're reading)
        let provider = await providers[identifier]
        
        guard let provider = provider else {
            let available = await listProviders().joined(separator: ", ")
            throw SnugError.storageError("Storage provider '\(identifier)' not found. Available providers: \(available)", nil)
        }
        
        // Pass configuration directly to provider
        // Provider implementations should handle Sendable requirements appropriately
        return try await provider.createChunkStorage(configuration: configuration)
    }
}

