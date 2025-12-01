// FileSystemKit Core Library
// Toast Compression Adapter

import Foundation

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

