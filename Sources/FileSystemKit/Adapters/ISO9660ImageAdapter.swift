// FileSystemKit - ISO 9660 Disk Image Adapter (Layer 2)
//
// This file implements ISO9660ImageAdapter for handling ISO 9660 disk images (.iso files).
// ISO 9660 is a file system standard for optical disc media (CD-ROM, DVD-ROM).
//
// Reference: ARCHITECTURE.md - Layer 2: Modern Disk Image Format Layer
// ISO 9660 Specification: https://en.wikipedia.org/wiki/ISO_9660

import Foundation

// MARK: - ISO9660ImageAdapter

/// ISO 9660 disk image adapter for .iso files
///
/// ISO 9660 is a file system standard for optical disc media introduced in 1988.
/// ISO disk images (.iso files) contain complete disc images including the ISO 9660
/// file system structure.
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
public final class ISO9660ImageAdapter: DiskImageAdapter {
    public static var format: DiskImageFormat { .iso9660 }
    
    public static var supportedExtensions: [String] {
        ["iso"]
    }
    
    /// ISO 9660 sector size (2048 bytes)
    private static let sectorSize = 2048
    
    /// Volume Descriptor Set starts at sector 16 (offset 0x8000)
    private static let volumeDescriptorSetStart = 16
    
    /// ISO 9660 signature ("CD001")
    private static let isoSignature = "CD001".data(using: .ascii)!
    
    /// Check if this adapter can read data (ISO 9660 signature check)
    public static func canRead(data: Data) -> Bool {
        // Check for ISO 9660 volume descriptor signature
        // Volume Descriptor Set starts at sector 16 (32768 bytes)
        guard data.count >= (volumeDescriptorSetStart + 1) * sectorSize else {
            return false
        }
        
        // Check for volume descriptor signature (0x01 'CD001')
        let vdsStart = volumeDescriptorSetStart * sectorSize
        guard vdsStart + 6 <= data.count else {
            return false
        }
        
        // Volume descriptor type should be 1 (Primary Volume Descriptor)
        // and should have 'CD001' signature at offset 1
        return data[vdsStart] == 0x01 && 
               data[vdsStart + 1..<vdsStart + 6] == Data([0x43, 0x44, 0x30, 0x30, 0x31]) // "CD001"
    }
    
    /// Extract raw disk data from an ISO 9660 disk image using ChunkStorage
    public static func read(chunkStorage: ChunkStorage, identifier: ChunkIdentifier) async throws -> RawDiskData {
        // Read chunk data from storage
        guard let data = try await chunkStorage.readChunk(identifier) else {
            throw DiskImageError.readFailed
        }
        
        // Try to parse ISO 9660 volume descriptor
        // For hybrid discs (Apple Partition Map), this may not be at sector 16
        var volumeDescriptor: PrimaryVolumeDescriptor?
        do {
            volumeDescriptor = try parsePrimaryVolumeDescriptor(from: data)
        } catch {
            // Hybrid disc - no ISO 9660 volume descriptor found at sector 16
            // Treat as raw ISO sectors (2048 bytes each)
            volumeDescriptor = nil
        }
        
        // Create sectors (ISO 9660 uses 2048-byte sectors)
        let sectors = try parseSectors(from: data, sectorSize: sectorSize)
        
        // Create track data (ISO 9660 is single-track)
        let tracks = [TrackData(
            track: 0,
            side: 0,
            sectors: sectors,
            encoding: .unknown,  // ISO 9660 is not magnetic media
            density: nil
        )]
        
        // Create metadata
        let geometry = DiskGeometry(
            tracks: 1,  // ISO 9660 is conceptually single-track
            sides: 1,
            sectorsPerTrack: sectors.count,
            sectorSize: sectorSize
        )
        
        // Use volume descriptor if available, otherwise use defaults for hybrid disc
        let title = volumeDescriptor?.volumeIdentifier ?? "Hybrid Disc"
        let creationDate = volumeDescriptor?.creationDate
        
        let metadata = DiskImageMetadata(
            title: title,
            imageDate: creationDate,
            geometry: geometry
        )
        
        let diskData = RawDiskData(sectors: sectors, rawData: data)
        diskData.tracks = tracks
        diskData.metadata = metadata
        return diskData
    }
    
    /// Extract metadata from an ISO 9660 disk image using MetadataStorage
    public static func extractMetadata(metadataStorage: MetadataStorage, hash: DiskImageHash) async throws -> DiskImageMetadata? {
        return try await metadataStorage.readMetadata(for: hash)
    }
    
    /// Extract metadata from ISO 9660 disk image data
    public static func extractMetadata(from data: Data) throws -> DiskImageMetadata? {
        guard data.count >= (volumeDescriptorSetStart + 1) * sectorSize else {
            return nil
        }
        
        let volumeDescriptor = try? parsePrimaryVolumeDescriptor(from: data)
        
        guard let descriptor = volumeDescriptor else {
            return nil
        }
        
        let geometry = DiskGeometry(
            tracks: 1,
            sides: 1,
            sectorsPerTrack: data.count / sectorSize,
            sectorSize: sectorSize
        )
        
        return DiskImageMetadata(
            title: descriptor.volumeIdentifier,
            imageDate: descriptor.creationDate,
            geometry: geometry
        )
    }
    
    /// Write raw disk data to storage using ChunkStorage
    public static func write(diskData: RawDiskData, metadata: DiskImageMetadata?, chunkStorage: ChunkStorage, identifier: ChunkIdentifier) async throws -> ChunkIdentifier {
        // TODO: Implement ISO 9660 image creation
        // This requires creating:
        // - Volume Descriptor Set
        // - Path Tables
        // - Directory Records
        // - File Data
        // This is complex and will be implemented in a future phase
        throw DiskImageError.notImplemented
    }
    
    // MARK: - Private Helpers
    
    /// Parse Primary Volume Descriptor from ISO 9660 data
    private static func parsePrimaryVolumeDescriptor(from data: Data) throws -> PrimaryVolumeDescriptor {
        // Volume Descriptor Set starts at sector 16
        let vdsStart = volumeDescriptorSetStart * sectorSize
        
        guard data.count >= vdsStart + sectorSize else {
            throw DiskImageError.invalidFormat
        }
        
        // Read first volume descriptor (should be Primary Volume Descriptor)
        let descriptorData = data.subdata(in: vdsStart..<vdsStart + sectorSize)
        
        // Check volume descriptor type (should be 1 for Primary)
        guard descriptorData.count > 0, descriptorData[0] == 1 else {
            throw DiskImageError.invalidFormat
        }
        
        // Check ISO signature at offset 1
        let signatureStart = 1
        let signatureEnd = signatureStart + 5
        guard signatureEnd <= descriptorData.count else {
            throw DiskImageError.invalidFormat
        }
        
        let signature = descriptorData.subdata(in: signatureStart..<signatureEnd)
        guard signature == isoSignature else {
            throw DiskImageError.invalidFormat
        }
        
        // Parse volume identifier (offset 40, 32 bytes)
        let volumeIdStart = 40
        let volumeIdEnd = volumeIdStart + 32
        guard volumeIdEnd <= descriptorData.count else {
            throw DiskImageError.invalidFormat
        }
        
        let volumeIdData = descriptorData.subdata(in: volumeIdStart..<volumeIdEnd)
        let volumeIdentifier = String(data: volumeIdData, encoding: .ascii)?
            .trimmingCharacters(in: CharacterSet(charactersIn: " \0")) ?? ""
        
        // Parse volume space size (offset 80, 8 bytes, both-endian)
        let volumeSizeStart = 80
        let volumeSizeEnd = volumeSizeStart + 8
        guard volumeSizeEnd <= descriptorData.count else {
            throw DiskImageError.invalidFormat
        }
        
        let volumeSizeData = descriptorData.subdata(in: volumeSizeStart..<volumeSizeEnd)
        // ISO 9660 stores numbers in both-endian format (little-endian first, then big-endian)
        // We'll use little-endian
        let volumeSize = volumeSizeData.withUnsafeBytes { bytes -> UInt32 in
            guard let baseAddress = bytes.baseAddress else { return 0 }
            return baseAddress.assumingMemoryBound(to: UInt32.self).pointee
        }
        
        // Parse creation date (offset 813, 17 bytes)
        // Format: "YYYYMMDDHHMMSSCC" (year, month, day, hour, minute, second, centisecond, timezone)
        let creationDateStart = 813
        let creationDateEnd = creationDateStart + 17
        var creationDate: Date? = nil
        
        if creationDateEnd <= descriptorData.count {
            let dateData = descriptorData.subdata(in: creationDateStart..<creationDateEnd)
            if let dateString = String(data: dateData, encoding: .ascii),
               dateString.count >= 16 {
                // Parse ISO 9660 date format
                creationDate = parseISO9660Date(dateString)
            }
        }
        
        return PrimaryVolumeDescriptor(
            volumeIdentifier: volumeIdentifier,
            volumeSize: Int(volumeSize),
            creationDate: creationDate
        )
    }
    
    /// Parse ISO 9660 date string
    /// Format: "YYYYMMDDHHMMSSCC" (17 bytes, null-terminated)
    private static func parseISO9660Date(_ dateString: String) -> Date? {
        guard dateString.count >= 16 else {
            return nil
        }
        
        let yearStr = String(dateString.prefix(4))
        let monthStr = String(dateString.dropFirst(4).prefix(2))
        let dayStr = String(dateString.dropFirst(6).prefix(2))
        let hourStr = String(dateString.dropFirst(8).prefix(2))
        let minuteStr = String(dateString.dropFirst(10).prefix(2))
        let secondStr = String(dateString.dropFirst(12).prefix(2))
        
        guard let year = Int(yearStr),
              let month = Int(monthStr),
              let day = Int(dayStr),
              let hour = Int(hourStr),
              let minute = Int(minuteStr),
              let second = Int(secondStr) else {
            return nil
        }
        
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = second
        components.timeZone = TimeZone(secondsFromGMT: 0)  // ISO 9660 uses UTC
        
        return Calendar.current.date(from: components)
    }
    
    /// Parse sectors from ISO 9660 data
    private static func parseSectors(from data: Data, sectorSize: Int) throws -> [SectorData] {
        let totalSectors = data.count / sectorSize
        
        guard totalSectors > 0 else {
            throw DiskImageError.invalidData
        }
        
        var sectors: [SectorData] = []
        
        for sectorIndex in 0..<totalSectors {
            let offset = sectorIndex * sectorSize
            guard offset + sectorSize <= data.count else {
                break
            }
            
            let sectorData = data.subdata(in: offset..<offset + sectorSize)
            sectors.append(SectorData(
                track: 0,  // ISO 9660 is conceptually single-track
                sector: sectorIndex,
                data: sectorData
            ))
        }
        
        return sectors
    }
}

// MARK: - PrimaryVolumeDescriptor

/// Primary Volume Descriptor from ISO 9660
private struct PrimaryVolumeDescriptor {
    let volumeIdentifier: String
    let volumeSize: Int  // In sectors
    let creationDate: Date?
}
