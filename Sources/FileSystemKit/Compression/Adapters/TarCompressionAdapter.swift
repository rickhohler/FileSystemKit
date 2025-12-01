// FileSystemKit Core Library
// Tar Compression Adapter

import Foundation

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

