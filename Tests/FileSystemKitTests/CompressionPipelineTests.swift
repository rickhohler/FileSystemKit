// FileSystemKit Tests
// Unit tests for compression pipeline stages and chained compression support

import XCTest
@testable import FileSystemKit
import Foundation

final class CompressionPipelineTests: XCTestCase {
    var tempDirectory: URL!
    
    override func setUp() {
        super.setUp()
        // Create a temporary directory for test files
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }
    
    override func tearDown() {
        // Clean up temporary directory
        try? FileManager.default.removeItem(at: tempDirectory)
        tempDirectory = nil
        super.tearDown()
    }
    
    // MARK: - Helper Methods
    
    /// Get the test resource file path
    private func getTestResource(_ resourcePath: String) -> URL? {
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
        let testSourceDir = testSourceFile.deletingLastPathComponent()
        let candidate = testSourceDir.appendingPathComponent("Resources/\(resourcePath)")
        if FileManager.default.fileExists(atPath: candidate.path) {
            return candidate
        }
        
        return nil
    }
    
    // MARK: - DecompressionStage Tests
    
    func testDecompressionStageWithGzip() async throws {
        // Ensure compression adapters are registered
        CompressionAdapterRegistry.shared.register(GzipCompressionAdapter.self)
        
        // Create a test gzip file
        let testContent = "Test content for gzip compression".data(using: .utf8)!
        let gzipURL = tempDirectory.appendingPathComponent("test.gz")
        try GzipCompressionAdapter.compress(data: testContent, to: gzipURL)
        
        // Create decompression stage
        let stage = DecompressionStage(detectNestedCompression: false)
        var context = PipelineContext(inputURL: gzipURL)
        
        // Process the stage
        try await stage.process(&context)
        
        // Verify decompression
        XCTAssertNotNil(context.stageData["compression_format"])
        XCTAssertEqual(context.stageData["compression_format"]?.value as? String, "gzip")
        XCTAssertNotNil(context.stageData["decompressed_url"])
        
        // Verify decompressed file exists and contains original content
        if let decompressedPath = context.stageData["decompressed_url"]?.value as? String {
            let decompressedURL = URL(fileURLWithPath: decompressedPath)
            let decompressedData = try Data(contentsOf: decompressedURL)
            XCTAssertEqual(decompressedData, testContent)
        }
    }
    
    func testDecompressionStageSkipsNonCompressed() async throws {
        // Create a non-compressed file
        let testContent = "Plain text file".data(using: .utf8)!
        let plainURL = tempDirectory.appendingPathComponent("test.txt")
        try testContent.write(to: plainURL)
        
        // Create decompression stage
        let stage = DecompressionStage()
        var context = PipelineContext(inputURL: plainURL)
        
        // Process the stage (should skip)
        try await stage.process(&context)
        
        // Verify no compression metadata was added
        XCTAssertNil(context.stageData["compression_format"])
        XCTAssertNil(context.stageData["decompressed_url"])
    }
    
    // MARK: - NestedCompressionStage Tests
    
    func testNestedCompressionStageWithGzippedTar() async throws {
        // Ensure compression adapters are registered
        CompressionAdapterRegistry.shared.register(GzipCompressionAdapter.self)
        CompressionAdapterRegistry.shared.register(TarCompressionAdapter.self)
        
        // Get test gzipped tar file
        guard let tarGzURL = getTestResource("Compressed/test.tar.gz") else {
            throw XCTSkip("test.tar.gz not found in test resources")
        }
        
        // First decompress gzip
        let decompressedURL = try GzipCompressionAdapter.decompress(url: tarGzURL)
        
        // Set up context as if DecompressionStage already ran
        var context = PipelineContext(inputURL: decompressedURL)
        context.stageData["compression_format"] = AnySendable("gzip")
        context.stageData["decompressed_url"] = AnySendable(decompressedURL.path)
        
        // Check if nested compression is detected
        if let nestedAdapter = CompressionAdapterRegistry.shared.findAdapter(for: decompressedURL) {
            context.stageData["nested_compression_format"] = AnySendable(nestedAdapter.format.rawValue)
            context.stageData["nested_compression_detected"] = AnySendable(true)
        }
        
        // Create nested compression stage
        let nestedStage = NestedCompressionStage()
        
        // Process the nested compression stage
        try await nestedStage.process(&context)
        
        // Verify nested compression was processed
        XCTAssertNotNil(context.stageData["nested_compression_processed"])
        XCTAssertEqual(context.stageData["nested_compression_processed"]?.value as? Bool, true)
        XCTAssertNotNil(context.stageData["final_decompressed_url"])
    }
    
    func testNestedCompressionStageSkipsWhenNotDetected() async throws {
        var context = PipelineContext(inputURL: tempDirectory.appendingPathComponent("test.txt"))
        // No nested compression detected
        
        let nestedStage = NestedCompressionStage()
        
        // Process should skip gracefully
        try await nestedStage.process(&context)
        
        // Verify no processing occurred
        XCTAssertNil(context.stageData["nested_compression_processed"])
    }
    
    // MARK: - CompressionPipeline Tests
    
    func testCompressionPipelineWithGzip() async throws {
        // Ensure compression adapters are registered
        CompressionAdapterRegistry.shared.register(GzipCompressionAdapter.self)
        
        // Create a test gzip file
        let testContent = "Test content".data(using: .utf8)!
        let gzipURL = tempDirectory.appendingPathComponent("test.gz")
        try GzipCompressionAdapter.compress(data: testContent, to: gzipURL)
        
        // Create compression pipeline
        let pipeline = CompressionPipeline(handleNestedCompression: false)
        
        // Execute pipeline
        let context = try await pipeline.execute(inputURL: gzipURL)
        
        // Verify decompression occurred
        XCTAssertNotNil(context.stageData["compression_format"])
        XCTAssertEqual(context.stageData["compression_format"]?.value as? String, "gzip")
        XCTAssertNotNil(context.stageData["decompressed_url"])
    }
    
    func testCompressionPipelineWithGzippedTar() async throws {
        // Ensure compression adapters are registered
        CompressionAdapterRegistry.shared.register(GzipCompressionAdapter.self)
        CompressionAdapterRegistry.shared.register(TarCompressionAdapter.self)
        
        // Get test gzipped tar file
        guard let tarGzURL = getTestResource("Compressed/test.tar.gz") else {
            throw XCTSkip("test.tar.gz not found in test resources")
        }
        
        // Create compression pipeline with nested compression handling
        let pipeline = CompressionPipeline(handleNestedCompression: true)
        
        // Execute pipeline
        let context = try await pipeline.execute(inputURL: tarGzURL)
        
        // Verify both decompressions occurred
        XCTAssertNotNil(context.stageData["compression_format"])
        XCTAssertEqual(context.stageData["compression_format"]?.value as? String, "gzip")
        XCTAssertNotNil(context.stageData["nested_compression_format"])
        XCTAssertEqual(context.stageData["nested_compression_format"]?.value as? String, "tar")
        XCTAssertNotNil(context.stageData["nested_compression_processed"])
        XCTAssertEqual(context.stageData["nested_compression_processed"]?.value as? Bool, true)
        XCTAssertNotNil(context.stageData["final_decompressed_url"])
        
        // Verify no errors
        XCTAssertTrue(context.errors.isEmpty)
    }
    
    // MARK: - GzippedTarPipeline Tests
    
    func testGzippedTarPipeline() async throws {
        // Ensure compression adapters are registered
        CompressionAdapterRegistry.shared.register(GzipCompressionAdapter.self)
        CompressionAdapterRegistry.shared.register(TarCompressionAdapter.self)
        
        // Get test gzipped tar file
        guard let tarGzURL = getTestResource("Compressed/test.tar.gz") else {
            throw XCTSkip("test.tar.gz not found in test resources")
        }
        
        // Create gzipped tar pipeline
        let pipeline = GzippedTarPipeline()
        
        // Execute pipeline
        let context = try await pipeline.execute(inputURL: tarGzURL)
        
        // Verify processing completed
        XCTAssertNotNil(context.stageData["compression_format"])
        XCTAssertNotNil(context.stageData["nested_compression_processed"])
        XCTAssertEqual(context.stageData["nested_compression_processed"]?.value as? Bool, true)
        XCTAssertNotNil(context.stageData["final_decompressed_url"])
        
        // Verify no errors
        XCTAssertTrue(context.errors.isEmpty)
    }
    
    func testGzippedTarPipelineWithTgzExtension() async throws {
        // Ensure compression adapters are registered
        CompressionAdapterRegistry.shared.register(GzipCompressionAdapter.self)
        CompressionAdapterRegistry.shared.register(TarCompressionAdapter.self)
        
        // Get test tgz file
        guard let tgzURL = getTestResource("Compressed/test.tgz") else {
            throw XCTSkip("test.tgz not found in test resources")
        }
        
        // Create gzipped tar pipeline
        let pipeline = GzippedTarPipeline()
        
        // Execute pipeline
        let context = try await pipeline.execute(inputURL: tgzURL)
        
        // Verify processing completed
        XCTAssertNotNil(context.stageData["compression_format"])
        XCTAssertNotNil(context.stageData["nested_compression_processed"])
        XCTAssertEqual(context.stageData["nested_compression_processed"]?.value as? Bool, true)
        
        // Verify no errors
        XCTAssertTrue(context.errors.isEmpty)
    }
    
    // MARK: - Pipeline Chaining Tests
    
    func testPipelineChainWithCompression() async throws {
        // Ensure compression adapters are registered
        CompressionAdapterRegistry.shared.register(GzipCompressionAdapter.self)
        CompressionAdapterRegistry.shared.register(TarCompressionAdapter.self)
        
        // Get test gzipped tar file
        guard let tarGzURL = getTestResource("Compressed/test.tar.gz") else {
            throw XCTSkip("test.tar.gz not found in test resources")
        }
        
        // Create compression pipeline
        let compressionPipeline = CompressionPipeline(handleNestedCompression: true)
        
        // Chain with another pipeline (using the |> operator)
        // For this test, we'll just verify the chain can be created
        let chain = compressionPipeline.chain(compressionPipeline)
        
        XCTAssertEqual(chain.pipelines.count, 2)
        XCTAssertEqual(chain.pipelineName, "Compression Processing → Compression Processing")
    }
}

