// FileSystemKit - VHD Disk Image Adapter (Layer 2)
//
// This file implements VHDImageAdapter for handling Virtual Hard Disk images (.vhd files).
// VHD is a file format for virtual hard disk images, commonly used for virtualization.
//
// Reference: ARCHITECTURE.md - Layer 2: Modern Disk Image Format Layer

import Foundation

// MARK: - VHDImageAdapter

/// VHD disk image adapter for .vhd files (Virtual Hard Disk format)
///
/// VHD (Virtual Hard Disk) format is used for virtual machine disk images.
/// The format includes a footer at the end of the file with metadata.
///
/// VHD Footer Structure (512 bytes, at end of file):
/// - Bytes 0-7: Cookie ("conectix")
/// - Bytes 8-11: Features
/// - Bytes 12-15: File format version
/// - Bytes 16-23: Data offset
/// - Bytes 24-27: Timestamp
/// - Bytes 28-31: Creator application
/// - Bytes 32-35: Creator version
/// - Bytes 36-39: Creator host OS
/// - Bytes 40-47: Original size
/// - Bytes 48-51: Current size
/// - Bytes 52-53: Disk geometry (cylinders)
/// - Bytes 54: Disk geometry (heads)
/// - Bytes 55: Disk geometry (sectors per track)
/// - Bytes 56-59: Disk type
/// - Bytes 60-63: Checksum
/// - Bytes 64-511: Reserved
public final class VHDImageAdapter: DiskImageAdapter {
    public static var format: DiskImageFormat { .vhd }
    
    public static var supportedExtensions: [String] {
        ["vhd"]
    }
    
    /// VHD footer size (512 bytes)
    private static let footerSize = 512
    
    /// VHD cookie signature ("conectix")
    private static let vhdCookie = "conectix".data(using: .ascii)!
    
    /// Standard sector size (512 bytes)
    private static let sectorSize = 512
    
    /// Check if this adapter can read data (VHD files have footer signature)
    public static func canRead(data: Data) -> Bool {
        // VHD footer is at the end of the file
        guard data.count >= footerSize else {
            return false
        }
        
        // Read footer
        let footerStart = data.count - footerSize
        let footerData = data.subdata(in: footerStart..<data.count)
        
        guard footerData.count >= vhdCookie.count else {
            return false
        }
        
        // Check cookie signature
        let cookie = footerData.subdata(in: 0..<vhdCookie.count)
        return cookie == vhdCookie
    }
    
    /// Extract raw disk data from a VHD disk image using ChunkStorage
    public static func read(chunkStorage: ChunkStorage, identifier: ChunkIdentifier) async throws -> RawDiskData {
        // Read chunk data from storage
        guard let data = try await chunkStorage.readChunk(identifier) else {
            throw DiskImageError.readFailed
        }
        
        guard data.count >= footerSize else {
            throw DiskImageError.invalidFormat
        }
        
        // Parse VHD footer (last 512 bytes)
        let footerStart = data.count - footerSize
        let footerData = data.subdata(in: footerStart..<data.count)
        let footer = try parseVHDFooter(from: footerData)
        
        // Extract sector data (everything before footer)
        let sectorData = data.subdata(in: 0..<footerStart)
        
        // Parse sectors
        let sectors = try parseSectors(from: sectorData, geometry: footer.geometry)
        
        // Create track data
        let tracks = createTracks(from: sectors, geometry: footer.geometry)
        
        // Create metadata
        let metadata = DiskImageMetadata(
            title: nil,
            imageDate: footer.creationDate,
            geometry: footer.geometry
        )
        
        let diskData = RawDiskData(sectors: sectors, rawData: data)
        diskData.tracks = tracks
        diskData.metadata = metadata
        return diskData
    }
    
    /// Extract metadata from a VHD disk image using MetadataStorage
    public static func extractMetadata(metadataStorage: MetadataStorage, hash: DiskImageHash) async throws -> DiskImageMetadata? {
        return try await metadataStorage.readMetadata(for: hash)
    }
    
    /// Extract metadata from VHD disk image data
    public static func extractMetadata(from data: Data) throws -> DiskImageMetadata? {
        guard data.count >= footerSize else {
            return nil
        }
        
        // Parse VHD footer
        let footerStart = data.count - footerSize
        let footerData = data.subdata(in: footerStart..<data.count)
        
        guard let footer = try? parseVHDFooter(from: footerData) else {
            return nil
        }
        
        return DiskImageMetadata(
            title: nil,
            imageDate: footer.creationDate,
            geometry: footer.geometry
        )
    }
    
    /// Write raw disk data to storage using ChunkStorage
    public static func write(diskData: RawDiskData, metadata: DiskImageMetadata?, chunkStorage: ChunkStorage, identifier: ChunkIdentifier) async throws -> ChunkIdentifier {
        // TODO: Implement VHD image creation
        // This requires creating:
        // - Sector data
        // - VHD footer with proper geometry and checksum
        // This is complex and will be implemented in a future phase
        throw DiskImageError.notImplemented
    }
    
    // MARK: - Private Helpers
    
    /// VHD footer structure
    private struct VHDFooter {
        let geometry: DiskGeometry
        let creationDate: Date?
        let diskType: UInt32
    }
    
    /// Parse VHD footer
    private static func parseVHDFooter(from footerData: Data) throws -> VHDFooter {
        guard footerData.count >= footerSize else {
            throw DiskImageError.invalidFormat
        }
        
        // Check cookie signature
        let cookie = footerData.subdata(in: 0..<vhdCookie.count)
        guard cookie == vhdCookie else {
            throw DiskImageError.invalidFormat
        }
        
        // Parse disk geometry (bytes 52-55)
        let cylinders = footerData.withUnsafeBytes { bytes -> UInt16 in
            guard let baseAddress = bytes.baseAddress else { return 0 }
            return baseAddress.assumingMemoryBound(to: UInt16.self).advanced(by: 26).pointee
        }
        let heads = footerData[54]
        let sectorsPerTrack = footerData[55]
        
        // Parse disk type (bytes 56-59)
        let diskType = footerData.withUnsafeBytes { bytes -> UInt32 in
            guard let baseAddress = bytes.baseAddress else { return 0 }
            return baseAddress.assumingMemoryBound(to: UInt32.self).advanced(by: 14).pointee
        }
        
        // Parse timestamp (bytes 24-27, seconds since 2000-01-01 00:00:00 UTC)
        let timestamp = footerData.withUnsafeBytes { bytes -> UInt32 in
            guard let baseAddress = bytes.baseAddress else { return 0 }
            return baseAddress.assumingMemoryBound(to: UInt32.self).advanced(by: 6).pointee
        }
        
        // Convert timestamp to Date (seconds since 2000-01-01)
        let creationDate: Date? = {
            let secondsSince2000 = TimeInterval(timestamp)
            let year2000 = Date(timeIntervalSince1970: 946684800) // 2000-01-01 00:00:00 UTC
            return Date(timeInterval: secondsSince2000, since: year2000)
        }()
        
        let geometry = DiskGeometry(
            tracks: Int(cylinders),
            sides: Int(heads),
            sectorsPerTrack: Int(sectorsPerTrack),
            sectorSize: sectorSize
        )
        
        return VHDFooter(
            geometry: geometry,
            creationDate: creationDate,
            diskType: diskType
        )
    }
    
    /// Parse sectors from VHD data
    private static func parseSectors(from data: Data, geometry: DiskGeometry) throws -> [SectorData] {
        let sectorSize = geometry.sectorSize
        let totalSectors = data.count / sectorSize
        
        guard totalSectors > 0 else {
            throw DiskImageError.invalidData
        }
        
        var sectors: [SectorData] = []
        var sectorIndex = 0
        
        for track in 0..<geometry.tracks {
            for _ in 0..<geometry.sides {
                for sector in 0..<geometry.sectorsPerTrack {
                    guard sectorIndex < totalSectors else {
                        break
                    }
                    
                    let offset = sectorIndex * sectorSize
                    guard offset + sectorSize <= data.count else {
                        break
                    }
                    
                    let sectorData = data.subdata(in: offset..<offset + sectorSize)
                    sectors.append(SectorData(
                        track: track,
                        sector: sector,
                        data: sectorData
                    ))
                    
                    sectorIndex += 1
                }
            }
        }
        
        return sectors
    }
    
    /// Create track data from sectors
    private static func createTracks(from sectors: [SectorData], geometry: DiskGeometry) -> [TrackData] {
        var trackList: [TrackData] = []
        
        for trackNum in 0..<geometry.tracks {
            for headNum in 0..<geometry.sides {
                let trackSectors = sectors.filter { $0.track == trackNum }
                if !trackSectors.isEmpty {
                    trackList.append(TrackData(
                        track: trackNum,
                        side: headNum,
                        sectors: trackSectors.sorted { $0.sector < $1.sector },
                        encoding: .mfm,  // VHD typically uses MFM encoding
                        density: nil
                    ))
                }
            }
        }
        
        return trackList
    }
}
