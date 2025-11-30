// FileSystemKit - SNUG Progress Reporting
// Progress callbacks and reporting for archive operations

import Foundation

/// Progress information for archive operations
public struct SnugProgress: Sendable {
    public let filesProcessed: Int
    public let totalFiles: Int?
    public let bytesProcessed: Int64
    public let totalBytes: Int64?
    public let currentFile: String?
    public let phase: ProgressPhase
    
    public init(
        filesProcessed: Int,
        totalFiles: Int? = nil,
        bytesProcessed: Int64,
        totalBytes: Int64? = nil,
        currentFile: String? = nil,
        phase: ProgressPhase
    ) {
        self.filesProcessed = filesProcessed
        self.totalFiles = totalFiles
        self.bytesProcessed = bytesProcessed
        self.totalBytes = totalBytes
        self.currentFile = currentFile
        self.phase = phase
    }
    
    /// Progress percentage (0.0 to 1.0) based on files if totalFiles is known, otherwise bytes
    public var progress: Double {
        if let totalFiles = totalFiles, totalFiles > 0 {
            return Double(filesProcessed) / Double(totalFiles)
        } else if let totalBytes = totalBytes, totalBytes > 0 {
            return Double(bytesProcessed) / Double(totalBytes)
        }
        return 0.0
    }
    
    /// Progress percentage as integer (0 to 100)
    public var progressPercent: Int {
        return Int(progress * 100)
    }
}

/// Phase of archive operation
public enum ProgressPhase: String, Sendable {
    case scanning = "Scanning"
    case processing = "Processing"
    case writing = "Writing"
    case compressing = "Compressing"
    case extracting = "Extracting"
    case validating = "Validating"
    case complete = "Complete"
}

/// Progress callback closure type
public typealias SnugProgressCallback = @Sendable (SnugProgress) -> Void

