# Multi-Layer Architecture Support

## Overview

FileSystemKit and RetroboxFS are designed to handle multi-layer file structures, like an onion with nested layers:

1. **Layer 1 (Compression)**: ZIP, GZIP, TAR, etc.
2. **Layer 2 (Disk Image Format)**: DMG, ISO9660, D64, NIB, HDV, etc.
3. **Layer 3 (File System)**: HFS, FAT32, Commodore 1541, Apple II DOS 3.3, etc.

## Architecture Components

### Layer 1: Compression (FileSystemKit)

**Components:**
- `CompressionAdapter` protocol - Base protocol for compression formats
- `DecompressionStage` - Pipeline stage that decompresses files
- `CompressionPipeline` - Pipeline for handling compression
- `NestedCompressionStage` - Handles nested compression (e.g., .tar.gz)

**Key Behavior:**
- `DecompressionStage` updates `PipelineContext.inputURL` to point to the decompressed file
- Supports nested compression detection (e.g., gzip containing tar)
- Decompressed files are stored temporarily and cleaned up after processing

### Layer 2: Disk Image Format (FileSystemKit + RetroboxFS)

**Components:**
- `DiskImageAdapter` protocol - Base protocol for disk image formats
- `FormatDetectionStage` - Detects disk image format from file signature
- `FileSystemDetectionStage` - Reads disk image and extracts `RawDiskData`

**Key Behavior:**
- Reads from `PipelineContext.inputURL` (which may be decompressed from Layer 1)
- Extracts raw disk data (`RawDiskData`) containing sectors, tracks, and metadata
- Stores `RawDiskData` in `PipelineContext.rawDiskData`

### Layer 3: File System (FileSystemKit + RetroboxFS)

**Components:**
- `FileSystemStrategy` protocol - Base protocol for file system formats
- `ParseFileSystemStage` - Parses `RawDiskData` into `FileSystemFolder` structure
- `ListFilesStage` - Lists files in the parsed file system

**Key Behavior:**
- Reads from `PipelineContext.rawDiskData` (extracted in Layer 2)
- Parses file system structures (directory tables, file allocation tables, etc.)
- Creates `FileSystemFolder` hierarchy with `File` objects

## Pipeline Chaining

The architecture supports chaining pipelines together using `PipelineChain`:

```swift
// Example: Process a ZIP file containing a D64 disk image with Commodore 1541 file system
let compressionPipeline = CompressionPipeline(handleNestedCompression: false)
let catalogPipeline = CatalogPipeline()

// Chain them together
let fullPipeline = compressionPipeline |> catalogPipeline

// Execute on ZIP file
let context = try await fullPipeline.execute(inputURL: zipFileURL)

// Result:
// - context.inputURL points to decompressed D64 file (Layer 1 → Layer 2)
// - context.rawDiskData contains raw disk sectors (Layer 2)
// - context.fileSystemFolder contains parsed file system (Layer 3)
```

## How It Works

### Step-by-Step Flow

1. **Compression Pipeline** (`CompressionPipeline`):
   - Detects ZIP format
   - Decompresses ZIP file
   - Updates `context.inputURL` to decompressed file (e.g., `game.d64`)

2. **Format Detection** (`FormatDetectionStage`):
   - Reads decompressed file signature
   - Detects disk image format (e.g., `.d64` for Commodore 64)
   - Stores format in `context.diskImageFormat`

3. **Disk Image Extraction** (`FileSystemDetectionStage`):
   - Uses `DiskImageAdapter` to read disk image
   - Extracts raw disk data (sectors, tracks)
   - Stores `RawDiskData` in `context.rawDiskData`

4. **File System Parsing** (`ParseFileSystemStage`):
   - Detects file system format from `RawDiskData`
   - Uses `FileSystemStrategy` to parse file system
   - Creates `FileSystemFolder` hierarchy
   - Stores in `context.fileSystemFolder`

5. **File Listing** (`ListFilesStage`):
   - Traverses `FileSystemFolder` structure
   - Lists all files with paths and metadata
   - Adds results to `context.results`

## Example: Complete Multi-Layer Pipeline

```swift
import FileSystemKit
import RetroboxFSCore

// Create a pipeline that handles all three layers
let multiLayerPipeline = PipelineChainBuilder(
    id: "multi_layer",
    name: "Multi-Layer Processing",
    description: "Handles compression → disk image → file system"
)
.pipe(CompressionPipeline(handleNestedCompression: false))  // Layer 1
.pipe(CatalogPipeline())  // Layers 2 & 3
.build()

// Process a ZIP file containing a vintage disk image
let zipFileURL = URL(fileURLWithPath: "/path/to/game.zip")
let context = try await multiLayerPipeline.execute(inputURL: zipFileURL)

// Access results
if let folder = context.fileSystemFolder {
    print("Root folder: \(folder.name)")
    for file in folder.getFiles() {
        print("  File: \(file.name) (\(file.size) bytes)")
    }
}

// Access file listing results
for result in context.results {
    if case .fileListing(let listing) = result {
        print("Total files: \(listing.totalFiles)")
        print("Total size: \(listing.totalSize) bytes")
    }
}
```

## Current Limitations

1. **Temporary File Cleanup**: Decompressed files are stored temporarily but may need explicit cleanup in some scenarios
2. **Error Handling**: Errors at any layer stop the pipeline (by design), but error messages could be more specific about which layer failed
3. **Nested Compression**: Currently supports one level of nested compression (e.g., .tar.gz), but deeper nesting may require additional stages
4. **TAR Directory Structures**: `TarCompressionAdapter` currently extracts only the first file from TAR archives, not the full directory structure. See `TAR_DIRECTORY_STRUCTURE_GAP.md` for details.

## Use Case: Gzipped TAR with Directory Structure

A special case of multi-layer architecture is a gzipped tar file (.tar.gz):
- **Level 1**: GZIP compression
- **Level 2**: TAR archive format  
- **Level 3**: Directory structure with directories and files

**Current Status**: ⚠️ **Partially Supported**
- ✅ GZIP decompression works
- ✅ TAR format detection works
- ✅ Nested compression detection works (gzip → tar)
- ❌ TAR directory structure extraction does NOT work (only first file extracted)
- ❌ Directory structure processing pipeline does NOT exist

See `TAR_DIRECTORY_STRUCTURE_GAP.md` for details and proposed solutions.

## Verification

The architecture **DOES** support the multi-layer use case:

✅ **Layer 1 (Compression)**: `CompressionPipeline` handles ZIP decompression  
✅ **Layer 2 (Disk Image)**: `FormatDetectionStage` + `FileSystemDetectionStage` handle disk image reading  
✅ **Layer 3 (File System)**: `ParseFileSystemStage` handles file system parsing  
✅ **Chaining**: `PipelineChain` properly chains pipelines and merges contexts  
✅ **Context Flow**: `PipelineContext.inputURL` is mutable and updated between layers  

## Future Enhancements

1. **Automatic Layer Detection**: Automatically detect and handle all layers without explicit pipeline chaining
2. **Better Error Messages**: More specific error messages indicating which layer failed
3. **Progress Tracking**: Track progress through each layer for better user feedback
4. **Caching**: Cache decompressed files and parsed file systems to avoid reprocessing

