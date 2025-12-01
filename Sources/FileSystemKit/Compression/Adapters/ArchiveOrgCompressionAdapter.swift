// FileSystemKit Core Library
// Archive.org Compression Adapter

import Foundation

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

