// FileSystemKit Core Library
// StuffIt Compression Adapter

import Foundation

// Note: StuffIt uses ZIP-like structure, so it reuses ZIP helpers
// The ZIP helpers are made internal to allow reuse

// MARK: - StuffItCompressionAdapter

/// StuffIt compression adapter (.sit, .sitx)
public struct StuffItCompressionAdapter: CompressionAdapter {
    public static var format: CompressionFormat { .stuffit }
    
    public static var supportedExtensions: [String] {
        format.extensions
    }
    
    public static func canHandle(url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return supportedExtensions.contains(where: { $0.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ".")) == ext })
    }
    
    public static func isCompressed(url: URL) -> Bool {
        return canHandle(url: url)
    }
    
    public static func decompress(url: URL) throws -> URL {
        let data = try Data(contentsOf: url)
        
        // Find first local file header
        guard let header = findFirstLocalFileHeader(in: data) else {
            throw CompressionError.invalidFormat
        }
        
        // Calculate offset to file data (after header)
        let headerSize = header.totalSize
        let dataOffset = data.startIndex + headerSize
        
        // Extract compressed file data
        let compressedData = data.subdata(in: dataOffset..<dataOffset + Int(header.compressedSize))
        
        // Decompress based on compression method
        let decompressedData: Data
        let compressionMethod = ZipCompressionMethod(rawValue: header.compressionMethod) ?? .unknown
        
        switch compressionMethod {
        case .store:
            // No compression - copy data as-is
            decompressedData = compressedData
        
        case .deflate, .deflate64:
            // Deflate compression - use Compression framework
            decompressedData = try decompressDeflate(data: compressedData)
        
        case .shrink:
            // PKZIP Shrinking (method 1) - Dynamic LZW with partial clearing
            var shrinker = PKZIPShrinkingDecompressor(data: compressedData)
            decompressedData = try shrinker.decompress(expectedSize: Int(header.uncompressedSize))
        
        case .reduce1:
            // PKZIP Reducing factor 1 (method 2)
            let reducer = PKZIPReducingDecompressor(data: compressedData, factor: 1)
            decompressedData = try reducer.decompress(expectedSize: Int(header.uncompressedSize))
        
        case .reduce2:
            // PKZIP Reducing factor 2 (method 3)
            let reducer = PKZIPReducingDecompressor(data: compressedData, factor: 2)
            decompressedData = try reducer.decompress(expectedSize: Int(header.uncompressedSize))
        
        case .reduce3:
            // PKZIP Reducing factor 3 (method 4)
            let reducer = PKZIPReducingDecompressor(data: compressedData, factor: 3)
            decompressedData = try reducer.decompress(expectedSize: Int(header.uncompressedSize))
        
        case .reduce4:
            // PKZIP Reducing factor 4 (method 5)
            let reducer = PKZIPReducingDecompressor(data: compressedData, factor: 4)
            decompressedData = try reducer.decompress(expectedSize: Int(header.uncompressedSize))
        
        case .implode:
            // PKZIP Imploding (method 6) - Shannon-Fano + sliding window
            let imploder = PKZIPImplodingDecompressor(data: compressedData)
            decompressedData = try imploder.decompress(expectedSize: Int(header.uncompressedSize))
        
        default:
            throw CompressionError.notImplemented
        }
        
        // Verify decompressed size matches expected
        guard decompressedData.count == Int(header.uncompressedSize) else {
            throw CompressionError.decompressionFailed
        }
        
        // Create temporary file for decompressed data
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(header.fileName.isEmpty ? "decompressed" : (header.fileName as NSString).pathExtension)
        
        try decompressedData.write(to: tempURL)
        return tempURL
    }
    
    public static func compress(data: Data, to url: URL) throws {
        // TODO: Implement StuffIt compression
        throw CompressionError.notImplemented
    }
}
