# Vendor Protocol

## Overview

The `FSVendorProtocol` provides a standardized way to represent vendor (company/organization) information for FileSystemKit. A similar protocol (`InventoryVendorProtocol`) exists in InventoryKit with identical structure, allowing clients to create a single vendor type that works with both libraries.

## Protocol Definition

```swift
public protocol FSVendorProtocol: Identifiable, Sendable where ID == UUID {
    var id: UUID { get }
    var name: String { get }
    var address: VendorAddress? { get }
    var inceptionDate: Date? { get }
    var websites: [URL] { get }
    var contactEmail: String? { get }
    var contactPhone: String? { get }
    var metadata: [String: String] { get }
}
```

## Properties

### Required Properties

- **`id: UUID`** - Unique identifier for the vendor
- **`name: String`** - Vendor name (company or organization name)

### Optional Properties (with defaults)

- **`address: VendorAddress?`** - Structured address information
- **`inceptionDate: Date?`** - When the vendor was founded/established
- **`websites: [URL]`** - Website URLs (official site, Wikipedia, etc.)
- **`contactEmail: String?`** - Contact email address
- **`contactPhone: String?`** - Contact phone number
- **`metadata: [String: String]`** - Additional metadata dictionary

## VendorAddress

The `VendorAddress` struct provides structured address information:

```swift
public struct VendorAddress {
    let street1: String?
    let street2: String?
    let city: String?
    let stateOrProvince: String?
    let postalCode: String?
    let country: String?
    
    var formattedAddress: String // Computed property for display
}
```

## Client Implementation Example

```swift
import InventoryKit
import FileSystemKit

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

## Cross-Library Compatibility

Similar protocols exist in both libraries:
- **FileSystemKit** - `FSVendorProtocol` for tracking vendors of file formats
- **InventoryKit** - `InventoryVendorProtocol` for tracking vendors of assets (computers, parts, etc.)

Both protocols have identical structure, allowing clients to create a single `Vendor` type that conforms to both:

```swift
struct Vendor: FSVendorProtocol, InventoryVendorProtocol {
    // Single implementation works for both libraries
}
```

See `VENDOR_CLIENT_IMPLEMENTATION.md` for complete examples.

## Integration with FileTypeMetadata

The `FileTypeMetadata` protocol includes a `vendor: String?` property. This can reference a vendor name that corresponds to a `VendorProtocol` instance:

```swift
struct ProDOSMetadata: FileTypeMetadata {
    var vendor: String? {
        "Apple Computer" // Can reference VendorProtocol.name
    }
    // ... other properties
}
```

## See Also

- `VENDOR_CLIENT_IMPLEMENTATION.md` - How to create a vendor type that works with both libraries
- `InventoryVendorProtocol` in InventoryKit - Similar protocol for inventory vendors
- `VendorAddress` - Structured address information
- `FileTypeMetadata` - File format metadata (includes vendor name)

