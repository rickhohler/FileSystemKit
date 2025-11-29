// FileSystemKit - Pipeline Registry and Builder
//
// This file implements a registry pattern for pipelines, making it easy to:
// - Register new pipelines
// - Discover available pipelines
// - Build custom pipelines using a builder pattern
//
// Design Patterns Used:
// - Registry Pattern: Central registry for pipeline discovery
// - Builder Pattern: Fluent API for constructing custom pipelines
// - Factory Pattern: Predefined pipeline factories

import Foundation

// MARK: - Pipeline Registry

/// Central registry for managing and discovering pipelines
public actor PipelineRegistry {
    /// Shared singleton instance
    public static let shared = PipelineRegistry()
    
    /// Registered pipelines by ID
    private var pipelines: [String: any Pipeline] = [:]
    
    /// Pipeline metadata for discovery
    private var pipelineMetadata: [String: PipelineMetadata] = [:]
    
    private init() {
        // Private initializer for singleton
    }
    
    /// Register a pipeline
    /// - Parameters:
    ///   - pipeline: Pipeline to register
    ///   - metadata: Optional metadata for discovery
    public func register(_ pipeline: any Pipeline, metadata: PipelineMetadata? = nil) {
        pipelines[pipeline.pipelineID] = pipeline
        
        if let metadata = metadata {
            pipelineMetadata[pipeline.pipelineID] = metadata
        } else {
            // Create default metadata
            pipelineMetadata[pipeline.pipelineID] = PipelineMetadata(
                id: pipeline.pipelineID,
                name: pipeline.pipelineName,
                description: pipeline.pipelineDescription,
                category: .general,
                tags: []
            )
        }
    }
    
    /// Get a pipeline by ID
    /// - Parameter id: Pipeline identifier
    /// - Returns: Pipeline if found, nil otherwise
    public func pipeline(for id: String) -> (any Pipeline)? {
        return pipelines[id]
    }
    
    /// List all registered pipelines
    /// - Returns: Array of pipeline metadata
    public func listPipelines() -> [PipelineMetadata] {
        return Array(pipelineMetadata.values).sorted { $0.name < $1.name }
    }
    
    /// List pipelines by category
    /// - Parameter category: Pipeline category
    /// - Returns: Array of pipeline metadata
    public func pipelines(in category: PipelineCategory) -> [PipelineMetadata] {
        return pipelineMetadata.values
            .filter { $0.category == category }
            .sorted { $0.name < $1.name }
    }
    
    /// Search pipelines by tag
    /// - Parameter tag: Tag to search for
    /// - Returns: Array of matching pipeline metadata
    public func pipelines(withTag tag: String) -> [PipelineMetadata] {
        return pipelineMetadata.values
            .filter { $0.tags.contains(tag.lowercased()) }
            .sorted { $0.name < $1.name }
    }
    
    /// Unregister a pipeline
    /// - Parameter id: Pipeline identifier
    public func unregister(_ id: String) {
        pipelines.removeValue(forKey: id)
        pipelineMetadata.removeValue(forKey: id)
    }
    
    /// Clear all registered pipelines
    public func clear() {
        pipelines.removeAll()
        pipelineMetadata.removeAll()
    }
}

// MARK: - Pipeline Metadata

/// Metadata for pipeline discovery and documentation
public struct PipelineMetadata: Sendable {
    public let id: String
    public let name: String
    public let description: String
    public let category: PipelineCategory
    public let tags: [String]
    public let author: String?
    public let version: String?
    
    public init(
        id: String,
        name: String,
        description: String,
        category: PipelineCategory,
        tags: [String] = [],
        author: String? = nil,
        version: String? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.category = category
        self.tags = tags.map { $0.lowercased() }
        self.author = author
        self.version = version
    }
}

/// Categories for organizing pipelines
public enum PipelineCategory: String, Sendable, CaseIterable {
    case general = "general"
    case fileOperations = "file_operations"
    case cataloging = "cataloging"
    case metadata = "metadata"
    case search = "search"
    case conversion = "conversion"
    case extraction = "extraction"
    case validation = "validation"
    case custom = "custom"
}

// MARK: - Pipeline Builder

/// Builder pattern for constructing custom pipelines
public struct PipelineBuilder {
    private var id: String
    private var name: String
    private var description: String
    private var stages: [PipelineStage] = []
    private var category: PipelineCategory = .custom
    private var tags: [String] = []
    
    /// Create a new pipeline builder
    /// - Parameters:
    ///   - id: Unique pipeline identifier
    ///   - name: Human-readable name
    ///   - description: Description of what the pipeline does
    public init(id: String, name: String, description: String) {
        self.id = id
        self.name = name
        self.description = description
    }
    
    /// Add a stage to the pipeline
    /// - Parameter stage: Stage to add
    /// - Returns: Builder for method chaining
    public mutating func addStage(_ stage: PipelineStage) -> PipelineBuilder {
        var builder = self
        builder.stages.append(stage)
        return builder
    }
    
    /// Add multiple stages to the pipeline
    /// - Parameter stages: Stages to add
    /// - Returns: Builder for method chaining
    public mutating func addStages(_ stages: [PipelineStage]) -> PipelineBuilder {
        var builder = self
        builder.stages.append(contentsOf: stages)
        return builder
    }
    
    /// Set the pipeline category
    /// - Parameter category: Category for organization
    /// - Returns: Builder for method chaining
    public mutating func category(_ category: PipelineCategory) -> PipelineBuilder {
        var builder = self
        builder.category = category
        return builder
    }
    
    /// Add tags for discovery
    /// - Parameter tags: Tags to add
    /// - Returns: Builder for method chaining
    public mutating func tags(_ tags: [String]) -> PipelineBuilder {
        var builder = self
        builder.tags.append(contentsOf: tags)
        return builder
    }
    
    /// Build the pipeline
    /// - Returns: Configured BasePipeline
    public func build() -> BasePipeline {
        return BasePipeline(
            id: id,
            name: name,
            description: description,
            stages: stages
        )
    }
    
    /// Build and register the pipeline
    /// - Parameter registry: Pipeline registry (defaults to shared)
    /// - Returns: Configured BasePipeline
    public func buildAndRegister(in registry: PipelineRegistry = PipelineRegistry.shared) async -> BasePipeline {
        let pipeline = build()
        let metadata = PipelineMetadata(
            id: id,
            name: name,
            description: description,
            category: category,
            tags: tags
        )
        await registry.register(pipeline, metadata: metadata)
        return pipeline
    }
}

// MARK: - Convenience Extensions

extension PipelineRegistry {
    /// Create a pipeline using the builder pattern
    /// - Parameter builder: Builder closure
    /// - Returns: Built pipeline
    public func buildPipeline(_ builder: (inout PipelineBuilder) -> Void) async -> BasePipeline {
        var pipelineBuilder = PipelineBuilder(id: UUID().uuidString, name: "Custom Pipeline", description: "")
        builder(&pipelineBuilder)
        return await pipelineBuilder.buildAndRegister(in: self)
    }
}

