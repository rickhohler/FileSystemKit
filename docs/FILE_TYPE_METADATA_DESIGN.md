# File Type Metadata Protocol - Design Document

## Overview

This document describes the `FileTypeMetadata` protocol design for FileSystemKit, providing industry-standard file type identification beyond simple file extensions.

## Problem Statement

File extensions are unreliable for file type identification:
- Multiple formats can share the same extension (e.g., `.img` for disk images, raw images, etc.)
- Extensions can be missing or incorrect
- Extensions don't convey version or variant information
- Extensions don't follow industry naming standards

## Solution: FileTypeMetadata Protocol

The `FileTypeMetadata` protocol provides:

1. **UTI-style identifiers** (reverse-DNS naming)
   - Example: `com.apple.disk-image.dsk.prodos` (DSK format containing ProDOS)
   - Format: `[reverse-DNS].[category].[layer2-format].[layer3-format]`
   - **Layer 2 (Disk Image Format)**: How the disk image is stored (dsk, woz, 2mg, etc.)
   - **Layer 3 (File System Format)**: The operating system's file system structure (dos33, prodos, sos, pascal, etc.)
   - **Both layers are included** because the same disk image format can contain different file systems
   - Examples:
     - `com.apple.disk-image.dsk.dos33` - DSK format containing DOS 3.3
     - `com.apple.disk-image.dsk.prodos` - DSK format containing ProDOS
     - `com.apple.disk-image.woz.dos33` - WOZ format containing DOS 3.3
     - `com.apple.disk-image.2mg.prodos` - 2MG format containing ProDOS
     - `com.apple.disk-image.dsk` - DSK format, unknown/unformatted file system

2. **Short IDs** (3-8 characters, lowercase)
   - Example: `apo` for "Apple II Disk Image Prodos Order"
   - Used for compact representation and database storage

3. **Human-readable names**
   - Example: "Apple II Disk Image Prodos Order"
   - Follows industry naming conventions

4. **Version information** (semantic versioning)
   - Major.Minor.Patch format
   - Tracks format variants and evolution

5. **MIME types** (IANA media types)
   - Example: `application/x-apple-diskimage-dsk-prodos` (includes both layers)
   - Format: `application/x-[vendor]-diskimage-[layer2]-[layer3]`
   - Industry-standard content type identification
   - Both disk image format and file system format are included in the MIME type

6. **Magic numbers** (file signatures)
   - Byte sequences at specific offsets
   - More reliable than extensions

## Industry Standards

### UTI (Uniform Type Identifier)

Apple's UTI system uses reverse-DNS naming:
- **Format**: `com.vendor.category.layer2-format.layer3-format`
- **Example**: `com.apple.disk-image.dsk.prodos` (DSK disk image containing ProDOS file system)
- **Benefits**: Hierarchical, namespaced, unambiguous, explicitly represents both disk image format and file system format
- **Layer 2 (Disk Image Format)**: Required - represents how the disk image is stored in the file
- **Layer 3 (File System Format)**: Optional - represents the file system structure inside the disk image
  - Omitted if file system is unknown, unformatted, or copy-protected
  - Examples:
    - `com.apple.disk-image.dsk.prodos` - DSK format with ProDOS file system
    - `com.apple.disk-image.dsk` - DSK format, file system unknown/unformatted
    - `com.apple.disk-image.woz` - WOZ format, may be copy-protected (file system detection not possible)

### MIME Types (IANA Media Types)

IANA maintains the official MIME type registry:
- **Format**: `type/subtype`
- **Example**: `application/x-apple-diskimage-prodos`
- **Benefits**: Widely recognized, standardized

### Versioning

Semantic versioning (major.minor.patch):
- **Major**: Incompatible changes
- **Minor**: Backward-compatible additions
- **Patch**: Bug fixes

## Protocol Design

### Core Protocol

```swift
public protocol FileTypeMetadata: Sendable {
    var typeIdentifier: String { get }           // UTI-style identifier
    var shortID: String { get }                  // Short ID (3-8 chars)
    var displayName: String { get }               // Human-readable name
    var version: FileTypeVersion? { get }         // Version info
    var mimeType: String? { get }                // MIME type
    var extensions: [String] { get }             // File extensions
    var magicNumbers: [FileTypeMagicNumber] { get } // Magic numbers
    var category: FileTypeMetadataCategory { get } // Category
    var additionalMetadata: [String: String] { get } // Additional metadata
}
```

### Example Implementation

```swift
struct AppleIIProDOSDiskImageMetadata: FileTypeMetadata {
    var typeIdentifier: String {
        "com.apple.disk-image.prodos-order"
    }
    
    var shortID: String {
        "apo"
    }
    
    var displayName: String {
        "Apple II Disk Image Prodos Order"
    }
    
    var version: FileTypeVersion? {
        FileTypeVersion(major: 1, minor: 0)
    }
    
    var mimeType: String? {
        "application/x-apple-diskimage-prodos"
    }
    
    var extensions: [String] {
        ["po", "prodos"]
    }
    
    var magicNumbers: [FileTypeMagicNumber] {
        [
            FileTypeMagicNumber(
                offset: 0x00,
                bytes: [0x50, 0x52, 0x4F, 0x44] // "PROD"
            )
        ]
    }
    
    var category: FileTypeMetadataCategory {
        .diskImage
    }
}
```

## Registry System

The `FileTypeMetadataRegistry` provides centralized discovery:

```swift
let registry = FileTypeMetadataRegistry.shared

// Register metadata
await registry.register(AppleIIProDOSDiskImageMetadata())

// Detect from file data
if let metadata = await registry.detect(from: data) {
    print("Detected: \(metadata.displayName)")
}

// Find by short ID
if let metadata = await registry.find(byShortID: "apo") {
    print("Found: \(metadata.displayName)")
}

// Find by extension
let metadataList = await registry.find(byExtension: "po")
```

## Naming Conventions

### Type Identifier (UTI)

**Format**: `[reverse-DNS].[category].[subcategory].[variant]`

**Examples**:
- `com.apple.disk-image.prodos-order`
- `com.commodore.disk-image.d64`
- `org.archive.zip`

### Short ID

- 3-8 characters, lowercase
- Should be memorable and unique
- Examples: `apo`, `d64`, `zip`

### Display Name

- Human-readable, descriptive
- Follows industry naming conventions
- Examples:
  - "Apple II Disk Image Prodos Order"
  - "Commodore 64 Disk Image (1541)"
  - "ZIP Archive"

## Magic Numbers

Magic numbers are byte sequences at specific offsets that uniquely identify file types.

### Example

```swift
FileTypeMagicNumber(
    offset: 0,  // Start of file
    bytes: [0x50, 0x4B, 0x03, 0x04],  // "PK" ZIP signature
    mask: nil  // Exact match required
)
```

### Masked Matching

For formats with variable bytes:

```swift
FileTypeMagicNumber(
    offset: 0,
    bytes: [0xFF, 0xD8, 0xFF, 0xE0],  // JPEG signature
    mask: [1, 1, 1, 0]  // Last byte can vary
)
```

## Integration Recommendations

### With RetroboxFS

The `FileTypeMetadata` protocol can be adopted by RetroboxFS `FileType` implementations:

```swift
class ProDOSFileType: FileType {
    // RetroboxFS FileType requirements
    var identifier: String { "prodos" }
    var displayName: String { "ProDOS Disk Image" }
    // ... other FileType requirements
    
    // FileTypeMetadata conformance
    var metadata: FileTypeMetadata {
        AppleIIProDOSDiskImageMetadata()
    }
}
```

### With FileSystemKit

FileSystemKit can use `FileTypeMetadata` for:
- Enhanced file type detection
- Standardized metadata storage
- Cross-platform compatibility

## Benefits

1. **Reliable Detection**: Magic numbers are more reliable than extensions
2. **Standardized Naming**: Follows industry conventions (UTI, MIME)
3. **Version Tracking**: Supports format variants and evolution
4. **Extensibility**: Additional metadata for vendor, spec URLs, etc.
5. **Interoperability**: Works with existing systems (UTI, MIME)

## Future Enhancements

1. **Magic Database**: Centralized database of magic numbers
2. **Format Registry**: Public registry of file type metadata
3. **Validation**: Tools to validate metadata implementations
4. **Migration**: Tools to migrate from extension-based to metadata-based identification

## See Also

- `FileTypeMetadata.swift` - Protocol implementation
- `FileTypeMetadataExamples.swift` - Example implementations
- [UTI Documentation](https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/understanding_utis/)
- [IANA Media Types](https://www.iana.org/assignments/media-types/)
- [Semantic Versioning](https://semver.org/)

