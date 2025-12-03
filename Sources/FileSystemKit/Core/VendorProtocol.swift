// FileSystemKit Core Library
// Vendor Protocol
//
// This file defines a protocol for vendor information that can be adopted by clients.
// The same protocol exists in InventoryKit to ensure compatibility across libraries.

import Foundation

/// Protocol defining vendor information for FileSystemKit.
///
/// This protocol allows clients to implement their own vendor models while maintaining
/// compatibility with FileSystemKit. Vendors represent companies or organizations that
/// create products, file formats, or provide services.
///
/// ## Client Adoption
///
/// Clients can create their own vendor types that conform to this protocol:
///
/// ```swift
/// struct Vendor: FSVendorProtocol {
///     let id: UUID
///     let name: String
///     var address: VendorAddress?
///     var inceptionDate: Date?
///     var websites: [URL]
///     // ... implement all protocol requirements
/// }
/// ```
///
/// ## Cross-Library Compatibility
///
/// A similar protocol (`InventoryVendorProtocol`) exists in InventoryKit, ensuring that vendor
/// information can be shared between InventoryKit (for asset tracking) and FileSystemKit
/// (for file format metadata). Both protocols have the same structure for compatibility.
///
/// - SeeAlso: ``VendorAddress`` for structured address information
/// - SeeAlso: `InventoryVendorProtocol` in InventoryKit for inventory vendor information
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public protocol FSVendorProtocol: Identifiable, Sendable where ID == UUID {
    /// Unique identifier for the vendor.
    var id: UUID { get }
    
    /// Vendor name (company or organization name).
    /// Example: "Apple Computer", "Commodore Business Machines", "Microsoft Corporation"
    var name: String { get }
    
    /// Structured address information.
    /// nil if address is unknown or not applicable.
    var address: VendorAddress? { get }
    
    /// Inception date - when the vendor was founded or established.
    /// nil if the date is unknown.
    var inceptionDate: Date? { get }
    
    /// Website URLs - official website, Wikipedia page, etc.
    /// Can include multiple URLs (main site, Wikipedia, company history, etc.).
    /// Empty array if no websites are available.
    var websites: [URL] { get }
    
    /// Contact email address.
    /// nil if not available or not applicable.
    var contactEmail: String? { get }
    
    /// Contact phone number.
    /// nil if not available or not applicable.
    var contactPhone: String? { get }
    
    /// Additional metadata dictionary.
    /// Can include industry, country, parent company, etc.
    var metadata: [String: String] { get }
}

// MARK: - VendorAddress

/// Structured address information for a vendor.
///
/// Provides a structured representation of vendor address information,
/// suitable for display and storage.
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public struct VendorAddress: Codable, Equatable, Hashable, Sendable {
    /// Street address (line 1).
    public let street1: String?
    
    /// Street address (line 2) - apartment, suite, etc.
    public let street2: String?
    
    /// City.
    public let city: String?
    
    /// State or province.
    public let stateOrProvince: String?
    
    /// Postal or ZIP code.
    public let postalCode: String?
    
    /// Country.
    public let country: String?
    
    /// Create a vendor address.
    /// - Parameters:
    ///   - street1: Street address (line 1)
    ///   - street2: Street address (line 2) - optional
    ///   - city: City
    ///   - stateOrProvince: State or province
    ///   - postalCode: Postal or ZIP code
    ///   - country: Country
    public init(
        street1: String? = nil,
        street2: String? = nil,
        city: String? = nil,
        stateOrProvince: String? = nil,
        postalCode: String? = nil,
        country: String? = nil
    ) {
        self.street1 = street1
        self.street2 = street2
        self.city = city
        self.stateOrProvince = stateOrProvince
        self.postalCode = postalCode
        self.country = country
    }
    
    /// Formatted address string for display.
    /// Combines all address components into a readable format.
    public var formattedAddress: String {
        var components: [String] = []
        
        if let street1 = street1, !street1.isEmpty {
            components.append(street1)
        }
        if let street2 = street2, !street2.isEmpty {
            components.append(street2)
        }
        
        var cityStateZip: [String] = []
        if let city = city, !city.isEmpty {
            cityStateZip.append(city)
        }
        if let stateOrProvince = stateOrProvince, !stateOrProvince.isEmpty {
            cityStateZip.append(stateOrProvince)
        }
        if let postalCode = postalCode, !postalCode.isEmpty {
            cityStateZip.append(postalCode)
        }
        if !cityStateZip.isEmpty {
            components.append(cityStateZip.joined(separator: ", "))
        }
        
        if let country = country, !country.isEmpty {
            components.append(country)
        }
        
        return components.joined(separator: "\n")
    }
}

// MARK: - FSVendorProtocol Default Implementation

public extension FSVendorProtocol {
    /// Default implementation: no address
    var address: VendorAddress? {
        return nil
    }
    
    /// Default implementation: no inception date
    var inceptionDate: Date? {
        return nil
    }
    
    /// Default implementation: no websites
    var websites: [URL] {
        return []
    }
    
    /// Default implementation: no contact email
    var contactEmail: String? {
        return nil
    }
    
    /// Default implementation: no contact phone
    var contactPhone: String? {
        return nil
    }
    
    /// Default implementation: empty metadata
    var metadata: [String: String] {
        return [:]
    }
}

