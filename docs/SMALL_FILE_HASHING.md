# Small File Hashing Recommendations

## The Question: Is SHA-256 "Too Large" for Small Files?

### Hash Size Comparison

| Algorithm | Hash Size | Storage (1M files) | Collision Risk (1M files) |
|-----------|-----------|-------------------|---------------------------|
| **CRC32** | 4 bytes | 4 MB | ~0.1% (unacceptable) |
| **MD5** | 16 bytes | 16 MB | Negligible (but broken) |
| **SHA-1** | 20 bytes | 20 MB | Negligible (deprecated) |
| **SHA-256** | 32 bytes | 32 MB | Negligible (secure) |

### Analysis: Is 32 bytes "too large"?

**For small files (< 1 MB):**
- **Hash size**: 32 bytes is negligible compared to file size
- **Storage overhead**: Even with 1 million files, only 32 MB total
- **Performance**: SHA-256 computation time is **negligible** for small files (< 1ms)

**The real question isn't hash size - it's collision risk and future-proofing.**

## Recommendations by Use Case

### ✅ **Use SHA-256 for Small Files** (Recommended)

**When to use:**
- Deduplication (need collision resistance)
- Integrity verification
- Long-term storage/archives
- Any use case where correctness matters

**Why SHA-256 is fine for small files:**
1. **Performance**: SHA-256 is fast enough (< 1ms for files < 1MB)
2. **Storage**: 32 bytes per hash is negligible
3. **Security**: No collision risk
4. **Future-proof**: Industry standard

**Example:**
```swift
// For small files, SHA-256 is perfectly fine
let hash = try computeHash(data: smallFileData, algorithm: .sha256)
// Hash size: 32 bytes
// Computation time: < 1ms for files < 1MB
```

### ⚠️ **Use CRC32 for Very High-Volume Scenarios** (Optional)

**When to use:**
- Initial filtering/quick comparison
- Very large collections (> 10 million files)
- When storage overhead matters significantly
- **Always verify with SHA-256** for exact matches

**Why CRC32 might be considered:**
1. **Storage**: 4 bytes vs 32 bytes (8x smaller)
2. **Performance**: Slightly faster (but negligible for small files)
3. **Trade-off**: Higher collision risk (~0.1% for 1M files)

**Example:**
```swift
// Two-stage approach: CRC32 for filtering, SHA-256 for verification
let crc32 = try computeHash(data: fileData, algorithm: .crc32)  // Fast filter
if potentialMatches.contains(crc32) {
    let sha256 = try computeHash(data: fileData, algorithm: .sha256)  // Exact match
    // Verify against SHA-256
}
```

### ❌ **Don't Use MD5 for New Small Files**

**Why not:**
- Only 16 bytes smaller than SHA-256 (not significant)
- Cryptographically broken
- Deprecated by Apple/CommonCrypto
- No real benefit over SHA-256

**Exception**: Only use MD5 for reading companion checksum files (`.md5`, `.md5sum`)

## Performance Analysis

### Computation Time (typical modern CPU)

| File Size | CRC32 | MD5 | SHA-1 | SHA-256 |
|-----------|-------|-----|-------|---------|
| 1 KB | < 0.01ms | < 0.01ms | < 0.01ms | < 0.01ms |
| 10 KB | < 0.01ms | < 0.01ms | < 0.01ms | < 0.01ms |
| 100 KB | < 0.1ms | < 0.1ms | < 0.1ms | < 0.1ms |
| 1 MB | < 0.5ms | < 0.5ms | < 0.5ms | < 0.5ms |

**Conclusion**: For small files (< 1MB), all algorithms are fast enough. The performance difference is negligible.

### Storage Overhead Analysis

**Scenario: 1 million small files**

| Algorithm | Hash Storage | Percentage of 1GB files |
|-----------|--------------|------------------------|
| CRC32 | 4 MB | 0.4% |
| MD5 | 16 MB | 1.6% |
| SHA-1 | 20 MB | 2.0% |
| SHA-256 | 32 MB | 3.2% |

**Conclusion**: Even SHA-256 overhead is only 3.2% for 1GB of files. Negligible.

## Recommended Strategy

### For Most Use Cases: **SHA-256**

```swift
// Default: Use SHA-256 for all files (including small ones)
let hash = try computeHash(data: fileData, algorithm: .sha256)
```

**Rationale:**
- ✅ Fast enough for small files (< 1ms)
- ✅ Storage overhead is negligible (32 bytes)
- ✅ No collision risk
- ✅ Future-proof
- ✅ Industry standard

### For Very High-Volume Scenarios: **Two-Stage Approach**

```swift
// Stage 1: Fast CRC32 filter
let crc32 = try computeHash(data: fileData, algorithm: .crc32)

// Stage 2: SHA-256 verification for potential matches
if needsVerification {
    let sha256 = try computeHash(data: fileData, algorithm: .sha256)
    // Verify exact match
}
```

**When to use two-stage:**
- Collections with > 10 million files
- When storage overhead becomes significant (> 100MB)
- When you need fast initial filtering

### For Companion File Support: **Multi-Algorithm**

```swift
// Support multiple algorithms when available
struct FileChecksums {
    let sha256: String  // Primary (always computed)
    let crc32: String?  // Optional fast checksum
    let md5: String?    // From companion file (if available)
}
```

## Real-World Examples

### Example 1: ROM Database (Small Files)

**Files**: 10,000 ROM files, average 64 KB each
- **Total file size**: ~640 MB
- **SHA-256 storage**: 320 KB (0.05% overhead)
- **CRC32 storage**: 40 KB (0.006% overhead)

**Recommendation**: Use SHA-256. The 280 KB difference is negligible.

### Example 2: Vintage Software Archive (Small Files)

**Files**: 100,000 files, average 100 KB each
- **Total file size**: ~10 GB
- **SHA-256 storage**: 3.2 MB (0.032% overhead)
- **CRC32 storage**: 400 KB (0.004% overhead)

**Recommendation**: Use SHA-256. The 2.8 MB difference is negligible.

### Example 3: Very Large Collection (Edge Case)

**Files**: 10 million files, average 50 KB each
- **Total file size**: ~500 GB
- **SHA-256 storage**: 320 MB (0.064% overhead)
- **CRC32 storage**: 40 MB (0.008% overhead)

**Recommendation**: Consider two-stage approach (CRC32 filter + SHA-256 verification) if storage/performance becomes a concern.

## Conclusion

### ✅ **SHA-256 is NOT "too large" for small files**

**Reasons:**
1. **Hash size**: 32 bytes is negligible compared to file size
2. **Performance**: SHA-256 is fast enough (< 1ms for small files)
3. **Storage**: Overhead is minimal (3.2% for 1GB of files)
4. **Security**: No collision risk
5. **Future-proof**: Industry standard

### When to Consider Alternatives

**CRC32**: Only for very high-volume scenarios (> 10M files) where storage overhead becomes significant, and always verify with SHA-256 for exact matches.

**MD5**: Only for reading companion checksum files (`.md5`, `.md5sum`), not for new hash generation.

### Final Recommendation

**For small files, use SHA-256 by default.** The "size" concern is not valid - SHA-256 is fast enough and the storage overhead is negligible. Only consider alternatives (CRC32) for very high-volume edge cases.

