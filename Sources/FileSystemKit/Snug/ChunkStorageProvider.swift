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
    
    /// Vendor information for this storage provider.
    /// nil if vendor information is not available or not applicable.
    /// Allows tracking which vendor/company provides the storage backend.
    var vendor: (any FSVendorProtocol)? { get }
    
    // MARK: - Vendor Operations
    
    /// Create a new vendor in storage.
    ///
    /// Creates a new vendor record. Throws an error if a vendor with the same ID already exists.
    ///
    /// - Parameter vendor: The vendor to create
    /// - Throws: Error if creation fails or vendor already exists
    func createVendor(_ vendor: any FSVendorProtocol) async throws
    
    /// Save a vendor to storage (create or update).
    ///
    /// Upsert operation: creates a new vendor if it doesn't exist, or updates an existing one.
    /// Use `createVendor` if you want to ensure the vendor doesn't already exist.
    ///
    /// - Parameter vendor: The vendor to save
    /// - Throws: Error if save fails
    func saveVendor(_ vendor: any FSVendorProtocol) async throws
    
    /// Load a vendor from storage by ID.
    ///
    /// - Parameter id: Vendor identifier
    /// - Returns: The vendor if found, nil otherwise
    /// - Throws: Error if loading fails
    func loadVendor(id: UUID) async throws -> (any FSVendorProtocol)?
    
    /// Fetch all vendors from storage.
    ///
    /// - Returns: Array of all vendors
    /// - Throws: Error if fetch fails
    func fetchVendors() async throws -> [any FSVendorProtocol]
    
    /// Delete a vendor from storage.
    ///
    /// - Parameter id: Vendor identifier
    /// - Throws: Error if deletion fails
    func deleteVendor(id: UUID) async throws
}

/// Default file system-based storage provider
/// Used for unit tests and local file system storage
public struct FileSystemChunkStorageProvider: ChunkStorageProvider {
    public let identifier: String = "filesystem"
    public let displayName: String = "File System"
    public let requiresConfiguration: Bool = false
    public let vendor: (any FSVendorProtocol)? = nil
    
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
            // Default to ~/.snug (macOS) or Application Support (iOS)
            #if os(iOS) || os(tvOS) || os(watchOS)
            // On iOS/tvOS/watchOS, use Application Support directory
            let urls = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            if let appSupportURL = urls.first {
                baseURL = appSupportURL.appendingPathComponent(".snug")
            } else {
                // Fallback to documents directory if application support is unavailable
                let docURLs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
                baseURL = docURLs.first?.appendingPathComponent(".snug") ?? URL(fileURLWithPath: "/tmp/.snug")
            }
            #else
            // On macOS/Linux, use home directory
            let homeDir = FileManager.default.homeDirectoryForCurrentUser
            baseURL = homeDir.appendingPathComponent(".snug")
            #endif
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

// MARK: - ChunkStorageProvider Default Implementations

extension ChunkStorageProvider {
    /// Default implementation: no vendor information
    public var vendor: (any FSVendorProtocol)? {
        return nil
    }
    
    /// Default implementation: throws error indicating vendor operations are not supported
    public func createVendor(_ vendor: any FSVendorProtocol) async throws {
        throw SnugError.storageError("Vendor operations are not supported by this storage provider", nil)
    }
    
    /// Default implementation: throws error indicating vendor operations are not supported
    public func saveVendor(_ vendor: any FSVendorProtocol) async throws {
        throw SnugError.storageError("Vendor operations are not supported by this storage provider", nil)
    }
    
    /// Default implementation: returns nil (vendor not found)
    public func loadVendor(id: UUID) async throws -> (any FSVendorProtocol)? {
        return nil
    }
    
    /// Default implementation: returns empty array
    public func fetchVendors() async throws -> [any FSVendorProtocol] {
        return []
    }
    
    /// Default implementation: throws error indicating vendor operations are not supported
    public func deleteVendor(id: UUID) async throws {
        throw SnugError.storageError("Vendor operations are not supported by this storage provider", nil)
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

