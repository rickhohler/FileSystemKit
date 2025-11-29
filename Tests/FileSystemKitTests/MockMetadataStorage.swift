// FileSystemKit Tests
// Mock implementation of MetadataStorage protocol for testing

import Foundation
@testable import FileSystemKit

/// Mock implementation of MetadataStorage for unit testing
/// Stores metadata in memory using a dictionary
final class MockMetadataStorage: MetadataStorage, @unchecked Sendable {
    /// In-memory storage: hash -> metadata
    private var storage: [String: DiskImageMetadata] = [:]
    
    /// Track operations for testing
    var writeCount: Int = 0
    var readCount: Int = 0
    var deleteCount: Int = 0
    var searchCount: Int = 0
    
    /// Optional error to throw for testing error cases
    var shouldThrowError: Error?
    
    init() {}
    
    func writeMetadata(_ metadata: DiskImageMetadata, for hash: DiskImageHash) async throws {
        if let error = shouldThrowError {
            throw error
        }
        
        writeCount += 1
        storage[hash.hexString] = metadata
    }
    
    func readMetadata(for hash: DiskImageHash) async throws -> DiskImageMetadata? {
        if let error = shouldThrowError {
            throw error
        }
        
        readCount += 1
        return storage[hash.hexString]
    }
    
    func updateMetadata(_ metadata: DiskImageMetadata, for hash: DiskImageHash) async throws {
        if let error = shouldThrowError {
            throw error
        }
        
        writeCount += 1
        storage[hash.hexString] = metadata
    }
    
    func deleteMetadata(for hash: DiskImageHash) async throws {
        if let error = shouldThrowError {
            throw error
        }
        
        deleteCount += 1
        storage.removeValue(forKey: hash.hexString)
    }
    
    func metadataExists(for hash: DiskImageHash) async throws -> Bool {
        if let error = shouldThrowError {
            throw error
        }
        
        return storage[hash.hexString] != nil
    }
    
    func searchMetadata(criteria: DiskImageSearchCriteria) async throws -> [DiskImageHash] {
        if let error = shouldThrowError {
            throw error
        }
        
        searchCount += 1
        
        var results: [DiskImageHash] = []
        
        for (hashHex, metadata) in storage {
            var matches = true
            
            // Hash match
            if let criteriaHash = criteria.hash, criteriaHash.hexString != hashHex {
                matches = false
                continue
            }
            
            // Exact filename match
            if criteria.exactFilename != nil {
                // Note: DiskImageMetadata doesn't have filename field in current implementation
                // This would need to be added or searched via alternative names
            }
            
            // Filename contains
            if criteria.filenameContains != nil {
                // Similar note as above
            }
            
            // Title contains
            if let titleContains = criteria.titleContains {
                if let title = metadata.title, !title.localizedCaseInsensitiveContains(titleContains) {
                    matches = false
                    continue
                }
            }
            
            // Publisher match
            if let publisher = criteria.publisher {
                if metadata.publisher != publisher {
                    matches = false
                    continue
                }
            }
            
            // Developer match
            if let developer = criteria.developer {
                if metadata.developer != developer {
                    matches = false
                    continue
                }
            }
            
            if matches {
                // Reconstruct hash from hex string
                if let hashData = Data(hexString: hashHex) {
                    let hash = DiskImageHash(algorithm: .sha256, value: hashData)
                    results.append(hash)
                }
            }
        }
        
        return results
    }
    
    /// Test helper: Clear all stored metadata
    func clear() {
        storage.removeAll()
        writeCount = 0
        readCount = 0
        deleteCount = 0
        searchCount = 0
    }
    
    /// Test helper: Get stored metadata count
    var metadataCount: Int {
        storage.count
    }
}

// MARK: - Data Extension for Hex String Conversion

extension Data {
    init?(hexString: String) {
        let len = hexString.count / 2
        var data = Data(capacity: len)
        var i = hexString.startIndex
        for _ in 0..<len {
            let j = hexString.index(i, offsetBy: 2)
            let bytes = hexString[i..<j]
            if let num = UInt8(bytes, radix: 16) {
                data.append(num)
            } else {
                return nil
            }
            i = j
        }
        self = data
    }
}

