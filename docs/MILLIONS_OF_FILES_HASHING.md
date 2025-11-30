# Hash Algorithm Selection for Millions of Files

## The Challenge

When storing hashes for **millions of files**, storage overhead becomes a significant consideration. This document provides recommendations for hash algorithm selection at scale.

## Storage Overhead Analysis

### Hash Storage Requirements

| Algorithm | Hash Size | 1M Files | 10M Files | 100M Files |
|-----------|-----------|----------|-----------|------------|
| **CRC32** | 4 bytes | 4 MB | 40 MB | 400 MB |
| **MD5** | 16 bytes | 16 MB | 160 MB | 1.6 GB |
| **SHA-1** | 20 bytes | 20 MB | 200 MB | 2.0 GB |
| **SHA-256** | 32 bytes | 32 MB | 320 MB | 3.2 GB |

### Additional Storage Considerations

**Metadata overhead** (beyond hash value):
- Hash algorithm identifier: ~10 bytes per entry
- File path/index: Variable
- Metadata (size, dates, etc.): Variable
- **Total per entry**: ~50-100 bytes (hash + metadata)

**For 10 million files:**
- Hash storage: 320 MB (SHA-256)
- Metadata storage: ~500 MB - 1 GB
- **Total**: ~1-1.5 GB

## Collision Risk Analysis

### CRC32 Collision Risk (Unacceptable for Millions)

CRC32 has only 2^32 (4.3 billion) possible values. Using the birthday paradox:

- **1M files**: ~0.1% collision probability (unacceptable)
- **10M files**: ~10% collision probability (unacceptable)
- **100M files**: ~100% collision probability (guaranteed collisions)

**Conclusion**: CRC32 is **NOT suitable** for millions of files due to high collision risk.

### MD5 vs SHA-256 Collision Risk

Both MD5 and SHA-256 have negligible collision risk for millions of files:

- **MD5**: 2^128 possible values → Negligible collision risk
- **SHA-256**: 2^256 possible values → Negligible collision risk

**However**: MD5 is cryptographically broken (intentional collisions possible), while SHA-256 is secure.

## Recommendations by Scale

### ✅ **< 1 Million Files: SHA-256**

**Storage**: 32 MB  
**Recommendation**: Use SHA-256

**Rationale**:
- Storage overhead is negligible
- Secure and future-proof
- Industry standard

### ✅ **1-10 Million Files: SHA-256**

**Storage**: 32-320 MB  
**Recommendation**: Use SHA-256

**Rationale**:
- Storage overhead is acceptable (< 1 GB)
- Secure and collision-resistant
- Simpler implementation (single algorithm)

**Example**:
```swift
// For 1-10 million files, SHA-256 is still the best choice
let hash = try computeHash(data: fileData, algorithm: .sha256)
// Storage: 32 bytes per file × 10M = 320 MB (acceptable)
```

### ⚠️ **10-100 Million Files: SHA-256 or Two-Stage**

**Storage**: 320 MB - 3.2 GB  
**Recommendation**: 
- **Primary**: SHA-256 (if storage is acceptable)
- **Alternative**: Two-stage approach (CRC32 filter + SHA-256 verification)

**Rationale**:
- SHA-256 storage (3.2 GB) is still acceptable for most systems
- Two-stage approach reduces storage but adds complexity
- Choose based on storage constraints

**Two-Stage Approach**:
```swift
// Stage 1: Fast CRC32 filter (4 bytes per file)
let crc32 = try computeHash(data: fileData, algorithm: .crc32)
// Store CRC32 for quick filtering

// Stage 2: SHA-256 verification for potential matches
if potentialMatches.contains(crc32) {
    let sha256 = try computeHash(data: fileData, algorithm: .sha256)
    // Verify exact match with SHA-256
    // Store SHA-256 only for verified matches
}
```

**Storage savings**:
- CRC32: 4 bytes × 100M = 400 MB
- SHA-256 (for matches only): ~32 bytes × matches
- **Total**: Much less than 3.2 GB if most files are unique

### ⚠️ **> 100 Million Files: Two-Stage (CRC32 + SHA-256)**

**Storage**: > 3.2 GB  
**Recommendation**: Two-stage approach (CRC32 filter + SHA-256 verification)

**Rationale**:
- Storage overhead becomes significant (> 3.2 GB)
- Two-stage approach optimizes storage
- CRC32 collision risk is acceptable for filtering (not final verification)

**Implementation**:
```swift
// Store CRC32 for all files (fast filter)
let crc32 = try computeHash(data: fileData, algorithm: .crc32)
storeHash(crc32, for: fileID)

// Compute SHA-256 only when needed (verification)
func verifyFile(fileID: String, data: Data) -> Bool {
    let crc32 = try computeHash(data: data, algorithm: .crc32)
    guard storedCRC32 == crc32 else { return false }  // Fast filter
    
    // Only compute SHA-256 if CRC32 matches
    let sha256 = try computeHash(data: data, algorithm: .sha256)
    return storedSHA256 == sha256  // Exact verification
}
```

## Why NOT MD5 for Millions of Files?

### Storage Comparison

| Files | MD5 Storage | SHA-256 Storage | Difference |
|-------|-------------|-----------------|------------|
| 1M | 16 MB | 32 MB | 16 MB |
| 10M | 160 MB | 320 MB | 160 MB |
| 100M | 1.6 GB | 3.2 GB | 1.6 GB |

### Analysis

**The 16-byte difference is NOT significant enough to justify MD5:**

1. **Storage savings**: Only 50% reduction (16 MB vs 32 MB per million files)
2. **Security risk**: MD5 is cryptographically broken
3. **Future-proofing**: SHA-256 is the industry standard
4. **Deprecation**: MD5 is deprecated by Apple/CommonCrypto

**Conclusion**: The 16-byte savings per hash is not worth the security and compatibility risks.

## Recommended Strategy

### For Most Use Cases: **SHA-256**

```swift
// Default: Use SHA-256 for all files
let hash = try computeHash(data: fileData, algorithm: .sha256)
storeHash(hash, for: fileID)
```

**When to use**:
- < 100 million files
- Storage overhead is acceptable (< 3.2 GB)
- Simplicity is preferred

### For Very Large Collections: **Two-Stage (CRC32 + SHA-256)**

```swift
// Stage 1: CRC32 filter (store for all files)
let crc32 = try computeHash(data: fileData, algorithm: .crc32)
storeCRC32(crc32, for: fileID)

// Stage 2: SHA-256 verification (compute on-demand or store for matches)
func verifyOrStore(fileID: String, data: Data) {
    let crc32 = try computeHash(data: data, algorithm: .crc32)
    guard storedCRC32 == crc32 else { return false }
    
    // Compute SHA-256 for exact verification
    let sha256 = try computeHash(data: data, algorithm: .sha256)
    storeSHA256(sha256, for: fileID)  // Store for future use
    return true
}
```

**When to use**:
- > 100 million files
- Storage overhead becomes significant (> 3.2 GB)
- Most files are unique (CRC32 filter reduces SHA-256 storage)

## Storage Optimization Strategies

### 1. **Deduplication**

If many files have the same content, store hash once:

```swift
// Store hash once per unique content
let hash = try computeHash(data: fileData, algorithm: .sha256)
if !hashExists(hash) {
    storeHash(hash, content: fileData)
}
// Reference hash for all files with same content
```

**Storage savings**: Significant if many duplicate files exist.

### 2. **Lazy SHA-256 Computation**

Compute SHA-256 only when needed:

```swift
// Store CRC32 immediately (fast)
let crc32 = try computeHash(data: fileData, algorithm: .crc32)
storeCRC32(crc32, for: fileID)

// Compute SHA-256 lazily (on-demand or background)
func getSHA256(for fileID: String) -> String? {
    if let cached = getCachedSHA256(fileID) {
        return cached
    }
    let data = loadFileData(fileID)
    let sha256 = try computeHash(data: data, algorithm: .sha256)
    cacheSHA256(sha256, for: fileID)
    return sha256
}
```

**Storage savings**: Only store SHA-256 for files that need verification.

### 3. **Compression**

Compress hash storage:

```swift
// Store hashes in compressed format
let hashData = hashString.data(using: .utf8)!
let compressed = try compress(hashData)  // gzip/deflate
storeCompressedHash(compressed, for: fileID)
```

**Storage savings**: ~50% reduction (hash strings compress well).

## Real-World Examples

### Example 1: 5 Million Files

**Storage with SHA-256**: 5M × 32 bytes = 160 MB

**Recommendation**: Use SHA-256. Storage overhead is acceptable.

### Example 2: 50 Million Files

**Storage with SHA-256**: 50M × 32 bytes = 1.6 GB

**Recommendation**: Use SHA-256. Storage overhead is still acceptable for most systems.

### Example 3: 500 Million Files

**Storage with SHA-256**: 500M × 32 bytes = 16 GB

**Recommendation**: Consider two-stage approach (CRC32 filter + SHA-256 verification) or deduplication.

## Conclusion

### ✅ **For Millions of Files: Use SHA-256**

**Up to 100 million files**, SHA-256 is the recommended choice:
- Storage overhead is acceptable (3.2 GB for 100M files)
- Secure and collision-resistant
- Simple implementation
- Industry standard

### ⚠️ **For > 100 Million Files: Consider Two-Stage**

**For very large collections** (> 100M files), consider:
- Two-stage approach (CRC32 filter + SHA-256 verification)
- Deduplication (store hash once per unique content)
- Lazy SHA-256 computation (compute on-demand)

### ❌ **Don't Use MD5 or CRC32 Alone**

- **MD5**: Only 16 bytes less than SHA-256, not worth the security risk
- **CRC32**: High collision risk for millions of files (unacceptable)

### Final Recommendation

**For millions of files, use SHA-256.** The storage overhead (32 bytes per file) is acceptable up to 100 million files (3.2 GB). Only consider alternatives (two-stage approach) for very large collections (> 100M files) where storage becomes a significant concern.

