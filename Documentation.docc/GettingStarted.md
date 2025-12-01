# Getting Started with FileSystemKit

Learn how to get started with FileSystemKit in your Swift project.

## Installation

Add FileSystemKit to your Swift Package Manager dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/rickhohler/FileSystemKit.git", from: "1.4.0")
]
```

## Basic Usage

### Creating a Facade Instance

```swift
import FileSystemKit

let storageURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
let facade = FileSystemKitArchiveFacade(storageURL: storageURL)
```

### Creating an Archive

```swift
let sourceURL = URL(fileURLWithPath: "/path/to/source")
let outputURL = URL(fileURLWithPath: "/path/to/archive.snug")

let result = try await facade.createArchive(
    from: sourceURL,
    outputURL: outputURL,
    options: .default
)

print("Created archive with \(result.filesProcessed) files")
```

### Extracting an Archive

```swift
let archiveURL = URL(fileURLWithPath: "/path/to/archive.snug")
let outputURL = URL(fileURLWithPath: "/path/to/output")

let result = try await facade.extractArchive(
    from: archiveURL,
    to: outputURL,
    options: .default
)

print("Extracted \(result.filesExtracted) files")
```

### Listing Archive Contents

```swift
let archiveURL = URL(fileURLWithPath: "/path/to/archive.snug")
let listing = try await facade.contents(of: archiveURL, options: .withMetadata)

for entry in listing.entries {
    print("\(entry.path): \(entry.size ?? 0) bytes")
}
```

## Next Steps

- Learn about <doc:CreatingArchives>
- Explore <doc:SnugFormat>
- See <doc:ArchiveValidation> for verifying archive integrity

