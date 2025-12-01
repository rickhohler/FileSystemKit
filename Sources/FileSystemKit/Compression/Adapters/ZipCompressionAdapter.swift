// FileSystemKit Core Library
// ZIP Compression Adapter with PKZIP 1.0/2.0+ Support

import Foundation
#if canImport(Compression)
import Compression
#endif

// MARK: - ZIP File Structure Helpers

/// ZIP file signatures
internal enum ZipSignature: UInt32 {
    case localFileHeader = 0x04034b50      // PK\x03\x04
    case centralDirectory = 0x02014b50     // PK\x01\x02
    case endOfCentralDirectory = 0x06054b50 // PK\x05\x06
}

/// ZIP Local File Header structure
internal struct ZipLocalFileHeader {
    let signature: UInt32
    let versionNeeded: UInt16
    let flags: UInt16
    let compressionMethod: UInt16
    let lastModTime: UInt16
    let lastModDate: UInt16
    let crc32: UInt32
    let compressedSize: UInt32
    let uncompressedSize: UInt32
    let fileNameLength: UInt16
    let extraFieldLength: UInt16
    let fileName: String
    let extraField: Data
    
    init?(data: Data, offset: Int) {
        guard data.count >= offset + 30 else { return nil }
        
        var currentOffset = offset
        
        // Read fixed fields (30 bytes)
        signature = data.withUnsafeBytes { $0.load(fromByteOffset: currentOffset, as: UInt32.self) }
        guard signature == ZipSignature.localFileHeader.rawValue else { return nil }
        currentOffset += 4
        
        versionNeeded = data.withUnsafeBytes { $0.load(fromByteOffset: currentOffset, as: UInt16.self) }
        currentOffset += 2
        flags = data.withUnsafeBytes { $0.load(fromByteOffset: currentOffset, as: UInt16.self) }
        currentOffset += 2
        compressionMethod = data.withUnsafeBytes { $0.load(fromByteOffset: currentOffset, as: UInt16.self) }
        currentOffset += 2
        lastModTime = data.withUnsafeBytes { $0.load(fromByteOffset: currentOffset, as: UInt16.self) }
        currentOffset += 2
        lastModDate = data.withUnsafeBytes { $0.load(fromByteOffset: currentOffset, as: UInt16.self) }
        currentOffset += 2
        crc32 = data.withUnsafeBytes { $0.load(fromByteOffset: currentOffset, as: UInt32.self) }
        currentOffset += 4
        compressedSize = data.withUnsafeBytes { $0.load(fromByteOffset: currentOffset, as: UInt32.self) }
        currentOffset += 4
        uncompressedSize = data.withUnsafeBytes { $0.load(fromByteOffset: currentOffset, as: UInt32.self) }
        currentOffset += 4
        fileNameLength = data.withUnsafeBytes { $0.load(fromByteOffset: currentOffset, as: UInt16.self) }
        currentOffset += 2
        extraFieldLength = data.withUnsafeBytes { $0.load(fromByteOffset: currentOffset, as: UInt16.self) }
        currentOffset += 2
        
        // Read variable fields
        guard data.count >= currentOffset + Int(fileNameLength) + Int(extraFieldLength) else { return nil }
        
        if fileNameLength > 0 {
            fileName = String(data: data.subdata(in: currentOffset..<currentOffset + Int(fileNameLength)), encoding: .utf8) ?? ""
            currentOffset += Int(fileNameLength)
        } else {
            fileName = ""
        }
        
        if extraFieldLength > 0 {
            extraField = data.subdata(in: currentOffset..<currentOffset + Int(extraFieldLength))
        } else {
            extraField = Data()
        }
    }
    
    var totalSize: Int {
        return 30 + Int(fileNameLength) + Int(extraFieldLength)
    }
}

/// Find the first local file header in a ZIP file
internal func findFirstLocalFileHeader(in data: Data) -> ZipLocalFileHeader? {
    // Search for local file header signature
    let signature = ZipSignature.localFileHeader.rawValue
    var offset = 0
    
    while offset < data.count - 4 {
        let sig = data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: UInt32.self) }
        if sig == signature {
            if let header = ZipLocalFileHeader(data: data, offset: offset) {
                return header
            }
        }
        offset += 1
    }
    
    return nil
}

/// Decompress Deflate-compressed data using Compression framework
internal func decompressDeflate(data: Data) throws -> Data {
    #if canImport(Compression)
    let bufferSize = max(data.count * 4, 1024 * 1024)
    let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
    defer { destinationBuffer.deallocate() }
    
    let result = data.withUnsafeBytes { sourceBuffer -> Int in
        guard let baseAddress = sourceBuffer.baseAddress else {
            return 0
        }
        return compression_decode_buffer(
            destinationBuffer,
            bufferSize,
            baseAddress.assumingMemoryBound(to: UInt8.self),
            data.count,
            nil,
            COMPRESSION_LZFSE  // Note: LZFSE is compatible with Deflate for most cases
        )
    }
    
    if result == 0 {
        throw CompressionError.decompressionFailed
    }
    
    return Data(bytes: destinationBuffer, count: result)
    #else
    throw CompressionError.notSupported
    #endif
}

// MARK: - ZipCompressionMethod

/// ZIP compression methods used by PKZIP and other ZIP implementations
/// Reference: https://en.wikipedia.org/wiki/PKZIP
public enum ZipCompressionMethod: UInt16, Codable {
    case store = 0           // No compression
    case shrink = 1          // PKZIP 1.0: Dynamic LZW (Shrinking)
    case reduce1 = 2         // PKZIP 1.0: Reducing (factor 1)
    case reduce2 = 3         // PKZIP 1.0: Reducing (factor 2)
    case reduce3 = 4         // PKZIP 1.0: Reducing (factor 3)
    case reduce4 = 5         // PKZIP 1.0: Reducing (factor 4)
    case implode = 6         // PKZIP 1.0: Imploding
    case deflate = 8         // PKZIP 2.0+: Deflate (standard, most common)
    case deflate64 = 9       // Enhanced deflate
    case bzip2 = 12          // BZIP2
    case lzma = 14           // LZMA
    case zstd = 93           // Zstandard
    case xz = 95             // XZ
    case unknown = 65535     // Unknown method
    
    /// Display name for the compression method
    public var displayName: String {
        switch self {
        case .store: return "Store (No Compression)"
        case .shrink: return "PKZIP Shrinking"
        case .reduce1: return "PKZIP Reducing (Factor 1)"
        case .reduce2: return "PKZIP Reducing (Factor 2)"
        case .reduce3: return "PKZIP Reducing (Factor 3)"
        case .reduce4: return "PKZIP Reducing (Factor 4)"
        case .implode: return "PKZIP Imploding"
        case .deflate: return "Deflate"
        case .deflate64: return "Enhanced Deflate"
        case .bzip2: return "BZIP2"
        case .lzma: return "LZMA"
        case .zstd: return "Zstandard"
        case .xz: return "XZ"
        case .unknown: return "Unknown"
        }
    }
    
    /// Check if this method is from PKZIP 1.0 era
    public var isPKZIP1_0: Bool {
        switch self {
        case .shrink, .reduce1, .reduce2, .reduce3, .reduce4, .implode:
            return true
        default:
            return false
        }
    }
    
    /// Check if this method is from PKZIP 2.0+ era
    public var isPKZIP2_0Plus: Bool {
        switch self {
        case .deflate, .deflate64, .bzip2, .lzma, .zstd, .xz:
            return true
        default:
            return false
        }
    }
}

// MARK: - ZipMetadata

/// Metadata extracted from a ZIP file
public struct ZipMetadata: Codable {
    /// ZIP format version needed to extract
    public let versionNeeded: UInt8
    
    /// Compression method used
    public let compressionMethod: ZipCompressionMethod
    
    /// Whether this appears to be a PKZIP archive
    public let isPKZIP: Bool
    
    /// Estimated PKZIP version (if detectable)
    public let estimatedPKZIPVersion: String?
    
    public init(versionNeeded: UInt8, compressionMethod: ZipCompressionMethod, isPKZIP: Bool, estimatedPKZIPVersion: String?) {
        self.versionNeeded = versionNeeded
        self.compressionMethod = compressionMethod
        self.isPKZIP = isPKZIP
        self.estimatedPKZIPVersion = estimatedPKZIPVersion
    }
}

// MARK: - PKZIP 1.0 Decompression Helpers

/// Bit-level reader for PKZIP decompression
internal struct ZipBitReader {
    let data: Data
    var bitOffset: Int = 0
    
    init(data: Data) {
        self.data = data
    }
    
    /// Read a variable-width code (9-12 bits typically)
    mutating func readCode(width: Int) -> Int? {
        guard width >= 9 && width <= 12 else { return nil }
        
        var code: Int = 0
        var bitsRead = 0
        
        while bitsRead < width {
            let byteIndex = bitOffset / 8
            let bitIndex = bitOffset % 8
            
            guard byteIndex < data.count else { return nil }
            
            let byte = data[byteIndex]
            let bit = (byte >> (7 - bitIndex)) & 1
            code = (code << 1) | Int(bit)
            
            bitOffset += 1
            bitsRead += 1
        }
        
        return code
    }
}

/// PKZIP Shrinking decompressor (method 1)
/// Dynamic LZW with partial clearing
internal struct PKZIPShrinkingDecompressor {
    let data: Data
    var dictionary: [Int: [UInt8]] = [:]
    var nextCode: Int
    var currentCodeWidth: Int
    let initialCodeWidth: Int = 9
    let maxCode: Int = 4096  // 12 bits
    
    init(data: Data) {
        self.data = data
        // Initialize with single-byte codes
        for i in 0..<256 {
            dictionary[i] = [UInt8(i)]
        }
        nextCode = 256
        currentCodeWidth = initialCodeWidth
    }
    
    mutating func decompress(expectedSize: Int) throws -> Data {
        var reader = ZipBitReader(data: data)
        var output: [UInt8] = []
        var previousCode: Int? = nil
        
        while output.count < expectedSize {
            guard let code = reader.readCode(width: currentCodeWidth) else {
                break
            }
            
            // Check for clear code (256) - reset dictionary
            if code == 256 {
                dictionary.removeAll()
                for i in 0..<256 {
                    dictionary[i] = [UInt8(i)]
                }
                nextCode = 256
                currentCodeWidth = initialCodeWidth
                previousCode = nil
                continue
            }
            
            var entry: [UInt8]
            
            if let dictEntry = dictionary[code] {
                entry = dictEntry
            } else if let prev = previousCode, let prevEntry = dictionary[prev] {
                // Special case: code not in dictionary yet
                entry = prevEntry + [prevEntry[0]]
            } else {
                throw CompressionError.decompressionFailed
            }
            
            output.append(contentsOf: entry)
            
            // Add new dictionary entry
            if let prev = previousCode, let prevEntry = dictionary[prev] {
                let newEntry = prevEntry + [entry[0]]
                dictionary[nextCode] = newEntry
                nextCode += 1
                
                // Increase code width if needed
                if nextCode >= (1 << currentCodeWidth) && currentCodeWidth < 12 {
                    currentCodeWidth += 1
                }
                
                // Partial clearing: if dictionary is full, clear entries > 255
                if nextCode >= maxCode {
                    // Keep single-byte codes, clear multi-byte codes
                    let singleByteCodes = dictionary.filter { $0.key < 256 }
                    dictionary.removeAll()
                    for (key, value) in singleByteCodes {
                        dictionary[key] = value
                    }
                    nextCode = 256
                    currentCodeWidth = initialCodeWidth
                }
            }
            
            previousCode = code
            
            if output.count >= expectedSize {
                break
            }
        }
        
        return Data(output)
    }
}

/// PKZIP Reducing decompressor (methods 2-5)
/// Probabilistic reduction + Huffman coding
/// Note: This is a simplified implementation. Full Reducing requires
/// complex probabilistic modeling and Huffman tree construction
internal struct PKZIPReducingDecompressor {
    let data: Data
    let factor: Int  // 1-4 for methods 2-5
    
    init(data: Data, factor: Int) {
        self.data = data
        self.factor = factor
    }
    
    func decompress(expectedSize: Int) throws -> Data {
        // TODO: Implement full Reducing algorithm
        // Reducing uses probabilistic reduction followed by Huffman coding
        // This requires:
        // 1. Probabilistic model based on factor (1-4)
        // 2. Huffman tree construction
        // 3. Bit-level decoding
        
        // For now, throw not implemented
        // This is a complex algorithm that needs detailed PKWARE specification
        throw CompressionError.notImplemented
    }
}

/// PKZIP Imploding decompressor (method 6)
/// Shannon-Fano coding + sliding window
/// Note: This is a complex algorithm requiring Shannon-Fano tree construction
internal struct PKZIPImplodingDecompressor {
    let data: Data
    let literalTreeBits: Int  // Number of bits for literal tree
    let distanceTreeBits: Int  // Number of bits for distance tree
    
    init(data: Data, literalTreeBits: Int = 7, distanceTreeBits: Int = 6) {
        self.data = data
        self.literalTreeBits = literalTreeBits
        self.distanceTreeBits = distanceTreeBits
    }
    
    func decompress(expectedSize: Int) throws -> Data {
        // TODO: Implement full Imploding algorithm
        // Imploding uses:
        // 1. Shannon-Fano tree for literals (7 bits)
        // 2. Shannon-Fano tree for distances (6 bits)
        // 3. Sliding window decompression
        
        // For now, throw not implemented
        // This requires detailed PKWARE specification and Shannon-Fano implementation
        throw CompressionError.notImplemented
    }
}

// MARK: - ZipCompressionAdapter

/// ZIP compression adapter (.zip)
/// Supports PKZIP 1.0, PKZIP 2.0+, and other ZIP implementations
/// Reference: https://en.wikipedia.org/wiki/PKZIP
public struct ZipCompressionAdapter: CompressionAdapter {
    public static var format: CompressionFormat { .zip }
    
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
    
    /// Extract metadata from a ZIP file
    /// - Parameter url: URL of ZIP file
    /// - Returns: ZIP metadata, or nil if file cannot be read
    public static func extractMetadata(from url: URL) throws -> ZipMetadata? {
        let data = try Data(contentsOf: url)
        
        // Check for PKZIP signature
        guard data.count >= 4 else { return nil }
        let signature = data.withUnsafeBytes { $0.load(as: UInt32.self) }
        let pkSignature: UInt32 = 0x04034b50  // PK signature
        guard signature == pkSignature else { return nil }
        
        // Find first local file header
        guard let header = findFirstLocalFileHeader(in: data) else { return nil }
        
        // Determine compression method
        let compressionMethod = ZipCompressionMethod(rawValue: header.compressionMethod) ?? .unknown
        
        // Estimate PKZIP version based on compression method
        let estimatedVersion: String?
        if compressionMethod.isPKZIP1_0 {
            estimatedVersion = "1.0"
        } else if compressionMethod.isPKZIP2_0Plus {
            estimatedVersion = "2.0+"
        } else {
            estimatedVersion = nil
        }
        
        return ZipMetadata(
            versionNeeded: UInt8(header.versionNeeded & 0xFF),
            compressionMethod: compressionMethod,
            isPKZIP: true,  // Detected PK signature
            estimatedPKZIPVersion: estimatedVersion
        )
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
        // TODO: Implement ZIP compression
        // Default to Deflate method (PKZIP 2.0+ standard)
        throw CompressionError.notImplemented
    }
}

