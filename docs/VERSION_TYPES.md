# Version Types Documentation

## Overview

FileSystemKit provides comprehensive version support for capturing versions of operating systems, applications, and individual files. This system supports multiple versioning schemes including Major.Minor, Major.Minor.Patch, semantic versioning, and date-based formats.

## Core Types

### VersionComponents

Represents the parsed components of a version string.

```swift
public struct VersionComponents {
    public let major: Int          // Required
    public let minor: Int          // Required
    public let patch: Int?         // Optional
    public let suffix: String?     // Optional (e.g., "beta", "alpha")
    public let build: String?      // Optional (e.g., "build.123")
}
```

**Examples**:
- `VersionComponents(major: 3, minor: 3)` → "3.3"
- `VersionComponents(major: 2, minor: 4, patch: 1)` → "2.4.1"
- `VersionComponents(major: 1, minor: 0, suffix: "beta")` → "1.0-beta"

### Version

Represents a version with source information and scheme.

```swift
public struct Version {
    public let versionString: String        // Original version string
    public let components: VersionComponents // Parsed components
    public let scheme: VersionScheme         // Versioning scheme used
    public let source: String?               // Where version was detected
    public let rawValue: Data?              // Raw bytes (for verification)
}
```

**Usage**:
```swift
// From string
let version = Version("3.3", source: "VTOC")

// From components
let components = VersionComponents(major: 2, minor: 4)
let version = Version(components: components, source: "Volume Header")
```

### VersionScheme

Enumeration of supported versioning schemes.

```swift
public enum VersionScheme {
    case majorMinor        // "3.3", "2.4" - most common for vintage systems
    case majorMinorPatch   // "2.1.3", "10.15.7"
    case semantic          // SemVer format
    case calendar          // Date-based (YYYY.MM)
    case date              // Date format (YYYY-MM-DD)
    case sequential        // Sequential numbers
    case unknown           // Unknown/custom scheme
}
```

## Versioned Entities

### OperatingSystemVersion

Version information for an operating system (file system format).

```swift
public struct OperatingSystemVersion {
    public let fileSystemFormat: FileSystemFormat
    public let version: Version?
    
    // Human-readable display name
    public var displayName: String  // e.g., "DOS 3.3", "ProDOS 2.4"
}
```

**Usage**:
```swift
let osVersion = OperatingSystemVersion(
    fileSystemFormat: .appleDOS33,
    version: Version("3.3", source: "VTOC")
)
print(osVersion.displayName)  // "DOS 3.3"
```

### ApplicationVersion

Version information for an application (entire disk image).

```swift
public struct ApplicationVersion {
    public let name: String?
    public let version: Version?
    public let publisher: String?
    public let copyright: String?
    public let releaseDate: Date?
    
    // Human-readable display string
    public var displayString: String  // e.g., "MyApp 1.0"
}
```

**Usage**:
```swift
let appVersion = ApplicationVersion(
    name: "MyApp",
    version: Version("1.0", source: "Metadata"),
    publisher: "Acme Corp",
    copyright: "© 2025"
)
print(appVersion.displayString)  // "MyApp 1.0"
```

### FileVersion

Version information for an individual file/program.

```swift
public struct FileVersion {
    public let fileName: String
    public let version: Version?
    public let fileType: String?
    public let size: Int64?
    public let modificationDate: Date?
    
    // Human-readable display string
    public var displayString: String  // e.g., "PROGRAM v2.1"
}
```

**Usage**:
```swift
let fileVersion = FileVersion(
    fileName: "PROGRAM",
    version: Version("2.1", source: "File Header"),
    fileType: "BIN",
    size: 1024
)
print(fileVersion.displayString)  // "PROGRAM v2.1"
```

## Version Parsing

### VersionParser

Utility for parsing version strings into `VersionComponents`.

```swift
public enum VersionParser {
    // Parse version string
    static func parse(_ versionString: String) -> VersionComponents?
    
    // Parse with defaults
    static func parse(_ versionString: String, 
                     defaultMajor: Int, 
                     defaultMinor: Int) -> VersionComponents
}
```

**Supported Formats**:
- `"3.3"` → `VersionComponents(major: 3, minor: 3)`
- `"2.4.1"` → `VersionComponents(major: 2, minor: 4, patch: 1)`
- `"1.0-beta"` → `VersionComponents(major: 1, minor: 0, suffix: "beta")`
- `"2.3.4+build.123"` → `VersionComponents(major: 2, minor: 3, patch: 4, build: "build.123")`

## Integration with DiskImageMetadata

### Operating System Version

```swift
var metadata = DiskImageMetadata()
metadata.operatingSystemVersion = OperatingSystemVersion(
    fileSystemFormat: .appleDOS33,
    version: Version("3.3", source: "VTOC")
)
```

### Application Version

```swift
metadata.applicationVersion = ApplicationVersion(
    name: "MyApp",
    version: Version("1.0", source: "Metadata"),
    publisher: "Acme Corp"
)
```

### File Versions

```swift
metadata.fileVersions = [
    "PROGRAM": FileVersion(
        fileName: "PROGRAM",
        version: Version("2.1", source: "File Header")
    ),
    "DATA": FileVersion(
        fileName: "DATA",
        version: nil  // No version available
    )
]
```

## Version Comparison

Versions can be compared numerically:

```swift
let v1 = Version("3.2", source: nil)
let v2 = Version("3.3", source: nil)

let result = v1.compare(to: v2)  // .orderedAscending
```

`VersionComponents` conforms to `Comparable`:

```swift
let v1 = VersionComponents(major: 3, minor: 2)
let v2 = VersionComponents(major: 3, minor: 3)

if v1 < v2 {
    print("v1 is older")
}
```

## Backward Compatibility

The legacy `detectedFileSystemVersion: String?` property is still available but deprecated:

```swift
// Legacy (deprecated)
metadata.detectedFileSystemVersion = "3.3"

// New (recommended)
metadata.operatingSystemVersion = OperatingSystemVersion(
    fileSystemFormat: .appleDOS33,
    version: Version("3.3", source: "VTOC")
)
```

The legacy property automatically syncs with `operatingSystemVersion` for backward compatibility.

## Examples

### Detecting DOS Version

```swift
// In AppleIIFormatDetector
let dosVersion = vtocSector.data[3]  // Byte 3 contains version
let versionString = "3.\(dosVersion)"
let version = Version(
    versionString: versionString,
    scheme: .majorMinor,
    source: "DOS VTOC (byte 3)",
    rawValue: Data([dosVersion])
)

metadata.operatingSystemVersion = OperatingSystemVersion(
    fileSystemFormat: .appleDOS33,
    version: version
)
```

### Detecting ProDOS Version

```swift
// In AppleIIProDOSFileSystemStrategy
let majorVersion = volumeHeader.version      // Byte 26
let minorVersion = volumeHeader.minVersion   // Byte 27
let versionString = "\(majorVersion).\(minorVersion)"
let version = Version(
    versionString: versionString,
    scheme: .majorMinor,
    source: "ProDOS Volume Header (bytes 26-27)",
    rawValue: Data([majorVersion, minorVersion])
)

metadata.operatingSystemVersion = OperatingSystemVersion(
    fileSystemFormat: .proDOS,
    version: version
)
```

### Extracting File Versions

```swift
// When parsing file system entries
for entry in fileSystemEntries {
    if let fileVersion = extractVersion(from: entry) {
        metadata.fileVersions[entry.name] = FileVersion(
            fileName: entry.name,
            version: fileVersion,
            fileType: entry.fileType,
            size: Int64(entry.size)
        )
    }
}
```

## See Also

- `VersionComponents` - Parsed version components
- `Version` - Version with source information
- `OperatingSystemVersion` - OS version information
- `ApplicationVersion` - Application version information
- `FileVersion` - File version information
- `VersionParser` - Version string parsing utility
- `DiskImageMetadata` - Disk image metadata container

