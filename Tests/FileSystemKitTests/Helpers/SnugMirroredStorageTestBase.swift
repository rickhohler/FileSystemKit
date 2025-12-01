// FileSystemKit Tests
// SnugMirroredStorage Test Base

import XCTest
@testable import FileSystemKit
import Foundation

class SnugMirroredStorageTestBase: XCTestCase {
    var tempPrimaryDir: URL!
    var tempMirrorDir: URL!
    var tempGlacierDir: URL!
    var primaryStorage: SnugFileSystemChunkStorage!
    var mirrorStorage: SnugFileSystemChunkStorage!
    var glacierStorage: SnugFileSystemChunkStorage!
    
    override func setUp() {
        super.setUp()
        tempPrimaryDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("snug-primary-\(UUID().uuidString)")
        tempMirrorDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("snug-mirror-\(UUID().uuidString)")
        tempGlacierDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("snug-glacier-\(UUID().uuidString)")
        
        try? FileManager.default.createDirectory(at: tempPrimaryDir, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: tempMirrorDir, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: tempGlacierDir, withIntermediateDirectories: true)
        
        primaryStorage = SnugFileSystemChunkStorage(baseURL: tempPrimaryDir)
        mirrorStorage = SnugFileSystemChunkStorage(baseURL: tempMirrorDir)
        glacierStorage = SnugFileSystemChunkStorage(baseURL: tempGlacierDir)
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: tempPrimaryDir)
        try? FileManager.default.removeItem(at: tempMirrorDir)
        try? FileManager.default.removeItem(at: tempGlacierDir)
        tempPrimaryDir = nil
        tempMirrorDir = nil
        tempGlacierDir = nil
        primaryStorage = nil
        mirrorStorage = nil
        glacierStorage = nil
        super.tearDown()
    }
}

