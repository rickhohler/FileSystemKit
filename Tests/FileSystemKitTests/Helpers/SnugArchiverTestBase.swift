// FileSystemKit Tests
// Base test class with shared setup for SnugArchiver tests

import XCTest
import Foundation
@testable import FileSystemKit

/// Base test class with shared setup and teardown for SnugArchiver tests
class SnugArchiverTestBase: XCTestCase {
    var tempDirectory: URL!
    var storageURL: URL!
    
    override func setUp() async throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SnugArchiverTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        
        storageURL = tempDirectory.appendingPathComponent("storage")
        try FileManager.default.createDirectory(at: storageURL, withIntermediateDirectories: true)
    }
    
    override func tearDown() async throws {
        if let tempDirectory = tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
    }
}

