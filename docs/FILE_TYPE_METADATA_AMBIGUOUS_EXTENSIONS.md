# Handling Ambiguous File Extensions

## Problem

Many file formats share the same extension. For example:
- `.img` - Used for disk images, raw images, and other formats
- `.bin` - Used for binary files, disk images, executables
- `.dat` - Used for data files, disk images, and archives

Simple extension-based detection fails in these cases.

## Solution

The `FileTypeMetadata` protocol and registry handle ambiguous extensions by:

1. **Storing multiple metadata per extension** - The registry maintains an array of metadata for each extension
2. **Magic number disambiguation** - When multiple formats share an extension, magic numbers are used to identify the correct format
3. **Combined detection methods** - Methods that use both extension and magic numbers together

## How It Works

### Registry Storage

The registry stores extensions as a dictionary mapping to arrays:

```swift
private var byExtension: [String: [any FileTypeMetadata]] = [:]
```

This allows multiple `FileTypeMetadata` instances to share the same extension.

### Detection Methods

#### 1. Extension-Only Detection

Returns all formats that use the extension:

```swift
let registry = FileTypeMetadataRegistry.shared
let allFormats = await registry.find(byExtension: "img")
// Returns: [DiskImageMetadata, RawImageMetadata, ...]
```

#### 2. Magic Number Detection

Uses file signatures to identify format:

```swift
let data = try Data(contentsOf: fileURL)
if let metadata = await registry.detect(from: data) {
    print("Detected: \(metadata.displayName)")
}
```

#### 3. Combined Detection (Recommended)

Uses extension to narrow candidates, then magic numbers to disambiguate:

```swift
let data = try Data(contentsOf: fileURL)
if let metadata = await registry.detect(extension: "img", data: data) {
    print("Detected: \(metadata.displayName)")
}
```

This method:
1. Finds all metadata matching the extension
2. If multiple candidates, uses magic numbers to find the best match
3. Falls back to first candidate if no magic number match

## Example: Multiple Formats with `.img` Extension

```swift
// Register multiple formats that use .img extension

// Disk image format
struct DiskImageMetadata: FileTypeMetadata {
    var extensions: [String] { ["img"] }
    var magicNumbers: [FileTypeMagicNumber] {
        [FileTypeMagicNumber(offset: 0, bytes: [0x00, 0x00, 0x01, 0x00])]
    }
    // ... other properties
}

// Raw image format
struct RawImageMetadata: FileTypeMetadata {
    var extensions: [String] { ["img"] }
    var magicNumbers: [FileTypeMagicNumber] {
        [FileTypeMagicNumber(offset: 0, bytes: [0xFF, 0xD8, 0xFF])] // JPEG-like
    }
    // ... other properties
}

// Register both
let registry = FileTypeMetadataRegistry.shared
await registry.register(DiskImageMetadata())
await registry.register(RawImageMetadata())

// Detection will use magic numbers to disambiguate
let data = try Data(contentsOf: fileURL)
if let metadata = await registry.detect(extension: "img", data: data) {
    // Will return the correct format based on magic numbers
    print("Detected: \(metadata.displayName)")
}
```

## Detection Priority

When using `detect(extension:data:)`, the registry follows this priority:

1. **Magic number match** - If magic numbers match, return that metadata
2. **Single candidate** - If only one format uses the extension, return it
3. **First candidate** - If multiple formats but no magic match, return first (fallback)

## Best Practices

### 1. Always Provide Magic Numbers

Magic numbers are the most reliable way to identify file types:

```swift
var magicNumbers: [FileTypeMagicNumber] {
    [
        FileTypeMagicNumber(
            offset: 0,
            bytes: [0x50, 0x4B, 0x03, 0x04] // ZIP signature
        )
    ]
}
```

### 2. Use Combined Detection

When you have both extension and file data, use combined detection:

```swift
// Good: Uses both extension and magic numbers
let metadata = await registry.detect(extension: "img", data: data)

// Less reliable: Only uses extension
let metadata = await registry.find(byExtension: "img").first
```

### 3. Handle Multiple Results

When extension-only detection returns multiple results:

```swift
let candidates = await registry.find(byExtension: "img")
if candidates.count > 1 {
    // Use magic numbers to disambiguate
    if let metadata = await registry.detect(from: data) {
        // Found specific format
    }
}
```

## Real-World Example: `.po` Extension

The `.po` extension is used for:
- ProDOS disk images (Apple II)
- Portable Object files (gettext)

```swift
// ProDOS disk image
struct ProDOSDiskImageMetadata: FileTypeMetadata {
    var extensions: [String] { ["po"] }
    var magicNumbers: [FileTypeMagicNumber] {
        [FileTypeMagicNumber(offset: 0, bytes: [0x50, 0x52, 0x4F, 0x44])] // "PROD"
    }
    // ...
}

// Portable Object file
struct PortableObjectMetadata: FileTypeMetadata {
    var extensions: [String] { ["po"] }
    var magicNumbers: [FileTypeMagicNumber] {
        [FileTypeMagicNumber(offset: 0, bytes: [0x6D, 0x73, 0x67, 0x69, 0x64])] // "msgid"
    }
    // ...
}

// Detection will correctly identify based on file content
let metadata = await registry.detect(extension: "po", data: data)
```

## Summary

The `FileTypeMetadata` protocol handles ambiguous extensions by:

✅ **Storing multiple formats per extension**  
✅ **Using magic numbers for disambiguation**  
✅ **Providing combined detection methods**  
✅ **Falling back gracefully when magic numbers aren't available**

This makes file type detection reliable even when extensions are ambiguous.

