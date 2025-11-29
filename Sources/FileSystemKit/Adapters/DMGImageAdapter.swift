// FileSystemKit - DMG Disk Image Adapter (Layer 2)
//
// This file implements DMGImageAdapter for handling Apple Disk Image (.dmg) files.
// DMG files use the Universal Disk Image Format (UDIF) and can contain various
// file systems including HFS, HFS+, FAT, ISO 9660, and UDF.
//
// Reference: ARCHITECTURE.md - Layer 2: Modern Disk Image Format Layer
// Wikipedia: https://en.wikipedia.org/wiki/Apple_Disk_Image

import Foundation

// MARK: - DMGImageAdapter

/// DMG disk image adapter for .dmg files (Apple Disk Image / UDIF format)
///
/// Apple Disk Image files are disk image files commonly used by macOS.
/// They use the Universal Disk Image Format (UDIF) and can contain various
/// file systems including HFS, HFS+, FAT, ISO 9660, and UDF.
///
/// DMG format characteristics:
/// - UDIF metadata trailer with 'koly' signature at end of file
/// - Supports compression (ADC, zlib, bzip2, LZFSE, lzma)
/// - Supports encryption (AES-128)
/// - Can contain multiple file systems (hybrid images)
/// - Data fork contains the actual disk image data
/// - Resource fork may contain additional metadata
///
/// Reference: https://en.wikipedia.org/wiki/Apple_Disk_Image
public final class DMGImageAdapter: DiskImageAdapter {
    public static var format: DiskImageFormat { .dmg }
    
    public static var supportedExtensions: [String] {
        return ["dmg"]
    }
    
    /// UDIF metadata trailer signature
    private static let udifSignature = Data([0x6B, 0x6F, 0x6C, 0x79]) // "koly"
    
    /// UDIF Resource File structure (simplified - we'll parse what we need)
    private struct UDIFResourceFile {
        let signature: Data          // "koly" (4 bytes)
        let version: UInt32          // Version (usually 4)
        let headerSize: UInt32       // Header size (usually 512)
        let flags: UInt32
        let runningDataForkOffset: UInt64
        let dataForkOffset: UInt64   // Usually 0, beginning of file
        let dataForkLength: UInt64
        let rsrcForkOffset: UInt64
        let rsrcForkLength: UInt64
        let xmlOffset: UInt64         // Position of XML property list
        let xmlLength: UInt64
        let sectorCount: UInt64
    }
    
    public static func canRead(data: Data) -> Bool {
        // Check for UDIF signature at end of file (last 512 bytes)
        guard data.count >= 512 else {
            return false
        }
        
        let trailerOffset = data.count - 512
        let trailerData = data.subdata(in: trailerOffset..<data.count)
        
        guard trailerData.count >= 4 else {
            return false
        }
        
        // Check for 'koly' signature at offset 0 in trailer
        return trailerData[0..<4] == udifSignature
    }
    
    public static func read(chunkStorage: ChunkStorage, identifier: ChunkIdentifier) async throws -> RawDiskData {
        // Read chunk data from storage
        guard let data = try await chunkStorage.readChunk(identifier) else {
            throw DiskImageError.readFailed
        }
        
        guard data.count >= 512 else {
            throw DiskImageError.invalidFormat
        }
        
        // Parse UDIF metadata trailer (last 512 bytes)
        let trailerOffset = data.count - 512
        let trailerData = data.subdata(in: trailerOffset..<data.count)
        
        guard trailerData[0..<4] == udifSignature else {
            throw DiskImageError.invalidFormat
        }
        
        // Parse UDIF resource file structure (big-endian)
        let resourceFile = try parseUDIFResourceFile(from: trailerData)
        
        // Extract data fork
        let dataForkOffset = Int(resourceFile.dataForkOffset)
        let dataForkLength = Int(resourceFile.dataForkLength)
        
        guard dataForkOffset + dataForkLength <= data.count else {
            throw DiskImageError.invalidData
        }
        
        let diskData = data.subdata(in: dataForkOffset..<(dataForkOffset + dataForkLength))
        
        // For now, treat DMG as a raw disk image
        // The actual file system (HFS, HFS+, ISO 9660, etc.) will be detected by FileSystemStrategy
        // Try to infer geometry from sector count
        let geometry = inferGeometry(from: Int(resourceFile.sectorCount), dataSize: dataForkLength)
        
        // Parse sectors (assume 512-byte sectors for now)
        let sectors = try parseSectors(from: diskData, geometry: geometry)
        
        // Create tracks
        let tracks = createTracks(from: sectors, geometry: geometry)
        
        // Extract metadata
        let metadata = DiskImageMetadata(
            title: identifier.metadata?.originalFilename,
            imageDate: nil,
            geometry: geometry
        )
        
        let rawDiskData = RawDiskData(sectors: sectors, rawData: diskData)
        rawDiskData.tracks = tracks
        rawDiskData.metadata = metadata
        
        return rawDiskData
    }
    
    public static func extractMetadata(metadataStorage: MetadataStorage, hash: DiskImageHash) async throws -> DiskImageMetadata? {
        return try await metadataStorage.readMetadata(for: hash)
    }
    
    public static func extractMetadata(from data: Data) throws -> DiskImageMetadata? {
        guard data.count >= 512 else { return nil }
        
        let trailerOffset = data.count - 512
        let trailerData = data.subdata(in: trailerOffset..<data.count)
        
        guard trailerData[0..<4] == udifSignature else {
            return nil
        }
        
        guard let resourceFile = try? parseUDIFResourceFile(from: trailerData) else {
            return nil
        }
        
        let geometry = inferGeometry(from: Int(resourceFile.sectorCount), dataSize: Int(resourceFile.dataForkLength))
        
        return DiskImageMetadata(
            title: nil,
            imageDate: nil,
            geometry: geometry
        )
    }
    
    public static func write(diskData: RawDiskData, metadata: DiskImageMetadata?, chunkStorage: ChunkStorage, identifier: ChunkIdentifier) async throws -> ChunkIdentifier {
        // TODO: Implement DMG writing
        throw DiskImageError.notImplemented
    }
    
    // MARK: - Private Helpers
    
    private static func parseUDIFResourceFile(from trailerData: Data) throws -> UDIFResourceFile {
        guard trailerData.count >= 512 else {
            throw DiskImageError.invalidFormat
        }
        
        // Parse UDIF resource file structure (big-endian)
        // Signature is already verified
        let signature = trailerData[0..<4]
        
        // Read big-endian values
        func readUInt32(at offset: Int) -> UInt32 {
            return (UInt32(trailerData[offset]) << 24) |
                   (UInt32(trailerData[offset + 1]) << 16) |
                   (UInt32(trailerData[offset + 2]) << 8) |
                   UInt32(trailerData[offset + 3])
        }
        
        func readUInt64(at offset: Int) -> UInt64 {
            let high = UInt64(readUInt32(at: offset))
            let low = UInt64(readUInt32(at: offset + 4))
            return (high << 32) | low
        }
        
        let version = readUInt32(at: 4)
        let headerSize = readUInt32(at: 8)
        let flags = readUInt32(at: 12)
        let runningDataForkOffset = readUInt64(at: 16)
        let dataForkOffset = readUInt64(at: 24)
        let dataForkLength = readUInt64(at: 32)
        let rsrcForkOffset = readUInt64(at: 40)
        let rsrcForkLength = readUInt64(at: 48)
        let xmlOffset = readUInt64(at: 200)  // XML offset at byte 200
        let xmlLength = readUInt64(at: 208)  // XML length at byte 208
        let sectorCount = readUInt64(at: 424) // Sector count at byte 424
        
        return UDIFResourceFile(
            signature: signature,
            version: version,
            headerSize: headerSize,
            flags: flags,
            runningDataForkOffset: runningDataForkOffset,
            dataForkOffset: dataForkOffset,
            dataForkLength: dataForkLength,
            rsrcForkOffset: rsrcForkOffset,
            rsrcForkLength: rsrcForkLength,
            xmlOffset: xmlOffset,
            xmlLength: xmlLength,
            sectorCount: sectorCount
        )
    }
    
    private static func inferGeometry(from sectorCount: Int, dataSize: Int) -> DiskGeometry {
        // DMG files typically use 512-byte sectors
        let sectorSize = 512
        
        // Calculate tracks and sectors per track
        // For hard disk images, we'll use a reasonable default
        let sectorsPerTrack = 63  // Common for hard disks
        let tracks = max(1, sectorCount / sectorsPerTrack)
        
        return DiskGeometry(
            tracks: tracks,
            sides: 1,
            sectorsPerTrack: sectorsPerTrack,
            sectorSize: sectorSize
        )
    }
    
    private static func parseSectors(from data: Data, geometry: DiskGeometry) throws -> [SectorData] {
        let sectorSize = geometry.sectorSize
        let totalSectors = data.count / sectorSize
        
        guard totalSectors > 0 else {
            throw DiskImageError.invalidData
        }
        
        var sectors: [SectorData] = []
        var sectorIndex = 0
        
        for track in 0..<geometry.tracks {
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
        
        return sectors
    }
    
    private static func createTracks(from sectors: [SectorData], geometry: DiskGeometry) -> [TrackData] {
        var tracks: [TrackData] = []
        
        for trackNum in 0..<geometry.tracks {
            let trackSectors = sectors.filter { $0.track == trackNum }
            if !trackSectors.isEmpty {
                tracks.append(TrackData(
                    track: trackNum,
                    side: 0,
                    sectors: trackSectors,
                    encoding: .mfm, // DMG typically contains MFM-encoded data
                    density: nil
                ))
            }
        }
        
        return tracks
    }
}

