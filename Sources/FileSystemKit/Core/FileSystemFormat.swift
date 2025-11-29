// FileSystemKit Core Library
// File System Format Types
//
// This file defines file system format types used throughout FileSystemKit

import Foundation

/// File system format enumeration
/// Represents the original file system layout (not the modern image format)
/// Includes both modern formats (FileSystemKit) and vintage formats (RetroboxFS)
public enum FileSystemFormat: String, Codable, CaseIterable, Sendable {
    // Modern file systems (post-2000, still in use) - FileSystemKit
    case iso9660 = "iso9660"      // ISO 9660 CD-ROM/DVD-ROM
    case fat32 = "fat32"          // FAT32 file system
    case ntfs = "ntfs"            // NTFS file system (future)
    case exfat = "exfat"          // exFAT file system (future)
    
    // Vintage file systems (pre-2000, obsolete) - RetroboxFS
    // Apple II
    case apple2DOS33 = "apple2-dos33"
    case apple2ProDOS = "apple2-prodos"
    case apple2Pascal = "apple2-pascal"
    case apple2Corvus = "apple2-corvus"
    case apple2Cassette = "apple2-cassette"
    
    // Apple III
    case apple3SOS = "apple3-sos"
    case apple3Pascal = "apple3-pascal"
    
    // Apple Lisa
    case lisaLFS = "lisa-lfs"
    
    // Commodore 64
    case c64_1541 = "c64-1541"
    case c64_1581 = "c64-1581"
    case c64_TAP = "c64-tap"
    case c64_T64 = "c64-t64"
    
    // Atari 8-bit
    case atariDOS20 = "atari-dos20"
    case atariDOS25 = "atari-dos25"
    
    // CP/M
    case cpm22 = "cpm-22"
    
    // ZX Spectrum
    case zxSpectrumTRDOS = "zx-spectrum-tr-dos"
    case zxSpectrumMGT = "zx-spectrum-mgt"
    case zxSpectrumPlus3DOS = "zx-spectrum-plus3dos"
    case zxSpectrumTAP = "zx-spectrum-tap"
    case zxSpectrumTZX = "zx-spectrum-tzx"
    
    // MS-DOS/PC-DOS
    case msdosFAT12 = "msdos-fat12"
    case msdosFAT16 = "msdos-fat16"
    
    // OS/2
    case os2HPFS = "os2-hpfs"
    
    // Sun
    case sunUFS = "sun-ufs"
    
    // Macintosh
    case macMFS = "mac-mfs"
    case macHFS = "mac-hfs"
    
    // Amiga
    case amigaOFS = "amiga-ofs"
    case amigaFFS = "amiga-ffs"
    
    /// Display name for the file system format
    public var displayName: String {
        rawValue.uppercased()
    }
    
    /// Typical capacity in bytes (approximate)
    public var typicalCapacity: Int {
        switch self {
        case .iso9660: return 737280000  // 700 MB CD-ROM (typical)
        case .fat32: return 1073741824   // 1 GB (typical)
        case .ntfs: return 10737418240  // 10 GB (typical)
        case .exfat: return 10737418240 // 10 GB (typical)
        // Vintage formats
        case .apple2DOS33: return 143360  // 35 tracks * 16 sectors * 256 bytes
        case .apple2ProDOS: return 143360
        case .c64_1541: return 174848     // 35 tracks * 17 sectors * 256 bytes
        case .c64_1581: return 819200     // 80 tracks * 10 sectors * 1024 bytes
        case .atariDOS20, .atariDOS25: return 92160  // 40 tracks * 18 sectors * 128 bytes
        case .cpm22: return 184320        // 40 tracks * 9 sectors * 512 bytes
        case .msdosFAT12: return 1474560   // 1.44 MB floppy
        case .msdosFAT16: return 10485760 // 10 MB (typical)
        default: return 0  // Unknown or variable
        }
    }
    
    /// File system format metadata
    public var metadata: FileSystemFormatMetadata {
        switch self {
        case .iso9660:
            return FileSystemFormatMetadata(
                inceptionYear: 1988,
                endOfPopularityYear: nil  // Still in use
            )
        case .fat32:
            return FileSystemFormatMetadata(
                inceptionYear: 1996,
                endOfPopularityYear: nil  // Still in use
            )
        case .ntfs:
            return FileSystemFormatMetadata(
                inceptionYear: 1993,
                endOfPopularityYear: nil  // Still in use
            )
        case .exfat:
            return FileSystemFormatMetadata(
                inceptionYear: 2006,
                endOfPopularityYear: nil  // Still in use
            )
        // Vintage formats - all pre-2000
        default:
            // For vintage formats, estimate inception year based on format
            let vintageYear: Int
            switch self {
            case .apple2DOS33: vintageYear = 1978
            case .apple2ProDOS: vintageYear = 1983
            case .c64_1541: vintageYear = 1982
            case .c64_1581: vintageYear = 1987
            case .atariDOS20, .atariDOS25: vintageYear = 1980
            case .cpm22: vintageYear = 1979
            case .msdosFAT12, .msdosFAT16: vintageYear = 1981
            case .macMFS: vintageYear = 1984
            case .macHFS: vintageYear = 1985
            default: vintageYear = 1980  // Default vintage year
            }
            return FileSystemFormatMetadata(
                inceptionYear: vintageYear,
                endOfPopularityYear: 2000  // Approximate end of vintage era
            )
        }
    }
}

// MARK: - FileSystemFormatMetadata

/// Metadata about a file system format
public struct FileSystemFormatMetadata: Codable, Sendable {
    /// Year the file system was created/introduced
    public let inceptionYear: Int
    
    /// Approximate year it fell out of common use (nil if still in use)
    public let endOfPopularityYear: Int?
    
    /// Whether this file system is still in common use
    public var isStillInUse: Bool {
        return endOfPopularityYear == nil
    }
    
    /// Whether this file system belongs in FileSystemKit (post-2000 or still in use)
    public var belongsInFileSystemKit: Bool {
        return endOfPopularityYear == nil || endOfPopularityYear! >= 2000
    }
    
    public init(inceptionYear: Int, endOfPopularityYear: Int?) {
        self.inceptionYear = inceptionYear
        self.endOfPopularityYear = endOfPopularityYear
    }
}

