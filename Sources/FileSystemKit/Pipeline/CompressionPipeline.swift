// FileSystemKit - Compression Pipeline Stages
//
// This file implements pipeline stages for handling compression formats,
// including support for nested compression (e.g., .tar.gz files).
//
// Design:
// - DecompressionStage: Decompresses files using CompressionAdapter
// - NestedCompressionStage: Detects and handles nested compression formats
// - CompressionPipeline: Pipeline for processing compressed files

import Foundation

// MARK: - Decompression Stage

/// Pipeline stage that decompresses files using compression adapters
public struct DecompressionStage: PipelineStage {
    public let stageID = "decompression"
    public let stageName = "Decompress File"
    public let stageDescription = "Decompresses files using compression adapters"
    
    /// Whether to detect nested compression after decompression
    public let detectNestedCompression: Bool
    
    public init(detectNestedCompression: Bool = true) {
        self.detectNestedCompression = detectNestedCompression
    }
    
    public func process(_ context: inout PipelineContext) async throws {
        let inputURL = context.inputURL
        
        // Check if input is compressed
        guard let compressionAdapter = CompressionAdapterRegistry.shared.findAdapter(for: inputURL) else {
            // Not compressed - skip this stage
            return
        }
        
        let format = compressionAdapter.format
        
        // Decompress the file
        let decompressedURL: URL
        do {
            decompressedURL = try compressionAdapter.decompress(url: inputURL)
        } catch {
            context.errors.append(error)
            throw error
        }
        
        // Store decompression metadata
        context.stageData["compression_format"] = AnySendable(format.rawValue)
        context.stageData["decompressed_url"] = AnySendable(decompressedURL.path)
        
        // Update context with decompressed URL
        context.inputURL = decompressedURL
        
        // If nested compression detection is enabled, check if decompressed file is also compressed
        if detectNestedCompression {
            // Check if decompressed file is another compression format
            if let nestedAdapter = CompressionAdapterRegistry.shared.findAdapter(for: decompressedURL) {
                let nestedFormat = nestedAdapter.format
                context.stageData["nested_compression_format"] = AnySendable(nestedFormat.rawValue)
                context.stageData["nested_compression_detected"] = AnySendable(true)
            }
        }
    }
}

// MARK: - Nested Compression Stage

/// Pipeline stage that handles nested compression formats (e.g., .tar.gz)
/// This stage detects when a decompressed file is itself compressed and processes it
public struct NestedCompressionStage: PipelineStage {
    public let stageID = "nested_compression"
    public let stageName = "Process Nested Compression"
    public let stageDescription = "Handles nested compression formats (e.g., .tar.gz)"
    
    public init() {}
    
    public func process(_ context: inout PipelineContext) async throws {
        // Check if nested compression was detected
        guard let nestedDetected = context.stageData["nested_compression_detected"]?.value as? Bool,
              nestedDetected == true else {
            // No nested compression detected - skip this stage
            return
        }
        
        guard let nestedFormatRaw = context.stageData["nested_compression_format"]?.value as? String,
              let nestedFormat = CompressionFormat(rawValue: nestedFormatRaw),
              let nestedAdapter = CompressionAdapterRegistry.shared.findAdapter(for: nestedFormat) else {
            // Nested compression format not supported
            let error = CompressionError.nestedCompressionNotSupported
            context.errors.append(error)
            throw error
        }
        
        // Get decompressed URL from previous stage
        guard let decompressedPath = context.stageData["decompressed_url"]?.value as? String else {
            // No decompressed URL found
            let error = CompressionError.invalidFormat
            context.errors.append(error)
            throw error
        }
        
        let decompressedURL = URL(fileURLWithPath: decompressedPath)
        
        // Decompress the nested compression format
        let finalDecompressedURL: URL
        do {
            finalDecompressedURL = try nestedAdapter.decompress(url: decompressedURL)
        } catch {
            context.errors.append(error)
            throw error
        }
        
        // Update context with final decompressed URL
        context.inputURL = finalDecompressedURL
        context.stageData["final_decompressed_url"] = AnySendable(finalDecompressedURL.path)
        context.stageData["nested_compression_processed"] = AnySendable(true)
    }
}

// MARK: - Compression Pipeline

/// Pipeline for processing compressed files, including nested compression
public struct CompressionPipeline: Pipeline {
    public let pipelineID = "compression"
    public let pipelineName = "Compression Processing"
    public let pipelineDescription = "Decompresses files and handles nested compression formats"
    
    public let stages: [PipelineStage]
    
    /// Create a compression pipeline
    /// - Parameter handleNestedCompression: Whether to automatically handle nested compression (default: true)
    public init(handleNestedCompression: Bool = true) {
        if handleNestedCompression {
            self.stages = [
                DecompressionStage(detectNestedCompression: true),
                NestedCompressionStage()
            ]
        } else {
            self.stages = [
                DecompressionStage(detectNestedCompression: false)
            ]
        }
    }
    
    public func execute(inputURL: URL) async throws -> PipelineContext {
        let basePipeline = BasePipeline(
            id: pipelineID,
            name: pipelineName,
            description: pipelineDescription,
            stages: stages
        )
        return try await basePipeline.execute(inputURL: inputURL)
    }
    
    public func execute(
        inputURLs: [URL],
        maxConcurrent: Int,
        progressHandler: ((PipelineProgress) -> Void)?
    ) async throws -> [PipelineContext] {
        let basePipeline = BasePipeline(
            id: pipelineID,
            name: pipelineName,
            description: pipelineDescription,
            stages: stages
        )
        return try await basePipeline.execute(
            inputURLs: inputURLs,
            maxConcurrent: maxConcurrent,
            progressHandler: progressHandler
        )
    }
}

// MARK: - Gzipped Tar Pipeline

/// Specialized pipeline for processing gzipped tar files (.tar.gz, .tgz)
/// This is a convenience pipeline that chains compression with tar extraction
public struct GzippedTarPipeline: Pipeline {
    public let pipelineID = "gzipped_tar"
    public let pipelineName = "Gzipped Tar Processing"
    public let pipelineDescription = "Processes gzipped tar files (.tar.gz, .tgz)"
    
    public let stages: [PipelineStage]
    
    /// Pipeline to use for processing extracted tar contents
    public let contentPipeline: (any Pipeline)?
    
    public init(contentPipeline: (any Pipeline)? = nil) {
        self.contentPipeline = contentPipeline
        self.stages = [
            DecompressionStage(detectNestedCompression: true),
            NestedCompressionStage()
        ]
    }
    
    public func execute(inputURL: URL) async throws -> PipelineContext {
        let basePipeline = BasePipeline(
            id: pipelineID,
            name: pipelineName,
            description: pipelineDescription,
            stages: stages
        )
        var context = try await basePipeline.execute(inputURL: inputURL)
        
        // If content pipeline is provided, process the extracted contents
        if let contentPipeline = contentPipeline {
            let contentContext = try await contentPipeline.execute(inputURL: context.inputURL)
            // Merge results
            context.results.append(contentsOf: contentContext.results)
            context.errors.append(contentsOf: contentContext.errors)
        }
        
        return context
    }
    
    public func execute(
        inputURLs: [URL],
        maxConcurrent: Int,
        progressHandler: ((PipelineProgress) -> Void)?
    ) async throws -> [PipelineContext] {
        let basePipeline = BasePipeline(
            id: pipelineID,
            name: pipelineName,
            description: pipelineDescription,
            stages: stages
        )
        var contexts = try await basePipeline.execute(
            inputURLs: inputURLs,
            maxConcurrent: maxConcurrent,
            progressHandler: progressHandler
        )
        
        // If content pipeline is provided, process extracted contents
        if let contentPipeline = contentPipeline {
            let contentURLs = contexts.map { $0.inputURL }
            let contentContexts = try await contentPipeline.execute(
                inputURLs: contentURLs,
                maxConcurrent: maxConcurrent,
                progressHandler: progressHandler
            )
            
            // Merge results
            for (index, contentContext) in contentContexts.enumerated() {
                if index < contexts.count {
                    contexts[index].results.append(contentsOf: contentContext.results)
                    contexts[index].errors.append(contentsOf: contentContext.errors)
                }
            }
        }
        
        return contexts
    }
}

