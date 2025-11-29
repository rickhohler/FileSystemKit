// FileSystemKit - SNUG Archive Creation
// Creates .snug archives from directories

import Foundation
import Yams
#if canImport(Compression)
import Compression
#endif
#if canImport(CommonCrypto)
import CommonCrypto
#endif
#if canImport(CryptoKit)
import CryptoKit
#endif

/// Creates SNUG archives from directory structures
public class SnugArchiver {
    let storageURL: URL
    let hashAlgorithm: String
    let chunkStorage: SnugFileSystemChunkStorage
    
    public init(storageURL: URL, hashAlgorithm: String) throws {
        self.storageURL = storageURL
        self.hashAlgorithm = hashAlgorithm
        self.chunkStorage = try SnugStorage.createChunkStorage(at: storageURL)
    }
    
    public func createArchive(from sourceURL: URL, outputURL: URL, verbose: Bool) throws -> SnugArchiveStats {
        // 1. Walk directory and collect files
        var entries: [ArchiveEntry] = []
        var hashRegistry: [String: HashDefinition] = [:]
        var processedHashes: Set<String> = []
        var totalSize: Int = 0
        
        try processDirectory(
            at: sourceURL,
            basePath: "",
            entries: &entries,
            hashRegistry: &hashRegistry,
            processedHashes: &processedHashes,
            totalSize: &totalSize,
            verbose: verbose
        )
        
        // 2. Create YAML structure
        let archive = SnugArchive(
            format: "snug",
            version: 1,
            hashAlgorithm: hashAlgorithm,
            hashes: hashRegistry.isEmpty ? nil : hashRegistry,
            metadata: nil,
            entries: entries
        )
        
        // 3. Encode to YAML
        let encoder = YAMLEncoder()
        let yamlString = try encoder.encode(archive)
        guard let yamlData = yamlString.data(using: .utf8) else {
            throw SnugError.storageError("Failed to encode YAML")
        }
        
        // 4. Compress YAML
        let compressedData = try compressGzip(data: yamlData)
        
        // 5. Write compressed file
        try compressedData.write(to: outputURL)
        
        let fileCount = entries.filter { $0.type == "file" }.count
        let directoryCount = entries.filter { $0.type == "directory" }.count
        
        if verbose {
            print("Archive created: \(entries.count) entries, \(hashRegistry.count) unique hashes")
        }
        
        return SnugArchiveStats(
            fileCount: fileCount,
            directoryCount: directoryCount,
            uniqueHashCount: hashRegistry.count,
            totalSize: totalSize
        )
    }
    
    private func processDirectory(
        at url: URL,
        basePath: String,
        entries: inout [ArchiveEntry],
        hashRegistry: inout [String: HashDefinition],
        processedHashes: inout Set<String>,
        totalSize: inout Int,
        verbose: Bool
    ) throws {
        let resourceKeys: [URLResourceKey] = [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey]
        let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsHiddenFiles],
            errorHandler: nil
        )
        
        guard let enumerator = enumerator else {
            throw SnugError.storageError("Failed to enumerate directory")
        }
        
        for case let fileURL as URL in enumerator {
            let relativePath = fileURL.path.replacingOccurrences(of: url.path, with: basePath)
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            
            let resourceValues = try fileURL.resourceValues(forKeys: Set(resourceKeys))
            let isDirectory = resourceValues.isDirectory ?? false
            
            if isDirectory {
                // Directory entry
                let entry = ArchiveEntry(
                    type: "directory",
                    path: relativePath,
                    hash: nil,
                    size: nil,
                    permissions: nil,
                    owner: nil,
                    group: nil,
                    modified: resourceValues.contentModificationDate,
                    created: nil
                )
                entries.append(entry)
            } else {
                // File entry
                let fileData = try Data(contentsOf: fileURL)
                totalSize += fileData.count
                let hash = try computeHash(data: fileData)
                
                // Store file in chunk storage (synchronous wrapper)
                let identifier = ChunkIdentifier(id: hash)
                let metadata = ChunkMetadata(
                    size: fileData.count,
                    contentHash: hash,
                    hashAlgorithm: hashAlgorithm,
                    contentType: nil,
                    chunkType: "file",
                    originalFilename: fileURL.lastPathComponent
                )
                
                let semaphore = DispatchSemaphore(value: 0)
                let errorHolder = ErrorHolder()
                
                Task { [chunkStorage] in
                    do {
                        _ = try await chunkStorage.writeChunk(fileData, identifier: identifier, metadata: metadata)
                        semaphore.signal()
                    } catch {
                        errorHolder.error = error
                        semaphore.signal()
                    }
                }
                
                semaphore.wait()
                
                if let error = errorHolder.error {
                    throw error
                }
                
                // Add to hash registry if not already present
                if !processedHashes.contains(hash) {
                    hashRegistry[hash] = HashDefinition(
                        hash: hash,
                        size: fileData.count,
                        algorithm: hashAlgorithm
                    )
                    processedHashes.insert(hash)
                }
                
                // File entry
                let entry = ArchiveEntry(
                    type: "file",
                    path: relativePath,
                    hash: hash,
                    size: fileData.count,
                    permissions: nil,
                    owner: nil,
                    group: nil,
                    modified: resourceValues.contentModificationDate,
                    created: nil
                )
                entries.append(entry)
                
                if verbose {
                    print("  Added: \(relativePath) (\(hash.prefix(8))...)")
                }
            }
        }
    }
    
    private func computeHash(data: Data) throws -> String {
        switch hashAlgorithm.lowercased() {
        case "sha256":
            return data.sha256().map { String(format: "%02x", $0) }.joined()
        case "sha1":
            return data.sha1().map { String(format: "%02x", $0) }.joined()
        case "md5":
            return data.md5().map { String(format: "%02x", $0) }.joined()
        default:
            throw SnugError.unsupportedHashAlgorithm(hashAlgorithm)
        }
    }
    
    private func compressGzip(data: Data) throws -> Data {
        #if canImport(Compression)
        let bufferSize = data.count + (data.count / 10) + 16
        let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { destinationBuffer.deallocate() }
        
        let compressedSize = data.withUnsafeBytes { sourceBuffer -> Int in
            guard let baseAddress = sourceBuffer.baseAddress else {
                return 0
            }
            return compression_encode_buffer(
                destinationBuffer,
                bufferSize,
                baseAddress.assumingMemoryBound(to: UInt8.self),
                data.count,
                nil,
                COMPRESSION_LZFSE
            )
        }
        
        guard compressedSize > 0 else {
            throw SnugError.compressionFailed("Compression returned zero size")
        }
        
        return Data(bytes: destinationBuffer, count: compressedSize)
        #else
        throw SnugError.compressionFailed("Compression not available on this platform")
        #endif
    }
}

// MARK: - Hash Extensions

extension Data {
    func sha256() -> [UInt8] {
        #if canImport(CommonCrypto)
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        self.withUnsafeBytes { bytes in
            _ = CC_SHA256(bytes.baseAddress, CC_LONG(self.count), &hash)
        }
        return hash
        #elseif canImport(CryptoKit)
        let hash = SHA256.hash(data: self)
        return Array(hash)
        #else
        return []
        #endif
    }
    
    func sha1() -> [UInt8] {
        #if canImport(CommonCrypto)
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
        self.withUnsafeBytes { bytes in
            _ = CC_SHA1(bytes.baseAddress, CC_LONG(self.count), &hash)
        }
        return hash
        #elseif canImport(CryptoKit)
        let hash = Insecure.SHA1.hash(data: self)
        return Array(hash)
        #else
        return []
        #endif
    }
    
    func md5() -> [UInt8] {
        #if canImport(CommonCrypto)
        var hash = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
        self.withUnsafeBytes { bytes in
            _ = CC_MD5(bytes.baseAddress, CC_LONG(self.count), &hash)
        }
        return hash
        #elseif canImport(CryptoKit)
        let hash = Insecure.MD5.hash(data: self)
        return Array(hash)
        #else
        return []
        #endif
    }
}

// Helper class for thread-safe error storage
private final class ErrorHolder: @unchecked Sendable {
    var error: Error?
}

