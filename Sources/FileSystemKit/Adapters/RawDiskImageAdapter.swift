// FileSystemKit - Raw Disk Image Adapter (Layer 2)
//
// This file implements RawDiskImageAdapter for handling generic raw sector dump formats.
// Raw sector dumps contain raw sector data with no special format structure.
//
// This is a generic adapter that can handle raw disk images of various geometries.
// Vintage-specific raw adapters (e.g., Apple II) are handled by RetroboxFS.

import Foundation

// MARK: - RawDiskImageAdapter

/// Generic raw disk image adapter for raw sector dump files
/// 
/// Raw sector dumps are the simplest disk image format - they contain
/// raw sector data with no special format structure. This adapter handles
/// generic raw sector dumps by inferring geometry from file size.
///
/// Common sector sizes:
/// - 256 bytes (vintage systems)
/// - 512 bytes (modern systems)
/// - 2048 bytes (CD-ROM sectors)
public final class RawDiskImageAdapter: DiskImageAdapter {
    public static var format: DiskImageFormat { .raw }
    
    public static var supportedExtensions: [String] {
        ["img", "raw"]
    }
    
    /// Check if this adapter can read data (raw disk images have no signature, so we accept any reasonable size)
    public static func canRead(data: Data) -> Bool {
        // Accept data between 64KB and 10GB (reasonable range for disk images)
        return data.count >= 64 * 1024 && data.count <= 10 * 1024 * 1024 * 1024
    }
    
    /// Extract raw disk data from a raw sector dump using ChunkStorage
    public static func read(chunkStorage: ChunkStorage, identifier: ChunkIdentifier) async throws -> RawDiskData {
        // Read chunk data from storage
        guard let data = try await chunkStorage.readChunk(identifier) else {
            throw DiskImageError.readFailed
        }
        
        // Infer disk geometry from file size
        let geometry = inferGeometry(from: data.count)
        
        // Parse sectors from raw data
        let sectors = try parseSectors(from: data, geometry: geometry)
        
        // Create track data
        let tracks = createTracks(from: sectors, geometry: geometry)
        
        // Create metadata
        let metadata = DiskImageMetadata(
            title: identifier.metadata?.originalFilename,
            imageDate: nil,
            geometry: geometry
        )
        
        let diskData = RawDiskData(sectors: sectors, rawData: data)
        diskData.tracks = tracks
        diskData.metadata = metadata
        return diskData
    }
    
    /// Extract metadata from a raw sector dump using MetadataStorage
    public static func extractMetadata(metadataStorage: MetadataStorage, hash: DiskImageHash) async throws -> DiskImageMetadata? {
        return try await metadataStorage.readMetadata(for: hash)
    }
    
    /// Extract metadata from raw disk image data
    public static func extractMetadata(from data: Data) throws -> DiskImageMetadata? {
        let geometry = inferGeometry(from: data.count)
        
        return DiskImageMetadata(
            title: nil,
            imageDate: nil,
            geometry: geometry
        )
    }
    
    /// Write raw disk data to storage using ChunkStorage
    public static func write(diskData: RawDiskData, metadata: DiskImageMetadata?, chunkStorage: ChunkStorage, identifier: ChunkIdentifier) async throws -> ChunkIdentifier {
        guard let sectors = diskData.sectors, !sectors.isEmpty else {
            throw DiskImageError.invalidData
        }
        
        // Sort sectors by track and sector number
        let sortedSectors = sectors.sorted { first, second in
            if first.track != second.track {
                return first.track < second.track
            }
            return first.sector < second.sector
        }
        
        // Write sectors sequentially
        var outputData = Data()
        for sector in sortedSectors {
            outputData.append(sector.data)
        }
        
        // Create chunk metadata
        let chunkMetadata = ChunkMetadata(
            size: outputData.count,
            contentHash: identifier.id,
            hashAlgorithm: "sha256",
            contentType: "application/octet-stream",
            chunkType: "disk-image",
            originalFilename: nil
        )
        
        // Store in ChunkStorage
        return try await chunkStorage.writeChunk(outputData, identifier: identifier, metadata: chunkMetadata)
    }
    
    // MARK: - Private Helpers
    
    /// Infer disk geometry from file size
    private static func inferGeometry(from fileSize: Int) -> DiskGeometry {
        // Try common sector sizes: 256, 512, 2048 bytes
        let sectorSize: Int
        if fileSize % 2048 == 0 {
            sectorSize = 2048  // CD-ROM sector size
        } else if fileSize % 512 == 0 {
            sectorSize = 512   // Standard hard disk/floppy sector size
        } else if fileSize % 256 == 0 {
            sectorSize = 256   // Vintage sector size
        } else {
            // Default to 512 bytes
            sectorSize = 512
        }
        
        let totalSectors = fileSize / sectorSize
        
        // Infer tracks and sectors per track
        // For modern systems, assume hard disk geometry (63 sectors per track)
        // For smaller images, assume floppy geometry
        var tracks: Int
        var sectorsPerTrack: Int
        
        if totalSectors <= 2880 {
            // Floppy disk size - assume 80 tracks, 18 sectors per track, 2 sides
            tracks = 80
            sectorsPerTrack = 18
        } else {
            // Hard disk size - assume 63 sectors per track
            sectorsPerTrack = 63
            tracks = max(1, totalSectors / sectorsPerTrack)
        }
        
        return DiskGeometry(
            tracks: tracks,
            sides: 1,  // Single-sided by default
            sectorsPerTrack: sectorsPerTrack,
            sectorSize: sectorSize
        )
    }
    
    /// Parse sectors from raw data
    private static func parseSectors(from data: Data, geometry: DiskGeometry) throws -> [SectorData] {
        let bytesPerSector = geometry.sectorSize
        let totalSectors = data.count / bytesPerSector
        
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
                
                let offset = sectorIndex * bytesPerSector
                guard offset + bytesPerSector <= data.count else {
                    break
                }
                
                let sectorData = data.subdata(in: offset..<offset + bytesPerSector)
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
    
    /// Create track data from sectors
    private static func createTracks(from sectors: [SectorData], geometry: DiskGeometry) -> [TrackData] {
        var tracks: [TrackData] = []
        
        for trackNum in 0..<geometry.tracks {
            let trackSectors = sectors.filter { $0.track == trackNum }
            if !trackSectors.isEmpty {
                tracks.append(TrackData(
                    track: trackNum,
                    side: 0,
                    sectors: trackSectors,
                    encoding: .unknown,  // Unknown encoding for generic raw
                    density: nil
                ))
            }
        }
        
        return tracks
    }
}

