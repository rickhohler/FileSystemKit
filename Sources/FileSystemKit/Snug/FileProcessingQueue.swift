// FileSystemKit - SNUG File Processing Queue
// High-performance concurrent file processing for archive operations

import Foundation

/// Represents a file to be processed
internal struct FileToProcess: Sendable {
    let url: URL
    let relativePath: String
    // Extract only Sendable values from URLResourceValues
    let isDirectory: Bool
    let isSymlink: Bool
    let isRegularFile: Bool
    let isSystem: Bool
    let isHidden: Bool
    let fileSize: Int64?
    let contentModificationDate: Date?
    let creationDate: Date?
    let isExecutable: Bool
}

/// Result of processing a file
internal struct FileProcessResult: Sendable {
    let entry: ArchiveEntry?
    let hash: String?
    let hashDefinition: HashDefinition?
    let embeddedFile: (hash: String, data: Data, path: String)?
    let size: Int
    let error: Error?
}

/// Thread-safe counter for progress tracking
internal final class ProgressCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var _filesProcessed: Int = 0
    private var _totalSize: Int = 0
    
    var filesProcessed: Int {
        lock.lock()
        defer { lock.unlock() }
        return _filesProcessed
    }
    
    var totalSize: Int {
        lock.lock()
        defer { lock.unlock() }
        return _totalSize
    }
    
    func increment(files: Int = 1, size: Int = 0) {
        lock.lock()
        defer { lock.unlock() }
        _filesProcessed += files
        _totalSize += size
    }
}

/// Thread-safe collections for accumulating results
internal final class ResultAccumulator: @unchecked Sendable {
    private let lock = NSLock()
    private var _entries: [ArchiveEntry] = []
    private var _hashRegistry: [String: HashDefinition] = [:]
    private var _processedHashes: Set<String> = []
    private var _embeddedFiles: [(hash: String, data: Data, path: String)] = []
    
    func appendEntry(_ entry: ArchiveEntry) {
        lock.lock()
        defer { lock.unlock() }
        _entries.append(entry)
    }
    
    func addHashDefinition(_ hash: String, _ definition: HashDefinition) {
        lock.lock()
        defer { lock.unlock() }
        if !_processedHashes.contains(hash) {
            _hashRegistry[hash] = definition
            _processedHashes.insert(hash)
        }
    }
    
    func appendEmbeddedFile(_ file: (hash: String, data: Data, path: String)) {
        lock.lock()
        defer { lock.unlock() }
        _embeddedFiles.append(file)
    }
    
    func getResults() -> (
        entries: [ArchiveEntry],
        hashRegistry: [String: HashDefinition],
        processedHashes: Set<String>,
        embeddedFiles: [(hash: String, data: Data, path: String)]
    ) {
        lock.lock()
        defer { lock.unlock() }
        return (_entries, _hashRegistry, _processedHashes, _embeddedFiles)
    }
}

/// Producer-consumer queue for file processing
internal actor FileProcessingQueue {
    private var files: [FileToProcess] = []
    private var isComplete = false
    private var error: Error?
    
    func enqueue(_ file: FileToProcess) {
        files.append(file)
    }
    
    func enqueueBatch(_ batch: [FileToProcess]) {
        files.append(contentsOf: batch)
    }
    
    func dequeue() -> FileToProcess? {
        if files.isEmpty {
            return nil
        }
        return files.removeFirst()
    }
    
    func markComplete() {
        isComplete = true
    }
    
    func setError(_ error: Error) {
        self.error = error
    }
    
    func checkError() throws {
        if let error = error {
            throw error
        }
    }
    
    var isEmpty: Bool {
        files.isEmpty && isComplete
    }
}

