# Corrupt Disk Image Test Resources

This directory contains intentionally corrupt disk image files for testing error handling and validation in FileSystemKit.

## Modern Formats (FileSystemKit)

### DMG Files
- **`empty.dmg`** (0 bytes) - Empty file, should fail format detection
- **`too_small.dmg`** (4 bytes) - File too small to be a valid DMG
- **`truncated.dmg`** (256 bytes) - Truncated DMG file (partial data)
- **`invalid_header.dmg`** (1024 bytes) - DMG with wrong signature (XXXX instead of "koly")
- **`all_zeros.dmg`** (1536 bytes) - Valid size but all bytes are 0x00 (invalid data)
- **`all_ones.dmg`** (1536 bytes) - Valid size but all bytes are 0xFF (invalid data)

### ISO9660 Files
- **`empty.iso`** (0 bytes) - Empty file, should fail format detection
- **`too_small.iso`** (4 bytes) - File too small to be a valid ISO
- **`truncated.iso`** (10000 bytes) - Truncated ISO file (less than sector 16)
- **`invalid_header.iso`** (~35KB) - ISO with wrong signature (XXXXX instead of "CD001")
- **`all_zeros.iso`** (~35KB) - Valid size but all bytes are 0x00 (invalid data)
- **`all_ones.iso`** (~35KB) - Valid size but all bytes are 0xFF (invalid data)

### VHD Files
- **`empty.vhd`** (0 bytes) - Empty file, should fail format detection
- **`too_small.vhd`** (4 bytes) - File too small to be a valid VHD
- **`truncated.vhd`** (256 bytes) - Truncated VHD file (less than footer size)
- **`invalid_header.vhd`** (1024 bytes) - VHD with wrong signature (XXXXXXXX instead of "conectix")
- **`all_zeros.vhd`** (1024 bytes) - Valid size but all bytes are 0x00 (invalid data)
- **`all_ones.vhd`** (1024 bytes) - Valid size but all bytes are 0xFF (invalid data)

### IMG Files
- **`empty.img`** (0 bytes) - Empty file, should fail format detection
- **`too_small.img`** (4 bytes) - File too small to be a valid IMG

## Usage

These files are used by `DiskImageAdapterTests` to verify:
- Error handling for invalid/corrupt disk images
- Format detection failure for invalid files
- Graceful error reporting
- Proper exception handling during parsing
- Adapter-specific error handling

## Expected Behavior

All corrupt disk images should:
- Fail format detection OR throw appropriate errors
- Fail file reading operations
- Fail disk info retrieval
- Fail metadata extraction operations
- Throw appropriate error types (`DiskImageError` or `FileSystemError`)
- Provide meaningful error messages indicating the corruption type

## Corruption Types

1. **Empty files** - No data, should fail immediately
2. **Too small** - Insufficient data for any format
3. **Truncated** - Partial data, may detect format but fail parsing
4. **Invalid headers** - Wrong magic numbers or header structure
5. **Invalid data** - Correct size/header but corrupt file system structures
6. **All zeros/ones** - Valid size but no meaningful data

## Note

Vintage file system formats (Apple II, Commodore, Atari, etc.) are NOT included here as they belong in RetroboxFS, not FileSystemKit.

