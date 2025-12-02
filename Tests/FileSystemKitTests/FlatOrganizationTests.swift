// FileSystemKit Tests
// Unit tests for FlatOrganization implementation

import XCTest
@testable import FileSystemKit

final class FlatOrganizationTests: XCTestCase {
    
    // MARK: - Initialization Tests
    
    func testFlatOrganizationProperties() {
        let organization = FlatOrganization()
        
        XCTAssertEqual(organization.name, "flat")
        XCTAssertEqual(organization.description, "Flat organization - all chunks in single directory")
    }
    
    // MARK: - Storage Path Generation Tests
    
    func testFlatOrganizationStoragePath() {
        let organization = FlatOrganization()
        let hash = "a1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456"
        let identifier = ChunkIdentifier(id: hash)
        
        let path = organization.storagePath(for: identifier)
        
        // Should be just the hash
        XCTAssertEqual(path, hash)
    }
    
    // MARK: - Identifier Parsing Tests
    
    func testFlatOrganizationIdentifierFromPath() {
        let organization = FlatOrganization()
        let hash = "a1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456"
        
        let identifier = organization.identifier(from: hash)
        
        XCTAssertNotNil(identifier)
        XCTAssertEqual(identifier?.id, hash)
    }
    
    func testFlatOrganizationIdentifierFromPathInvalid() {
        let organization = FlatOrganization()
        
        XCTAssertNil(organization.identifier(from: "invalid"))
        XCTAssertNil(organization.identifier(from: "abc")) // Too short
        XCTAssertNil(organization.identifier(from: "xyz123")) // Invalid hex
        XCTAssertNil(organization.identifier(from: "a1/b2/hash")) // Contains slashes
    }
    
    // MARK: - Path Validation Tests
    
    func testFlatOrganizationIsValidPath() {
        let organization = FlatOrganization()
        let hash = "a1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456"
        
        XCTAssertTrue(organization.isValidPath(hash))
        XCTAssertFalse(organization.isValidPath("invalid"))
        XCTAssertFalse(organization.isValidPath("abc"))
        XCTAssertFalse(organization.isValidPath("a1/b2/hash"))
    }
    
    // MARK: - Round Trip Tests
    
    func testFlatOrganizationRoundTrip() {
        let organization = FlatOrganization()
        let originalIdentifier = ChunkIdentifier(
            id: "a1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456",
            metadata: ChunkMetadata(size: 1024, hashAlgorithm: "sha256")
        )
        
        let path = organization.storagePath(for: originalIdentifier)
        let parsedIdentifier = organization.identifier(from: path)
        
        XCTAssertNotNil(parsedIdentifier)
        XCTAssertEqual(parsedIdentifier?.id, originalIdentifier.id)
    }
    
    // MARK: - Protocol Conformance Tests
    
    func testFlatOrganizationSendable() {
        let organization = FlatOrganization()
        // If this compiles, Sendable conformance is correct
        let _: ChunkStorageOrganization = organization
    }
}

