// FileSystemKit Tests
// Unit tests for GitStyleOrganization implementation

import XCTest
@testable import FileSystemKit

final class GitStyleOrganizationTests: XCTestCase {
    
    // MARK: - Initialization Tests
    
    func testGitStyleOrganizationDefaultDepth() {
        let organization = GitStyleOrganization()
        
        XCTAssertEqual(organization.name, "git-style")
        XCTAssertEqual(organization.description, "Git-style hash-based directory organization")
    }
    
    func testGitStyleOrganizationCustomDepth() {
        let organization1 = GitStyleOrganization(directoryDepth: 1)
        let organization3 = GitStyleOrganization(directoryDepth: 3)
        let organization4 = GitStyleOrganization(directoryDepth: 4)
        
        XCTAssertEqual(organization1.name, "git-style")
        XCTAssertEqual(organization3.name, "git-style")
        XCTAssertEqual(organization4.name, "git-style")
    }
    
    func testGitStyleOrganizationDepthLimits() {
        // Test that depth is clamped to 1-4
        let org0 = GitStyleOrganization(directoryDepth: 0) // Should clamp to 1
        let org5 = GitStyleOrganization(directoryDepth: 5) // Should clamp to 4
        
        let identifier = ChunkIdentifier(id: "a1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456")
        let path0 = org0.storagePath(for: identifier)
        let path5 = org5.storagePath(for: identifier)
        
        // Depth 0 clamped to 1: "a1/hash..."
        XCTAssertTrue(path0.hasPrefix("a1/"))
        
        // Depth 5 clamped to 4: "a1/b2/c3/d4/hash..."
        let components5 = path5.split(separator: "/")
        XCTAssertEqual(components5.count, 5) // 4 dirs + hash
    }
    
    // MARK: - Storage Path Generation Tests
    
    func testGitStyleOrganizationStoragePathDepth1() {
        let organization = GitStyleOrganization(directoryDepth: 1)
        let hash = "a1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456"
        let identifier = ChunkIdentifier(id: hash)
        
        let path = organization.storagePath(for: identifier)
        
        // Should be: "a1/a1b2c3d4..."
        XCTAssertTrue(path.hasPrefix("a1/"))
        XCTAssertTrue(path.hasSuffix(hash))
        XCTAssertEqual(path, "a1/\(hash)")
    }
    
    func testGitStyleOrganizationStoragePathDepth2() {
        let organization = GitStyleOrganization(directoryDepth: 2)
        let hash = "a1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456"
        let identifier = ChunkIdentifier(id: hash)
        
        let path = organization.storagePath(for: identifier)
        
        // Should be: "a1/b2/a1b2c3d4..."
        XCTAssertTrue(path.hasPrefix("a1/b2/"))
        XCTAssertTrue(path.hasSuffix(hash))
        XCTAssertEqual(path, "a1/b2/\(hash)")
    }
    
    func testGitStyleOrganizationStoragePathDepth3() {
        let organization = GitStyleOrganization(directoryDepth: 3)
        let hash = "a1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456"
        let identifier = ChunkIdentifier(id: hash)
        
        let path = organization.storagePath(for: identifier)
        
        // Should be: "a1/b2/c3/a1b2c3d4..."
        XCTAssertTrue(path.hasPrefix("a1/b2/c3/"))
        XCTAssertTrue(path.hasSuffix(hash))
    }
    
    func testGitStyleOrganizationStoragePathDepth4() {
        let organization = GitStyleOrganization(directoryDepth: 4)
        let hash = "a1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456"
        let identifier = ChunkIdentifier(id: hash)
        
        let path = organization.storagePath(for: identifier)
        
        // Should be: "a1/b2/c3/d4/a1b2c3d4..."
        XCTAssertTrue(path.hasPrefix("a1/b2/c3/d4/"))
        XCTAssertTrue(path.hasSuffix(hash))
    }
    
    // MARK: - Identifier Parsing Tests
    
    func testGitStyleOrganizationIdentifierFromPathDepth2() {
        let organization = GitStyleOrganization(directoryDepth: 2)
        let hash = "a1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456"
        let path = "a1/b2/\(hash)"
        
        let identifier = organization.identifier(from: path)
        
        XCTAssertNotNil(identifier)
        XCTAssertEqual(identifier?.id, hash)
    }
    
    func testGitStyleOrganizationIdentifierFromPathDepth3() {
        let organization = GitStyleOrganization(directoryDepth: 3)
        let hash = "a1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456"
        let path = "a1/b2/c3/\(hash)"
        
        let identifier = organization.identifier(from: path)
        
        XCTAssertNotNil(identifier)
        XCTAssertEqual(identifier?.id, hash)
    }
    
    func testGitStyleOrganizationIdentifierFromPathInvalid() {
        let organization = GitStyleOrganization()
        
        XCTAssertNil(organization.identifier(from: "invalid"))
        XCTAssertNil(organization.identifier(from: "a1/b2"))
        XCTAssertNil(organization.identifier(from: "a1/b2/abc")) // Too short
        XCTAssertNil(organization.identifier(from: "a1/b2/xyz123")) // Invalid hex
        XCTAssertNil(organization.identifier(from: "wrong/depth/path/hash")) // Wrong depth
    }
    
    // MARK: - Path Validation Tests
    
    func testGitStyleOrganizationIsValidPath() {
        let organization = GitStyleOrganization()
        let hash = "a1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456"
        
        XCTAssertTrue(organization.isValidPath("a1/b2/\(hash)"))
        XCTAssertFalse(organization.isValidPath("invalid"))
        XCTAssertFalse(organization.isValidPath("a1/b2/abc"))
        XCTAssertFalse(organization.isValidPath("a1/b2/xyz123"))
    }
    
    // MARK: - Round Trip Tests
    
    func testGitStyleOrganizationRoundTrip() {
        let organization = GitStyleOrganization(directoryDepth: 2)
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
    
    func testGitStyleOrganizationSendable() {
        let organization = GitStyleOrganization()
        // If this compiles, Sendable conformance is correct
        let _: ChunkStorageOrganization = organization
    }
}

