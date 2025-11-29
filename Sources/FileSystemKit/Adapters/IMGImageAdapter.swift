// FileSystemKit - IMG Disk Image Adapter (Layer 2)
//
// This file implements IMGImageAdapter for handling MS-DOS/PC-DOS raw disk images (.img, .ima files).
// IMG/IMA format is a raw sector-by-sector copy of a floppy disk or hard disk partition.
//
// Reference: ARCHITECTURE.md - Layer 2: Modern Disk Image Format Layer

import Foundation

// MARK: - IMGImageAdapter

/// IMG disk image adapter for .img and .ima files (MS-DOS/PC-DOS raw disk images)
///
/// IMG/IMA format is a raw sector-by-sector copy of a disk or partition.
/// Unlike other formats, IMG files have no header - they contain pure sector data.
///
/// Common disk sizes:
/// - 360KB: 720 sectors × 512 bytes (5.25" double density)
/// - 720KB: 1440 sectors × 512 bytes (3.5" double density)
/// - 1.2MB: 2400 sectors × 512 bytes (5.25" high density)
/// - 1.44MB: 2880 sectors × 512 bytes (3.5" high density)
/// - 2.88MB: 5760 sectors × 512 bytes (3.5" extended density)
///
/// Hard disk partitions can be any size, typically multiples of 512 bytes.
public final class IMGImageAdapter: DiskImageAdapter {
    public static var format: DiskImageFormat { .img }
    
    public static var supportedExtensions: [String] {
        ["img", "ima"]
    }
    
    /// Standard sector size for MS-DOS/PC-DOS (512 bytes)
    private static let sectorSize = 512
    
    /// Minimum file size (360KB floppy)
    private static let minSize = 360 * 1024
    
    /// Maximum reasonable file size (10MB for vintage systems)
    private static let maxSize = 10 * 1024 * 1024
    
    /// Check if this adapter can read data (IMG files are sector-aligned)
    public static func canRead(data: Data) -> Bool {
        // Accept files that are multiples of sector size and within reasonable range
        return data.count >= minSize && data.count <= maxSize && (data.count % sectorSize == 0)
    }
    
    /// Extract raw disk data from an IMG disk image using ChunkStorage
    public static func read(chunkStorage: ChunkStorage, identifier: ChunkIdentifier) async throws -> RawDiskData {
        // Read chunk data from storage
        guard let data = try await chunkStorage.readChunk(identifier) else {
            throw DiskImageError.readFailed
        }
        
        // Validate size
        guard data.count >= minSize && data.count <= maxSize && (data.count % sectorSize == 0) else {
            throw DiskImageError.invalidFormat
        }
        
        // Infer disk geometry from file size
        let geometry = inferGeometry(from: data.count)
        
        // Parse sectors
        let sectors = try parseSectors(from: data, geometry: geometry)
        
        // Create track data
        let tracks = createTracks(from: sectors, geometry: geometry)
        
        // Create metadata
        let metadata = DiskImageMetadata(
            title: nil,
            imageDate: nil,
            geometry: geometry
        )
        
        let diskData = RawDiskData(sectors: sectors, rawData: data)
        diskData.tracks = tracks
        diskData.metadata = metadata
        return diskData
    }
    
    /// Extract metadata from an IMG disk image using MetadataStorage
    public static func extractMetadata(metadataStorage: MetadataStorage, hash: DiskImageHash) async throws -> DiskImageMetadata? {
        return try await metadataStorage.readMetadata(for: hash)
    }
    
    /// Extract metadata from IMG disk image data
    public static func extractMetadata(from data: Data) throws -> DiskImageMetadata? {
        guard data.count >= minSize && data.count <= maxSize && (data.count % sectorSize == 0) else {
            return nil
        }
        
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
        
        // Determine sector size from first sector or metadata
        let sectorSize = metadata?.geometry?.sectorSize ?? sectors[0].data.count
        
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
            // Pad to sector size if needed
            var sectorData = sector.data
            if sectorData.count < sectorSize {
                sectorData.append(Data(repeating: 0, count: sectorSize - sectorData.count))
            } else if sectorData.count > sectorSize {
                sectorData = sectorData.prefix(sectorSize)
            }
            outputData.append(sectorData)
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
        let totalSectors = fileSize / sectorSize
        
        // Common MS-DOS/PC-DOS floppy disk geometries:
        // 360KB: 40 tracks × 9 sectors × 2 sides × 512 bytes = 368,640 bytes
        // 720KB: 80 tracks × 9 sectors × 2 sides × 512 bytes = 737,280 bytes
        // 1.2MB: 80 tracks × 15 sectors × 2 sides × 512 bytes = 1,228,800 bytes
        // 1.44MB: 80 tracks × 18 sectors × 2 sides × 512 bytes = 1,474,560 bytes
        // 2.88MB: 80 tracks × 36 sectors × 2 sides × 512 bytes = 2,949,120 bytes
        
        var tracks = 40  // Default
        var heads = 1    // Default single-sided
        var sectorsPerTrack = 9  // Default
        
        if totalSectors == 720 {
            // 360KB: 40 tracks × 9 sectors × 2 sides
            tracks = 40
            heads = 2
            sectorsPerTrack = 9
        } else if totalSectors == 1440 {
            // 720KB: 80 tracks × 9 sectors × 2 sides
            tracks = 80
            heads = 2
            sectorsPerTrack = 9
        } else if totalSectors == 2400 {
            // 1.2MB: 80 tracks × 15 sectors × 2 sides
            tracks = 80
            heads = 2
            sectorsPerTrack = 15
        } else if totalSectors == 2880 {
            // 1.44MB: 80 tracks × 18 sectors × 2 sides
            tracks = 80
            heads = 2
            sectorsPerTrack = 18
        } else if totalSectors == 5760 {
            // 2.88MB: 80 tracks × 36 sectors × 2 sides
            tracks = 80
            heads = 2
            sectorsPerTrack = 36
        } else {
            // Try to infer from total sectors
            // Assume double-sided if possible
            if totalSectors % 2 == 0 {
                heads = 2
                let sectorsPerSide = totalSectors / 2
                // Try common track counts
                if sectorsPerSide % 40 == 0 {
                    tracks = 40
                    sectorsPerTrack = sectorsPerSide / 40
                } else if sectorsPerSide % 80 == 0 {
                    tracks = 80
                    sectorsPerTrack = sectorsPerSide / 80
                } else {
                    // Estimate
                    tracks = 40
                    sectorsPerTrack = max(9, sectorsPerSide / 40)
                }
            } else {
                // Single-sided
                heads = 1
                if totalSectors % 40 == 0 {
                    tracks = 40
                    sectorsPerTrack = totalSectors / 40
                } else {
                    tracks = 40
                    sectorsPerTrack = max(9, totalSectors / 40)
                }
            }
        }
        
        return DiskGeometry(
            tracks: tracks,
            sides: heads,
            sectorsPerTrack: sectorsPerTrack,
            sectorSize: sectorSize
        )
    }
    
    /// Parse sectors from IMG data
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
                        encoding: .mfm,  // MS-DOS/PC-DOS uses MFM encoding
                        density: nil
                    ))
                }
            }
        }
        
        return trackList
    }
}
