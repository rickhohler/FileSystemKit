# Vendor Protocol Client Implementation

## Overview

Since `FSVendorProtocol` and `InventoryVendorProtocol` have identical structures, clients can create a single concrete type that conforms to both protocols. This allows vendor information to be shared seamlessly between FileSystemKit and InventoryKit.

## Implementation Pattern

Create a single `Vendor` type that adopts both protocols:

```swift
import InventoryKit
import FileSystemKit

/// Client implementation of vendor that works with both FileSystemKit and InventoryKit
struct Vendor: FSVendorProtocol, InventoryVendorProtocol {
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

## Usage with FileSystemKit

```swift
import FileSystemKit

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
let storageProvider: ChunkStorageProvider = // ... your provider
try await storageProvider.createVendor(appleVendor)
```

## Usage with InventoryKit

```swift
import InventoryKit

// Same vendor instance works with InventoryKit
let storageProvider: InventoryStorageProvider = // ... your provider
try await storageProvider.createVendor(appleVendor)
```

## Type Compatibility

Since both protocols have identical requirements, a single type can satisfy both:

```swift
let vendor: Vendor = Vendor(name: "Apple Computer")

// Works with FileSystemKit
let fsVendor: any FSVendorProtocol = vendor

// Works with InventoryKit
let inventoryVendor: any InventoryVendorProtocol = vendor
```

## Protocol Conformance

The `Vendor` type automatically satisfies both protocol requirements because:

1. Both protocols require the same properties
2. Both protocols have the same method signatures
3. The default implementations are identical

## Example: Complete Vendor Model

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

// Example usage
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
    ],
    metadata: [
        "industry": "Technology",
        "founded_by": "Steve Jobs, Steve Wozniak, Ronald Wayne"
    ]
)
```

## See Also

- `FSVendorProtocol` - FileSystemKit vendor protocol
- `InventoryVendorProtocol` - InventoryKit vendor protocol
- `VendorAddress` - Structured address information

