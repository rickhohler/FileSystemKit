// FileSystemKit Tests
// Base test class with shared setup for DiskImageAdapter tests

import XCTest
import Foundation
@testable import FileSystemKit

/// Base test class with shared setup and teardown for DiskImageAdapter tests
class DiskImageAdapterTestBase: XCTestCase {
    var testResourcesURL: URL!
    var tempDirectory: URL!
    
    override func setUp() {
        super.setUp()
        // Get test resources directory
        let testBundle = Bundle(for: type(of: self))
        testResourcesURL = testBundle.resourceURL ?? URL(fileURLWithPath: NSTemporaryDirectory())
        
        // Create temporary directory for test outputs
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }
    
    override func tearDown() {
        // Clean up temporary directory
        try? FileManager.default.removeItem(at: tempDirectory)
        tempDirectory = nil
        testResourcesURL = nil
        super.tearDown()
    }
    
    /// Get the test resource file path
    func getTestResource(_ resourcePath: String) -> URL? {
        let testBundle = Bundle(for: type(of: self))
        
        // Try multiple approaches to find resources
        if let resourcesURL = testBundle.resourceURL {
            let resourceFile = resourcesURL.appendingPathComponent(resourcePath)
            if FileManager.default.fileExists(atPath: resourceFile.path) {
                return resourceFile
            }
        }
        
        // Try relative to test source file
        let testSourceFile = URL(fileURLWithPath: #file)
        let testSourceDir = testSourceFile
            .deletingLastPathComponent() // Remove DiskImageAdapterTestBase.swift
            .deletingLastPathComponent() // Remove Helpers/
        let candidate = testSourceDir.appendingPathComponent("Resources/\(resourcePath)")
        if FileManager.default.fileExists(atPath: candidate.path) {
            return candidate
        }
        
        return nil
    }
}

