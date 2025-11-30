// FileSystemKit Tests
// Mock implementation of ChunkStorage protocol for testing

import Foundation
@testable import FileSystemKit

/// Mock implementation of ChunkStorage for unit testing
/// Stores chunks in memory using a dictionary
final class MockChunkStorage: ChunkStorage, @unchecked Sendable {
    /// In-memory storage: identifier -> (data, metadata)
    private var storage: [String: (data: Data, metadata: ChunkMetadata?)] = [:]
    
    /// Track write operations for testing
    var writeCount: Int = 0
    var readCount: Int = 0
    var deleteCount: Int = 0
    
    /// Optional error to throw for testing error cases
    var shouldThrowError: Error?
    
    init() {}
    
    func writeChunk(_ data: Data, identifier: ChunkIdentifier, metadata: ChunkMetadata?) async throws -> ChunkIdentifier {
        if let error = shouldThrowError {
            throw error
        }
        
        writeCount += 1
        storage[identifier.id] = (data, metadata)
        return identifier
    }
    
    func readChunk(_ identifier: ChunkIdentifier) async throws -> Data? {
        if let error = shouldThrowError {
            throw error
        }
        
        readCount += 1
        return storage[identifier.id]?.data
    }
    
    func readChunk(_ identifier: ChunkIdentifier, offset: Int, length: Int) async throws -> Data? {
        if let error = shouldThrowError {
            throw error
        }
        
        guard let fullData = storage[identifier.id]?.data else {
            return nil
        }
        
        guard offset >= 0 && offset < fullData.count else {
            return nil
        }
        
        let endIndex = min(offset + length, fullData.count)
        return fullData.subdata(in: offset..<endIndex)
    }
    
    func updateChunk(_ data: Data, identifier: ChunkIdentifier, metadata: ChunkMetadata?) async throws -> ChunkIdentifier {
        if let error = shouldThrowError {
            throw error
        }
        
        writeCount += 1
        storage[identifier.id] = (data, metadata)
        return identifier
    }
    
    func deleteChunk(_ identifier: ChunkIdentifier) async throws {
        if let error = shouldThrowError {
            throw error
        }
        
        deleteCount += 1
        storage.removeValue(forKey: identifier.id)
    }
    
    func chunkExists(_ identifier: ChunkIdentifier) async throws -> Bool {
        if let error = shouldThrowError {
            throw error
        }
        
        return storage[identifier.id] != nil
    }
    
    func chunkSize(_ identifier: ChunkIdentifier) async throws -> Int? {
        if let error = shouldThrowError {
            throw error
        }
        
        return storage[identifier.id]?.data.count
    }
    
    func chunkHandle(_ identifier: ChunkIdentifier) async throws -> ChunkHandle? {
        if let error = shouldThrowError {
            throw error
        }
        
        guard let (data, _) = storage[identifier.id] else {
            return nil
        }
        
        return MockChunkHandle(data: data, identifier: identifier)
    }
    
    /// Test helper: Clear all stored chunks
    func clear() {
        storage.removeAll()
        writeCount = 0
        readCount = 0
        deleteCount = 0
    }
    
    /// Test helper: Get stored chunk count
    var chunkCount: Int {
        storage.count
    }
}

// MARK: - Mock Chunk Handle

final class MockChunkHandle: ChunkHandle, @unchecked Sendable {
    private let data: Data
    private let identifier: ChunkIdentifier
    private var isClosed = false
    
    init(data: Data, identifier: ChunkIdentifier) {
        self.data = data
        self.identifier = identifier
    }
    
    func read(range: Range<Int>) async throws -> Data {
        guard !isClosed else {
            throw FileSystemError.storageUnavailable(reason: "Mock storage is closed")
        }
        
        guard range.lowerBound >= 0,
              range.upperBound <= data.count,
              range.lowerBound < range.upperBound else {
            throw FileSystemError.invalidOffset(offset: range.lowerBound, maxOffset: data.count)
        }
        
        return data.subdata(in: range)
    }
    
    var size: Int {
        data.count
    }
    
    func close() async throws {
        isClosed = true
    }
}

