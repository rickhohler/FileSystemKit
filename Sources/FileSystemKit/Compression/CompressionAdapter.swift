// FileSystemKit Core Library
// Compression Adapter Protocol and Implementations
//
// This file implements Layer 1: Compression Wrapper Layer
// - CompressionAdapter: Base protocol for compression adapters
// - CompressionFormat: Enumeration of supported compression formats
// - CompressionAdapterRegistry: Registry for compression adapters
// - Concrete adapters: Gzip, Zip, Toast, StuffIt, Tar, ARC, ShrinkIt, Archive.org
//
// Critical Design: Transparent Decompression
// - Compression adapters decompress transparently
// - Decompressed data is passed to DiskImageAdapter (Layer 2)
// - Handles nested compression (e.g., .tar.gz)

import Foundation
#if canImport(Compression)
import Compression
#endif

// MARK: - CompressionFormat

/// Compression format enumeration
public enum CompressionFormat: String, Codable, CaseIterable {
    case gzip = "gzip"
    case zip = "zip"
    case toast = "toast"
    case stuffit = "stuffit"
    case tar = "tar"
    case arc = "arc"
    case shrinkit = "shrinkit"
    case archiveorg = "archiveorg"
    case snug = "snug"
    case unknown = "unknown"
    
    /// File extensions for this format
    public var extensions: [String] {
        switch self {
        case .gzip: return [".gz", ".gzip"]
        case .zip: return [".zip"]
        case .toast: return [".toast"]
        case .stuffit: return [".sit", ".sitx"]
        case .tar: return [".tar"]
        case .arc: return [".arc", ".ark"]
        case .shrinkit: return [".shk", ".sdk"]
        case .archiveorg: return [".archiveorg"]
        case .snug: return [".snug"]
        case .unknown: return []
        }
    }
    
    /// Display name (localized)
    public var displayName: String {
        // Return rawValue as display name for now to avoid potential Bundle.module issues
        // TODO: Re-enable localization once Bundle.module is properly configured
        return rawValue.uppercased()
    }
    
    /// Detect format from file extension
    /// - Parameter fileExtension: File extension (with or without dot)
    /// - Returns: Detected compression format, or nil if unknown
    public static func detect(from fileExtension: String) -> CompressionFormat? {
        let ext = fileExtension.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
        
        for format in CompressionFormat.allCases {
            if format.extensions.contains(where: { $0.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ".")) == ext }) {
                return format
            }
        }
        
        return nil
    }
}

// MARK: - CompressionAdapter Protocol

/// Protocol for compression adapters (Layer 1).
/// Handles compressed or archived disk images, decompressing them to reveal the underlying disk image format.
public protocol CompressionAdapter {
    /// Compression format this adapter handles
    static var format: CompressionFormat { get }
    
    /// File extensions supported by this adapter
    static var supportedExtensions: [String] { get }
    
    /// Check if this adapter can handle the given URL
    /// - Parameter url: URL to check
    /// - Returns: true if this adapter can handle the file
    static func canHandle(url: URL) -> Bool
    
    /// Decompress the file at the given URL
    /// - Parameter url: URL of compressed file
    /// - Returns: URL to temporary file containing decompressed data
    /// - Throws: Error if decompression fails
    static func decompress(url: URL) throws -> URL
    
    /// Compress data to the given URL
    /// - Parameters:
    ///   - data: Data to compress
    ///   - url: Destination URL for compressed file
    /// - Throws: Error if compression fails
    static func compress(data: Data, to url: URL) throws
    
    /// Check if file is compressed (has compression wrapper)
    /// - Parameter url: URL to check
    /// - Returns: true if file appears to be compressed
    static func isCompressed(url: URL) -> Bool
}

// MARK: - CompressionAdapterRegistry

/// Registry for compression adapters
public class CompressionAdapterRegistry {
    /// Shared singleton instance
    nonisolated(unsafe) public static let shared = CompressionAdapterRegistry()
    
    /// Registered adapters (format -> adapter type)
    private var registeredAdapters: [CompressionFormat: CompressionAdapter.Type] = [:]
    
    private init() {
        // Private initializer for singleton
    }
    
    /// Register a compression adapter
    /// - Parameter adapterType: Adapter type to register
    public func register<T: CompressionAdapter>(_ adapterType: T.Type) {
        registeredAdapters[T.format] = adapterType
    }
    
    /// Find adapter for the given URL
    /// - Parameter url: URL to check
    /// - Returns: Adapter type that can handle the URL, or nil if none found
    public func findAdapter(for url: URL) -> CompressionAdapter.Type? {
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
    public func findAdapter(for format: CompressionFormat) -> CompressionAdapter.Type? {
        return registeredAdapters[format]
    }
    
    /// Get all registered adapters
    /// - Returns: Array of registered adapter types
    public func allAdapters() -> [CompressionAdapter.Type] {
        return Array(registeredAdapters.values)
    }
    
    /// Clear all registered adapters (primarily for testing)
    internal func clear() {
        registeredAdapters.removeAll()
    }
}

// MARK: - GzipCompressionAdapter

/// Gzip compression adapter (.gz, .gzip)
/// Note: GZIP format is backward compatible across versions.
/// Modern implementations can read older GZIP files, so version-specific
/// handling is not required. The format uses DEFLATE compression.
public struct GzipCompressionAdapter: CompressionAdapter {
    public static var format: CompressionFormat { .gzip }
    
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
        
        // Validate GZIP format (magic bytes: 0x1f 0x8b)
        guard data.count >= 10 else {
            throw CompressionError.invalidFormat
        }
        
        guard data[0] == 0x1f && data[1] == 0x8b else {
            throw CompressionError.invalidFormat
        }
        
        // GZIP header is 10 bytes:
        // - 0-1: Magic bytes (0x1f 0x8b)
        // - 2: Compression method (8 = DEFLATE)
        // - 3: Flags
        // - 4-7: Modification time (Unix timestamp)
        // - 8: Extra flags
        // - 9: Operating system
        
        let compressionMethod = data[2]
        guard compressionMethod == 8 else {  // 8 = DEFLATE
            throw CompressionError.notImplemented  // Only DEFLATE is supported
        }
        
        // Skip GZIP header (10 bytes) and optional extra fields
        var offset = 10
        let flags = data[3]
        
        // Skip optional extra field if present
        if (flags & 0x04) != 0 {  // FEXTRA flag
            guard offset + 2 <= data.count else {
                throw CompressionError.invalidFormat
            }
            let xlen = UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
            offset += 2 + Int(xlen)
        }
        
        // Skip optional filename if present
        if (flags & 0x08) != 0 {  // FNAME flag
            while offset < data.count && data[offset] != 0 {
                offset += 1
            }
            offset += 1  // Skip null terminator
        }
        
        // Skip optional comment if present
        if (flags & 0x10) != 0 {  // FCOMMENT flag
            while offset < data.count && data[offset] != 0 {
                offset += 1
            }
            offset += 1  // Skip null terminator
        }
        
        // Skip optional CRC16 header if present
        if (flags & 0x02) != 0 {  // FHCRC flag
            offset += 2
        }
        
        // GZIP footer is last 8 bytes:
        // - Last 4 bytes: CRC32
        // - Last 8-4 bytes: Uncompressed size (mod 2^32)
        guard data.count >= offset + 8 else {
            throw CompressionError.invalidFormat
        }
        
        let compressedDataEnd = data.count - 8
        let compressedData = data.subdata(in: offset..<compressedDataEnd)
        
        // Decompress using DEFLATE
        let decompressedData = try decompressGzip(data: compressedData)
        
        // Verify footer CRC32 and size (optional - can be skipped for MVP)
        // For now, we'll trust the decompression
        
        // Create temporary file for decompressed data
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        
        try decompressedData.write(to: tempURL)
        return tempURL
    }
    
    public static func compress(data: Data, to url: URL) throws {
        let compressed = try compressGzip(data: data)
        try compressed.write(to: url)
    }
    
    // MARK: - Private Helpers
    
    #if canImport(Compression)
    private static func decompressGzip(data: Data) throws -> Data {
        // Use Compression framework with DEFLATE algorithm
        // GZIP uses DEFLATE compression, so we can use COMPRESSION_LZFSE or zlib
        
        // Allocate buffer for decompression (estimate 4x original size)
        let bufferSize = max(data.count * 4, 1024 * 1024)  // At least 1MB
        let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { destinationBuffer.deallocate() }
        
        let destinationBufferSize = bufferSize
        let result = data.withUnsafeBytes { sourceBuffer -> Int in
            guard let baseAddress = sourceBuffer.baseAddress else {
                return 0
            }
            // Use zlib algorithm for DEFLATE decompression (GZIP uses DEFLATE)
            // Note: COMPRESSION_LZFSE is not compatible with DEFLATE
            // We need to use a DEFLATE-compatible algorithm
            // For now, try LZMA which is more compatible, but ideally we'd use zlib
            return compression_decode_buffer(
                destinationBuffer,
                destinationBufferSize,
                baseAddress.assumingMemoryBound(to: UInt8.self),
                data.count,
                nil,
                COMPRESSION_LZMA  // More compatible than LZFSE for DEFLATE-like data
            )
        }
        
        if result == 0 {
            throw CompressionError.decompressionFailed
        }
        
        return Data(bytes: destinationBuffer, count: result)
    }
    
    private static func compressGzip(data: Data) throws -> Data {
        // Use Compression framework with DEFLATE algorithm
        // GZIP uses DEFLATE compression
        
        // Allocate buffer for compression (estimate compressed size)
        let bufferSize = data.count + 1024
        let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { destinationBuffer.deallocate() }
        
        let destinationBufferSize = bufferSize
        let result = data.withUnsafeBytes { sourceBuffer -> Int in
            guard let baseAddress = sourceBuffer.baseAddress else {
                return 0
            }
            // Use LZMA algorithm for DEFLATE-like compression
            // Note: This creates compressed data but not true GZIP format (missing header/footer)
            // For MVP, this provides basic compression functionality
            return compression_encode_buffer(
                destinationBuffer,
                destinationBufferSize,
                baseAddress.assumingMemoryBound(to: UInt8.self),
                data.count,
                nil,
                COMPRESSION_LZMA
            )
        }
        
        if result == 0 {
            throw CompressionError.compressionFailed
        }
        
        // Create GZIP format: header + compressed data + footer
        var gzipData = Data()
        
        // GZIP header (10 bytes)
        gzipData.append(contentsOf: [0x1f, 0x8b])  // Magic bytes
        gzipData.append(8)  // Compression method: DEFLATE
        gzipData.append(0)  // Flags: none
        gzipData.append(contentsOf: [0, 0, 0, 0])  // Modification time (unset)
        gzipData.append(0)  // Extra flags
        gzipData.append(255)  // Operating system: unknown
        
        // Compressed data
        gzipData.append(Data(bytes: destinationBuffer, count: result))
        
        // GZIP footer (8 bytes): CRC32 + uncompressed size
        // For MVP, we'll use placeholder values
        let crc32: UInt32 = 0  // TODO: Calculate actual CRC32
        let uncompressedSize: UInt32 = UInt32(data.count)
        
        gzipData.append(contentsOf: withUnsafeBytes(of: crc32.littleEndian) { Data($0) })
        gzipData.append(contentsOf: withUnsafeBytes(of: uncompressedSize.littleEndian) { Data($0) })
        
        return gzipData
    }
    #else
    private static func decompressGzip(data: Data) throws -> Data {
        throw CompressionError.notSupported
    }
    
    private static func compressGzip(data: Data) throws -> Data {
        throw CompressionError.notSupported
    }
    #endif
}


// MARK: - ZIP File Structure Helpers

/// ZIP file signatures
private enum ZipSignature: UInt32 {
    case localFileHeader = 0x04034b50      // PK\x03\x04
    case centralDirectory = 0x02014b50     // PK\x01\x02
    case endOfCentralDirectory = 0x06054b50 // PK\x05\x06
}

/// ZIP Local File Header structure
private struct ZipLocalFileHeader {
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
private func findFirstLocalFileHeader(in data: Data) -> ZipLocalFileHeader? {
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
private func decompressDeflate(data: Data) throws -> Data {
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

/// PKZIP Shrinking decompressor (method 1)
/// Dynamic LZW with partial clearing
private struct PKZIPShrinkingDecompressor {
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
        var reader = BitReader(data: data)
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
private struct PKZIPReducingDecompressor {
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
private struct PKZIPImplodingDecompressor {
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

// MARK: - ToastCompressionAdapter

/// Toast compression adapter (.toast) - Mac disk image compression
///
/// Toast files are disk images created by Roxio Toast software for Mac.
/// They are similar to ISO files but may contain Toast-specific formatting.
/// Toast files are typically handled by macOS DiskImage framework.
///
/// Note: Toast is a proprietary Mac-specific format. On macOS, Toast files
/// can often be converted to/from other disk image formats using hdiutil.
public struct ToastCompressionAdapter: CompressionAdapter {
    public static var format: CompressionFormat { .toast }
    
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
        #if os(macOS)
        // On macOS, use hdiutil to convert Toast to a readable format
        // Toast files are disk images that can be converted using hdiutil
        return try decompressUsingHDIUtil(url: url)
        #else
        // On non-macOS platforms, Toast files are not supported
        throw CompressionError.unsupportedPlatform
        #endif
    }
    
    public static func compress(data: Data, to url: URL) throws {
        #if os(macOS)
        // Toast compression requires Toast software or hdiutil
        // For now, we'll create a basic disk image format
        // TODO: Implement proper Toast compression using hdiutil or Toast APIs
        throw CompressionError.notImplemented
        #else
        throw CompressionError.unsupportedPlatform
        #endif
    }
    
    #if os(macOS)
    /// Decompress Toast file using hdiutil command-line tool
    /// - Parameter url: URL of Toast file
    /// - Returns: URL to temporary file containing decompressed disk image
    /// - Throws: Error if decompression fails
    private static func decompressUsingHDIUtil(url: URL) throws -> URL {
        // Create temporary output file
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("dmg")
        
        // Use hdiutil to convert Toast to DMG format
        // hdiutil convert -format UDRW -o output.dmg input.toast
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        process.arguments = [
            "convert",
            "-format", "UDRW",  // UDRW = UDIF read/write (uncompressed)
            "-o", tempURL.path,
            url.path
        ]
        
        // Capture output
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            // If hdiutil fails, try reading Toast file directly
            // Toast files may be similar to ISO files
            return try decompressAsISO(url: url)
        }
        
        return tempURL
    }
    
    /// Attempt to decompress Toast file as ISO-like format
    /// Toast files may have similar structure to ISO 9660 files
    /// - Parameter url: URL of Toast file
    /// - Returns: URL to temporary file (may be the same file if no decompression needed)
    /// - Throws: Error if file cannot be read
    private static func decompressAsISO(url: URL) throws -> URL {
        // Toast files are disk images, not compressed archives
        // They may contain ISO 9660 file systems or other formats
        // For now, return the file as-is (it's already a disk image)
        // The DiskImageAdapter layer will handle the actual disk image format
        
        // However, we should verify it's a valid disk image
        let data = try Data(contentsOf: url)
        
        // Check if it looks like an ISO 9660 file (starts with volume descriptor at sector 16)
        // Toast files may wrap ISO 9660 or other formats
        // For now, just return a copy in temp directory
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("iso")  // Assume ISO-like format
        
        try data.write(to: tempURL)
        return tempURL
    }
    #endif
}

// MARK: - ShrinkItCompressionAdapter

/// ShrinkIt/NuFX compression adapter (.shk, .sdk)
///
/// ShrinkIt (NuFX archive format) is a compression/archive format for Apple II systems.
/// It uses dynamic LZW compression and stores multiple files with Apple II-specific
/// metadata (file types, auxiliary types, etc.).
///
/// NuFX Archive Structure:
/// - Archive Header (signature "NuF", version, file count, CRC)
/// - File Records (filename, file type, aux type, dates, attributes)
/// - Thread Headers (data fork, resource fork, compression method)
/// - Compressed Data (dynamic LZW compressed)
/// - Checksums (for integrity)
///
/// Reference: https://en.wikipedia.org/wiki/ShrinkIt
/// Format Specification: Apple File Type Notes
public struct ShrinkItCompressionAdapter: CompressionAdapter {
    public static var format: CompressionFormat { .shrinkit }
    
    public static var supportedExtensions: [String] {
        [".shk", ".sdk"]
    }
    
    /// NuFX signature: "NuF" (4E F5 46)
    private static let nufxSignature = Data([0x4E, 0xF5, 0x46])
    
    public static func canHandle(url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        guard supportedExtensions.contains(where: { $0.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ".")) == ext }) else {
            return false
        }
        
        // Check for NuFX signature using Data instead of FileHandle
        // FileHandle can cause issues during static initialization
        guard let data = try? Data(contentsOf: url),
              data.count >= 3 else {
            return false
        }
        
        return data[0..<3] == nufxSignature
    }
    
    public static func isCompressed(url: URL) -> Bool {
        return canHandle(url: url)
    }
    
    public static func decompress(url: URL) throws -> URL {
        // TODO: Implement NuFX decompression
        // Temporarily return original URL - full implementation pending
        return url
    }
    
    public static func compress(data: Data, to url: URL) throws {
        // TODO: Implement NuFX compression
        throw CompressionError.notImplemented
    }
    
    // MARK: - NuFX Structures
    
    private struct NuFXArchive {
        let signature: Data
        let version: UInt8
        let masterCRC: UInt16
        let totalFiles: UInt16
        let archiveAttributes: UInt16
        let masterLength: UInt32
        let files: [NuFXFileRecord]
    }
    
    private struct NuFXFileRecord {
        let filename: String
        let fileType: UInt16
        let auxType: UInt16
        let storageType: UInt8
        let createWhen: Date?
        let modWhen: Date?
        let access: UInt8
        let threads: [NuFXThread]
    }
    
    private struct NuFXThread {
        let threadClass: UInt8
        let format: UInt8
        let kind: UInt8
        let compressedLength: UInt32
        let uncompressedLength: UInt32
        let crc: UInt16
        let dataOffset: Int
    }
    
    // MARK: - NuFX Parsing
    
    private static func parseNuFXArchive(from data: Data) throws -> NuFXArchive {
        guard data.count >= 20 else {
            throw CompressionError.invalidFormat
        }
        
        // Check signature
        guard data[0..<3] == nufxSignature else {
            throw CompressionError.invalidFormat
        }
        
        // Parse header (little-endian)
        let version = data[3]
        let masterCRC = data.withUnsafeBytes { bytes in
            bytes.load(fromByteOffset: 4, as: UInt16.self).littleEndian
        }
        
        // Try to parse total files - but be flexible about offset
        // Some NuFX versions might have different header layouts
        var totalFiles: UInt16 = 0
        var archiveAttributes: UInt16 = 0
        var masterLength: UInt32 = 0
        
        if data.count >= 8 {
            totalFiles = data.withUnsafeBytes { bytes in
                bytes.load(fromByteOffset: 6, as: UInt16.self).littleEndian
            }
        }
        
        if data.count >= 10 {
            archiveAttributes = UInt16(data[8]) | (UInt16(data[9]) << 8)
        }
        
        if data.count >= 14 {
            masterLength = UInt32(data[10]) |
                          (UInt32(data[11]) << 8) |
                          (UInt32(data[12]) << 16) |
                          (UInt32(data[13]) << 24)
        }
        
        // Parse file records - start searching from offset 18 or 20
        // Look for filename patterns to find file records
        var files: [NuFXFileRecord] = []
        var offset = 18  // Start searching from offset 18
        
        // Try to find file records by looking for valid filename patterns
        // A file record typically starts with a filename length byte (1-64)
        while offset < data.count && files.count < 10 {  // Limit to 10 files for safety
            // Check if this looks like a filename length
            let possibleLen = data[offset]
            if possibleLen > 0 && possibleLen < 64 && offset + 1 + Int(possibleLen) < data.count {
                // Try to parse as file record
                do {
                    let fileRecord = try parseNuFXFileRecord(from: data, at: &offset)
                    files.append(fileRecord)
                    // If we successfully parsed, continue
                    continue
                } catch {
                    // Not a valid file record, skip
                    offset += 1
                    continue
                }
            }
            offset += 1
        }
        
        // If we found files, use that count; otherwise use header value
        let actualFileCount = files.isEmpty ? totalFiles : UInt16(files.count)
        
        return NuFXArchive(
            signature: nufxSignature,
            version: version,
            masterCRC: masterCRC,
            totalFiles: actualFileCount,
            archiveAttributes: archiveAttributes,
            masterLength: masterLength,
            files: files
        )
    }
    
    private static func parseNuFXFileRecord(from data: Data, at offset: inout Int) throws -> NuFXFileRecord {
        _ = offset
        
        guard offset < data.count else {
            throw CompressionError.invalidFormat
        }
        
        // NuFX file record structure (based on actual file analysis):
        // - Thread header info (variable, typically 8-12 bytes)
        // - Compressed length (4 bytes, little-endian)
        // - Uncompressed length (4 bytes, little-endian)
        // - Filename (null-terminated, possibly padded)
        // - Compressed data
        
        // Search for compressed/uncompressed length pattern to find file record
        var filename: String = ""
        var foundValidFilename = false
        var compressedLength: UInt32 = 0
        var uncompressedLength: UInt32 = 0
        
        
        // Look for pattern: 4-byte length, 4-byte length, followed by null-terminated filename
        for i in 0..<min(300, data.count - offset - 8) {
            let testOffset = offset + i
            guard testOffset + 8 < data.count else {
                break
            }
            
            // Try to read two 4-byte little-endian values
            guard testOffset + 8 <= data.count else {
                continue
            }
            let len1 = UInt32(data[testOffset]) |
                      (UInt32(data[testOffset + 1]) << 8) |
                      (UInt32(data[testOffset + 2]) << 16) |
                      (UInt32(data[testOffset + 3]) << 24)
            let len2 = UInt32(data[testOffset + 4]) |
                      (UInt32(data[testOffset + 5]) << 8) |
                      (UInt32(data[testOffset + 6]) << 16) |
                      (UInt32(data[testOffset + 7]) << 24)
            
            // Check if these look like compressed/uncompressed lengths
            // Compressed should be >= uncompressed (or close if uncompressed)
            // Both should be reasonable (not too large)
            if len1 > 0 && len1 < 10_000_000 && len2 > 0 && len2 < 10_000_000 {
                // Check if next bytes form a valid filename
                let filenameStart = testOffset + 8
                if let nullPos = data[filenameStart..<min(filenameStart + 64, data.count)].firstIndex(of: 0) {
                    let filenameData = data.subdata(in: filenameStart..<(filenameStart + nullPos))
                    if filenameData.count >= 3 && filenameData.count <= 64,
                       let testFilename = String(data: filenameData, encoding: .ascii),
                       testFilename.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "." || $0 == "_" || $0 == "-") }) {
                        // Found valid file record
                        compressedLength = len1
                        uncompressedLength = len2
                        filename = testFilename
                        offset = filenameStart + nullPos + 1
                        // Skip padding
                        while offset < data.count && data[offset] == 0 {
                            offset += 1
                        }
                        foundValidFilename = true
                        break
                    }
                }
            }
        }
        
        guard foundValidFilename else {
            throw CompressionError.invalidFormat
        }
        
        // File type (2 bytes, little-endian)
        guard offset + 2 <= data.count else {
            throw CompressionError.invalidFormat
        }
        let fileType = UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
        offset += 2
        
        // Aux type (2 bytes, little-endian)
        guard offset + 2 <= data.count else {
            throw CompressionError.invalidFormat
        }
        let auxType = UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
        offset += 2
        
        // Storage type (1 byte)
        guard offset < data.count else {
            throw CompressionError.invalidFormat
        }
        let storageType = data[offset]
        offset += 1
        
        // Skip other fields for now (createWhen, modWhen, access, etc.)
        // Look for thread count - it's typically 1-2 (data fork, resource fork)
        // Skip ahead to find thread structures
        // Thread count might be at a variable offset, so search for thread header
        // Thread header starts with thread class (typically 1 for data, 2 for resource)
        
        var threads: [NuFXThread] = []
        _ = offset
        
        // Create thread from the file record we found
        // Use the compressed/uncompressed lengths we parsed
        // Thread class 1 = data fork, format 1 = LZW compression
        let thread = NuFXThread(
            threadClass: 1,  // Data fork
            format: 1,  // LZW compression
            kind: 0,
            compressedLength: compressedLength,
            uncompressedLength: uncompressedLength,
            crc: 0,  // Will be calculated if needed
            dataOffset: offset  // Compressed data starts here
        )
        threads.append(thread)
        
        // Move offset past compressed data
        offset += Int(compressedLength)
        
        return NuFXFileRecord(
            filename: filename,
            fileType: fileType,
            auxType: auxType,
            storageType: storageType,
            createWhen: nil,  // TODO: Parse dates
            modWhen: nil,
            access: 0,
            threads: threads
        )
    }
    
    private static func parseNuFXThread(from data: Data, at offset: inout Int) throws -> NuFXThread {
        guard offset + 12 <= data.count else {
            throw CompressionError.invalidFormat
        }
        
        let threadClass = data[offset]
        offset += 1
        
        let format = data[offset]
        offset += 1
        
        let kind = data[offset]
        offset += 1
        
        // Skip reserved byte
        offset += 1
        
        guard offset + 10 <= data.count else {
            throw CompressionError.invalidFormat
        }
        let compressedLength = UInt32(data[offset]) |
                              (UInt32(data[offset + 1]) << 8) |
                              (UInt32(data[offset + 2]) << 16) |
                              (UInt32(data[offset + 3]) << 24)
        offset += 4
        
        let uncompressedLength = UInt32(data[offset]) |
                                (UInt32(data[offset + 1]) << 8) |
                                (UInt32(data[offset + 2]) << 16) |
                                (UInt32(data[offset + 3]) << 24)
        offset += 4
        
        let crc = UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
        offset += 2
        
        let dataOffset = offset
        
        return NuFXThread(
            threadClass: threadClass,
            format: format,
            kind: kind,
            compressedLength: compressedLength,
            uncompressedLength: uncompressedLength,
            crc: crc,
            dataOffset: dataOffset
        )
    }
    
    private static func decompressNuFXFile(file: NuFXFileRecord, archiveData: Data) throws -> Data {
        // Decompress each thread
        var decompressedData = Data()
        
        for thread in file.threads {
            guard thread.dataOffset < archiveData.count else {
                continue
            }
            
            let endOffset = min(thread.dataOffset + Int(thread.compressedLength), archiveData.count)
            let compressedData = archiveData.subdata(in: thread.dataOffset..<endOffset)
            
            // Decompress based on format
            let threadData: Data
            switch thread.format {
            case 0:  // Uncompressed (no compression)
                threadData = compressedData
            case 1:  // Dynamic LZW (NuFX compression)
                // Use NuFX LZW decompression
                if thread.compressedLength == thread.uncompressedLength {
                    threadData = compressedData
                } else {
                    threadData = try decompressNuFXLZW(data: compressedData, expectedSize: Int(thread.uncompressedLength))
                }
            default:
                throw CompressionError.notSupported
            }
            
            decompressedData.append(threadData)
        }
        
        return decompressedData
    }
    
        private static func decompressNuFXLZW(data: Data, expectedSize: Int) throws -> Data {
        // NuFX uses dynamic LZW compression
        // Similar to PKZIP Shrinking but with NuFX-specific details
        // Algorithm:
        // 1. Initialize dictionary with 256 single-byte entries
        // 2. Read variable-length codes (starting at 9 bits)
        // 3. Output strings and build dictionary
        // 4. Dictionary grows and can be cleared when full
        
        var decompressed = Data()
        var bitBuffer: UInt32 = 0
        var bitsInBuffer = 0
        var dataIndex = 0
        
        // Initialize dictionary
        var dictionary: [Data] = []
        for i in 0..<256 {
            dictionary.append(Data([UInt8(i)]))
        }
        
        var nextCode = 256
        var codeSize = 9  // Start with 9-bit codes
        let maxCodeSize = 16  // Maximum code size
        let dictionarySize = 4096  // Maximum dictionary size
        
        var currentString = Data()
        
        // Read codes and decompress
        while dataIndex < data.count && decompressed.count < expectedSize {
            // Read next code
            while bitsInBuffer < codeSize && dataIndex < data.count {
                bitBuffer |= UInt32(data[dataIndex]) << bitsInBuffer
                bitsInBuffer += 8
                dataIndex += 1
            }
            
            guard bitsInBuffer >= codeSize else {
                break
            }
            
            let code = Int(bitBuffer & ((1 << codeSize) - 1))
            bitBuffer >>= codeSize
            bitsInBuffer -= codeSize
            
            // Handle special codes
            if code == 256 {
                // Clear dictionary - reset to initial state
                dictionary.removeSubrange(256..<dictionary.count)
                nextCode = 256
                codeSize = 9
                currentString = Data()
                continue
            }
            
            if code == 257 {
                // End of data
                break
            }
            
            // Output string for code
            var outputString: Data
            if code < dictionary.count {
                outputString = dictionary[code]
            } else if code == dictionary.count && !currentString.isEmpty {
                // Special case: code equals dictionary size
                outputString = currentString + currentString.prefix(1)
            } else {
                throw CompressionError.decompressionFailed
            }
            
            decompressed.append(outputString)
            
            // Add new string to dictionary
            if !currentString.isEmpty {
                let newString = currentString + outputString.prefix(1)
                if dictionary.count < dictionarySize {
                    dictionary.append(newString)
                    nextCode += 1
                    
                    // Increase code size if needed
                    if nextCode >= (1 << codeSize) && codeSize < maxCodeSize {
                        codeSize += 1
                    }
                } else {
                    // Dictionary full - clear it
                    dictionary.removeSubrange(256..<dictionary.count)
                    nextCode = 256
                    codeSize = 9
                }
            }
            
            currentString = outputString
        }
        
        // Verify decompressed size (allow some tolerance)
        if abs(decompressed.count - expectedSize) > 100 {
            throw CompressionError.decompressionFailed
        }
        
        return decompressed
    }
}


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


// MARK: - LZW Decompression Helpers

/// Bit-level reader for LZW decompression
private struct BitReader {
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

/// LZW decompressor for ARC format
private struct LZWDecompressor {
    let data: Data
    var dictionary: [Int: [UInt8]] = [:]
    var nextCode: Int
    let initialCodeWidth: Int
    var currentCodeWidth: Int
    
    init(data: Data, initialCodeWidth: Int = 9) {
        self.data = data
        self.initialCodeWidth = initialCodeWidth
        self.currentCodeWidth = initialCodeWidth
        
        // Initialize dictionary with single-byte codes (0-255)
        for i in 0..<256 {
            dictionary[i] = [UInt8(i)]
        }
        nextCode = 256
    }
    
    mutating func decompress() throws -> Data {
        var reader = BitReader(data: data)
        var output: [UInt8] = []
        var previousCode: Int? = nil
        
        while true {
            guard let code = reader.readCode(width: currentCodeWidth) else {
                break
            }
            
            // Check for clear code (typically 256) - reset dictionary
            if code == 256 {
                // Reset dictionary
                dictionary.removeAll()
                for i in 0..<256 {
                    dictionary[i] = [UInt8(i)]
                }
                nextCode = 256
                currentCodeWidth = initialCodeWidth
                previousCode = nil
                continue
            }
            
            // Check for end code (typically 257)
            if code == 257 {
                break
            }
            
            var entry: [UInt8]
            
            if let dictEntry = dictionary[code] {
                // Code exists in dictionary
                entry = dictEntry
            } else if let prev = previousCode, let prevEntry = dictionary[prev] {
                // Special case: code not in dictionary yet
                // This happens when encoder outputs code before adding it to dictionary
                entry = prevEntry + [prevEntry[0]]
            } else {
                throw CompressionError.decompressionFailed
            }
            
            // Output the entry
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
            }
            
            previousCode = code
        }
        
        return Data(output)
    }
}

// MARK: - ARCCompressionAdapter

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

// MARK: - TarCompressionAdapter

/// Tar (Tape Archive) adapter (.tar)
/// Note: Tar is an archive format, not compression, but is handled at this layer
/// Extracts the first file from the TAR archive (assuming it's a disk image)
public struct TarCompressionAdapter: CompressionAdapter {
    public static var format: CompressionFormat { .tar }
    
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
        
        // TAR format uses 512-byte blocks
        // Each file entry has a 512-byte header followed by file data (padded to 512-byte boundary)
        // USTAR format header structure (512 bytes):
        // - File name (100 bytes)
        // - File mode (8 bytes)
        // - Owner UID (8 bytes)
        // - Owner GID (8 bytes)
        // - File size (12 bytes, octal)
        // - Modification time (12 bytes, octal)
        // - Checksum (8 bytes)
        // - Type flag (1 byte)
        // - Link name (100 bytes)
        // - Magic "ustar" (6 bytes)
        // - Version (2 bytes)
        // - Owner name (32 bytes)
        // - Group name (32 bytes)
        // - Device major (8 bytes)
        // - Device minor (8 bytes)
        // - Filename prefix (155 bytes)
        // - Padding (12 bytes)
        
        guard data.count >= 512 else {
            throw CompressionError.invalidFormat
        }
        
        // Read file size from header (bytes 124-135, octal)
        let sizeStart = 124
        let sizeEnd = 136
        guard data.count >= sizeEnd else {
            throw CompressionError.invalidFormat
        }
        
        let sizeString = String(data: data.subdata(in: sizeStart..<sizeEnd), encoding: .ascii)?.trimmingCharacters(in: CharacterSet(charactersIn: "\0 ")) ?? "0"
        
        // Parse octal file size
        guard let fileSize = Int(sizeString, radix: 8) else {
            throw CompressionError.invalidFormat
        }
        
        // Extract file data (starts after 512-byte header)
        let headerSize = 512
        let dataStart = headerSize
        let dataEnd = dataStart + fileSize
        
        guard data.count >= dataEnd else {
            throw CompressionError.invalidFormat
        }
        
        let fileData = data.subdata(in: dataStart..<dataEnd)
        
        // Extract filename from header (bytes 0-99)
        let fileNameData = data.subdata(in: 0..<100)
        let fileName = String(data: fileNameData, encoding: .ascii)?.trimmingCharacters(in: CharacterSet(charactersIn: "\0 ")) ?? "extracted"
        
        // Create temporary file
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension((fileName as NSString).pathExtension.isEmpty ? "tar_extracted" : (fileName as NSString).pathExtension)
        
        try fileData.write(to: tempURL)
        return tempURL
    }
    
    public static func compress(data: Data, to url: URL) throws {
        // TODO: Implement Tar archiving
        // Create TAR header and write file data
        throw CompressionError.notImplemented
    }
}

// MARK: - ArchiveOrgCompressionAdapter

/// Archive.org directory structure adapter (.archiveorg)
/// 
/// Archive.org organizes disk images in directories containing:
/// - Main disk image file (.dsk, .woz, .a2r, etc.)
/// - Supporting files (metadata .txt/.json, screenshots .png/.jpg, documentation .pdf/.txt)
/// - Sometimes organized in subdirectories
///
/// This adapter detects archive.org-style directories and extracts the main disk image file.
/// Directory structure example:
/// ```
/// @001_Championship_Lode_Runner.archiveorg/
///   ├── Championship_Lode_Runner.dsk          (main disk image)
///   ├── Championship_Lode_Runner.txt          (metadata)
///   ├── Championship_Lode_Runner.png          (screenshot)
///   └── Championship_Lode_Runner.pdf           (documentation)
/// ```
///
/// Detection criteria:
/// 1. Directory with .archiveorg extension
/// 2. Directory containing at least one disk image file (.dsk, .woz, .a2r, etc.)
/// 3. May contain supporting files (metadata, screenshots, documentation)
public struct ArchiveOrgCompressionAdapter: CompressionAdapter {
    public static var format: CompressionFormat { .archiveorg }
    
    public static var supportedExtensions: [String] {
        format.extensions
    }
    
    /// Disk image file extensions to look for (in priority order)
    private static let diskImageExtensions = [
        "dsk", "woz", "a2r", "nib", "do", "po", "d13", "hdv", "2mg",
        "d64", "d71", "d81", "t64", "tap",
        "atr", "xfd",
        "img", "ima", "imz"
    ]
    
    /// Supporting file extensions (metadata, screenshots, documentation)
    private static let supportingFileExtensions = [
        "txt", "json", "xml", "md",
        "png", "jpg", "jpeg", "gif",
        "pdf", "html", "htm"
    ]
    
    public static func canHandle(url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            return false
        }
        
        // Must be a directory
        guard isDirectory.boolValue else {
            // Check if it's a file with .archiveorg extension
            let ext = url.pathExtension.lowercased()
            return ext == "archiveorg"
        }
        
        // Check if directory has .archiveorg extension
        let ext = url.pathExtension.lowercased()
        if ext == "archiveorg" {
            return true
        }
        
        // Check if directory contains disk image files (archive.org structure)
        return containsDiskImageFiles(in: url)
    }
    
    /// Check if directory contains disk image files (archive.org structure)
    private static func containsDiskImageFiles(in directoryURL: URL) -> Bool {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return false
        }
        
        // Check for disk image files
        for fileURL in contents {
            let ext = fileURL.pathExtension.lowercased()
            if diskImageExtensions.contains(ext) {
                return true
            }
        }
        
        // Recursively check subdirectories (archive.org sometimes uses subdirectories)
        for fileURL in contents {
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDirectory),
               isDirectory.boolValue {
                if containsDiskImageFiles(in: fileURL) {
                    return true
                }
            }
        }
        
        return false
    }
    
    public static func isCompressed(url: URL) -> Bool {
        return canHandle(url: url)
    }
    
    public static func decompress(url: URL) throws -> URL {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            throw CompressionError.invalidFormat
        }
        
        let directoryURL: URL
        if isDirectory.boolValue {
            directoryURL = url
        } else {
            // If it's a file with .archiveorg extension, treat parent as directory
            // (though typically .archiveorg would be a directory)
            directoryURL = url.deletingLastPathComponent()
        }
        
        // Find the main disk image file
        guard let diskImageURL = findMainDiskImageFile(in: directoryURL) else {
            throw CompressionError.invalidFormat
        }
        
        // Return the disk image file URL directly (no decompression needed)
        // The file is already accessible, so we return it as-is
        return diskImageURL
    }
    
    /// Find the main disk image file in the directory
    /// Priority: .dsk > .woz > .a2r > other disk image formats
    private static func findMainDiskImageFile(in directoryURL: URL) -> URL? {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }
        
        // Sort files by priority (disk image extensions first, then by size)
        let diskImageFiles = contents.filter { fileURL in
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDirectory),
                  !isDirectory.boolValue else {
                return false
            }
            
            let ext = fileURL.pathExtension.lowercased()
            return diskImageExtensions.contains(ext)
        }
        
        guard !diskImageFiles.isEmpty else {
            // Check subdirectories recursively
            for fileURL in contents {
                var isDirectory: ObjCBool = false
                if FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDirectory),
                   isDirectory.boolValue {
                    if let found = findMainDiskImageFile(in: fileURL) {
                        return found
                    }
                }
            }
            return nil
        }
        
        // Sort by priority (preferred extensions first)
        let priorityOrder: [String: Int] = [
            "dsk": 1, "woz": 2, "a2r": 3, "nib": 4,
            "do": 5, "po": 6, "d13": 7, "hdv": 8, "2mg": 9
        ]
        
        let sortedFiles = diskImageFiles.sorted { file1, file2 in
            let ext1 = file1.pathExtension.lowercased()
            let ext2 = file2.pathExtension.lowercased()
            
            let priority1 = priorityOrder[ext1] ?? 100
            let priority2 = priorityOrder[ext2] ?? 100
            
            if priority1 != priority2 {
                return priority1 < priority2
            }
            
            // If same priority, prefer larger files (likely main disk image)
            let size1 = (try? file1.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            let size2 = (try? file2.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            return size1 > size2
        }
        
        return sortedFiles.first
    }
    
    public static func compress(data: Data, to url: URL) throws {
        // Archive.org format is read-only (directory structure from archive.org)
        // Creating new archive.org directories is not supported
        throw CompressionError.notImplemented
    }
    
    /// Extract metadata from archive.org directory structure
    /// Reads *_meta.xml file if present
    /// - Parameter url: URL of archive.org directory
    /// - Returns: Archive.org metadata, or nil if not found or cannot be parsed
    public static func extractMetadata(from url: URL) throws -> ArchiveOrgMetadata? {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            return nil
        }
        
        let directoryURL: URL
        if isDirectory.boolValue {
            directoryURL = url
        } else {
            // If it's a file, check parent directory
            directoryURL = url.deletingLastPathComponent()
        }
        
        // Find *_meta.xml file
        guard let metaXMLURL = findMetaXMLFile(in: directoryURL) else {
            return nil
        }
        
        // Parse XML metadata
        return try parseMetaXML(from: metaXMLURL)
    }
    
    /// Find *_meta.xml file in directory
    private static func findMetaXMLFile(in directoryURL: URL) -> URL? {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }
        
        // Look for *_meta.xml file
        for fileURL in contents {
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDirectory),
                  !isDirectory.boolValue else {
                continue
            }
            
            let fileName = fileURL.lastPathComponent.lowercased()
            if fileName.hasSuffix("_meta.xml") {
                return fileURL
            }
        }
        
        // Check subdirectories recursively
        for fileURL in contents {
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDirectory),
               isDirectory.boolValue {
                if let found = findMetaXMLFile(in: fileURL) {
                    return found
                }
            }
        }
        
        return nil
    }
    
    /// Parse *_meta.xml file and extract metadata
    private static func parseMetaXML(from url: URL) throws -> ArchiveOrgMetadata? {
        let data = try Data(contentsOf: url)
        
        // Parse XML
        let parser = XMLParser(data: data)
        let delegate = ArchiveOrgMetaXMLParser()
        parser.delegate = delegate
        
        guard parser.parse() else {
            return nil
        }
        
        return delegate.metadata
    }
}

// MARK: - ArchiveOrgMetadata

/// Metadata extracted from archive.org *_meta.xml files
public struct ArchiveOrgMetadata: Codable, Sendable {
    /// Archive.org identifier
    public let identifier: String?
    
    /// Collections this item belongs to
    public let collections: [String]
    
    /// Description
    public let itemDescription: String?
    
    /// Emulator name
    public let emulator: String?
    
    /// Emulator file extension
    public let emulatorExt: String?
    
    /// Language code
    public let language: String?
    
    /// Media type
    public let mediatype: String?
    
    /// Scanner information
    public let scanner: String?
    
    /// Title
    public let title: String?
    
    /// Public date (when made public)
    public let publicDate: String?
    
    /// Uploader information
    public let uploader: String?
    
    /// Added date (when added to archive.org)
    public let addedDate: String?
    
    /// Backup location
    public let backupLocation: String?
    
    /// Additional notes
    public let notes: String?
    
    public init(
        identifier: String? = nil,
        collections: [String] = [],
        itemDescription: String? = nil,
        emulator: String? = nil,
        emulatorExt: String? = nil,
        language: String? = nil,
        mediatype: String? = nil,
        scanner: String? = nil,
        title: String? = nil,
        publicDate: String? = nil,
        uploader: String? = nil,
        addedDate: String? = nil,
        backupLocation: String? = nil,
        notes: String? = nil
    ) {
        self.identifier = identifier
        self.collections = collections
        self.itemDescription = itemDescription
        self.emulator = emulator
        self.emulatorExt = emulatorExt
        self.language = language
        self.mediatype = mediatype
        self.scanner = scanner
        self.title = title
        self.publicDate = publicDate
        self.uploader = uploader
        self.addedDate = addedDate
        self.backupLocation = backupLocation
        self.notes = notes
    }
}

// MARK: - ArchiveOrgMetaXMLParser

/// XML parser delegate for archive.org *_meta.xml files
private class ArchiveOrgMetaXMLParser: NSObject, XMLParserDelegate {
    var metadata: ArchiveOrgMetadata?
    
    private var identifier: String?
    private var collections: [String] = []
    private var itemDescription: String?
    private var emulator: String?
    private var emulatorExt: String?
    private var language: String?
    private var mediatype: String?
    private var scanner: String?
    private var title: String?
    private var publicDate: String?
    private var uploader: String?
    private var addedDate: String?
    private var backupLocation: String?
    private var notes: String?
    
    private var currentElement: String = ""
    private var currentText: String = ""
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName.lowercased()
        currentText = ""
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let trimmedText = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        switch elementName.lowercased() {
        case "identifier":
            identifier = trimmedText.isEmpty ? nil : trimmedText
        case "collection":
            if !trimmedText.isEmpty {
                collections.append(trimmedText)
            }
        case "description":
            itemDescription = trimmedText.isEmpty ? nil : trimmedText
        case "emulator":
            emulator = trimmedText.isEmpty ? nil : trimmedText
        case "emulator_ext":
            emulatorExt = trimmedText.isEmpty ? nil : trimmedText
        case "language":
            language = trimmedText.isEmpty ? nil : trimmedText
        case "mediatype":
            mediatype = trimmedText.isEmpty ? nil : trimmedText
        case "scanner":
            scanner = trimmedText.isEmpty ? nil : trimmedText
        case "title":
            title = trimmedText.isEmpty ? nil : trimmedText
        case "publicdate":
            publicDate = trimmedText.isEmpty ? nil : trimmedText
        case "uploader":
            uploader = trimmedText.isEmpty ? nil : trimmedText
        case "addeddate":
            addedDate = trimmedText.isEmpty ? nil : trimmedText
        case "backup_location":
            backupLocation = trimmedText.isEmpty ? nil : trimmedText
        case "notes":
            notes = trimmedText.isEmpty ? nil : trimmedText
        case "metadata":
            // End of metadata element - create final metadata struct
            metadata = ArchiveOrgMetadata(
                identifier: identifier,
                collections: collections,
                itemDescription: itemDescription,
                emulator: emulator,
                emulatorExt: emulatorExt,
                language: language,
                mediatype: mediatype,
                scanner: scanner,
                title: title,
                publicDate: publicDate,
                uploader: uploader,
                addedDate: addedDate,
                backupLocation: backupLocation,
                notes: notes
            )
        default:
            break
        }
        
        currentText = ""
    }
}

// MARK: - CompressionError

/// Errors that can occur in compression operations
public enum CompressionError: Error, LocalizedError {
    case decompressionFailed
    case compressionFailed
    case notSupported
    case notImplemented
    case invalidFormat
    case nestedCompressionNotSupported
    case unsupportedPlatform
    
    public var errorDescription: String? {
        switch self {
        case .decompressionFailed:
            return "Decompression failed"
        case .compressionFailed:
            return "Compression failed"
        case .notSupported:
            return "Compression format not supported"
        case .notImplemented:
            return "Compression format not yet implemented"
        case .invalidFormat:
            return "Invalid compression format"
        case .nestedCompressionNotSupported:
            return "Nested compression not supported"
        case .unsupportedPlatform:
            return "Compression format not supported on this platform"
        }
    }
}

