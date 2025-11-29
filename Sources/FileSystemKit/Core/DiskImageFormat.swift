// FileSystemKit Core Library
// Disk Image Format Types
//
// This file defines disk image format types used throughout FileSystemKit

import Foundation

/// Disk image format enumeration
/// Represents how disk images are stored in files
/// Includes both modern formats (FileSystemKit) and vintage formats (for compatibility)
public enum DiskImageFormat: String, Codable, CaseIterable, Sendable {
    // Modern formats (post-2000, still in use) - FileSystemKit
    case raw = "raw"              // Raw sector dumps (generic)
    case dmg = "dmg"               // Macintosh disk images
    case iso9660 = "iso-9660"      // ISO 9660 CD-ROM/DVD-ROM
    case vhd = "vhd"               // Virtual Hard Disk format
    case img = "img"               // Raw disk images (for modern FAT32/NTFS)
    
    // Vintage formats (pre-2000, obsolete) - For compatibility with extended packages
    // Apple II formats
    case a2r = "a2r"               // A2R flux-level format
    case woz = "woz"               // WOZ format with copy protection
    case nib = "nib"               // NIB (Nibble) format with raw GCR data
    case hdv = "hdv"               // HDV (Hard Disk Volume) format for ProDOS
    case twoMG = "2mg"             // 2MG (Universal) Apple II disk image format
    
    // Commodore formats
    case d64 = "d64"               // Commodore 64 1541 disk images
    case d81 = "d81"               // Commodore 64 1581 disk images
    case tap = "tap"               // Commodore 64 cassette tape
    case t64 = "t64"               // Commodore 64 tape archive
    
    // Atari formats
    case atr = "atr"               // Atari 8-bit disk images
    
    // Apple II cassette formats
    case cass = "cass"             // Apple II cassette tape
    case wav = "wav"               // WAV audio (for cassette)
    
    // Apple Lisa/III formats
    case lisa = "lisa"             // Apple Lisa FileWare
    case fileware = "fileware"     // Apple Lisa FileWare
    case a3d = "a3d"               // Apple III disk images
    case a3 = "a3"                 // Apple III disk images
    
    // ZX Spectrum formats
    case tzx = "tzx"               // ZX Spectrum extended tape format
    case scl = "scl"               // ZX Spectrum TR-DOS disk image
    case mgt = "mgt"               // ZX Spectrum DISCiPLE/+D disk image
    
    // Corvus formats
    case corvus = "corvus"         // Corvus hard disk images
    case cvs = "cvs"               // Corvus hard disk images
    
    case unknown = "unknown"       // Unknown format
    
    /// File extensions associated with this format
    public var extensions: [String] {
        switch self {
        case .raw: return ["img", "raw"]
        case .dmg: return ["dmg"]
        case .iso9660: return ["iso"]
        case .vhd: return ["vhd"]
        case .img: return ["img", "ima"]
        case .a2r: return ["a2r"]
        case .woz: return ["woz"]
        case .nib: return ["nib"]
        case .hdv: return ["hdv"]
        case .twoMG: return ["2mg"]
        case .d64: return ["d64"]
        case .d81: return ["d81"]
        case .tap: return ["tap"]
        case .t64: return ["t64"]
        case .atr: return ["atr"]
        case .cass: return ["cass"]
        case .wav: return ["wav"]
        case .lisa: return ["lisa"]
        case .fileware: return ["fileware"]
        case .a3d: return ["a3d"]
        case .a3: return ["a3"]
        case .tzx: return ["tzx"]
        case .scl: return ["scl"]
        case .mgt: return ["mgt"]
        case .corvus: return ["corvus", "cvs"]
        case .cvs: return ["cvs"]
        case .unknown: return []
        }
    }
    
    /// Display name for the disk image format
    public var displayName: String {
        return rawValue.uppercased()
    }
}

