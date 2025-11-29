# FileSystemKit Test Resources

This directory contains test resource files for FileSystemKit tests.

## Directory Structure

- `DMG/` - macOS disk image files (.dmg)
  - `test.dmg` - Minimal valid DMG file with UDIF structure
- `ISO9660/` - ISO 9660 CD-ROM/DVD-ROM images (.iso)
  - `test.iso` - Minimal valid ISO9660 file with volume descriptors
- `VHD/` - Virtual Hard Disk files (.vhd)
  - `test.vhd` - Minimal valid VHD file with footer
- `IMG/` - Raw disk images (.img, .ima)
  - `test.img` - Minimal valid raw disk image (360KB, sector-aligned)
- `Compressed/` - Compressed test files (.gz, .zip, .tar, .arc)
  - `test.gz` - Gzip compressed test file
  - `test.zip` - ZIP archive with test file
  - `test.tar` - TAR archive with test file
  - `test.arc` - ARC archive with test file
- `Corrupt/` - Intentionally corrupt files for error handling tests
  - See `Corrupt/README.md` for details

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

Or use the helper method in `DiskImageAdapterTests`:

```swift
if let dmgFile = getTestResource("DMG/test.dmg") {
    // Use the file
}
```

## Test Files

### Valid Files

All valid test files are minimal implementations that:
- Contain correct format signatures/headers
- Are small (< 1MB) for fast test execution
- Are sufficient for format detection and basic parsing tests
- May not contain complete file system structures (for simplicity)

### Corrupt Files

Corrupt test files are located in `Corrupt/` and include:
- Empty files (0 bytes)
- Too small files (< minimum format size)
- Truncated files (partial data)
- Invalid headers (wrong signatures)
- Invalid data (all zeros/ones)

See `Corrupt/README.md` for complete documentation.

## File Formats

### DMG (Apple Disk Image)
- Format: UDIF (Universal Disk Image Format)
- Signature: "koly" at end of file (512-byte footer)
- Test file: `DMG/test.dmg` (1.5KB)

### ISO9660 (CD-ROM/DVD-ROM)
- Format: ISO 9660 file system
- Signature: "CD001" at sector 16 (offset 0x8000)
- Sector size: 2048 bytes
- Test file: `ISO9660/test.iso` (36KB)

### VHD (Virtual Hard Disk)
- Format: Microsoft VHD format
- Signature: "conectix" in 512-byte footer at end
- Test file: `VHD/test.vhd` (1KB)

### IMG (Raw Disk Image)
- Format: Raw sector dump
- Requirements: Minimum 360KB, sector-aligned (512 bytes)
- Test file: `IMG/test.img` (360KB)

### Compression Formats
- **GZIP** (.gz): Standard gzip compression
- **ZIP** (.zip): ZIP archive with deflate compression
- **TAR** (.tar): Unix tar archive
- **ARC** (.arc): ARC archive format

## Note

These test files are created programmatically for testing purposes only.
They are minimal implementations sufficient for unit testing but may not
represent complete, real-world disk images. For production use, always
test with actual disk image files.

Vintage file system formats (Apple II, Commodore, Atari, etc.) are NOT
included here as they belong in RetroboxFS, not FileSystemKit.

