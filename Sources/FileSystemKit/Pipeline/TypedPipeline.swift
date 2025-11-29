// FileSystemKit - Typed Pipeline Architecture
//
// This file implements type-safe pipelines that distinguish between:
// - Single-item pipelines: Operate on a single PipelineContext
// - Collection pipelines: Operate on collections of PipelineContext (map, filter, group, etc.)
//
// Design:
// - Type-safe context handling
// - Functional programming operations for collections
// - Clear separation between single and collection operations

import Foundation

// MARK: - Typed Pipeline Protocols

/// A pipeline that operates on a single context
/// Input: Single PipelineContext
/// Output: Single PipelineContext (transformed)
public protocol SinglePipeline: Sendable {
    /// Unique identifier for this pipeline
    var pipelineID: String { get }
    
    /// Human-readable name for this pipeline
    var pipelineName: String { get }
    
    /// Description of what this pipeline does
    var pipelineDescription: String { get }
    
    /// Execute the pipeline on a single context
    /// - Parameter context: Input context
    /// - Returns: Transformed context
    func execute(context: PipelineContext) async throws -> PipelineContext
    
    /// Execute the pipeline on a single URL (convenience method)
    /// - Parameter inputURL: URL to process
    /// - Returns: Pipeline context with results
    func execute(inputURL: URL) async throws -> PipelineContext
}

/// A pipeline that operates on a collection of contexts
/// Input: Collection of PipelineContext
/// Output: Collection of PipelineContext (transformed/filtered)
public protocol CollectionPipeline: Sendable {
    /// Unique identifier for this pipeline
    var pipelineID: String { get }
    
    /// Human-readable name for this pipeline
    var pipelineName: String { get }
    
    /// Description of what this pipeline does
    var pipelineDescription: String { get }
    
    /// Execute the pipeline on a collection of contexts
    /// - Parameter contexts: Input contexts
    /// - Returns: Transformed/filtered contexts
    func execute(contexts: [PipelineContext]) async throws -> [PipelineContext]
    
    /// Execute the pipeline on a collection of URLs (convenience method)
    /// - Parameter inputURLs: URLs to process
    /// - Parameter maxConcurrent: Maximum concurrent operations
    /// - Parameter progressHandler: Optional progress callback
    /// - Returns: Pipeline contexts with results
    func execute(
        inputURLs: [URL],
        maxConcurrent: Int,
        progressHandler: ((PipelineProgress) -> Void)?
    ) async throws -> [PipelineContext]
}

// MARK: - Single Pipeline Default Implementation

extension SinglePipeline {
    /// Default implementation: Create context from URL and execute
    public func execute(inputURL: URL) async throws -> PipelineContext {
        let context = PipelineContext(inputURL: inputURL)
        return try await execute(context: context)
    }
}

// MARK: - Collection Pipeline Default Implementation

extension CollectionPipeline {
    /// Default implementation: Create contexts from URLs and execute
    public func execute(
        inputURLs: [URL],
        maxConcurrent: Int,
        progressHandler: ((PipelineProgress) -> Void)?
    ) async throws -> [PipelineContext] {
        let contexts = inputURLs.map { PipelineContext(inputURL: $0) }
        return try await execute(contexts: contexts)
    }
}

// MARK: - Collection Operations

/// Map operation: Transform each context in a collection
public struct MapPipeline: CollectionPipeline {
    public let pipelineID: String
    public let pipelineName: String
    public let pipelineDescription: String
    
    private let transform: @Sendable (PipelineContext) async throws -> PipelineContext
    
    /// Create a map pipeline
    /// - Parameters:
    ///   - id: Pipeline identifier
    ///   - name: Pipeline name
    ///   - description: Pipeline description
    ///   - transform: Transformation function
    public init(
        id: String = "map",
        name: String = "Map",
        description: String = "Transforms each context in a collection",
        transform: @escaping @Sendable (PipelineContext) async throws -> PipelineContext
    ) {
        self.pipelineID = id
        self.pipelineName = name
        self.pipelineDescription = description
        self.transform = transform
    }
    
    public func execute(contexts: [PipelineContext]) async throws -> [PipelineContext] {
        try await withThrowingTaskGroup(of: PipelineContext.self) { group in
            for context in contexts {
                group.addTask {
                    try await self.transform(context)
                }
            }
            
            var results: [PipelineContext] = []
            for try await result in group {
                results.append(result)
            }
            return results
        }
    }
}

/// Filter operation: Filter contexts in a collection based on a predicate
public struct FilterPipeline: CollectionPipeline {
    public let pipelineID: String
    public let pipelineName: String
    public let pipelineDescription: String
    
    private let predicate: @Sendable (PipelineContext) async throws -> Bool
    
    /// Create a filter pipeline
    /// - Parameters:
    ///   - id: Pipeline identifier
    ///   - name: Pipeline name
    ///   - description: Pipeline description
    ///   - predicate: Filter predicate function
    public init(
        id: String = "filter",
        name: String = "Filter",
        description: String = "Filters contexts in a collection based on a predicate",
        predicate: @escaping @Sendable (PipelineContext) async throws -> Bool
    ) {
        self.pipelineID = id
        self.pipelineName = name
        self.pipelineDescription = description
        self.predicate = predicate
    }
    
    public func execute(contexts: [PipelineContext]) async throws -> [PipelineContext] {
        var results: [PipelineContext] = []
        for context in contexts {
            if try await predicate(context) {
                results.append(context)
            }
        }
        return results
    }
}

/// Group operation: Group contexts by a key function
public struct GroupPipeline: CollectionPipeline {
    public let pipelineID: String
    public let pipelineName: String
    public let pipelineDescription: String
    
    private let keySelector: @Sendable (PipelineContext) async throws -> String
    
    /// Create a group pipeline
    /// - Parameters:
    ///   - id: Pipeline identifier
    ///   - name: Pipeline name
    ///   - description: Pipeline description
    ///   - keySelector: Function to extract grouping key
    public init(
        id: String = "group",
        name: String = "Group",
        description: String = "Groups contexts by a key",
        keySelector: @escaping @Sendable (PipelineContext) async throws -> String
    ) {
        self.pipelineID = id
        self.pipelineName = name
        self.pipelineDescription = description
        self.keySelector = keySelector
    }
    
    public func execute(contexts: [PipelineContext]) async throws -> [PipelineContext] {
        // Group contexts by key
        var groups: [String: [PipelineContext]] = [:]
        
        for context in contexts {
            let key = try await keySelector(context)
            groups[key, default: []].append(context)
        }
        
        // Create a result context for each group
        // Store grouped contexts in stageData
        var results: [PipelineContext] = []
        for (key, groupContexts) in groups {
            // Use first context as base, store group in stageData
            var resultContext = groupContexts.first ?? PipelineContext(inputURL: URL(fileURLWithPath: "/"))
            resultContext.stageData["groupKey"] = AnySendable(key)
            resultContext.stageData["groupedContexts"] = AnySendable(groupContexts)
            results.append(resultContext)
        }
        
        return results
    }
}

/// Reduce operation: Reduce a collection to a single value
public struct ReducePipeline: CollectionPipeline {
    public let pipelineID: String
    public let pipelineName: String
    public let pipelineDescription: String
    
    private let initialValue: PipelineContext
    private let reducer: @Sendable (PipelineContext, PipelineContext) async throws -> PipelineContext
    
    /// Create a reduce pipeline
    /// - Parameters:
    ///   - id: Pipeline identifier
    ///   - name: Pipeline name
    ///   - description: Pipeline description
    ///   - initialValue: Initial accumulator value
    ///   - reducer: Reduction function
    public init(
        id: String = "reduce",
        name: String = "Reduce",
        description: String = "Reduces a collection to a single context",
        initialValue: PipelineContext,
        reducer: @escaping @Sendable (PipelineContext, PipelineContext) async throws -> PipelineContext
    ) {
        self.pipelineID = id
        self.pipelineName = name
        self.pipelineDescription = description
        self.initialValue = initialValue
        self.reducer = reducer
    }
    
    public func execute(contexts: [PipelineContext]) async throws -> [PipelineContext] {
        var accumulator = initialValue
        for context in contexts {
            accumulator = try await reducer(accumulator, context)
        }
        return [accumulator]
    }
}

/// FlatMap operation: Transform and flatten a collection
public struct FlatMapPipeline: CollectionPipeline {
    public let pipelineID: String
    public let pipelineName: String
    public let pipelineDescription: String
    
    private let transform: @Sendable (PipelineContext) async throws -> [PipelineContext]
    
    /// Create a flatMap pipeline
    /// - Parameters:
    ///   - id: Pipeline identifier
    ///   - name: Pipeline name
    ///   - description: Pipeline description
    ///   - transform: Transformation function that returns an array
    public init(
        id: String = "flatMap",
        name: String = "FlatMap",
        description: String = "Transforms and flattens a collection",
        transform: @escaping @Sendable (PipelineContext) async throws -> [PipelineContext]
    ) {
        self.pipelineID = id
        self.pipelineName = name
        self.pipelineDescription = description
        self.transform = transform
    }
    
    public func execute(contexts: [PipelineContext]) async throws -> [PipelineContext] {
        var results: [PipelineContext] = []
        for context in contexts {
            let transformed = try await transform(context)
            results.append(contentsOf: transformed)
        }
        return results
    }
}

// MARK: - Single to Collection Conversion

/// Adapter to convert a SinglePipeline to a CollectionPipeline
public struct SingleToCollectionAdapter: CollectionPipeline {
    public let pipelineID: String
    public let pipelineName: String
    public let pipelineDescription: String
    
    private let singlePipeline: any SinglePipeline
    
    /// Create an adapter from a single pipeline
    /// - Parameter singlePipeline: Single pipeline to adapt
    public init(_ singlePipeline: any SinglePipeline) {
        self.singlePipeline = singlePipeline
        self.pipelineID = "\(singlePipeline.pipelineID)_collection"
        self.pipelineName = "\(singlePipeline.pipelineName) (Collection)"
        self.pipelineDescription = "Applies \(singlePipeline.pipelineName) to each context in a collection"
    }
    
    public func execute(contexts: [PipelineContext]) async throws -> [PipelineContext] {
        try await withThrowingTaskGroup(of: PipelineContext.self) { group in
            for context in contexts {
                group.addTask {
                    try await self.singlePipeline.execute(context: context)
                }
            }
            
            var results: [PipelineContext] = []
            for try await result in group {
                results.append(result)
            }
            return results
        }
    }
}

// MARK: - Collection to Single Conversion

/// Adapter to convert a CollectionPipeline to a SinglePipeline (takes first result)
public struct CollectionToSingleAdapter: SinglePipeline {
    public let pipelineID: String
    public let pipelineName: String
    public let pipelineDescription: String
    
    private let collectionPipeline: any CollectionPipeline
    
    /// Create an adapter from a collection pipeline
    /// - Parameter collectionPipeline: Collection pipeline to adapt
    public init(_ collectionPipeline: any CollectionPipeline) {
        self.collectionPipeline = collectionPipeline
        self.pipelineID = "\(collectionPipeline.pipelineID)_single"
        self.pipelineName = "\(collectionPipeline.pipelineName) (Single)"
        self.pipelineDescription = "Applies \(collectionPipeline.pipelineName) and takes first result"
    }
    
    public func execute(context: PipelineContext) async throws -> PipelineContext {
        let results = try await collectionPipeline.execute(contexts: [context])
        return results.first ?? context
    }
}

// MARK: - Convenience Extensions

extension SinglePipeline {
    /// Convert this single pipeline to a collection pipeline
    public func asCollection() -> SingleToCollectionAdapter {
        SingleToCollectionAdapter(self)
    }
}

extension CollectionPipeline {
    /// Convert this collection pipeline to a single pipeline (takes first result)
    public func asSingle() -> CollectionToSingleAdapter {
        CollectionToSingleAdapter(self)
    }
}

