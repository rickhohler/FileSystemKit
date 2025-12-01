// FileSystemKit Tests
// Base class for FileHashCache tests

import XCTest
@testable import FileSystemKit
import Foundation

class FileHashCacheTestBase: XCTestCase {
    var tempDirectory: URL!
    var cacheFileURL: URL!
    var hashCache: FileHashCache!
    
    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("hashcache-test-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        cacheFileURL = tempDirectory.appendingPathComponent(".hashcache.json")
        hashCache = FileHashCache(cacheFileURL: cacheFileURL, hashAlgorithm: "sha256", maxCacheSize: 100)
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        tempDirectory = nil
        cacheFileURL = nil
        hashCache = nil
        super.tearDown()
    }
}

