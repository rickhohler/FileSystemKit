// FileSystemKit Core Library
// Raw Disk Data Structures
//
// This file implements structures for raw disk data extracted from modern image formats:
// - RawDiskData: Main structure holding extracted disk data
// - SectorData: Logical sector data
// - TrackData: Track-level data
// - FluxData: Raw magnetic flux transitions (for preservation)
// - DiskImageMetadata: Metadata about the disk image
// - DiskImageHash: Cryptographic hash for disk images

import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif
#if canImport(CommonCrypto)
import CommonCrypto
#endif

// MARK: - SectorData

/// Represents a logical sector from a disk
public struct SectorData: Codable, Equatable {
    /// Track number (0-based)
    public let track: Int
    
    /// Sector number within track (0-based)
    public let sector: Int
    
    /// Sector data
    public let data: Data
    
    /// Sector size in bytes
    public var size: Int { data.count }
    
    /// Optional sector flags/attributes
    public var flags: SectorFlags?
    
    public init(track: Int, sector: Int, data: Data, flags: SectorFlags? = nil) {
        self.track = track
        self.sector = sector
        self.data = data
        self.flags = flags
    }
}

/// Sector flags/attributes
public struct SectorFlags: OptionSet, Codable, Sendable {
    public let rawValue: UInt8
    
    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }
    
    public static let deleted = SectorFlags(rawValue: 1 << 0)  // Deleted sector marker
    public static let weak = SectorFlags(rawValue: 1 << 1)    // Weak/flaky bits
    public static let damaged = SectorFlags(rawValue: 1 << 2) // Damaged/corrupted
}

// MARK: - TrackData

/// Represents track-level data from a disk
public struct TrackData: Codable, Equatable {
    /// Track number (0-based)
    public let track: Int
    
    /// Side/head number (0-based, for double-sided disks)
    public let side: Int
    
    /// Sectors in this track
    public let sectors: [SectorData]
    
    /// Track format/encoding (GCR, MFM, FM, etc.)
    public var encoding: TrackEncoding?
    
    /// Track density (single, double, high)
    public var density: TrackDensity?
    
    public init(
        track: Int,
        side: Int = 0,
        sectors: [SectorData],
        encoding: TrackEncoding? = nil,
        density: TrackDensity? = nil
    ) {
        self.track = track
        self.side = side
        self.sectors = sectors
        self.encoding = encoding
        self.density = density
    }
}

/// Track encoding schemes
public enum TrackEncoding: String, Codable {
    case gcr = "gcr"           // Group Code Recording (Apple II, Commodore)
    case mfm = "mfm"           // Modified Frequency Modulation (MS-DOS, CP/M)
    case fm = "fm"             // Frequency Modulation (early systems)
    case unknown = "unknown"
}

/// Track density
public enum TrackDensity: String, Codable {
    case single = "single"     // Single density
    case double = "double"     // Double density
    case high = "high"        // High density
    case extended = "extended" // Extended density
}

// MARK: - MirrorDistance

/// Mirror distance for fat tracks
public struct MirrorDistance: Codable, Equatable {
    public let outward: UInt8
    public let inward: UInt8
    
    public init(outward: UInt8, inward: UInt8) {
        self.outward = outward
        self.inward = inward
    }
}

// MARK: - FluxTrack

/// Represents flux data for a single track
public struct FluxTrack: Codable, Equatable {
    /// Track location (cylinder + side)
    public let location: Int
    
    /// Flux transitions (timing in ticks)
    public let fluxTransitions: [UInt32]
    
    /// Index signal timings for this track
    public let indexSignals: [UInt32]
    
    /// Mirror distance (for fat tracks)
    public let mirrorDistance: MirrorDistance?
    
    public init(
        location: Int,
        fluxTransitions: [UInt32],
        indexSignals: [UInt32] = [],
        mirrorDistance: MirrorDistance? = nil
    ) {
        self.location = location
        self.fluxTransitions = fluxTransitions
        self.indexSignals = indexSignals
        self.mirrorDistance = mirrorDistance
    }
}

// MARK: - FluxCaptureType

/// Type of flux capture
public enum FluxCaptureType: String, Codable {
    case timing = "timing"       // 1.25 revolutions
    case xtiming = "xtiming"     // 2.25+ revolutions
    case bits = "bits"          // Bit-level data
    case unknown = "unknown"
}

// MARK: - FluxData

/// Raw magnetic flux transitions from a disk
/// Preserves exact timing information for copy protection and accurate emulation
public struct FluxData: Codable, Equatable {
    /// Flux data per track
    public let tracks: [FluxTrack]
    
    /// Timing resolution in picoseconds per tick
    public let resolution: Int
    
    /// Index signal timings (global)
    public let indexSignals: [UInt32]?
    
    /// Capture type
    public let captureType: FluxCaptureType
    
    public init(
        tracks: [FluxTrack],
        resolution: Int,
        indexSignals: [UInt32]? = nil,
        captureType: FluxCaptureType = .timing
    ) {
        self.tracks = tracks
        self.resolution = resolution
        self.indexSignals = indexSignals
        self.captureType = captureType
    }
}

// MARK: - DiskImageHash

/// Cryptographic hash for a disk image
public struct DiskImageHash: Hashable, Codable, Sendable {
    /// Hash algorithm used
    public let algorithm: HashAlgorithm
    
    /// Raw hash bytes
    public let value: Data
    
    /// Hex string representation (for display/API)
    public var hexString: String {
        value.map { String(format: "%02x", $0) }.joined()
    }
    
    /// Standard identifier format: "sha256:abc123..."
    public var identifier: String {
        "\(algorithm.rawValue):\(hexString)"
    }
    
    public init(algorithm: HashAlgorithm, value: Data) {
        self.algorithm = algorithm
        self.value = value
    }
    
    // Hashable conformance
    public func hash(into hasher: inout Hasher) {
        hasher.combine(algorithm)
        hasher.combine(value)
    }
    
    // Equatable conformance
    public static func == (lhs: DiskImageHash, rhs: DiskImageHash) -> Bool {
        lhs.algorithm == rhs.algorithm && lhs.value == rhs.value
    }
}

// MARK: - DiskImageMetadata

/// Metadata about a disk image
public struct DiskImageMetadata: Codable, Sendable {
    /// Disk title/name
    public var title: String?
    
    /// Publisher name
    public var publisher: String?
    
    /// Developer name
    public var developer: String?
    
    /// Copyright information
    public var copyright: String?
    
    /// Version number
    public var version: String?
    
    /// Language
    public var language: String?
    
    /// Required platform
    public var requiresPlatform: String?
    
    /// Required machine
    public var requiresMachine: String?
    
    /// Additional notes
    public var notes: String?
    
    /// Image creation date
    public var imageDate: Date?
    
    /// Contributor name
    public var contributor: String?
    
    /// Disk geometry
    public var geometry: DiskGeometry?
    
    /// Copy protection information (extracted from A2R/WOZ formats)
    public var copyProtection: CopyProtectionInfo?
    
    /// Tags for categorization and identification
    /// Created automatically based on disk image format detection
    public var tags: [String]
    
    public init(
        title: String? = nil,
        publisher: String? = nil,
        developer: String? = nil,
        copyright: String? = nil,
        version: String? = nil,
        language: String? = nil,
        requiresPlatform: String? = nil,
        requiresMachine: String? = nil,
        notes: String? = nil,
        imageDate: Date? = nil,
        contributor: String? = nil,
        geometry: DiskGeometry? = nil,
        copyProtection: CopyProtectionInfo? = nil,
        tags: [String] = []
    ) {
        self.title = title
        self.publisher = publisher
        self.developer = developer
        self.copyright = copyright
        self.version = version
        self.language = language
        self.requiresPlatform = requiresPlatform
        self.requiresMachine = requiresMachine
        self.notes = notes
        self.imageDate = imageDate
        self.contributor = contributor
        self.geometry = geometry
        self.copyProtection = copyProtection
        self.tags = tags
    }
}

// MARK: - DiskGeometry

/// Disk geometry information
public struct DiskGeometry: Codable, Equatable, Sendable {
    /// Number of tracks
    public let tracks: Int
    
    /// Number of sides
    public let sides: Int
    
    /// Sectors per track
    public let sectorsPerTrack: Int
    
    /// Sector size in bytes
    public let sectorSize: Int
    
    /// Total capacity in bytes
    public var totalCapacity: Int {
        tracks * sides * sectorsPerTrack * sectorSize
    }
    
    public init(
        tracks: Int,
        sides: Int = 1,
        sectorsPerTrack: Int,
        sectorSize: Int
    ) {
        self.tracks = tracks
        self.sides = sides
        self.sectorsPerTrack = sectorsPerTrack
        self.sectorSize = sectorSize
    }
}

// MARK: - CopyProtectionInfo

/// Copy protection information (extracted from A2R/WOZ formats)
public struct CopyProtectionInfo: Codable, Equatable, Sendable {
    /// Type of copy protection
    public let type: CopyProtectionType
    
    /// Characteristics/description
    public let characteristics: [String]
    
    public init(type: CopyProtectionType, characteristics: [String] = []) {
        self.type = type
        self.characteristics = characteristics
    }
}

/// Copy protection types (extracted from formats, not detected)
public enum CopyProtectionType: String, Codable, Sendable {
    case weakBits = "weakBits"
    case timingBased = "timingBased"
    case longNibbles = "longNibbles"
    case multiTrackHead = "multiTrackHead"
    case spiralPattern = "spiralPattern"
    case trackHalfTrack = "trackHalfTrack"
    case customRWTS = "customRWTS"
    case textMemoryData = "textMemoryData"
    case customSectorLayout = "customSectorLayout"
    case multiple = "multiple"
    case none = "none"
}

// MARK: - RawDiskData

/// Raw disk data extracted from modern image format.
/// This is the output of DiskImageAdapter (Layer 2) and input to FileSystemStrategy (Layer 3).
public class RawDiskData {
    /// Logical sector data (decoded from flux if needed)
    public var sectors: [SectorData]?
    
    /// Track-level data (if available)
    public var tracks: [TrackData]?
    
    /// Raw magnetic flux transitions (if available, from A2R/WOZ formats)
    public var fluxData: FluxData?
    
    /// Disk image metadata
    public var metadata: DiskImageMetadata?
    
    /// Cryptographic hash for deduplication (lazy-computed)
    public var hash: DiskImageHash?
    
    /// Raw disk image data (for reading file content)
    private let rawData: Data
    
    /// Initialize with raw disk data
    /// - Parameter rawData: Raw disk image data
    public init(rawData: Data) {
        self.rawData = rawData
    }
    
    /// Initialize with sectors
    /// - Parameters:
    ///   - sectors: Sector data
    ///   - rawData: Raw disk image data
    public init(sectors: [SectorData], rawData: Data) {
        self.sectors = sectors
        self.rawData = rawData
    }
    
    /// Initialize with tracks
    /// - Parameters:
    ///   - tracks: Track data
    ///   - rawData: Raw disk image data
    public init(tracks: [TrackData], rawData: Data) {
        self.tracks = tracks
        self.rawData = rawData
    }
    
    /// Initialize with flux data
    /// - Parameters:
    ///   - fluxData: Flux data
    ///   - rawData: Raw disk image data
    public init(fluxData: FluxData, rawData: Data) {
        self.fluxData = fluxData
        self.rawData = rawData
    }
    
    /// Read data at specified offset and length
    /// - Parameters:
    ///   - offset: Byte offset in disk image
    ///   - length: Number of bytes to read
    /// - Returns: Data read from disk
    /// - Throws: Error if read fails
    public func readData(at offset: Int, length: Int) throws -> Data {
        guard offset >= 0 && offset + length <= rawData.count else {
            throw FileSystemError.invalidOffset(offset: offset, maxOffset: rawData.count)
        }
        return rawData.subdata(in: offset..<(offset + length))
    }
    
    /// Get total size of raw disk data
    public var totalSize: Int {
        rawData.count
    }
    
    /// Get disk geometry
    /// - Returns: Disk geometry from metadata, or default Apple II geometry if not available
    public func getGeometry() -> DiskGeometry {
        return metadata?.geometry ?? DiskGeometry(
            tracks: 35,
            sides: 1,
            sectorsPerTrack: 16,
            sectorSize: 256
        )
    }
    
    /// Generate hash for disk image (default: SHA-256).
    /// Hash is cached for future use.
    /// - Parameter algorithm: Hash algorithm to use (default: SHA-256)
    /// - Returns: Disk image hash
    /// - Throws: Error if hash cannot be generated
    public func generateHash(algorithm: HashAlgorithm = .sha256) throws -> DiskImageHash {
        // Check if hash already computed and cached
        if let cachedHash = hash, cachedHash.algorithm == algorithm {
            return cachedHash
        }
        
        // Generate hash from raw disk data
        let hashValue = try computeHash(data: rawData, algorithm: algorithm)
        
        // Cache hash
        hash = hashValue
        
        return hashValue
    }
    
    // MARK: - Private Helpers
    
    private func computeHash(data: Data, algorithm: HashAlgorithm) throws -> DiskImageHash {
        #if canImport(CryptoKit)
        let digest: any Digest
        switch algorithm {
        case .sha256:
            digest = SHA256.hash(data: data)
        case .sha1:
            digest = Insecure.SHA1.hash(data: data)
        case .md5:
            digest = Insecure.MD5.hash(data: data)
        case .crc32:
            // CRC32 not in CryptoKit, use simple implementation
            return DiskImageHash(algorithm: .crc32, value: computeCRC32(data: data))
        }
        
        return DiskImageHash(algorithm: algorithm, value: Data(digest))
        #elseif canImport(CommonCrypto)
        // Fallback: Use CommonCrypto (available on Apple platforms)
        switch algorithm {
        case .sha256:
            var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
            data.withUnsafeBytes { bytes in
                _ = CC_SHA256(bytes.baseAddress, CC_LONG(data.count), &digest)
            }
            return DiskImageHash(algorithm: .sha256, value: Data(digest))
        case .sha1:
            var digest = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
            data.withUnsafeBytes { bytes in
                _ = CC_SHA1(bytes.baseAddress, CC_LONG(data.count), &digest)
            }
            return DiskImageHash(algorithm: .sha1, value: Data(digest))
        case .md5:
            #if canImport(CryptoKit)
            // Use CryptoKit's Insecure.MD5 - explicitly marked as insecure for legacy compatibility
            let digest = Insecure.MD5.hash(data: data)
            return DiskImageHash(algorithm: .md5, value: Data(digest))
            #elseif canImport(CommonCrypto)
            // Fallback: Use CommonCrypto (deprecated but kept for legacy compatibility)
            // MD5 is intentionally kept for legacy compatibility (companion files, existing checksums)
            // Note: CC_MD5 deprecation warning is intentional - MD5 is read-only legacy support
            var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
            data.withUnsafeBytes { bytes in
                digest.withUnsafeMutableBytes { digestBytes in
                    // Using deprecated CC_MD5 intentionally for legacy compatibility
                    _ = CC_MD5(bytes.baseAddress, CC_LONG(data.count), digestBytes.baseAddress)
                }
            }
            return DiskImageHash(algorithm: .md5, value: Data(digest))
            #else
            throw FileSystemError.hashNotImplemented(algorithm: .md5)
            #endif
        case .crc32:
            return DiskImageHash(algorithm: .crc32, value: computeCRC32(data: data))
        }
        #else
        throw FileSystemError.hashNotImplemented(algorithm: nil)
        #endif
    }
    
    private func computeCRC32(data: Data) -> Data {
        // Simple CRC32 implementation
        var crc: UInt32 = 0xFFFFFFFF
        let polynomial: UInt32 = 0xEDB88320
        
        var table: [UInt32] = Array(repeating: 0, count: 256)
        for i in 0..<256 {
            var value = UInt32(i)
            for _ in 0..<8 {
                value = (value & 1) != 0 ? (value >> 1) ^ polynomial : value >> 1
            }
            table[i] = value
        }
        
        for byte in data {
            let index = Int((crc ^ UInt32(byte)) & 0xFF)
            crc = (crc >> 8) ^ table[index]
        }
        
        crc ^= 0xFFFFFFFF
        return withUnsafeBytes(of: crc.bigEndian) { Data($0) }
    }
}

