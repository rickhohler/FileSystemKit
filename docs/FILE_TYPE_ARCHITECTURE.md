# File Type Architecture

## Overview

The file type system operates at **two distinct levels**:

1. **Disk Image Level (Layer 2)**: File type for the disk image container itself
2. **File System Level (Layer 3)**: File types for individual files/programs within the disk image

## Two-Level Architecture

### Level 1: Disk Image Container (Layer 2)

The disk image file itself has a type that describes **how the disk image is stored**:

- **Format**: `.dsk`, `.woz`, `.2mg`, `.d64`, `.atr`, etc.
- **UTI**: `com.apple.disk-image.dsk`, `com.apple.disk-image.woz`, etc.
- **Purpose**: Identifies the container format, not the contents

**Example**:
- File: `prodos-disk.po`
- Disk Image Format: `.po` (ProDOS disk image format)
- UTI: `com.apple.disk-image.po`

### Level 2: Files Within Disk Image (Layer 3)

Individual files/programs **inside** the disk image have their own file types:

- **Format**: `.BAS`, `.BIN`, `.TXT`, `.SYS`, etc. (vintage file types)
- **UTI**: Based on file extension, magic numbers, or file system metadata
- **Purpose**: Identifies what each file/program is

**Example**:
- Disk Image: `prodos-disk.po` (container)
- Files Inside:
  - `HELLO.BAS` → File type: BASIC program
  - `SYSTEM.SYS` → File type: System file
  - `DATA.TXT` → File type: Text file

## UTI Structure

### Disk Image UTI (Layer 2)

```
com.apple.disk-image.[format]
```

**Examples**:
- `com.apple.disk-image.dsk` - DSK format container
- `com.apple.disk-image.woz` - WOZ format container
- `com.apple.disk-image.po` - ProDOS format container

### Disk Image with File System UTI (Layer 2 + Layer 3)

```
com.apple.disk-image.[format].[filesystem].[version]
```

**Examples**:
- `com.apple.disk-image.dsk.prodos.v2.4` - DSK container with ProDOS 2.4 file system
- `com.apple.disk-image.woz.dos33.v3.3` - WOZ container with DOS 3.3 file system

### Individual File UTI (Within Disk Image)

```
com.apple.file.[type]
```

**Examples**:
- `com.apple.file.basic` - BASIC program file
- `com.apple.file.binary` - Binary executable
- `com.apple.file.text` - Text file

## Implementation

### Disk Image File Type

**Storage**: `DiskImageMetadata.detectedDiskImageFormat`

```swift
var metadata = DiskImageMetadata()
metadata.detectedDiskImageFormat = .po  // ProDOS disk image format
```

**UTI Generation**:
```swift
let uti = UTIGenerator.generateUTI(
    diskImageFormat: .po,
    fileSystemFormat: .proDOS,
    fileSystemVersion: "2.4"
)
// Returns: "com.apple.disk-image.po.prodos.v2.4"
```

### Individual File Types

**Storage**: `FileSystemEntryMetadata.fileType`

```swift
let entry = FileSystemEntry(
    metadata: FileSystemEntryMetadata(
        name: "HELLO.BAS",
        size: 1024,
        fileType: .text  // or .binary, .basic, etc.
    )
)
```

**File Type Detection**:
- From file extension (`.BAS`, `.BIN`, `.TXT`)
- From file system metadata (DOS file type byte, ProDOS file type)
- From magic numbers (file signatures)
- From file content analysis

## File Type Registry

### RetroboxFS File Types

`RetroboxFS` maintains a registry of vintage file types:

```swift
FileTypeRegistry.shared.register(BasicFileType.self)
FileTypeRegistry.shared.register(BinaryFileType.self)
FileTypeRegistry.shared.register(TextFileType.self)
// ... etc
```

### File Type Detection Flow

1. **Parse file system** → Extract file entries
2. **For each file entry**:
   - Check file extension
   - Check file system metadata (DOS file type byte, ProDOS file type)
   - Check magic numbers
   - Match against registered file types
3. **Assign file type** → Store in `FileSystemEntryMetadata.fileType`

## Examples

### Example 1: ProDOS Disk Image

**Disk Image File**: `prodos-disk.po`
- **Container Type**: `.po` (ProDOS disk image format)
- **UTI**: `com.apple.disk-image.po.prodos.v2.4`

**Files Inside**:
- `HELLO.BAS` → File type: BASIC program
- `SYSTEM.SYS` → File type: System file
- `DATA.TXT` → File type: Text file

### Example 2: DOS 3.3 Disk Image

**Disk Image File**: `dos-disk.dsk`
- **Container Type**: `.dsk` (DSK format)
- **UTI**: `com.apple.disk-image.dsk.dos33.v3.3`

**Files Inside**:
- `PROGRAM` → File type: Binary executable (from DOS file type byte)
- `DATA` → File type: Binary data (from DOS file type byte)

## File Type Categories

### Disk Image Categories

- **Raw formats**: `.dsk`, `.do`, `.po`, `.d13`
- **Preservation formats**: `.woz`, `.a2r`, `.nib`
- **Universal formats**: `.2mg`
- **Platform-specific**: `.d64` (Commodore), `.atr` (Atari)

### File Categories (Within Disk Image)

**FileTypeCategory Enum** (`FileSystemKit/Core/FileTypeCategory.swift`):
- `.text` - Text files
- `.basic` - BASIC programs (Integer BASIC, Applesoft BASIC)
- `.binary` - Binary executables
- `.data` - Data files
- `.graphics` - Graphics files
- `.audio` - Audio files
- `.video` - Video files
- `.archive` - Archive/compressed files
- `.document` - Document files
- `.system` - System files
- `.unknown` - Unknown type

**Detection Sources**:
1. **File System Metadata** (most reliable):
   - DOS file type byte → Maps to FileTypeCategory
   - ProDOS file type byte → Maps to FileTypeCategory

2. **File Extension**:
   - `.BAS` → `.basic`
   - `.BIN` → `.binary`
   - `.TXT` → `.text`

3. **Magic Numbers**:
   - File signatures → FileTypeRegistry detection

## Version Support

### Disk Image Version

Version applies to the **file system format** within the disk image:

- DOS 3.1, 3.2, 3.3
- ProDOS 1.0, 1.1, 2.0, 2.4
- CP/M 2.2, 3.0

**Stored in**: `DiskImageMetadata.operatingSystemVersion`

### File Version

Version can apply to **individual files/programs**:

- Application version (e.g., "Word Processor v2.1")
- Program version (e.g., "Game v1.0")

**Stored in**: `DiskImageMetadata.fileVersions["filename"]`

## Summary

| Level | What | Example | UTI Format | Storage Location |
|-------|------|---------|-------------|------------------|
| **Layer 2** | Disk Image Container | `prodos-disk.po` | `com.apple.disk-image.po` | `DiskImageMetadata.detectedDiskImageFormat` |
| **Layer 2 + 3** | Disk Image + File System | ProDOS 2.4 disk | `com.apple.disk-image.po.prodos.v2.4` | `DiskImageMetadata.operatingSystemVersion` |
| **Layer 3 Files** | Files Inside Disk | `HELLO.BAS` | `com.apple.file.basic` | `FileSystemEntryMetadata.fileType` |

## Current Implementation Status

### ✅ Disk Image File Types (Layer 2)

**Detected**: Yes - via `DiskImageAdapter` registry
**Stored**: `DiskImageMetadata.detectedDiskImageFormat`
**UTI**: Generated via `UTIGenerator.generateUTI(diskImageFormat:fileSystemFormat:fileSystemVersion:)`

**Examples**:
- `.dsk` → `DiskImageFormat.raw`
- `.woz` → `DiskImageFormat.woz`
- `.po` → `DiskImageFormat.po`

### ✅ File System File Types (Layer 3 - OS)

**Detected**: Yes - via `FileSystemStrategy` registry
**Stored**: `DiskImageMetadata.operatingSystemVersion`
**UTI**: Included in disk image UTI (e.g., `com.apple.disk-image.dsk.prodos.v2.4`)

**Examples**:
- DOS 3.3 → `FileSystemFormat.appleDOS33`
- ProDOS 2.4 → `FileSystemFormat.proDOS`

### ✅ Individual File Types (Layer 3 - Files)

**Detected**: Yes - via file system metadata and `FileTypeRegistry`
**Stored**: `FileSystemEntryMetadata.fileType` (FileTypeCategory enum)
**UTI**: Not currently generated (could be added)

**Detection Methods**:
1. **File System Metadata** (primary):
   - DOS: File type byte in catalog entry (0x00=TEXT, 0x01=INTEGER BASIC, 0x02=APPLESOFT BASIC, 0x04=BINARY)
   - ProDOS: File type byte in directory entry (0x04=TXT, 0x06=BAS, 0xFF=BIN)

2. **File Extension** (secondary):
   - `.BAS` → BASIC program
   - `.BIN` → Binary executable
   - `.TXT` → Text file

3. **Magic Numbers** (tertiary):
   - File signature detection via `FileTypeRegistry`

**Examples**:
- `HELLO.BAS` → `FileTypeCategory.basic`
- `PROGRAM` → `FileTypeCategory.binary` (from DOS file type byte)
- `DATA.TXT` → `FileTypeCategory.text`

## See Also

- `FileSystemKit/Core/FileTypeMetadata.swift` - File type metadata protocol
- `RetroboxFS/Core/FileType.swift` - Vintage file type registry
- `FileSystemKit/Core/UTIGenerator.swift` - UTI generation utility
- `FileSystemKit/Core/Version.swift` - Version types

