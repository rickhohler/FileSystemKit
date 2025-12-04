# File Type Metadata Protocol

## Overview

The `FileTypeMetadata` protocol provides industry-standard file type identification beyond simple file extensions. It enables file types to be identified using:

- **UTI-style identifiers** (e.g., `com.apple.disk-image.dsk.prodos` - includes both disk image format and file system format)
- **Short IDs** (e.g., `apo`)
- **Human-readable names** (e.g., "Apple II Disk Image Prodos Order")
- **Version information** (semantic versioning)
- **MIME types** (IANA media types)
- **Magic numbers** (file signatures)

## Design Rationale

### Problem

File extensions are unreliable for file type identification:
- Multiple formats can share the same extension (e.g., `.img` for disk images, raw images, etc.)
- Extensions can be missing or incorrect
- Extensions don't convey version or variant information
- Extensions don't follow industry naming standards

### Solution

The `FileTypeMetadata` protocol provides:
1. **Standardized identification** using UTI-style identifiers (reverse-DNS naming)
2. **Magic number detection** for reliable file type identification
3. **Version tracking** for format variants
4. **Industry-standard naming** following UTI and MIME type conventions
5. **Extensibility** through additional metadata

## Industry Standards

### UTI (Uniform Type Identifier)

Apple's UTI system uses reverse-DNS naming:
- Format: `com.vendor.category.layer2-format.layer3-format.version`
- Example: `com.apple.disk-image.dsk.prodos.v2.4` (DSK disk image containing ProDOS 2.4 file system)
- Benefits: Hierarchical, namespaced, unambiguous, explicitly represents both disk image format and file system format with version
- **Layer 2 (Disk Image Format)**: Required - how the disk image is stored (dsk, woz, 2mg, etc.)
- **Layer 3 (File System Format)**: Optional - the file system structure inside (dos33, prodos, sos, etc.)
  - Omitted if file system is unknown, unformatted, or copy-protected
- **Version**: Optional - file system version (v3.3, v2.4, v1.0, etc.)
  - Format: `vMajor.Minor` (e.g., `v3.3`, `v2.4`)
  - Omitted if version cannot be determined or is not applicable
  - Only included when Layer 3 (file system format) is present
  - **Note**: For DOS formats, the layer 3 name reflects the version (dos31, dos32, dos33) to ensure dos33 specifically means DOS 3.3

### MIME Types (IANA Media Types)

IANA maintains the official MIME type registry:
- Format: `type/subtype`
- Example: `application/x-apple-diskimage-dsk-prodos` (includes both Layer 2 and Layer 3)
- Benefits: Widely recognized, standardized
- Both disk image format and file system format are included in the MIME type

### Versioning

Semantic versioning (major.minor.patch):
- Major: Incompatible changes
- Minor: Backward-compatible additions
- Patch: Bug fixes

## Usage

### Basic Implementation

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
    
    var category: FileTypeCategory {
        .diskImage
    }
}
```

### Registration

```swift
let registry = FileTypeMetadataRegistry.shared
await registry.register(AppleIIProDOSDiskImageMetadata())
```

### Detection

```swift
// Detect from file data (magic numbers)
let data = try Data(contentsOf: fileURL)
if let metadata = await registry.detect(from: data) {
    print("Detected: \(metadata.displayName)")
    print("Type ID: \(metadata.typeIdentifier)")
    print("Short ID: \(metadata.shortID)")
}

// Find by short ID
if let metadata = await registry.find(byShortID: "apo") {
    print("Found: \(metadata.displayName)")
}

// Find by extension
let metadataList = await registry.find(byExtension: "po")
for metadata in metadataList {
    print("\(metadata.displayName) uses .po extension")
}
```

## Protocol Requirements

### Required Properties

- `typeIdentifier: String` - UTI-style identifier
- `shortID: String` - Short identifier (3-8 chars)
- `displayName: String` - Human-readable name
- `version: FileTypeVersion?` - Version information
- `mimeType: String?` - MIME type (IANA)
- `extensions: [String]` - File extensions
- `magicNumbers: [FileTypeMagicNumber]` - Magic numbers
- `category: FileTypeCategory` - Category classification

### Optional Properties

- `additionalMetadata: [String: String]` - Additional metadata (default: empty)

## Naming Conventions

### Type Identifier (UTI)

Format: `[reverse-DNS].[category].[subcategory].[variant]`

Examples:
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

## Integration with RetroboxFS

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

## Benefits

1. **Reliable Detection**: Magic numbers are more reliable than extensions
2. **Standardized Naming**: Follows industry conventions (UTI, MIME)
3. **Version Tracking**: Supports format variants and evolution
4. **Extensibility**: Additional metadata for vendor, spec URLs, etc.
5. **Interoperability**: Works with existing systems (UTI, MIME)

## See Also

- [UTI Documentation](https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/understanding_utis/)
- [IANA Media Types](https://www.iana.org/assignments/media-types/)
- [Semantic Versioning](https://semver.org/)

