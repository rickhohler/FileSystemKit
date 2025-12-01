// FileSystemKit Core Library
// ARC Compression Adapter

import Foundation

/// ARC compression adapter (.arc, .ark)
/// ARC is a lossless data compression and archival format by System Enhancement Associates (SEA)
/// Popular on BBS systems in the 1980s, predecessor to ZIP format
/// Reference: https://en.wikipedia.org/wiki/ARC_(file_format)
public struct ARCCompressionAdapter: CompressionAdapter {
    public static var format: CompressionFormat { .arc }
    
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
        
        // ARC format uses LZW compression with optional Huffman coding
        // Check for ARC signature
        guard data.count >= 7 else {
            throw CompressionError.invalidFormat
        }
        
        let arcSignature = "Archive"
        let signatureData = arcSignature.data(using: .ascii)!
        
        // Search for ARC signature
        var foundSignature = false
        var signatureOffset = 0
        for offset in 0..<(data.count - signatureData.count) {
            if data.subdata(in: offset..<offset + signatureData.count) == signatureData {
                foundSignature = true
                signatureOffset = offset
                break
            }
        }
        
        guard foundSignature else {
            throw CompressionError.invalidFormat
        }
        
        // ARC file structure:
        // - Signature "Archive" (7 bytes)
        // - File header (11 bytes): filename, size, etc.
        // - Compressed data (LZW)
        
        // Skip signature and header to get compressed data
        // Header is typically 11 bytes after signature
        let headerStart = signatureOffset + signatureData.count
        guard data.count > headerStart + 11 else {
            throw CompressionError.invalidFormat
        }
        
        // Extract filename from header (first 13 bytes after signature)
        let filenameData = data.subdata(in: headerStart..<min(headerStart + 13, data.count))
        let filename = String(data: filenameData, encoding: .ascii)?.trimmingCharacters(in: CharacterSet(charactersIn: "\0 ")) ?? "extracted"
        
        // Compressed data starts after header (11 bytes)
        let compressedDataStart = headerStart + 11
        guard data.count > compressedDataStart else {
            throw CompressionError.invalidFormat
        }
        
        let compressedData = data.subdata(in: compressedDataStart..<data.count)
        
        // Decompress using LZW
        var decompressor = LZWDecompressor(data: compressedData, initialCodeWidth: 9)
        let decompressedData = try decompressor.decompress()
        
        // Create temporary file
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension((filename as NSString).pathExtension.isEmpty ? "arc_extracted" : (filename as NSString).pathExtension)
        
        try decompressedData.write(to: tempURL)
        return tempURL
    }
    
    public static func compress(data: Data, to url: URL) throws {
        // TODO: Implement ARC compression with LZW
        throw CompressionError.notImplemented
    }
}

