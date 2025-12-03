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

/// Represents a logical sector from a disk.
///
/// `SectorData` contains the decoded data from a single disk sector, including
/// track and sector numbers, sector data, and optional flags.
///
/// ## See Also
///
/// - [Disk Sector (Wikipedia)](https://en.wikipedia.org/wiki/Disk_sector) - Information about disk sectors
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

/// Represents track-level data from a disk.
///
/// `TrackData` contains information about a single track including its sectors,
/// encoding scheme, and density. This is useful for vintage disk formats that
/// use track-based organization.
///
/// ## See Also
///
/// - ``SectorData`` - Individual sector data
/// - ``TrackEncoding`` - Track encoding schemes
/// - [Track (disk drive) (Wikipedia)](https://en.wikipedia.org/wiki/Track_(disk_drive)) - Information about disk tracks
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

/// Track encoding schemes used for magnetic disk storage.
///
/// Different encoding schemes were used by various computer systems to store
/// data on magnetic disks. Each encoding has different characteristics for
/// density, reliability, and compatibility.
///
/// ## See Also
///
/// - [Group Code Recording (Wikipedia)](https://en.wikipedia.org/wiki/Group_code_recording) - GCR encoding details
/// - [Modified Frequency Modulation (Wikipedia)](https://en.wikipedia.org/wiki/Modified_frequency_modulation) - MFM encoding details
/// - [Frequency Modulation (Wikipedia)](https://en.wikipedia.org/wiki/Frequency_modulation) - FM encoding details
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

/// Raw magnetic flux transitions from a disk.
///
/// `FluxData` preserves exact timing information for copy protection and accurate emulation.
/// This data format captures the magnetic flux transitions directly from the disk surface,
/// enabling preservation of copy-protected disks and accurate emulation.
///
/// ## See Also
///
/// - [Magnetic Storage (Wikipedia)](https://en.wikipedia.org/wiki/Magnetic_storage) - Overview of magnetic storage
/// - [Copy Protection (Wikipedia)](https://en.wikipedia.org/wiki/Copy_protection) - Information about copy protection
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

/// Metadata describing a disk image's properties and provenance.
///
/// `DiskImageMetadata` provides comprehensive information about a disk image including
/// title, publisher, developer, copyright, version, and other descriptive information.
/// This metadata helps with cataloging, searching, and identifying disk images.
///
/// ## Usage
///
/// Create metadata for a disk image:
/// ```swift
/// let metadata = DiskImageMetadata(
///     title: "My Application",
///     publisher: "Acme Software",
///     developer: "John Developer",
///     copyright: "© 2024 Acme Software",
///     version: "1.0.0",
///     language: "en",
///     requiresPlatform: "macOS",
///     imageDate: Date(),
///     geometry: diskGeometry
/// )
/// ```
///
/// Add tags for categorization:
/// ```swift
/// var metadata = DiskImageMetadata()
/// metadata.tags = ["game", "adventure", "1980s"]
/// ```
///
/// Include copy protection information:
/// ```swift
/// let metadata = DiskImageMetadata(
///     title: "Protected Game",
///     copyProtection: CopyProtectionInfo(
///         type: .nibble,
///         description: "Nibble-based copy protection"
///     )
/// )
/// ```
///
/// ## Properties
///
/// - `title` - Disk title/name
/// - `publisher` - Publisher name
/// - `developer` - Developer name
/// - `copyright` - Copyright information
/// - `version` - Version number
/// - `language` - Language code
/// - `requiresPlatform` - Required platform
/// - `requiresMachine` - Required machine
/// - `notes` - Additional notes
/// - `imageDate` - Image creation date
/// - `contributor` - Contributor name
/// - `geometry` - Disk geometry information
/// - `copyProtection` - Copy protection details
/// - `tags` - Categorization tags
/// - `bootability` - Bootability state and boot instructions
///
/// ## See Also
///
/// - ``RawDiskData`` - Disk data container
/// - ``DiskGeometry`` - Disk geometry information
/// - [Metadata (Wikipedia)](https://en.wikipedia.org/wiki/Metadata) - Overview of metadata concepts
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
    
    /// Vendor identifier (UUID) - references a vendor from vendor storage
    /// Identified automatically based on disk image format and file system format
    /// nil if vendor cannot be identified
    public var vendorID: UUID?
    
    /// Vendor name - human-readable vendor name
    /// Identified automatically based on disk image format and file system format
    /// This is a convenience field; the canonical vendor data is stored via vendorID
    /// nil if vendor cannot be identified
    public var vendorName: String?
    
    /// Detected disk image format (Layer 2: how disk is stored in file)
    /// Examples: .dsk, .woz, .d64, .atr, .dmg, .iso9660
    /// This is the container format, not the file system format
    /// Set by DiskImageAdapter when extracting raw disk data
    public var detectedDiskImageFormat: DiskImageFormat?
    
    /// Detected file system format (Layer 3: operating system's file system structure)
    /// Examples: .appleDOS33, .proDOS, .sos, .ucsdPascal, .c64_1541
    /// This is the file system format within the disk image
    /// Set by FileSystemStrategy when detecting format from raw disk data
    public var detectedFileSystemFormat: FileSystemFormat?
    
    /// Bootability information for this disk image
    /// Contains bootability state and boot instructions
    /// Set automatically during disk image analysis based on detection of boot code patterns
    /// and file system format analysis
    public var bootability: BootInstructions?
    
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
        tags: [String] = [],
        vendorID: UUID? = nil,
        vendorName: String? = nil,
        detectedDiskImageFormat: DiskImageFormat? = nil,
        detectedFileSystemFormat: FileSystemFormat? = nil,
        bootability: BootInstructions? = nil
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
        self.vendorID = vendorID
        self.vendorName = vendorName
        self.detectedDiskImageFormat = detectedDiskImageFormat
        self.detectedFileSystemFormat = detectedFileSystemFormat
        self.bootability = bootability
    }
}

// MARK: - DiskGeometry

/// Disk geometry information describing the physical layout of a disk.
///
/// `DiskGeometry` specifies the number of tracks, sides, sectors per track, and
/// sector size. This information is essential for reading and writing disk images
/// accurately, especially for vintage formats.
///
/// ## Usage
///
/// Create geometry for a standard floppy disk:
/// ```swift
/// let geometry = DiskGeometry(
///     tracks: 80,
///     sides: 2,
///     sectorsPerTrack: 18,
///     sectorSize: 512
/// )
///
/// print("Capacity: \(geometry.totalCapacity) bytes")
/// ```
///
/// ## See Also
///
/// - ``RawDiskData`` - Uses disk geometry
/// - [Cylinder-head-sector (Wikipedia)](https://en.wikipedia.org/wiki/Cylinder-head-sector) - CHS addressing system
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

/// Raw disk data extracted from modern disk image formats.
///
/// `RawDiskData` represents the raw binary data extracted from disk image formats
/// (DMG, ISO, VHD, etc.). It serves as the bridge between disk image adapters
/// (Layer 2) and file system strategies (Layer 3).
///
/// ## Overview
///
/// Raw disk data can contain:
/// - **Sector Data**: Logical sectors decoded from the disk image
/// - **Track Data**: Track-level information with encoding details
/// - **Flux Data**: Raw magnetic flux transitions (for preservation formats)
/// - **Metadata**: Disk image metadata (title, geometry, etc.)
///
/// ## Usage
///
/// Create from raw data:
/// ```swift
/// let diskImageData = try Data(contentsOf: diskImageURL)
/// let rawDiskData = RawDiskData(rawData: diskImageData)
/// ```
///
/// Create with sectors:
/// ```swift
/// let sectors: [SectorData] = // ... decoded sectors
/// let rawDiskData = RawDiskData(sectors: sectors, rawData: diskImageData)
/// ```
///
/// Read data at specific offset:
/// ```swift
/// let rawDiskData: RawDiskData = // ... obtained from adapter
///
/// // Read 512 bytes starting at offset 1024
/// let data = try rawDiskData.readData(at: 1024, length: 512)
/// ```
///
/// Access disk geometry:
/// ```swift
/// let geometry = rawDiskData.getGeometry()
/// print("Tracks: \(geometry.tracks), Sectors: \(geometry.sectorsPerTrack)")
/// print("Capacity: \(geometry.totalCapacity) bytes")
/// ```
///
/// Generate hash for deduplication:
/// ```swift
/// let hash = try rawDiskData.generateHash(algorithm: .sha256)
/// print("Disk hash: \(hash.hexString)")
/// ```
///
/// Access metadata:
/// ```swift
/// if let metadata = rawDiskData.metadata {
///     print("Title: \(metadata.title ?? "Unknown")")
///     print("Publisher: \(metadata.publisher ?? "Unknown")")
/// }
/// ```
///
/// ## Architecture Role
///
/// `RawDiskData` is the output of **Layer 2** (Disk Image Adapters) and the input
/// to **Layer 3** (File System Strategies):
///
/// ```
/// Disk Image (DMG/ISO/VHD) 
///   → DiskImageAdapter (Layer 2)
///   → RawDiskData
///   → FileSystemStrategy (Layer 3)
///   → FileSystemFolder
/// ```
///
/// ## See Also
///
/// - ``SectorData`` - Logical sector representation
/// - ``TrackData`` - Track-level data
/// - ``FluxData`` - Raw flux transitions
/// - ``DiskImageMetadata`` - Disk metadata
/// - ``DiskGeometry`` - Disk geometry information
/// - [Disk Image (Wikipedia)](https://en.wikipedia.org/wiki/Disk_image) - Overview of disk image formats
/// - [DMG (Wikipedia)](https://en.wikipedia.org/wiki/Apple_Disk_Image) - Apple Disk Image format
/// - [ISO Image (Wikipedia)](https://en.wikipedia.org/wiki/ISO_image) - ISO 9660 disk images
/// - [VHD (Wikipedia)](https://en.wikipedia.org/wiki/VHD_(file_format)) - Virtual Hard Disk format
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
        // Use FileSystemKit's core HashComputation for unified implementation
        let hashData = try HashComputation.computeHash(data: data, algorithm: algorithm)
        return DiskImageHash(algorithm: algorithm, value: hashData)
    }
}

