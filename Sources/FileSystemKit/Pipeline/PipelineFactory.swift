// FileSystemKit - Pipeline Factory
//
// Factory for creating predefined pipelines

import Foundation

/// Factory for creating pipelines
public struct PipelineFactory {
    /// Create a custom pipeline from stages
    /// - Parameters:
    ///   - id: Pipeline identifier
    ///   - name: Pipeline name
    ///   - description: Pipeline description
    ///   - stages: Pipeline stages
    /// - Returns: Configured BasePipeline
    public static func custom(
        id: String,
        name: String,
        description: String,
        stages: [PipelineStage]
    ) -> BasePipeline {
        BasePipeline(id: id, name: name, description: description, stages: stages)
    }
}

