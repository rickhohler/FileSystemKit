// FileSystemKit Tests
// DirectoryParser Test Base

import XCTest
@testable import FileSystemKit
import Foundation

class DirectoryParserTestBase: XCTestCase {
    var tempDirectory: URL!
    
    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DirectoryParserTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        tempDirectory = nil
        super.tearDown()
    }
}

// MARK: - Test Helpers

/// Thread-safe array wrapper for collecting directory entries during parsing
final class NSLockedArray<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var array: [T] = []
    
    func append(_ element: T) {
        lock.lock()
        defer { lock.unlock() }
        array.append(element)
    }
    
    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return array.count
    }
    
    func compactMap<U>(_ transform: @escaping (T) -> U?) -> [U] {
        lock.lock()
        defer { lock.unlock() }
        return array.compactMap(transform)
    }
    
    func filter(_ predicate: @escaping (T) -> Bool) -> [T] {
        lock.lock()
        defer { lock.unlock() }
        return array.filter(predicate)
    }
    
    func map<U>(_ transform: @escaping (T) -> U) -> [U] {
        lock.lock()
        defer { lock.unlock() }
        return array.map(transform)
    }
    
    func contains(where predicate: @escaping (T) -> Bool) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return array.contains(where: predicate)
    }
}

/// Test delegate implementation for collecting directory entries
final class TestDirectoryParserDelegate: DirectoryParserDelegate {
    private let entries: NSLockedArray<DirectoryEntry>
    
    init(entries: NSLockedArray<DirectoryEntry>) {
        self.entries = entries
    }
    
    func processEntry(_ entry: DirectoryEntry) throws -> Bool {
        entries.append(entry)
        return true
    }
    
    func didStartParsing(rootURL: URL) {
        // No-op for tests
    }
    
    func didFinishParsing(rootURL: URL) {
        // No-op for tests
    }
}

