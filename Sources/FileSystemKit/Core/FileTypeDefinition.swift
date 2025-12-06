//
//  FileTypeDefinition.swift
//  FileSystemKit
//
//  Complete definition of a file type with metadata and capabilities
//

import Foundation

/// Complete definition of a file type
public struct FileTypeDefinition: Sendable {
    /// Unique UTI for this type
    public let uti: UTI
    
    /// Short identifier (3-8 chars, lowercase)
    public let shortID: String
    
    /// Display name
    public let displayName: String
    
    /// File extensions (lowercase, no leading dots)
    public let extensions: [String]
    
    /// MIME type (IANA media type)
    public let mimeType: String?
    
    /// Detection patterns for magic number matching
    public let magicNumbers: [FileSignaturePattern]
    
    /// Version information
    public let version: FileTypeVersion?
    
    /// Icon representation
    public let icon: FileTypeIcon
    
    /// Category classification
    public let category: FileTypeMetadataCategory
    
    /// Vendor/creator information
    public let vendor: String?
    
    /// Additional custom metadata
    public let metadata: [String: String]
    
    /// Feature capabilities
    public let capabilities: FileTypeCapabilities
    
    /// Priority for detection (higher = check first)
    public let priority: Int
    
    public init(
        uti: UTI,
        shortID: String,
        displayName: String,
        extensions: [String],
        mimeType: String? = nil,
        magicNumbers: [FileSignaturePattern] = [],
        version: FileTypeVersion? = nil,
        icon: FileTypeIcon,
        category: FileTypeMetadataCategory,
        vendor: String? = nil,
        metadata: [String: String] = [:],
        capabilities: FileTypeCapabilities = [],
        priority: Int = 50
    ) {
        self.uti = uti
        self.shortID = shortID
        self.displayName = displayName
        self.extensions = extensions.map { $0.lowercased() }
        self.mimeType = mimeType
        self.magicNumbers = magicNumbers
        self.version = version
        self.icon = icon
        self.category = category
        self.vendor = vendor
        self.metadata = metadata
        self.capabilities = capabilities
        self.priority = priority
    }
}

/// Icon representation for file types
public enum FileTypeIcon: Sendable, Codable {
    /// SF Symbol name
    case sfSymbol(String)
    
    /// Custom image name
    case custom(String)
    
    /// System icon
    case system(String)
}

/// File type capabilities
public struct FileTypeCapabilities: OptionSet, Sendable, Codable {
    public let rawValue: UInt
    
    public init(rawValue: UInt) {
        self.rawValue = rawValue
    }
    
    public static let readable     = FileTypeCapabilities(rawValue: 1 << 0)
    public static let writable     = FileTypeCapabilities(rawValue: 1 << 1)
    public static let executable   = FileTypeCapabilities(rawValue: 1 << 2)
    public static let editable     = FileTypeCapabilities(rawValue: 1 << 3)
    public static let convertible  = FileTypeCapabilities(rawValue: 1 << 4)
    public static let previewable  = FileTypeCapabilities(rawValue: 1 << 5)
    public static let searchable   = FileTypeCapabilities(rawValue: 1 << 6)
    public static let versionable  = FileTypeCapabilities(rawValue: 1 << 7)
}

/// File signature pattern for file detection
public struct FileSignaturePattern: Sendable {
    /// Offset in file
    public let offset: SignatureOffset
    
    /// Test to perform
    public let test: SignatureTest
    
    /// Expected value
    public let value: SignatureValue
    
    /// Confidence score (0.0-1.0)
    public let confidence: Float
    
    /// Child patterns (for nested tests)
    public let children: [FileSignaturePattern]
    
    public init(
        offset: SignatureOffset,
        test: SignatureTest,
        value: SignatureValue,
        confidence: Float = 1.0,
        children: [FileSignaturePattern] = []
    ) {
        self.offset = offset
        self.test = test
        self.value = value
        self.confidence = confidence
        self.children = children
    }
    
    /// Check if data matches this pattern
    public func matches(data: Data) -> Bool {
        // Get offset value
        let actualOffset: Int
        switch offset {
        case .absolute(let off):
            actualOffset = off
        case .relative(let off):
            // For now, relative offsets not supported in root pattern
            actualOffset = off
        case .fromEnd(let off):
            actualOffset = max(0, data.count - off)
        case .indirect(let off, _):
            // Read offset from file (advanced feature)
            actualOffset = off
        }
        
        // Check bounds
        guard actualOffset >= 0 && actualOffset < data.count else {
            return false
        }
        
        // Perform test based on value type
        switch (test, value) {
        case (.equals, .bytes(let expected)):
            guard actualOffset + expected.count <= data.count else { return false }
            let actualBytes = data.subdata(in: actualOffset..<(actualOffset + expected.count))
            return actualBytes.elementsEqual(expected)
            
        case (.equals, .string(let expected)):
            guard let expectedData = expected.data(using: .utf8) else { return false }
            guard actualOffset + expectedData.count <= data.count else { return false }
            let actualBytes = data.subdata(in: actualOffset..<(actualOffset + expectedData.count))
            return actualBytes == expectedData
            
        case (.equals, .masked(let expected, let mask)):
            guard actualOffset + expected.count <= data.count else { return false }
            for i in 0..<expected.count {
                let actual = data[actualOffset + i]
                let exp = expected[i]
                let m = mask[i]
                if (actual & m) != (exp & m) {
                    return false
                }
            }
            return true
            
        default:
            // Other test types not yet implemented
            return false
        }
    }
}

/// Offset specification for signature patterns
public enum SignatureOffset: Sendable {
    case absolute(Int)
    case relative(Int)
    case fromEnd(Int)
    case indirect(Int, type: SignatureNumericType)
}

/// Test type for signature patterns
public enum SignatureTest: Sendable {
    case equals
    case notEquals
    case lessThan
    case greaterThan
    case bitwiseAnd(UInt64)
    case regex(String)
    case string(caseSensitive: Bool)
}

/// Value specification for signature patterns
public enum SignatureValue: Sendable {
    case bytes([UInt8])
    case string(String)
    case number(Int64)
    case float(Double)
    case masked([UInt8], mask: [UInt8])
}

/// Numeric type for indirect offsets
public enum SignatureNumericType: Sendable {
    case byte, short, long, quad
}
