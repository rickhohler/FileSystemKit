# FileSystemKit Test Resources

This directory contains test resource files for FileSystemKit tests.

## Directory Structure

- `DMG/` - macOS disk image files (.dmg)
- `ISO9660/` - ISO 9660 CD-ROM/DVD-ROM images (.iso)
- `VHD/` - Virtual Hard Disk files (.vhd)
- `IMG/` - Raw disk images (.img, .ima)
- `Compressed/` - Compressed test files (.gz, .zip, .tar, .arc)

## Usage in Tests

Tests can access resources using the test bundle:

```swift
let testBundle = Bundle(for: type(of: self))
guard let resourceURL = testBundle.resourceURL else {
    XCTFail("Could not find test resources")
    return
}
let testFile = resourceURL.appendingPathComponent("DMG/test.dmg")
```

## Creating Test Files

Test files should be:
- Small (preferably < 1MB)
- Valid format files (not corrupt)
- Representative of real-world usage
- Licensed appropriately for testing

## Note

Some test files may need to be created programmatically or obtained from public sources.
For compressed formats, we can create test archives using standard tools.

