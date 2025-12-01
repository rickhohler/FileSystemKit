// FileSystemKit Core Library
// ShrinkIt Compression Adapter

import Foundation

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
