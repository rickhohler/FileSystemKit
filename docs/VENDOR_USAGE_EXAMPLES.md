# Vendor Protocol Usage Examples

## Overview

Clients can create a single `Vendor` type that conforms to both `FSVendorProtocol` and `InventoryVendorProtocol`. This same concrete instance can be passed to both FileSystemKit and InventoryKit APIs.

## Single Concrete Type for Both Libraries

```swift
import Foundation
import InventoryKit
import FileSystemKit

/// Vendor model that works with both FileSystemKit and InventoryKit
struct Vendor: FSVendorProtocol, InventoryVendorProtocol, Codable, Hashable {
    let id: UUID
    let name: String
    var address: VendorAddress?
    var inceptionDate: Date?
    var websites: [URL]
    var contactEmail: String?
    var contactPhone: String?
    var metadata: [String: String]
    
    init(
        id: UUID = UUID(),
        name: String,
        address: VendorAddress? = nil,
        inceptionDate: Date? = nil,
        websites: [URL] = [],
        contactEmail: String? = nil,
        contactPhone: String? = nil,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.name = name
        self.address = address
        self.inceptionDate = inceptionDate
        self.websites = websites
        self.contactEmail = contactEmail
        self.contactPhone = contactPhone
        self.metadata = metadata
    }
}
```

## Using the Same Instance with Both APIs

### Example: Create Vendor Once, Use with Both Libraries

```swift
import FileSystemKit
import InventoryKit

// Create a single vendor instance
let appleVendor = Vendor(
    name: "Apple Computer",
    address: VendorAddress(
        street1: "1 Apple Park Way",
        city: "Cupertino",
        stateOrProvince: "CA",
        postalCode: "95014",
        country: "United States"
    ),
    inceptionDate: DateComponents(
        calendar: .current,
        year: 1976,
        month: 4,
        day: 1
    ).date,
    websites: [
        URL(string: "https://www.apple.com")!,
        URL(string: "https://en.wikipedia.org/wiki/Apple_Inc.")!
    ]
)

// Use with FileSystemKit storage provider
let fsProvider: ChunkStorageProvider = // ... your provider
try await fsProvider.createVendor(appleVendor)  // ✅ Works!

// Use the SAME instance with InventoryKit storage provider
let inventoryProvider: InventoryStorageProvider = // ... your provider
try await inventoryProvider.createVendor(appleVendor)  // ✅ Works!

// Load from FileSystemKit
if let loadedVendor = try await fsProvider.loadVendor(id: appleVendor.id) {
    // Use the same loaded vendor with InventoryKit
    try await inventoryProvider.saveVendor(loadedVendor)  // ✅ Works!
}
```

## Type Compatibility

The same concrete `Vendor` instance satisfies both protocol requirements:

```swift
let vendor = Vendor(name: "Apple Computer")

// Can be used as FSVendorProtocol
let fsVendor: any FSVendorProtocol = vendor
try await fsProvider.createVendor(fsVendor)

// Can be used as InventoryVendorProtocol
let inventoryVendor: any InventoryVendorProtocol = vendor
try await inventoryProvider.createVendor(inventoryVendor)

// Or use directly - Swift's type system handles the conformance
try await fsProvider.createVendor(vendor)         // ✅ Works!
try await inventoryProvider.createVendor(vendor)    // ✅ Works!
```

## Complete CRUD Example

```swift
import FileSystemKit
import InventoryKit

// Create vendor
let vendor = Vendor(
    name: "Commodore Business Machines",
    inceptionDate: DateComponents(calendar: .current, year: 1954).date,
    websites: [URL(string: "https://en.wikipedia.org/wiki/Commodore_International")!]
)

// Create in FileSystemKit
let fsProvider: ChunkStorageProvider = // ... your provider
try await fsProvider.createVendor(vendor)

// Create in InventoryKit (same instance)
let inventoryProvider: InventoryStorageProvider = // ... your provider
try await inventoryProvider.createVendor(vendor)

// Load from FileSystemKit
if let loaded = try await fsProvider.loadVendor(id: vendor.id) {
    // Update and save to InventoryKit
    var updated = loaded
    updated.metadata["industry"] = "Computer Hardware"
    try await inventoryProvider.saveVendor(updated)  // Upsert operation
}

// Fetch all vendors from FileSystemKit
let allVendors = try await fsProvider.fetchVendors()

// Use fetched vendors with InventoryKit
for vendor in allVendors {
    try await inventoryProvider.saveVendor(vendor)  // Sync to InventoryKit
}

// Delete from both
try await fsProvider.deleteVendor(id: vendor.id)
try await inventoryProvider.deleteVendor(id: vendor.id)
```

## Benefits

1. **Single Source of Truth**: One vendor instance works with both libraries
2. **Type Safety**: Swift's type system ensures compatibility
3. **No Conversion**: No need to convert between different vendor types
4. **Seamless Integration**: Same vendor data can be used across both systems

## See Also

- `VENDOR_PROTOCOL.md` - Protocol definitions
- `VENDOR_CLIENT_IMPLEMENTATION.md` - Implementation guide

