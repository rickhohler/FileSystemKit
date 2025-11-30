// FileSystemKit - SNUG Mirrored Storage
// Provides redundancy by mirroring chunks to multiple storage locations

import Foundation

/// Mirrored chunk storage that writes to multiple locations for redundancy
public struct SnugMirroredChunkStorage: ChunkStorage, Sendable {
    private let primaryStorage: SnugFileSystemChunkStorage
    private let mirrorStorages: [SnugFileSystemChunkStorage]
    private let glacierStorages: [SnugFileSystemChunkStorage]  // Always mirrored during archive creation
    private let failOnPrimaryError: Bool
    
    public init(
        primaryStorage: SnugFileSystemChunkStorage,
        mirrorStorages: [SnugFileSystemChunkStorage] = [],
        glacierStorages: [SnugFileSystemChunkStorage] = [],
        failOnPrimaryError: Bool = true
    ) {
        self.primaryStorage = primaryStorage
        self.mirrorStorages = mirrorStorages
        self.glacierStorages = glacierStorages
        self.failOnPrimaryError = failOnPrimaryError
    }
    
    public func writeChunk(_ data: Data, identifier: ChunkIdentifier, metadata: ChunkMetadata?) async throws -> ChunkIdentifier {
        // Write to primary first
        do {
            _ = try await primaryStorage.writeChunk(data, identifier: identifier, metadata: metadata)
        } catch {
            if failOnPrimaryError {
                throw error
            }
            // Continue to mirrors even if primary fails (if not failing on error)
        }
        
        // Write to all mirror locations in parallel
        await withTaskGroup(of: Error?.self) { group in
            for mirrorStorage in mirrorStorages {
                group.addTask {
                    do {
                        _ = try await mirrorStorage.writeChunk(data, identifier: identifier, metadata: metadata)
                        return nil
                    } catch {
                        return error
                    }
                }
            }
            
            // Collect errors (but don't fail operation)
            for await error in group {
                if error != nil {
                    // Log error but don't fail (mirrors are for redundancy)
                    // In a real implementation, you might want to log these
                }
            }
        }
        
        // Always write to glacier/backup storage (for long-term archival)
        // These are written asynchronously and errors don't fail the operation
        await withTaskGroup(of: Void.self) { group in
            for glacierStorage in glacierStorages {
                group.addTask {
                    _ = try? await glacierStorage.writeChunk(data, identifier: identifier, metadata: metadata)
                }
            }
        }
        
        // Mirror errors are handled in the task group above
        // They don't fail the operation (mirrors are for redundancy)
        
        return identifier
    }
    
    public func readChunk(_ identifier: ChunkIdentifier) async throws -> Data? {
        // Try primary first
        if let data = try await primaryStorage.readChunk(identifier) {
            return data
        }
        
        // Try mirrors if primary doesn't have it
        for mirrorStorage in mirrorStorages {
            if let data = try await mirrorStorage.readChunk(identifier) {
                return data
            }
        }
        
        // Try glacier storage last (slowest, but has everything)
        for glacierStorage in glacierStorages {
            if let data = try await glacierStorage.readChunk(identifier) {
                return data
            }
        }
        
        return nil
    }
    
    public func readChunk(_ identifier: ChunkIdentifier, offset: Int, length: Int) async throws -> Data? {
        // Try primary first
        if let data = try await primaryStorage.readChunk(identifier, offset: offset, length: length) {
            return data
        }
        
        // Try mirrors if primary doesn't have it
        for mirrorStorage in mirrorStorages {
            if let data = try await mirrorStorage.readChunk(identifier, offset: offset, length: length) {
                return data
            }
        }
        
        // Try glacier storage last
        for glacierStorage in glacierStorages {
            if let data = try await glacierStorage.readChunk(identifier, offset: offset, length: length) {
                return data
            }
        }
        
        return nil
    }
    
    public func updateChunk(_ data: Data, identifier: ChunkIdentifier, metadata: ChunkMetadata?) async throws -> ChunkIdentifier {
        // Update primary
        let result = try await primaryStorage.updateChunk(data, identifier: identifier, metadata: metadata)
        
        // Update mirrors
        await withTaskGroup(of: Void.self) { group in
            for mirrorStorage in mirrorStorages {
                group.addTask {
                    _ = try? await mirrorStorage.updateChunk(data, identifier: identifier, metadata: metadata)
                }
            }
        }
        
        return result
    }
    
    public func deleteChunk(_ identifier: ChunkIdentifier) async throws {
        // Delete from primary
        try await primaryStorage.deleteChunk(identifier)
        
        // Delete from mirrors
        await withTaskGroup(of: Void.self) { group in
            for mirrorStorage in mirrorStorages {
                group.addTask {
                    try? await mirrorStorage.deleteChunk(identifier)
                }
            }
        }
    }
    
    public func chunkExists(_ identifier: ChunkIdentifier) async throws -> Bool {
        // Check primary first
        if try await primaryStorage.chunkExists(identifier) {
            return true
        }
        
        // Check mirrors
        for mirrorStorage in mirrorStorages {
            if try await mirrorStorage.chunkExists(identifier) {
                return true
            }
        }
        
        // Check glacier storage
        for glacierStorage in glacierStorages {
            if try await glacierStorage.chunkExists(identifier) {
                return true
            }
        }
        
        return false
    }
    
    public func chunkSize(_ identifier: ChunkIdentifier) async throws -> Int? {
        // Try primary first
        if let size = try await primaryStorage.chunkSize(identifier) {
            return size
        }
        
        // Try mirrors
        for mirrorStorage in mirrorStorages {
            if let size = try await mirrorStorage.chunkSize(identifier) {
                return size
            }
        }
        
        // Try glacier storage
        for glacierStorage in glacierStorages {
            if let size = try await glacierStorage.chunkSize(identifier) {
                return size
            }
        }
        
        return nil
    }
    
    public func chunkHandle(_ identifier: ChunkIdentifier) async throws -> ChunkHandle? {
        // Try primary first
        if let handle = try await primaryStorage.chunkHandle(identifier) {
            return handle
        }
        
        // Try mirrors
        for mirrorStorage in mirrorStorages {
            if let handle = try await mirrorStorage.chunkHandle(identifier) {
                return handle
            }
        }
        
        // Try glacier storage
        for glacierStorage in glacierStorages {
            if let handle = try await glacierStorage.chunkHandle(identifier) {
                return handle
            }
        }
        
        return nil
    }
}

/// Extension to SnugStorage for creating mirrored storage
public extension SnugStorage {
    /// Create mirrored chunk storage from configuration
    static func createMirroredChunkStorage(from config: SnugConfig) throws -> SnugMirroredChunkStorage {
        let available = try SnugConfigManager.getAvailableStorageLocations(from: config)
        
        guard let primary = available.first(where: { $0.volumeType == .primary }) ?? available.first else {
            throw SnugError.storageError("No primary storage location available")
        }
        
        let primaryStorage = try createChunkStorage(at: URL(fileURLWithPath: primary.path))
        
        // Separate locations by type
        var mirrorStorages: [SnugFileSystemChunkStorage] = []
        var glacierStorages: [SnugFileSystemChunkStorage] = []
        
        // Get mirror locations (explicit mirrors or secondary volumes)
        let mirrorLocations = available.filter { location in
            location.volumeType == .mirror || location.volumeType == .secondary
        }
        
        for location in mirrorLocations {
            let mirrorStorage = try createChunkStorage(at: URL(fileURLWithPath: location.path))
            mirrorStorages.append(mirrorStorage)
        }
        
        // Get glacier/backup locations (always mirrored during archive creation)
        let glacierLocations = available.filter { $0.volumeType == .glacier }
        
        for location in glacierLocations {
            let glacierStorage = try createChunkStorage(at: URL(fileURLWithPath: location.path))
            glacierStorages.append(glacierStorage)
        }
        
        // Legacy: If mirroring is enabled via config flag, use additional locations
        if config.enableMirroring && mirrorStorages.isEmpty && glacierStorages.isEmpty {
            // Get mirror locations from config.mirrorLocations
            for mirrorPath in config.mirrorLocations {
                // Resolve path or label to actual location
                let resolvedPath: String
                if let location = config.storageLocations.first(where: { $0.path == mirrorPath || $0.label == mirrorPath }) {
                    resolvedPath = location.path
                } else {
                    resolvedPath = mirrorPath
                }
                
                let mirrorURL = URL(fileURLWithPath: resolvedPath)
                if FileManager.default.fileExists(atPath: mirrorURL.path) && FileManager.default.isWritableFile(atPath: mirrorURL.path) {
                    let mirrorStorage = try createChunkStorage(at: mirrorURL)
                    mirrorStorages.append(mirrorStorage)
                }
            }
            
            // If still no mirrors, use additional configured locations
            if mirrorStorages.isEmpty && available.count > 1 {
                for location in available.dropFirst() {
                    if location.volumeType != .glacier {
                        let mirrorStorage = try createChunkStorage(at: URL(fileURLWithPath: location.path))
                        mirrorStorages.append(mirrorStorage)
                    }
                }
            }
        }
        
        return SnugMirroredChunkStorage(
            primaryStorage: primaryStorage,
            mirrorStorages: mirrorStorages,
            glacierStorages: glacierStorages,
            failOnPrimaryError: config.failIfPrimaryUnavailable
        )
    }
}

