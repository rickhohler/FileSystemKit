// FileSystemKit Core Library
// Version Types
//
// This file defines core types for capturing and managing versions of operating systems,
// applications, and individual programs. Supports multiple versioning schemes including
// Major.Minor, Major.Minor.Patch, date-based, and semantic versioning.

import Foundation

// MARK: - Version Components

/// Represents the components of a version string
/// Supports Major.Minor, Major.Minor.Patch, and extended formats
public struct VersionComponents: Codable, Sendable, Equatable, Comparable {
    /// Major version number (required)
    public let major: Int
    
    /// Minor version number (required)
    public let minor: Int
    
    /// Patch/build version number (optional)
    public let patch: Int?
    
    /// Additional version suffix (e.g., "beta", "alpha", "rc1")
    public let suffix: String?
    
    /// Build metadata (optional, e.g., "build.123")
    public let build: String?
    
    public init(major: Int, minor: Int, patch: Int? = nil, suffix: String? = nil, build: String? = nil) {
        self.major = major
        self.minor = minor
        self.patch = patch
        self.suffix = suffix
        self.build = build
    }
    
    /// Compare versions numerically (ignores suffix and build)
    public static func < (lhs: VersionComponents, rhs: VersionComponents) -> Bool {
        if lhs.major != rhs.major {
            return lhs.major < rhs.major
        }
        if lhs.minor != rhs.minor {
            return lhs.minor < rhs.minor
        }
        let lhsPatch = lhs.patch ?? 0
        let rhsPatch = rhs.patch ?? 0
        return lhsPatch < rhsPatch
    }
    
    /// Format as string (e.g., "3.3", "2.4.1", "1.0-beta")
    public var stringValue: String {
        var result = "\(major).\(minor)"
        if let patch = patch {
            result += ".\(patch)"
        }
        if let suffix = suffix {
            result += "-\(suffix)"
        }
        if let build = build {
            result += "+\(build)"
        }
        return result
    }
    
    /// Format as Major.Minor only (for vintage systems)
    public var majorMinorString: String {
        return "\(major).\(minor)"
    }
}

// MARK: - Version String Parser

/// Utility for parsing version strings into VersionComponents
/// Supports multiple formats:
/// - Major.Minor: "3.3", "2.4"
/// - Major.Minor.Patch: "2.1.3", "10.15.7"
/// - With suffix: "1.0-beta", "2.0-alpha.1"
/// - With build: "2.3.4+build.123"
public enum VersionParser {
    /// Parse a version string into VersionComponents
    /// - Parameter versionString: Version string to parse
    /// - Returns: VersionComponents if parsing succeeds, nil otherwise
    ///
    /// Examples:
    /// - "3.3" → VersionComponents(major: 3, minor: 3)
    /// - "2.4.1" → VersionComponents(major: 2, minor: 4, patch: 1)
    /// - "1.0-beta" → VersionComponents(major: 1, minor: 0, suffix: "beta")
    /// - "2.3.4+build.123" → VersionComponents(major: 2, minor: 3, patch: 4, build: "build.123")
    public static func parse(_ versionString: String) -> VersionComponents? {
        let trimmed = versionString.trimmingCharacters(in: .whitespaces)
        
        // Split by + to separate build metadata
        let buildComponents = trimmed.split(separator: "+", maxSplits: 1)
        let build = buildComponents.count > 1 ? String(buildComponents[1]) : nil
        
        // Split by - to separate suffix
        let suffixComponents = buildComponents[0].split(separator: "-", maxSplits: 1)
        let suffix = suffixComponents.count > 1 ? String(suffixComponents[1]) : nil
        
        // Parse numeric components
        let numericPart = String(suffixComponents[0])
        let parts = numericPart.split(separator: ".")
        
        guard parts.count >= 2,
              let major = Int(parts[0]),
              let minor = Int(parts[1]) else {
            return nil
        }
        
        let patch = parts.count >= 3 ? Int(parts[2]) : nil
        
        return VersionComponents(
            major: major,
            minor: minor,
            patch: patch,
            suffix: suffix,
            build: build
        )
    }
    
    /// Parse a version string, returning default components if parsing fails
    /// - Parameters:
    ///   - versionString: Version string to parse
    ///   - defaultMajor: Default major version if parsing fails
    ///   - defaultMinor: Default minor version if parsing fails
    /// - Returns: VersionComponents (parsed or default)
    public static func parse(_ versionString: String, defaultMajor: Int = 0, defaultMinor: Int = 0) -> VersionComponents {
        return parse(versionString) ?? VersionComponents(major: defaultMajor, minor: defaultMinor)
    }
}

// MARK: - Version Type

/// Represents a version with source information
/// Can represent operating system versions, application versions, or file versions
public struct Version: Codable, Sendable, Equatable {
    /// Version string as stored in source (e.g., "3.3", "2.4.1")
    public let versionString: String
    
    /// Parsed version components
    public let components: VersionComponents
    
    /// Version scheme used (e.g., "Major.Minor", "SemVer", "Date")
    public let scheme: VersionScheme
    
    /// Source where version was detected (e.g., "VTOC", "Volume Header", "File Metadata")
    public let source: String?
    
    /// Raw bytes/values used to determine version (for debugging/verification)
    public let rawValue: Data?
    
    public init(
        versionString: String,
        components: VersionComponents? = nil,
        scheme: VersionScheme = .majorMinor,
        source: String? = nil,
        rawValue: Data? = nil
    ) {
        self.versionString = versionString
        self.components = components ?? VersionParser.parse(versionString, defaultMajor: 0, defaultMinor: 0)
        self.scheme = scheme
        self.source = source
        self.rawValue = rawValue
    }
    
    /// Create version from string (auto-detects scheme)
    public init(_ versionString: String, source: String? = nil) {
        self.versionString = versionString
        self.components = VersionParser.parse(versionString, defaultMajor: 0, defaultMinor: 0)
        self.scheme = .majorMinor // Default, can be refined
        self.source = source
        self.rawValue = nil
    }
    
    /// Create version from components
    public init(components: VersionComponents, source: String? = nil) {
        self.versionString = components.stringValue
        self.components = components
        self.scheme = .majorMinor
        self.source = source
        self.rawValue = nil
    }
    
    /// Human-readable display string
    public var displayString: String {
        return versionString
    }
    
    /// Compare versions
    public func compare(to other: Version) -> ComparisonResult {
        if components < other.components {
            return .orderedAscending
        } else if components > other.components {
            return .orderedDescending
        } else {
            return .orderedSame
        }
    }
}

// MARK: - Version Scheme

/// Version numbering scheme used
public enum VersionScheme: String, Codable, Sendable {
    /// Major.Minor format (e.g., 3.3, 2.4) - most common for vintage systems
    case majorMinor = "Major.Minor"
    
    /// Major.Minor.Patch format (e.g., 2.1.3, 10.15.7)
    case majorMinorPatch = "Major.Minor.Patch"
    
    /// Semantic Versioning (SemVer) - MAJOR.MINOR.PATCH[-PRERELEASE][+BUILD]
    case semantic = "SemVer"
    
    /// Calendar Versioning (CalVer) - YYYY.MM or YYYY.MM.DD
    case calendar = "Calendar"
    
    /// Date-based versioning (YYYY-MM-DD or similar)
    case date = "Date"
    
    /// Sequential numbering (1, 2, 3, ...)
    case sequential = "Sequential"
    
    /// Unknown or custom scheme
    case unknown = "Unknown"
}

// MARK: - Versioned Entity

/// Protocol for entities that have a version
public protocol Versioned: Sendable {
    /// Version information
    var version: Version? { get }
}

// MARK: - Operating System Version

/// Version information for an operating system (file system format)
public struct OperatingSystemVersion: Codable, Sendable, Versioned {
    /// File system format
    public let fileSystemFormat: FileSystemFormat
    
    /// Version of the operating system
    public let version: Version?
    
    /// Human-readable name (e.g., "DOS 3.3", "ProDOS 2.4")
    public var displayName: String {
        guard let version = version else {
            return fileSystemFormat.rawValue
        }
        
        switch fileSystemFormat {
        case .appleDOS33:
            return "DOS \(version.displayString)"
        case .proDOS:
            return "ProDOS \(version.displayString)"
        case .sos:
            return "SOS \(version.displayString)"
        case .ucsdPascal:
            return "UCSD Pascal \(version.displayString)"
        default:
            return "\(fileSystemFormat.rawValue) \(version.displayString)"
        }
    }
    
    public init(fileSystemFormat: FileSystemFormat, version: Version?) {
        self.fileSystemFormat = fileSystemFormat
        self.version = version
    }
}

// MARK: - Application Version

/// Version information for an application (entire disk image or program)
public struct ApplicationVersion: Codable, Sendable, Versioned {
    /// Application name
    public let name: String?
    
    /// Application version
    public let version: Version?
    
    /// Publisher/developer name
    public let publisher: String?
    
    /// Copyright information
    public let copyright: String?
    
    /// Release date (if known)
    public let releaseDate: Date?
    
    /// Human-readable display string
    public var displayString: String {
        var parts: [String] = []
        if let name = name {
            parts.append(name)
        }
        if let version = version {
            parts.append(version.displayString)
        }
        return parts.joined(separator: " ")
    }
    
    public init(
        name: String? = nil,
        version: Version? = nil,
        publisher: String? = nil,
        copyright: String? = nil,
        releaseDate: Date? = nil
    ) {
        self.name = name
        self.version = version
        self.publisher = publisher
        self.copyright = copyright
        self.releaseDate = releaseDate
    }
}

// MARK: - File Version

/// Version information for an individual file/program
public struct FileVersion: Codable, Sendable, Versioned {
    /// File name
    public let fileName: String
    
    /// File version
    public let version: Version?
    
    /// File type/category
    public let fileType: String?
    
    /// File size
    public let size: Int64?
    
    /// Modification date
    public let modificationDate: Date?
    
    /// Human-readable display string
    public var displayString: String {
        var parts: [String] = [fileName]
        if let version = version {
            parts.append("v\(version.displayString)")
        }
        return parts.joined(separator: " ")
    }
    
    public init(
        fileName: String,
        version: Version? = nil,
        fileType: String? = nil,
        size: Int64? = nil,
        modificationDate: Date? = nil
    ) {
        self.fileName = fileName
        self.version = version
        self.fileType = fileType
        self.size = size
        self.modificationDate = modificationDate
    }
}

