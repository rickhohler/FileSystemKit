// FileSystemKit - ISO 9660 File System Strategy (Layer 3)
//
// This file implements ISO9660FileSystemStrategy for parsing ISO 9660 file systems.
// ISO 9660 is a file system standard for optical disc media (CD-ROM, DVD-ROM).
//
// Reference: ARCHITECTURE.md - Layer 3: Original Disk Layout Layer
// ISO 9660 Specification: https://en.wikipedia.org/wiki/ISO_9660

import Foundation

// MARK: - ISO9660FileSystemStrategy

/// File system strategy for ISO 9660 file systems
///
/// ISO 9660 Structure:
/// - Volume Descriptor Set (starts at sector 16, offset 0x8000)
///   - Primary Volume Descriptor (type 1)
///   - Supplementary Volume Descriptors (type 2, for Joliet)
///   - Boot Record (type 0)
///   - Volume Descriptor Set Terminator (type 255)
/// - Path Tables (for efficient directory traversal)
/// - Directory and File Records
/// - System Use Area (for extensions like Rock Ridge, Joliet)
///
/// ISO 9660 uses 2048-byte sectors (standard CD-ROM sector size).
public struct ISO9660FileSystemStrategy: FileSystemStrategy {
    public static var format: FileSystemFormat { .iso9660 }
    
    // ISO 9660 constants
    static let sectorSize = 2048
    static let volumeDescriptorSetStart = 16
    private static let isoSignature = "CD001".data(using: .ascii)!
    
    // Instance properties
    public var format: FileSystemFormat { .iso9660 }
    public var capacity: Int
    public var blockSize: Int { ISO9660FileSystemStrategy.sectorSize }
    
    private let volumeDescriptor: PrimaryVolumeDescriptor
    private let rootDirectoryRecord: DirectoryRecord
    
    /// Initialize ISO9660FileSystemStrategy
    /// - Parameter diskData: Raw disk data containing ISO 9660 file system
    public init(diskData: RawDiskData) throws {
        // Parse volume descriptor
        guard let sectors = diskData.sectors,
              !sectors.isEmpty,
              let firstSector = sectors.first,
              firstSector.data.count >= ISO9660FileSystemStrategy.sectorSize * ISO9660FileSystemStrategy.volumeDescriptorSetStart + ISO9660FileSystemStrategy.sectorSize else {
            throw FileSystemError.invalidFileSystem
        }
        
        // Extract ISO data from sectors
        guard let sectors = diskData.sectors else {
            throw FileSystemError.invalidFileSystem
        }
        var isoData = Data()
        for sector in sectors {
            isoData.append(sector.data)
        }
        
        // Parse primary volume descriptor
        volumeDescriptor = try parsePrimaryVolumeDescriptor(from: isoData)
        
        // Parse root directory record
        rootDirectoryRecord = try parseRootDirectoryRecord(from: isoData, volumeDescriptor: volumeDescriptor)
        
        // Calculate capacity
        capacity = volumeDescriptor.volumeSpaceSize * ISO9660FileSystemStrategy.sectorSize
    }
    
    /// Check if this strategy can handle the given raw disk data
    public static func canHandle(diskData: RawDiskData) -> Bool {
        // Check if we have enough sectors
        guard let sectors = diskData.sectors,
              sectors.count > ISO9660FileSystemStrategy.volumeDescriptorSetStart else {
            return false
        }
        
        // Check first sector of volume descriptor set
        let vdsSector = ISO9660FileSystemStrategy.volumeDescriptorSetStart
        guard vdsSector < sectors.count,
              sectors[vdsSector].data.count >= ISO9660FileSystemStrategy.sectorSize else {
            return false
        }
        
        let sectorData = sectors[vdsSector].data
        guard sectorData.count >= 7 else {
            return false
        }
        
        // Check for ISO signature at offset 1 (after type byte)
        let signatureStart = sectorData.index(sectorData.startIndex, offsetBy: 1)
        let signatureEnd = sectorData.index(signatureStart, offsetBy: 5)
        guard signatureEnd <= sectorData.endIndex else {
            return false
        }
        
        let signature = sectorData.subdata(in: signatureStart..<signatureEnd)
        return signature == isoSignature
    }
    
    /// Detect ISO 9660 file system format
    public static func detectFormat(in diskData: RawDiskData) -> FileSystemFormat? {
        return canHandle(diskData: diskData) ? .iso9660 : nil
    }
    
    /// Parse the file system structure from raw disk data
    public func parse(diskData: RawDiskData) throws -> FileSystemFolder {
        // Extract ISO data from sectors
        guard let sectors = diskData.sectors else {
            throw FileSystemError.invalidFileSystem
        }
        var isoData = Data()
        for sector in sectors {
            isoData.append(sector.data)
        }
        
        // Parse root directory
        return try parseDirectory(
            from: isoData,
            directoryRecord: rootDirectoryRecord,
            volumeDescriptor: volumeDescriptor,
            parent: nil
        )
    }
    
    /// Read file content from raw disk data
    public func readFile(_ file: File, from diskData: RawDiskData) throws -> Data {
        let location = file.metadata.location
        
        // Extract ISO data from sectors
        guard let sectors = diskData.sectors else {
            throw FileSystemError.invalidFileSystem
        }
        var isoData = Data()
        for sector in sectors {
            isoData.append(sector.data)
        }
        
        // Read file data from logical sector
        let logicalSector = location.offset / ISO9660FileSystemStrategy.sectorSize
        let sectorOffset = location.offset % ISO9660FileSystemStrategy.sectorSize
        
        guard logicalSector * ISO9660FileSystemStrategy.sectorSize + location.length <= isoData.count else {
            throw FileSystemError.invalidOffset
        }
        
        let startIndex = isoData.index(isoData.startIndex, offsetBy: logicalSector * ISO9660FileSystemStrategy.sectorSize + sectorOffset)
        let endIndex = isoData.index(startIndex, offsetBy: location.length)
        
        return isoData.subdata(in: startIndex..<endIndex)
    }
    
    /// Write file content to raw disk data
    public func writeFile(_ data: Data, as file: File, to diskData: inout RawDiskData) throws {
        // ISO 9660 is read-only (CD-ROM standard)
        throw FileSystemError.unsupportedFileSystemFormat
    }
    
    /// Register this strategy with the factory
    /// Call this during module initialization
    public static func register() {
        FileSystemStrategyFactory.register(ISO9660FileSystemStrategy.self)
    }
    
    /// Create a new formatted ISO 9660 disk image
    public static func format(parameters: FormatParameters) throws -> RawDiskData {
        // TODO: Implement ISO 9660 formatting
        throw FileSystemError.unsupportedFileSystemFormat
    }
}

// MARK: - ISO 9660 Structures

/// Primary Volume Descriptor (type 1)
private struct PrimaryVolumeDescriptor {
    let type: UInt8
    let standardIdentifier: String
    let volumeSpaceSize: Int
    let volumeSetIdentifier: String
    let volumeIdentifier: String
    let rootDirectoryRecord: DirectoryRecord
    let pathTableSize: Int
    let pathTableLocation: Int
    let rootDirectoryLocation: Int
    let rootDirectorySize: Int
}

/// Directory Record
private struct DirectoryRecord {
    let length: UInt8
    let extendedAttributeLength: UInt8
    let location: Int  // Logical sector number
    let dataLength: Int
    let recordingDateAndTime: Date?
    let flags: UInt8
    let fileUnitSize: UInt8
    let interleaveGapSize: UInt8
    let volumeSequenceNumber: UInt16
    let identifierLength: UInt8
    let identifier: String
    let systemUseArea: Data
}

// MARK: - ISO 9660 Parsing

/// Parse primary volume descriptor from ISO data
private func parsePrimaryVolumeDescriptor(from data: Data) throws -> PrimaryVolumeDescriptor {
    let vdsStart = ISO9660FileSystemStrategy.volumeDescriptorSetStart * ISO9660FileSystemStrategy.sectorSize
    
    // Find primary volume descriptor (type 1)
    var offset = vdsStart
    while offset < data.count {
        let sectorStart = (offset / ISO9660FileSystemStrategy.sectorSize) * ISO9660FileSystemStrategy.sectorSize
        let sectorOffset = offset % ISO9660FileSystemStrategy.sectorSize
        
        guard sectorStart + sectorOffset + 7 <= data.count else {
            break
        }
        
        let type = data[sectorStart + sectorOffset]
        
        // Check for terminator
        if type == 255 {
            break
        }
        
        // Check for primary volume descriptor
        if type == 1 {
            return try parseVolumeDescriptor(at: sectorStart + sectorOffset, from: data)
        }
        
        // Move to next volume descriptor (each is one sector)
        offset += ISO9660FileSystemStrategy.sectorSize
    }
    
    throw FileSystemError.invalidFileSystem
}

/// Parse volume descriptor at offset
private func parseVolumeDescriptor(at offset: Int, from data: Data) throws -> PrimaryVolumeDescriptor {
    guard offset + ISO9660FileSystemStrategy.sectorSize <= data.count else {
        throw FileSystemError.invalidFileSystem
    }
    
    let sectorData = data.subdata(in: offset..<offset + ISO9660FileSystemStrategy.sectorSize)
    var cursor = 0
    
    // Type (already checked)
    let type = sectorData[cursor]
    cursor += 1
    
    // Standard identifier (5 bytes: "CD001")
    let standardIdentifier = String(data: sectorData.subdata(in: cursor..<cursor + 5), encoding: .ascii) ?? ""
    cursor += 5
    
    // Volume space size (both little-endian and big-endian)
    let volumeSpaceSizeLE = sectorData.withUnsafeBytes { bytes in
        bytes.load(fromByteOffset: cursor, as: UInt32.self).littleEndian
    }
    cursor += 4
    
    // Skip big-endian version
    cursor += 4
    
    // Volume set identifier (128 bytes, padded with spaces)
    let volumeSetIdentifierData = sectorData.subdata(in: cursor..<cursor + 128)
    let volumeSetIdentifier = String(data: volumeSetIdentifierData, encoding: .ascii)?
        .trimmingCharacters(in: CharacterSet(charactersIn: " ")) ?? ""
    cursor += 128
    
    // Volume identifier (32 bytes)
    let volumeIdentifierData = sectorData.subdata(in: cursor..<cursor + 32)
    let volumeIdentifier = String(data: volumeIdentifierData, encoding: .ascii)?
        .trimmingCharacters(in: CharacterSet(charactersIn: " ")) ?? ""
    cursor += 32
    
    // Root directory record (34 bytes)
    let rootDirectoryRecord = try parseDirectoryRecord(at: cursor, from: sectorData)
    cursor += 34
    
    // Path table size (both LE and BE)
    let pathTableSizeLE = sectorData.withUnsafeBytes { bytes in
        bytes.load(fromByteOffset: cursor, as: UInt32.self).littleEndian
    }
    cursor += 4
    cursor += 4  // Skip BE
    
    // Path table location (both LE and BE)
    let pathTableLocationLE = sectorData.withUnsafeBytes { bytes in
        bytes.load(fromByteOffset: cursor, as: UInt32.self).littleEndian
    }
    cursor += 4
    cursor += 4  // Skip BE
    
    // Root directory location and size are in root directory record
    let rootDirectoryLocation = rootDirectoryRecord.location
    let rootDirectorySize = rootDirectoryRecord.dataLength
    
    return PrimaryVolumeDescriptor(
        type: type,
        standardIdentifier: standardIdentifier,
        volumeSpaceSize: Int(volumeSpaceSizeLE),
        volumeSetIdentifier: volumeSetIdentifier,
        volumeIdentifier: volumeIdentifier,
        rootDirectoryRecord: rootDirectoryRecord,
        pathTableSize: Int(pathTableSizeLE),
        pathTableLocation: Int(pathTableLocationLE),
        rootDirectoryLocation: rootDirectoryLocation,
        rootDirectorySize: rootDirectorySize
    )
}

/// Parse root directory record
private func parseRootDirectoryRecord(from data: Data, volumeDescriptor: PrimaryVolumeDescriptor) throws -> DirectoryRecord {
    return volumeDescriptor.rootDirectoryRecord
}

/// Parse directory record at offset
private func parseDirectoryRecord(at offset: Int, from data: Data) throws -> DirectoryRecord {
    guard offset + 33 <= data.count else {
        throw FileSystemError.invalidFileSystem
    }
    
    var cursor = offset
    
    // Length of directory record
    let length = data[cursor]
    guard length > 0, length <= 255 else {
        throw FileSystemError.invalidFileSystem
    }
    cursor += 1
    
    guard offset + Int(length) <= data.count else {
        throw FileSystemError.invalidFileSystem
    }
    
    // Extended attribute length
    let extendedAttributeLength = data[cursor]
    cursor += 1
    
    // Location (logical sector number, both LE and BE)
    let locationLE = data.withUnsafeBytes { bytes in
        bytes.load(fromByteOffset: cursor, as: UInt32.self).littleEndian
    }
    cursor += 4
    cursor += 4  // Skip BE
    
    // Data length (both LE and BE)
    let dataLengthLE = data.withUnsafeBytes { bytes in
        bytes.load(fromByteOffset: cursor, as: UInt32.self).littleEndian
    }
    cursor += 4
    cursor += 4  // Skip BE
    
    // Recording date and time (17 bytes)
    let dateData = data.subdata(in: cursor..<cursor + 17)
    let recordingDateAndTime = parseDateTime(from: dateData)
    cursor += 17
    
    // Flags
    let flags = data[cursor]
    cursor += 1
    
    // File unit size
    let fileUnitSize = data[cursor]
    cursor += 1
    
    // Interleave gap size
    let interleaveGapSize = data[cursor]
    cursor += 1
    
    // Volume sequence number (both LE and BE)
    let volumeSequenceNumberLE = data.withUnsafeBytes { bytes in
        bytes.load(fromByteOffset: cursor, as: UInt16.self).littleEndian
    }
    cursor += 2
    cursor += 2  // Skip BE
    
    // Identifier length
    let identifierLength = data[cursor]
    cursor += 1
    
    // Identifier (padded to even length)
    let identifierEnd = cursor + Int(identifierLength)
    let identifierData = data.subdata(in: cursor..<identifierEnd)
    let identifier = String(data: identifierData, encoding: .ascii) ?? ""
    cursor = identifierEnd
    
    // Padding to even length
    if cursor % 2 != 0 {
        cursor += 1
    }
    
    // System use area (remaining bytes in record)
    let systemUseAreaEnd = offset + Int(length)
    let systemUseArea = cursor < systemUseAreaEnd ? data.subdata(in: cursor..<systemUseAreaEnd) : Data()
    
    return DirectoryRecord(
        length: length,
        extendedAttributeLength: extendedAttributeLength,
        location: Int(locationLE),
        dataLength: Int(dataLengthLE),
        recordingDateAndTime: recordingDateAndTime,
        flags: flags,
        fileUnitSize: fileUnitSize,
        interleaveGapSize: interleaveGapSize,
        volumeSequenceNumber: volumeSequenceNumberLE,
        identifierLength: identifierLength,
        identifier: identifier,
        systemUseArea: systemUseArea
    )
}

/// Parse date and time from ISO 9660 format
private func parseDateTime(from data: Data) -> Date? {
    guard data.count >= 17 else {
        return nil
    }
    
    // ISO 9660 date format: YYYYMMDDHHMMSSCC (17 bytes)
    // Years since 1900, month (1-12), day (1-31), hour (0-23), minute (0-59), second (0-59), centisecond (0-99)
    let year = Int(data[0]) + 1900
    let month = Int(data[1])
    let day = Int(data[2])
    let hour = Int(data[3])
    let minute = Int(data[4])
    let second = Int(data[5])
    
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    components.hour = hour
    components.minute = minute
    components.second = second
    
    return Calendar.current.date(from: components)
}

/// Parse directory from directory record
private func parseDirectory(
    from data: Data,
    directoryRecord: DirectoryRecord,
    volumeDescriptor: PrimaryVolumeDescriptor,
    parent: FileSystemFolder?
) throws -> FileSystemFolder {
    let directoryLocation = directoryRecord.location * ISO9660FileSystemStrategy.sectorSize
    let directorySize = directoryRecord.dataLength
    
    guard directoryLocation + directorySize <= data.count else {
        throw FileSystemError.invalidFileSystem
    }
    
    let directoryData = data.subdata(in: directoryLocation..<directoryLocation + directorySize)
    
    // Create directory
        let directory = FileSystemFolder(
        name: directoryRecord.identifier.isEmpty ? "/" : directoryRecord.identifier
    )
    directory.parent = parent
    
    // Parse directory entries
    var offset = 0
    while offset < directoryData.count {
        guard offset + 1 <= directoryData.count else {
            break
        }
        
        let recordLength = Int(directoryData[offset])
        if recordLength == 0 {
            // Skip padding
            offset += 1
            continue
        }
        
        guard offset + recordLength <= directoryData.count else {
            break
        }
        
        do {
            let record = try parseDirectoryRecord(at: offset, from: directoryData)
            
            // Skip "." and ".." entries
            if record.identifier == "." || record.identifier == ".." {
                offset += Int(record.length)
                continue
            }
            
            // Check if it's a directory or file
            let isDirectory = (record.flags & 0x02) != 0
            
            if isDirectory {
                // Recursively parse subdirectory
                let subdirectory = try parseDirectory(
                    from: data,
                    directoryRecord: record,
                    volumeDescriptor: volumeDescriptor,
                    parent: directory
                )
                directory.addChild(subdirectory)
            } else {
                // Create file
                let fileLocation = FileLocation(
                    track: nil,
                    sector: nil,
                    offset: record.location * ISO9660FileSystemStrategy.sectorSize,
                    length: record.dataLength
                )
                
                let fileMetadata = FileMetadata(
                    name: record.identifier,
                    size: record.dataLength,
                    modificationDate: record.recordingDateAndTime,
                    fileType: nil,  // Will be detected from content
                    attributes: [:],
                    location: fileLocation,
                    hashes: [:]
                )
                
                let file = File(metadata: fileMetadata)
                directory.addChild(file)
            }
            
            offset += Int(record.length)
        } catch {
            // Skip invalid records
            offset += 1
        }
    }
    
    return directory
}
