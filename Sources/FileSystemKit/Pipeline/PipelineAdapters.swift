// FileSystemKit - Pipeline Adapters
//
// Adapters to bridge between old Pipeline protocol and new typed pipelines

import Foundation

// MARK: - Pipeline to SinglePipeline Adapter

/// Adapter to make existing Pipeline conform to SinglePipeline
public struct PipelineToSingleAdapter: SinglePipeline {
    public let pipelineID: String
    public let pipelineName: String
    public let pipelineDescription: String
    
    private let pipeline: any Pipeline
    
    /// Create an adapter from an existing pipeline
    /// - Parameter pipeline: Pipeline to adapt
    public init(_ pipeline: any Pipeline) {
        self.pipeline = pipeline
        self.pipelineID = pipeline.pipelineID
        self.pipelineName = pipeline.pipelineName
        self.pipelineDescription = pipeline.pipelineDescription
    }
    
    public func execute(context: PipelineContext) async throws -> PipelineContext {
        // Execute pipeline on the context's input URL
        return try await pipeline.execute(inputURL: context.inputURL)
    }
}

// MARK: - Pipeline to CollectionPipeline Adapter

/// Adapter to make existing Pipeline conform to CollectionPipeline
public struct PipelineToCollectionAdapter: CollectionPipeline {
    public let pipelineID: String
    public let pipelineName: String
    public let pipelineDescription: String
    
    private let pipeline: any Pipeline
    
    /// Create an adapter from an existing pipeline
    /// - Parameter pipeline: Pipeline to adapt
    public init(_ pipeline: any Pipeline) {
        self.pipeline = pipeline
        self.pipelineID = pipeline.pipelineID
        self.pipelineName = pipeline.pipelineName
        self.pipelineDescription = pipeline.pipelineDescription
    }
    
    public func execute(contexts: [PipelineContext]) async throws -> [PipelineContext] {
        let urls = contexts.map { $0.inputURL }
        return try await pipeline.execute(
            inputURLs: urls,
            maxConcurrent: 5,
            progressHandler: nil
        )
    }
}

// MARK: - Convenience Extensions

extension Pipeline {
    /// Convert this pipeline to a SinglePipeline
    public func asSingle() -> PipelineToSingleAdapter {
        PipelineToSingleAdapter(self)
    }
    
    /// Convert this pipeline to a CollectionPipeline
    public func asCollection() -> PipelineToCollectionAdapter {
        PipelineToCollectionAdapter(self)
    }
}

