// FileSystemKit - Pipeline Chaining
//
// This file implements pipeline chaining, allowing pipelines to be composed
// together similar to shell pipe operators (e.g., `cat file | grep pattern | sort`).
//
// Design:
// - Pipelines can be chained where the output of one becomes input to the next
// - Each pipeline in the chain processes the context from the previous pipeline
// - Supports filtering, transformation, and accumulation of results
// - Provides a fluent API for composing complex workflows

import Foundation

// MARK: - Pipeline Chain

/// A chain of pipelines that execute sequentially, passing context between them
public struct PipelineChain: Pipeline {
    public let pipelineID: String
    public let pipelineName: String
    public let pipelineDescription: String
    
    /// Pipelines in the chain, executed in order
    internal let pipelines: [any Pipeline]
    
    /// Create a pipeline chain from multiple pipelines
    /// - Parameters:
    ///   - id: Unique identifier for the chain
    ///   - name: Human-readable name
    ///   - description: Description of what the chain does
    ///   - pipelines: Pipelines to chain together
    public init(
        id: String,
        name: String,
        description: String,
        pipelines: [any Pipeline]
    ) {
        self.pipelineID = id
        self.pipelineName = name
        self.pipelineDescription = description
        self.pipelines = pipelines
    }
    
    /// Computed stages property (flattened from all pipelines)
    public var stages: [PipelineStage] {
        pipelines.flatMap { $0.stages }
    }
    
    /// Execute the chain on a single file
    /// Each pipeline processes the context from the previous pipeline
    public func execute(inputURL: URL) async throws -> PipelineContext {
        var context = PipelineContext(inputURL: inputURL)
        
        // Execute each pipeline in sequence, passing context through
        for pipeline in pipelines {
            guard context.shouldContinue else {
                break
            }
            
            // Execute pipeline on the current context's input URL
            // The pipeline will read from context if it has the necessary data
            let pipelineContext = try await pipeline.execute(inputURL: context.inputURL)
            
            // Merge results from pipeline into our context
            context = mergeContexts(context, pipelineContext)
        }
        
        return context
    }
    
    /// Execute the chain on multiple files
    public func execute(
        inputURLs: [URL],
        maxConcurrent: Int,
        progressHandler: ((PipelineProgress) -> Void)?
    ) async throws -> [PipelineContext] {
        var results: [PipelineContext] = []
        results.reserveCapacity(inputURLs.count)
        
        // Execute first pipeline on all files
        var currentContexts = try await pipelines.first?.execute(
            inputURLs: inputURLs,
            maxConcurrent: maxConcurrent,
            progressHandler: progressHandler
        ) ?? inputURLs.map { PipelineContext(inputURL: $0) }
        
        // Chain remaining pipelines
        for pipeline in pipelines.dropFirst() {
            guard !currentContexts.isEmpty else { break }
            
            // Extract URLs from contexts that should continue
            let continueURLs = currentContexts
                .filter { $0.shouldContinue }
                .map { $0.inputURL }
            
            guard !continueURLs.isEmpty else { break }
            
            // Execute next pipeline on continuing contexts
            let nextContexts = try await pipeline.execute(
                inputURLs: continueURLs,
                maxConcurrent: maxConcurrent,
                progressHandler: progressHandler
            )
            
            // Merge contexts
            currentContexts = mergeContextArrays(currentContexts, nextContexts)
        }
        
        return currentContexts
    }
    
    // MARK: - Private Helpers
    
    /// Merge two pipeline contexts, preserving data from both
    private func mergeContexts(_ base: PipelineContext, _ new: PipelineContext) -> PipelineContext {
        var merged = base
        
        // Merge detected formats (prefer new if available)
        merged.diskImageFormat = new.diskImageFormat ?? merged.diskImageFormat
        merged.fileSystemFormat = new.fileSystemFormat ?? merged.fileSystemFormat
        
        // Merge raw disk data (prefer new if available)
        merged.rawDiskData = new.rawDiskData ?? merged.rawDiskData
        
        // Merge file system folder (prefer new if available)
        merged.fileSystemFolder = new.fileSystemFolder ?? merged.fileSystemFolder
        
        // Merge metadata (prefer new if available)
        merged.metadata = new.metadata ?? merged.metadata
        
        // Merge stage data
        for (key, value) in new.stageData {
            merged.stageData[key] = value
        }
        
        // Merge errors
        merged.errors.append(contentsOf: new.errors)
        
        // Merge results
        merged.results.append(contentsOf: new.results)
        
        return merged
    }
    
    /// Merge two arrays of contexts by matching URLs
    private func mergeContextArrays(_ base: [PipelineContext], _ new: [PipelineContext]) -> [PipelineContext] {
        var merged: [PipelineContext] = []
        let newMap = Dictionary(uniqueKeysWithValues: new.map { ($0.inputURL, $0) })
        
        for baseContext in base {
            if let newContext = newMap[baseContext.inputURL] {
                merged.append(mergeContexts(baseContext, newContext))
            } else {
                merged.append(baseContext)
            }
        }
        
        return merged
    }
}

// MARK: - Pipeline Chain Builder

/// Builder for creating pipeline chains with a fluent API
public struct PipelineChainBuilder {
    private var id: String
    private var name: String
    private var description: String
    private var pipelines: [any Pipeline] = []
    
    /// Create a new pipeline chain builder
    public init(id: String, name: String, description: String) {
        self.id = id
        self.name = name
        self.description = description
    }
    
    /// Add a pipeline to the chain
    /// - Parameter pipeline: Pipeline to add
    /// - Returns: Builder for method chaining
    public mutating func pipe(_ pipeline: any Pipeline) -> PipelineChainBuilder {
        var builder = self
        builder.pipelines.append(pipeline)
        return builder
    }
    
    /// Build the pipeline chain
    /// - Returns: Configured PipelineChain
    public func build() -> PipelineChain {
        PipelineChain(
            id: id,
            name: name,
            description: description,
            pipelines: pipelines
        )
    }
}

// MARK: - Pipeline Chain Operator

/// Infix operator for chaining pipelines (similar to shell pipe `|`)
infix operator |>

/// Chain two pipelines together
/// - Parameters:
///   - left: First pipeline
///   - right: Second pipeline
/// - Returns: A new PipelineChain
public func |>(left: any Pipeline, right: any Pipeline) -> PipelineChain {
    PipelineChain(
        id: "\(left.pipelineID)_\(right.pipelineID)",
        name: "\(left.pipelineName) → \(right.pipelineName)",
        description: "\(left.pipelineDescription) then \(right.pipelineDescription)",
        pipelines: [left, right]
    )
}

/// Chain a pipeline with a pipeline chain
/// - Parameters:
///   - left: Pipeline to prepend
///   - right: Pipeline chain to append to
/// - Returns: A new PipelineChain with the pipeline prepended
public func |>(left: any Pipeline, right: PipelineChain) -> PipelineChain {
    var pipelines = [left]
    pipelines.append(contentsOf: right.pipelines)
    return PipelineChain(
        id: "\(left.pipelineID)_\(right.pipelineID)",
        name: "\(left.pipelineName) → \(right.pipelineName)",
        description: "\(left.pipelineDescription) then \(right.pipelineDescription)",
        pipelines: pipelines
    )
}

/// Chain a pipeline chain with a pipeline
/// - Parameters:
///   - left: Pipeline chain to prepend
///   - right: Pipeline to append
/// - Returns: A new PipelineChain with the pipeline appended
public func |>(left: PipelineChain, right: any Pipeline) -> PipelineChain {
    var pipelines = left.pipelines
    pipelines.append(right)
    return PipelineChain(
        id: "\(left.pipelineID)_\(right.pipelineID)",
        name: "\(left.pipelineName) → \(right.pipelineName)",
        description: "\(left.pipelineDescription) then \(right.pipelineDescription)",
        pipelines: pipelines
    )
}

/// Chain two pipeline chains together
/// - Parameters:
///   - left: First pipeline chain
///   - right: Second pipeline chain
/// - Returns: A new PipelineChain combining both chains
public func |>(left: PipelineChain, right: PipelineChain) -> PipelineChain {
    var pipelines = left.pipelines
    pipelines.append(contentsOf: right.pipelines)
    return PipelineChain(
        id: "\(left.pipelineID)_\(right.pipelineID)",
        name: "\(left.pipelineName) → \(right.pipelineName)",
        description: "\(left.pipelineDescription) then \(right.pipelineDescription)",
        pipelines: pipelines
    )
}

// MARK: - Convenience Extensions

extension Pipeline {
    /// Chain this pipeline with another pipeline
    /// - Parameter next: Next pipeline in the chain
    /// - Returns: A new PipelineChain
    public func chain(_ next: any Pipeline) -> PipelineChain {
        self |> next
    }
}

extension PipelineChain {
    /// Chain this chain with another pipeline
    /// - Parameter next: Next pipeline in the chain
    /// - Returns: A new PipelineChain
    public func chain(_ next: any Pipeline) -> PipelineChain {
        self |> next
    }
}

