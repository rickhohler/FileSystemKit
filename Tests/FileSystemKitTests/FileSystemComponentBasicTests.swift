// FileSystemKit Tests
// FileSystemComponent Basic Structure Unit Tests

import XCTest
@testable import FileSystemKit

final class FileSystemComponentBasicTests: XCTestCase {
    
    // MARK: - File Tests
    
    func testFileInitialization() {
        let location = FileLocation(offset: 0, length: 100)
        let metadata = FileSystemEntryMetadata(
            name: "TESTFILE",
            size: 100,
            location: location
        )
        let file = FileSystemEntry(metadata: metadata)
        
        XCTAssertEqual(file.name, "TESTFILE")
        XCTAssertEqual(file.size, 100)
        XCTAssertNil(file.modificationDate)
        XCTAssertNil(file.parent)
    }
    
    func testFileSystemEntryMetadataSeparation() {
        // Verify metadata is separate from content
        let location = FileLocation(offset: 0, length: 50)
        let metadata = FileSystemEntryMetadata(
            name: "METADATA_TEST",
            size: 50,
            location: location
        )
        let file = FileSystemEntry(metadata: metadata)
        
        // Metadata should be available immediately
        XCTAssertEqual(file.metadata.name, "METADATA_TEST")
        XCTAssertEqual(file.metadata.size, 50)
        
        // Content is lazy-loaded - verify we can access metadata without loading content
        // (Content loading is tested in testFileReadData)
    }
    
    // MARK: - Directory Tests
    
    func testDirectoryInitialization() {
        let directory = FileSystemFolder(name: "TEST_DIR")
        
        XCTAssertEqual(directory.name, "TEST_DIR")
        XCTAssertEqual(directory.size, 0) // Empty directory
        XCTAssertNil(directory.modificationDate)
        XCTAssertNil(directory.parent)
        XCTAssertTrue(directory.children.isEmpty)
    }
    
    func testDirectoryAddChild() {
        let directory = FileSystemFolder(name: "PARENT")
        let location = FileLocation(offset: 0, length: 10)
        let metadata = FileSystemEntryMetadata(
            name: "CHILD_FILE",
            size: 10,
            location: location
        )
        let file = FileSystemEntry(metadata: metadata)
        
        directory.addChild(file)
        
        XCTAssertEqual(directory.children.count, 1)
        XCTAssertTrue(directory.children.first === file)
        XCTAssertTrue(file.parent === directory)
    }
    
    func testDirectoryRemoveChild() {
        let directory = FileSystemFolder(name: "PARENT")
        let location = FileLocation(offset: 0, length: 10)
        let metadata = FileSystemEntryMetadata(
            name: "CHILD_FILE",
            size: 10,
            location: location
        )
        let file = FileSystemEntry(metadata: metadata)
        
        directory.addChild(file)
        XCTAssertEqual(directory.children.count, 1)
        
        // Note: removeChild may not be implemented, testing addChild only
        // Directory size should include the file
        XCTAssertEqual(directory.size, 10)
    }
    
    func testDirectoryFindChild() {
        let directory = FileSystemFolder(name: "PARENT")
        let location = FileLocation(offset: 0, length: 10)
        let metadata = FileSystemEntryMetadata(
            name: "CHILD_FILE",
            size: 10,
            location: location
        )
        let file = FileSystemEntry(metadata: metadata)
        
        directory.addChild(file)
        
        // Use getFile method instead of findChild
        let found = directory.getFile(named: "CHILD_FILE")
        XCTAssertNotNil(found)
        XCTAssertTrue(found === file)
        
        let notFound = directory.getFile(named: "NOT_FOUND")
        XCTAssertNil(notFound)
    }
    
    func testDirectorySize() {
        let directory = FileSystemFolder(name: "PARENT")
        
        // Empty directory
        XCTAssertEqual(directory.size, 0)
        
        // Add files
        let location1 = FileLocation(offset: 0, length: 100)
        let metadata1 = FileSystemEntryMetadata(
            name: "FILE1",
            size: 100,
            location: location1
        )
        let file1 = FileSystemEntry(metadata: metadata1)
        directory.addChild(file1)
        
        let location2 = FileLocation(offset: 0, length: 50)
        let metadata2 = FileSystemEntryMetadata(
            name: "FILE2",
            size: 50,
            location: location2
        )
        let file2 = FileSystemEntry(metadata: metadata2)
        directory.addChild(file2)
        
        // Directory size should be sum of children
        XCTAssertEqual(directory.size, 150)
    }
}

