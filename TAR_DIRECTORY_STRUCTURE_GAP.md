# TAR Directory Structure Support Gap

## Use Case

A gzipped tar file (.tar.gz) represents a multi-layer architecture:
- **Level 1**: GZIP compression
- **Level 2**: TAR archive format
- **Level 3**: Directory structure with directories and files

## Current Implementation

### What Works ✅

1. **Level 1 (GZIP)**: `GzipCompressionAdapter` correctly decompresses GZIP files
2. **Level 2 (TAR Detection)**: `TarCompressionAdapter` can detect TAR format
3. **Nested Compression**: `CompressionPipeline` with `NestedCompressionStage` handles gzip → tar detection

### Current Limitation ❌

**`TarCompressionAdapter.decompress()`** currently:
- Extracts only the **first file** from the TAR archive
- Does **NOT** extract the full directory structure
- Returns a single temporary file, not a directory

**Code Reference:**
```swift
// FileSystemKit/Sources/FileSystemKit/Compression/CompressionAdapter.swift:1774-1837
public static func decompress(url: URL) throws -> URL {
    // ... reads TAR header ...
    // Extracts only first file's data
    let fileData = data.subdata(in: dataStart..<dataEnd)
    // Creates single temporary file
    let tempURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension(...)
    try fileData.write(to: tempURL)
    return tempURL  // Returns single file, not directory structure
}
```

## Gap Analysis

### What's Missing

1. **Full TAR Extraction**: Need to extract all files and directories from TAR archive
2. **Directory Structure Creation**: Need to create directory hierarchy matching TAR structure
3. **Pipeline Stage for Directory Processing**: Need a stage that processes extracted directory structures

### Impact

- ✅ GZIP → TAR detection works
- ✅ TAR → single file extraction works
- ❌ TAR → directory structure extraction does NOT work
- ❌ Directory structure → file processing pipeline does NOT exist

## Proposed Solution

### Option 1: Enhance TarCompressionAdapter

Modify `TarCompressionAdapter.decompress()` to:
1. Parse all TAR entries (files and directories)
2. Create directory structure in temporary location
3. Extract all files to their proper locations
4. Return root directory URL instead of single file URL

### Option 2: Create TarExtractionStage

Create a new pipeline stage `TarExtractionStage` that:
1. Detects TAR format
2. Extracts full directory structure
3. Updates `context.inputURL` to extracted directory
4. Stores directory structure metadata in `context.stageData`

### Option 3: Create DirectoryStructurePipeline

Create a pipeline for processing directory structures:
1. Traverses directory structure
2. Processes files based on type (disk images, metadata, etc.)
3. Uses `NestedPipelineStage` to handle multiple files

## Recommended Approach

**Combine Option 1 + Option 3:**

1. **Enhance `TarCompressionAdapter`** to extract full directory structure
2. **Create `DirectoryStructurePipeline`** that processes extracted directories
3. **Chain pipelines**: `CompressionPipeline` → `DirectoryStructurePipeline`

## Example Usage (After Implementation)

```swift
// Process .tar.gz file with directory structure
let compressionPipeline = CompressionPipeline(handleNestedCompression: true)
let directoryPipeline = DirectoryStructurePipeline()

let fullPipeline = compressionPipeline |> directoryPipeline

let context = try await fullPipeline.execute(inputURL: tarGzURL)

// Access extracted directory structure
if let extractedDir = context.stageData["extracted_directory"]?.value as? String {
    let directoryURL = URL(fileURLWithPath: extractedDir)
    // Process files in directory...
}
```

## Related Components

- `CompressionPipeline` - Handles Level 1 (GZIP)
- `TarCompressionAdapter` - Handles Level 2 (TAR) - **needs enhancement**
- `NestedPipelineStage` - Could be used for Level 3 (directory processing)
- `ArchiveOrgPipeline` - Similar pattern for directory structures

## Priority

**Medium** - This is a valid use case but less common than:
- ZIP → disk image → file system (already supported)
- GZIP → disk image → file system (already supported)

However, TAR archives with directory structures are common in Unix/Linux environments and should be supported.

