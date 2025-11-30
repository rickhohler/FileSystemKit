# Hash Algorithm Policy

## Overview

FileSystemKit supports multiple hash algorithms for different use cases. This document outlines the policy for algorithm selection and MD5 support.

## Supported Algorithms

| Algorithm | Status | Use Case | Security |
|-----------|--------|----------|----------|
| **SHA-256** | ✅ **Recommended** | New hash generation, integrity verification | Cryptographically secure |
| **SHA-1** | ⚠️ **Legacy** | Compatibility with existing systems | Deprecated, collision-resistant |
| **MD5** | ⚠️ **Read-Only Legacy** | Validation against existing checksums | Cryptographically broken |
| **CRC32** | ✅ **Fast Checksum** | Quick integrity checks, initial filtering | Not cryptographic |

## MD5 Support Policy

### ✅ **MD5 is Supported For:**

1. **Reading Companion Checksum Files**
   - `.md5` files (standard MD5 checksum format)
   - `.md5sum` files (GNU md5sum format)
   - Other formats containing MD5 hashes
   - Example: `file.txt` with companion `file.txt.md5`

2. **Validating Against Existing MD5 Hashes**
   - When a file already has an MD5 hash stored in metadata
   - When validating against external MD5 checksum databases
   - When verifying integrity of files with existing MD5 checksums
   - Example: ROM databases, vintage software archives

3. **Legacy System Compatibility**
   - Vintage disk image formats that use MD5
   - Existing archives/catalogs that reference MD5 hashes
   - Cross-validation with systems that only provide MD5

### ❌ **MD5 Should NOT Be Used For:**

1. **New Hash Generation**
   - Default algorithm for new files → Use SHA-256
   - New archive creation → Use SHA-256
   - New deduplication systems → Use SHA-256

2. **Security-Critical Operations**
   - Authentication
   - Digital signatures
   - Tamper detection (MD5 collisions are possible)

3. **Primary Integrity Verification**
   - When you have a choice, prefer SHA-256
   - For new systems, always use SHA-256

## Implementation Strategy

### Current Implementation

```swift
// MD5 is available but marked as legacy
public enum HashAlgorithm: String {
    case sha256 = "sha256"  // ✅ Default
    case sha1 = "sha1"       // ⚠️ Legacy
    case md5 = "md5"         // ⚠️ Read-only legacy
    case crc32 = "crc32"    // ✅ Fast checksum
}
```

### Recommended Usage Patterns

#### 1. Reading Companion Checksum Files

```swift
// Read MD5 from companion file
func validateFileWithCompanionChecksum(fileURL: URL) throws -> Bool {
    let checksumFileURL = fileURL.appendingPathExtension("md5")
    guard let checksumData = try? Data(contentsOf: checksumFileURL),
          let expectedMD5 = String(data: checksumData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) else {
        return false
    }
    
    // Compute MD5 for validation (read-only use)
    let fileData = try Data(contentsOf: fileURL)
    let computedMD5 = fileData.md5().map { String(format: "%02x", $0) }.joined()
    
    return computedMD5 == expectedMD5
}
```

#### 2. New Hash Generation (Default)

```swift
// Always use SHA-256 for new hashes
let hash = try computeHash(data: fileData, algorithm: .sha256)
```

#### 3. Multi-Algorithm Support

```swift
// Support multiple algorithms for compatibility
struct FileChecksums {
    let sha256: String  // Primary (always present)
    let md5: String?    // Legacy (if available from companion file)
    let sha1: String?   // Legacy (if available)
}
```

## Rationale

### Why Support MD5 for Read-Only Validation?

1. **Companion File Compatibility**
   - Many systems generate `.md5` companion files
   - GNU `md5sum` format is widely used
   - ROM databases often use MD5

2. **Legacy System Integration**
   - Vintage software archives may only have MD5 checksums
   - Existing catalogs reference MD5 hashes
   - Cross-validation with legacy systems

3. **Integrity Checking (Not Security)**
   - MD5 is sufficient for detecting accidental corruption
   - Collision attacks require intentional malicious input
   - For vintage files, corruption detection is the primary concern

### Why Not Use MD5 for New Hashes?

1. **Cryptographic Weakness**
   - MD5 collisions are computationally feasible
   - Not suitable for security-critical operations
   - Deprecated by Apple/CommonCrypto

2. **Future-Proofing**
   - SHA-256 is the current standard
   - Better long-term compatibility
   - Industry best practice

3. **Performance**
   - SHA-256 performance is acceptable for modern systems
   - Vintage files are small enough that SHA-256 is fast
   - No significant performance advantage for MD5

## Best Practices

### ✅ Do:

- Use SHA-256 as the default algorithm for new code
- Support MD5 for reading companion checksum files
- Validate against existing MD5 hashes when present
- Store multiple hash types when available (SHA-256 + legacy MD5)
- Document when MD5 is used and why

### ❌ Don't:

- Use MD5 as the default algorithm for new files
- Generate new MD5 hashes unless required for compatibility
- Use MD5 for security-critical operations
- Remove MD5 support (breaks companion file compatibility)

## Migration Path

For systems currently using MD5:

1. **Phase 1**: Continue supporting MD5 for validation
2. **Phase 2**: Generate SHA-256 alongside MD5 (dual-hash)
3. **Phase 3**: Prefer SHA-256, fall back to MD5 if needed
4. **Phase 4**: Eventually deprecate MD5 generation (keep validation)

## Example: Companion File Support

```swift
// Proposed API for companion checksum file support
public struct CompanionChecksum {
    let algorithm: HashAlgorithm
    let value: String
    let source: Source
    
    enum Source {
        case companionFile(URL)
        case metadata
        case database
    }
}

// Read companion checksum files
func readCompanionChecksum(for fileURL: URL) throws -> CompanionChecksum? {
    // Try .md5 file
    if let md5 = try? readMD5CompanionFile(for: fileURL) {
        return CompanionChecksum(algorithm: .md5, value: md5, source: .companionFile(fileURL))
    }
    
    // Try .sha256 file
    if let sha256 = try? readSHA256CompanionFile(for: fileURL) {
        return CompanionChecksum(algorithm: .sha256, value: sha256, source: .companionFile(fileURL))
    }
    
    return nil
}
```

## Conclusion

**Recommendation**: Continue supporting MD5 for read-only validation (companion files, existing checksums) while using SHA-256 as the default for new hash generation. This provides:

- ✅ Compatibility with existing systems and companion files
- ✅ Security for new operations (SHA-256)
- ✅ Flexibility for legacy validation (MD5)
- ✅ Future-proofing (SHA-256 standard)

The deprecation warning for `CC_MD5` is acceptable and documented as intentional for legacy compatibility.

