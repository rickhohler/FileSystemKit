# MD5 Deprecation Warning Solution

## Problem

Apple deprecated `CC_MD5` in macOS 10.15 because MD5 is cryptographically broken. However, FileSystemKit intentionally supports MD5 for **read-only legacy compatibility** (companion checksum files, existing archives, vintage systems).

## Current Situation

- **MD5 is intentionally supported** for legacy compatibility (see `HASH_ALGORITHM_POLICY.md`)
- **MD5 is NOT used for new hash generation** - SHA-256 is the default
- **MD5 is only used for**:
  - Reading companion `.md5` files
  - Validating against existing MD5 checksums
  - Legacy system compatibility

## Solution Options

### ✅ **Option 1: Use CryptoKit's `Insecure.MD5` (Recommended)**

**Best for**: Modern Swift code, clear intent, no warnings

```swift
func md5() -> [UInt8] {
    #if canImport(CryptoKit)
    // Use CryptoKit's Insecure.MD5 - explicitly marked as insecure
    let hash = Insecure.MD5.hash(data: self)
    return Array(hash)
    #elseif canImport(CommonCrypto)
    // Fallback: Suppress deprecation warning for legacy compatibility
    var hash = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
    self.withUnsafeBytes { bytes in
        hash.withUnsafeMutableBytes { hashBytes in
            _ = CC_MD5(bytes.baseAddress, CC_LONG(self.count), hashBytes.baseAddress)
        }
    }
    return hash
    #else
    return []
    #endif
}
```

**Pros**:
- No deprecation warnings
- Clear intent (`Insecure.MD5` explicitly warns developers)
- Modern Swift API
- Fixes unsafe pointer issue

**Cons**:
- Requires CryptoKit (available on Apple platforms)

### Option 2: Suppress Deprecation Warning

**Best for**: When CryptoKit is not available

```swift
func md5() -> [UInt8] {
    #if canImport(CommonCrypto)
    var hash = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
    self.withUnsafeBytes { bytes in
        hash.withUnsafeMutableBytes { hashBytes in
            // Suppress deprecation warning - MD5 is intentionally kept for legacy compatibility
            #pragma clang diagnostic push
            #pragma clang diagnostic ignored "-Wdeprecated-declarations"
            _ = CC_MD5(bytes.baseAddress, CC_LONG(self.count), hashBytes.baseAddress)
            #pragma clang diagnostic pop
        }
    }
    return hash
    #elseif canImport(CryptoKit)
    let hash = Insecure.MD5.hash(data: self)
    return Array(hash)
    #else
    return []
    #endif
}
```

**Pros**:
- Works without CryptoKit
- Explicitly documents why warning is suppressed

**Cons**:
- Still uses deprecated API
- Requires pragma directives

### Option 3: Remove MD5 Support (Not Recommended)

**Why not**: Breaks legacy compatibility, removes support for companion `.md5` files

## Recommended Implementation

**Priority order**:
1. **CryptoKit's `Insecure.MD5`** (when available) - modern, safe, no warnings
2. **CommonCrypto with suppressed warning** (fallback) - for legacy platforms

This approach:
- ✅ Uses modern APIs when available
- ✅ Maintains legacy compatibility
- ✅ Fixes unsafe pointer warnings
- ✅ Clearly documents intent
- ✅ No deprecation warnings in modern code

## Implementation Details

### Fix Unsafe Pointer Issue

The current code has a dangling pointer warning:
```swift
let hashPtr = UnsafeMutablePointer<UInt8>(mutating: &hash)  // ❌ Dangling pointer
```

**Fix**: Use `withUnsafeMutableBytes`:
```swift
hash.withUnsafeMutableBytes { hashBytes in
    _ = CC_MD5(bytes.baseAddress, CC_LONG(self.count), hashBytes.baseAddress)
}
```

## Conclusion

**Best Solution**: Use CryptoKit's `Insecure.MD5` as primary, with CommonCrypto fallback and suppressed warning. This maintains legacy compatibility while using modern APIs and eliminating warnings.

