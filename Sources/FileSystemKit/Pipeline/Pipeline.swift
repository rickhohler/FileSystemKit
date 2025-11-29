// FileSystemKit - Pipeline Architecture
//
// This file implements a pipeline architecture for processing disk images
// with goal-oriented workflows. Pipelines are composed of stages that can
// be executed in a queue/concurrent context.
//
// Pipeline Goals:
// - List files in disk images
// - Grep/search for text in embedded file systems
// - Extract specific files
// - Generate catalogs/indices
// - Convert formats
// - etc.

import Foundation

// MARK: - Pipeline Context

/// Context passed through pipeline stages, accumulating results
/// Note: Uses @unchecked Sendable because RawDiskData and FileSystemFolder are not Sendable
@preconcurrency
public struct PipelineContext: @unchecked Sendable {
    /// The input file URL being processed
    /// Note: This can be updated during pipeline processing (e.g., after decompression)
    public var inputURL: URL
    
    /// Detected disk image format
    public var diskImageFormat: DiskImageFormat?
    
    /// Detected file system format
    public var fileSystemFormat: FileSystemFormat?
    
    /// Raw disk data (if extracted)
    public var rawDiskData: RawDiskData?
    
    /// Parsed file system folder structure
    public var fileSystemFolder: FileSystemFolder?
    
    /// Extracted metadata
    public var metadata: DiskImageMetadata?
    
    /// Custom data dictionary for stage-specific data
    public var stageData: [String: AnySendable] = [:]
    
    /// Errors encountered during processing
    public var errors: [Error] = []
    
    /// Results accumulated by stages
    public var results: [PipelineResult] = []
    
    public init(inputURL: URL) {
        self.inputURL = inputURL
    }
    
    /// Check if processing should continue
    public var shouldContinue: Bool {
        errors.isEmpty || !errors.contains { $0 is PipelineFatalError }
    }
}

/// Type-erased Sendable value for stage data dictionary
public struct AnySendable: @unchecked Sendable {
    public let value: Any
    public init<T: Sendable>(_ value: T) {
        self.value = value
    }
}

/// Fatal error that stops pipeline processing
public struct PipelineFatalError: Error {
    public let message: String
    public init(_ message: String) {
        self.message = message
    }
}

/// Result produced by a pipeline stage
public enum PipelineResult: Sendable {
    case fileListing(FileListingResult)
    case grepMatch(GrepMatchResult)
    case extractedFile(ExtractedFileResult)
    case metadata(MetadataResult)
    case custom(String, AnySendable)
}

// MARK: - Pipeline Result Types

public struct FileListingResult: Sendable {
    public let diskImageURL: URL
    public let files: [FileListingEntry]
    public let totalFiles: Int
    public let totalSize: Int64
    
    public init(diskImageURL: URL, files: [FileListingEntry], totalFiles: Int, totalSize: Int64) {
        self.diskImageURL = diskImageURL
        self.files = files
        self.totalFiles = totalFiles
        self.totalSize = totalSize
    }
    
    public struct FileListingEntry: Sendable {
        public let path: String
        public let name: String
        public let size: Int64
        public let isDirectory: Bool
        public let fileType: String?
        
        public init(path: String, name: String, size: Int64, isDirectory: Bool, fileType: String? = nil) {
            self.path = path
            self.name = name
            self.size = size
            self.isDirectory = isDirectory
            self.fileType = fileType
        }
    }
}

public struct GrepMatchResult: Sendable {
    public let diskImageURL: URL
    public let filePath: String
    public let matches: [GrepMatch]
    
    public init(diskImageURL: URL, filePath: String, matches: [GrepMatch]) {
        self.diskImageURL = diskImageURL
        self.filePath = filePath
        self.matches = matches
    }
    
    public struct GrepMatch: Sendable {
        public let lineNumber: Int?
        public let offset: Int
        public let matchedText: String
        public let context: String?
        
        public init(lineNumber: Int?, offset: Int, matchedText: String, context: String? = nil) {
            self.lineNumber = lineNumber
            self.offset = offset
            self.matchedText = matchedText
            self.context = context
        }
    }
}

public struct ExtractedFileResult: Sendable {
    public let diskImageURL: URL
    public let sourcePath: String
    public let destinationURL: URL?
    public let size: Int64
    public let success: Bool
}

public struct MetadataResult: Sendable {
    public let diskImageURL: URL
    public let metadata: DiskImageMetadata
}

// MARK: - Pipeline Stage

/// A single stage in a processing pipeline
public protocol PipelineStage: Sendable {
    /// Unique identifier for this stage
    var stageID: String { get }
    
    /// Human-readable name for this stage
    var stageName: String { get }
    
    /// Process the context and return updated context
    /// - Parameter context: Current pipeline context
    /// - Returns: Updated context (may be modified in place)
    func process(_ context: inout PipelineContext) async throws
}

// MARK: - Pipeline

/// A goal-oriented processing pipeline composed of stages
public protocol Pipeline: Sendable {
    /// Unique identifier for this pipeline
    var pipelineID: String { get }
    
    /// Human-readable name for this pipeline
    var pipelineName: String { get }
    
    /// Description of what this pipeline does
    var pipelineDescription: String { get }
    
    /// Ordered stages that compose this pipeline
    var stages: [PipelineStage] { get }
    
    /// Execute the pipeline on a single file
    /// - Parameter inputURL: URL of the file to process
    /// - Returns: Final pipeline context with results
    func execute(inputURL: URL) async throws -> PipelineContext
    
    /// Execute the pipeline on multiple files
    /// - Parameter inputURLs: URLs of files to process
    /// - Parameter maxConcurrent: Maximum concurrent executions
    /// - Parameter progressHandler: Optional progress callback
    /// - Returns: Array of pipeline contexts, one per input file
    func execute(
        inputURLs: [URL],
        maxConcurrent: Int,
        progressHandler: ((PipelineProgress) -> Void)?
    ) async throws -> [PipelineContext]
}

// MARK: - Pipeline Progress

public struct PipelineProgress: Sendable {
    public let completed: Int
    public let total: Int
    public let currentFile: URL?
    public let currentStage: String?
    public let progress: Double
    public let rate: Double
    public let estimatedTimeRemaining: TimeInterval?
    
    public init(
        completed: Int,
        total: Int,
        currentFile: URL? = nil,
        currentStage: String? = nil,
        rate: Double = 0.0,
        estimatedTimeRemaining: TimeInterval? = nil
    ) {
        self.completed = completed
        self.total = total
        self.currentFile = currentFile
        self.currentStage = currentStage
        self.progress = total > 0 ? Double(completed) / Double(total) : 0.0
        self.rate = rate
        self.estimatedTimeRemaining = estimatedTimeRemaining
    }
}

// MARK: - Base Pipeline Implementation

/// Base implementation of Pipeline protocol
public struct BasePipeline: Pipeline {
    public let pipelineID: String
    public let pipelineName: String
    public let pipelineDescription: String
    public let stages: [PipelineStage]
    
    public init(
        id: String,
        name: String,
        description: String,
        stages: [PipelineStage]
    ) {
        self.pipelineID = id
        self.pipelineName = name
        self.pipelineDescription = description
        self.stages = stages
    }
    
    public func execute(inputURL: URL) async throws -> PipelineContext {
        var context = PipelineContext(inputURL: inputURL)
        
        for stage in stages {
            guard context.shouldContinue else {
                break
            }
            
            do {
                try await stage.process(&context)
            } catch {
                context.errors.append(error)
                if error is PipelineFatalError {
                    break
                }
            }
        }
        
        return context
    }
    
    public func execute(
        inputURLs: [URL],
        maxConcurrent: Int,
        progressHandler: ((PipelineProgress) -> Void)?
    ) async throws -> [PipelineContext] {
        let startTime = Date()
        var completed = 0
        var results: [PipelineContext] = []
        results.reserveCapacity(inputURLs.count)
        
        await withTaskGroup(of: (Int, PipelineContext).self) { group in
            var nextIndex = 0
            var activeTasks = 0
            
            // Start initial batch
            while activeTasks < maxConcurrent && nextIndex < inputURLs.count {
                let index = nextIndex
                let url = inputURLs[index]
                nextIndex += 1
                activeTasks += 1
                
                group.addTask { [self] in
                    do {
                        let context = try await self.execute(inputURL: url)
                        return (index, context)
                    } catch {
                        // Return context with error
                        var context = PipelineContext(inputURL: url)
                        context.errors.append(error)
                        return (index, context)
                    }
                }
            }
            
            // Process completed tasks and start new ones
            while activeTasks > 0 {
                if let (_, context) = await group.next() {
                    results.append(context)
                    completed += 1
                    activeTasks -= 1
                    
                    // Report progress
                    let elapsed = Date().timeIntervalSince(startTime)
                    let rate = elapsed > 0 ? Double(completed) / elapsed : 0.0
                    let remaining = inputURLs.count - completed
                    let eta = rate > 0 ? TimeInterval(remaining) / rate : nil
                    
                    progressHandler?(PipelineProgress(
                        completed: completed,
                        total: inputURLs.count,
                        currentFile: context.inputURL,
                        currentStage: stages.last?.stageName,
                        rate: rate,
                        estimatedTimeRemaining: eta
                    ))
                    
                    // Start next task if available
                    if nextIndex < inputURLs.count {
                        let index = nextIndex
                        let url = inputURLs[index]
                        nextIndex += 1
                        activeTasks += 1
                        
                        group.addTask {
                            do {
                                let context = try await self.execute(inputURL: url)
                                return (index, context)
                            } catch {
                                // Return context with error
                                var errorContext = PipelineContext(inputURL: url)
                                errorContext.errors.append(error)
                                return (index, errorContext)
                            }
                        }
                    }
                }
            }
        }
        
        // Sort results by original input order
        return results.sorted { $0.inputURL.path < $1.inputURL.path }
    }
}

