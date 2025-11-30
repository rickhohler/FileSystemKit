// FileSystemKit Tests
// Unit tests for Chunk lazy loading and builder pattern

import XCTest
@testable import FileSystemKit

final class ChunkTests: XCTestCase {
    var mockStorage: MockChunkStorage!
    
    override func setUp() {
        super.setUp()
        mockStorage = MockChunkStorage()
    }
    
    override func tearDown() {
        mockStorage = nil
        super.tearDown()
    }
    
    // MARK: - Builder Pattern Tests
    
    func testChunkBuilderMagicNumber() async throws {
        let testData = Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F, 0x10])
        let identifier = ChunkIdentifier(
            id: "test-chunk",
            metadata: ChunkMetadata(size: testData.count, contentHash: "test")
        )
        
        _ = try await mockStorage.writeChunk(testData, identifier: identifier, metadata: identifier.metadata)
        
        // Build chunk with magic number pattern (only first 10 bytes)
        let chunk = try await Chunk.builder()
            .identifier(identifier)
            .storage(mockStorage)
            .magicNumber(maxBytes: 10)
            .build()
        
        let cachedData = chunk.getCachedData()
        XCTAssertNotNil(cachedData)
        XCTAssertEqual(cachedData?.count, 10)
        XCTAssertEqual(cachedData, testData.prefix(10))
    }
    
    func testChunkBuilderHeader() async throws {
        let testData = Data((0..<1024).map { UInt8($0 % 256) })
        let identifier = ChunkIdentifier(
            id: "test-header",
            metadata: ChunkMetadata(size: testData.count, contentHash: "test")
        )
        
        _ = try await mockStorage.writeChunk(testData, identifier: identifier, metadata: identifier.metadata)
        
        // Build chunk with header pattern (first 512 bytes)
        let chunk = try await Chunk.builder()
            .identifier(identifier)
            .storage(mockStorage)
            .header(maxBytes: 512)
            .build()
        
        let cachedData = chunk.getCachedData()
        XCTAssertNotNil(cachedData)
        XCTAssertEqual(cachedData?.count, 512)
        XCTAssertEqual(cachedData, testData.prefix(512))
    }
    
    func testChunkBuilderFull() async throws {
        let testData = Data((0..<1000).map { UInt8($0 % 256) })
        let identifier = ChunkIdentifier(
            id: "test-full",
            metadata: ChunkMetadata(size: testData.count, contentHash: "test")
        )
        
        _ = try await mockStorage.writeChunk(testData, identifier: identifier, metadata: identifier.metadata)
        
        // Build chunk with full pattern
        let chunk = try await Chunk.builder()
            .identifier(identifier)
            .storage(mockStorage)
            .full()
            .build()
        
        let cachedData = chunk.getCachedData()
        XCTAssertNotNil(cachedData)
        XCTAssertEqual(cachedData?.count, testData.count)
        XCTAssertEqual(cachedData, testData)
        XCTAssertTrue(chunk.isFullyCached)
    }
    
    func testChunkBuilderRange() async throws {
        let testData = Data((0..<1000).map { UInt8($0 % 256) })
        let identifier = ChunkIdentifier(
            id: "test-range",
            metadata: ChunkMetadata(size: testData.count, contentHash: "test")
        )
        
        _ = try await mockStorage.writeChunk(testData, identifier: identifier, metadata: identifier.metadata)
        
        // Build chunk with specific range (bytes 100-200)
        let chunk = try await Chunk.builder()
            .identifier(identifier)
            .storage(mockStorage)
            .range(100..<200)
            .build()
        
        let cachedData = chunk.getCachedData()
        XCTAssertNotNil(cachedData)
        XCTAssertEqual(cachedData?.count, 100)
        XCTAssertEqual(cachedData, testData.subdata(in: 100..<200))
    }
    
    // MARK: - Lazy Loading Tests
    
    func testChunkReadMagicNumber() async throws {
        let testData = Data([0x96, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A])
        let identifier = ChunkIdentifier(
            id: "test-magic",
            metadata: ChunkMetadata(size: testData.count, contentHash: "test")
        )
        
        _ = try await mockStorage.writeChunk(testData, identifier: identifier, metadata: identifier.metadata)
        
        var chunk = try await Chunk.builder()
            .identifier(identifier)
            .storage(mockStorage)
            .magicNumber(maxBytes: 4)
            .build()
        
        // Read magic number (should use cached data)
        let magicBytes = try await chunk.readMagicNumber(maxBytes: 4)
        XCTAssertEqual(magicBytes.count, 4)
        XCTAssertEqual(magicBytes, Data([0x96, 0x02, 0x03, 0x04]))
    }
    
    func testChunkReadHeader() async throws {
        let testData = Data((0..<1024).map { UInt8($0 % 256) })
        let identifier = ChunkIdentifier(
            id: "test-header-read",
            metadata: ChunkMetadata(size: testData.count, contentHash: "test")
        )
        
        _ = try await mockStorage.writeChunk(testData, identifier: identifier, metadata: identifier.metadata)
        
        var chunk = try await Chunk.builder()
            .identifier(identifier)
            .storage(mockStorage)
            .header(maxBytes: 256)
            .build()
        
        // Read header (should use cached data)
        let header = try await chunk.readHeader(maxBytes: 256)
        XCTAssertEqual(header.count, 256)
        XCTAssertEqual(header, testData.prefix(256))
    }
    
    func testChunkReadTail() async throws {
        let testData = Data((0..<1000).map { UInt8($0 % 256) })
        let identifier = ChunkIdentifier(
            id: "test-tail",
            metadata: ChunkMetadata(size: testData.count, contentHash: "test")
        )
        
        _ = try await mockStorage.writeChunk(testData, identifier: identifier, metadata: identifier.metadata)
        
        var chunk = try await Chunk.builder()
            .identifier(identifier)
            .storage(mockStorage)
            .build()
        
        // Read tail (should load on demand)
        let tail = try await chunk.readTail(maxBytes: 100)
        XCTAssertEqual(tail.count, 100)
        let expectedTail = testData.suffix(100)
        XCTAssertEqual(tail, expectedTail)
    }
    
    func testChunkReadRange() async throws {
        let testData = Data((0..<1000).map { UInt8($0 % 256) })
        let identifier = ChunkIdentifier(
            id: "test-range-read",
            metadata: ChunkMetadata(size: testData.count, contentHash: "test")
        )
        
        _ = try await mockStorage.writeChunk(testData, identifier: identifier, metadata: identifier.metadata)
        
        var chunk = try await Chunk.builder()
            .identifier(identifier)
            .storage(mockStorage)
            .build()
        
        // Read specific range (should load on demand)
        let range = try await chunk.read(range: 200..<300)
        XCTAssertEqual(range.count, 100)
        XCTAssertEqual(range, testData.subdata(in: 200..<300))
    }
    
    func testChunkReadFull() async throws {
        let testData = Data((0..<500).map { UInt8($0 % 256) })
        let identifier = ChunkIdentifier(
            id: "test-full-read",
            metadata: ChunkMetadata(size: testData.count, contentHash: "test")
        )
        
        _ = try await mockStorage.writeChunk(testData, identifier: identifier, metadata: identifier.metadata)
        
        var chunk = try await Chunk.builder()
            .identifier(identifier)
            .storage(mockStorage)
            .magicNumber(maxBytes: 10)
            .build()
        
        // Initially only 10 bytes cached
        XCTAssertEqual(chunk.getCachedData()?.count, 10)
        XCTAssertFalse(chunk.isFullyCached)
        
        // Read full chunk
        let full = try await chunk.readFull()
        XCTAssertEqual(full.count, testData.count)
        XCTAssertEqual(full, testData)
        XCTAssertTrue(chunk.isFullyCached)
    }
    
    // MARK: - Cache Management Tests
    
    func testChunkClearCache() async throws {
        let testData = Data((0..<100).map { UInt8($0 % 256) })
        let identifier = ChunkIdentifier(
            id: "test-cache-clear",
            metadata: ChunkMetadata(size: testData.count, contentHash: "test")
        )
        
        _ = try await mockStorage.writeChunk(testData, identifier: identifier, metadata: identifier.metadata)
        
        var chunk = try await Chunk.builder()
            .identifier(identifier)
            .storage(mockStorage)
            .full()
            .build()
        
        XCTAssertNotNil(chunk.getCachedData())
        XCTAssertTrue(chunk.isFullyCached)
        
        // Clear cache
        chunk.clearCache()
        XCTAssertNil(chunk.getCachedData())
        XCTAssertFalse(chunk.isFullyCached)
    }
    
    func testChunkExpandCache() async throws {
        let testData = Data((0..<1000).map { UInt8($0 % 256) })
        let identifier = ChunkIdentifier(
            id: "test-expand",
            metadata: ChunkMetadata(size: testData.count, contentHash: "test")
        )
        
        _ = try await mockStorage.writeChunk(testData, identifier: identifier, metadata: identifier.metadata)
        
        var chunk = try await Chunk.builder()
            .identifier(identifier)
            .storage(mockStorage)
            .magicNumber(maxBytes: 10)
            .build()
        
        // Initially only 10 bytes cached
        XCTAssertEqual(chunk.getCachedData()?.count, 10)
        
        // Expand cache to include more range
        try await chunk.expandCache(to: 0..<100)
        XCTAssertGreaterThanOrEqual(chunk.getCachedData()?.count ?? 0, 100)
    }
}

