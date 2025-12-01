// FileSystemKit - SNUG Archive Creation
// Progress Reporting Utilities

import Foundation

/// Helper for reporting progress during archive operations
internal struct ProgressReporter {
    let callback: SnugProgressCallback?
    
    func report(
        filesProcessed: Int,
        totalFiles: Int?,
        bytesProcessed: Int64,
        totalBytes: Int64?,
        currentFile: String?,
        phase: ProgressPhase
    ) {
        let progress = SnugProgress(
            filesProcessed: filesProcessed,
            totalFiles: totalFiles,
            bytesProcessed: bytesProcessed,
            totalBytes: totalBytes,
            currentFile: currentFile,
            phase: phase
        )
        callback?(progress)
    }
}

