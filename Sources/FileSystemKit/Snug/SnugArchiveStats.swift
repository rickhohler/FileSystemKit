// FileSystemKit - SNUG Archive Statistics

import Foundation

/// Statistics from creating a SNUG archive
public struct SnugArchiveStats {
    public let fileCount: Int
    public let directoryCount: Int
    public let uniqueHashCount: Int
    public let totalSize: Int
    
    public init(fileCount: Int, directoryCount: Int, uniqueHashCount: Int, totalSize: Int) {
        self.fileCount = fileCount
        self.directoryCount = directoryCount
        self.uniqueHashCount = uniqueHashCount
        self.totalSize = totalSize
    }
}

/// Validation result for SNUG archive
public struct SnugValidationResult {
    public let allFilesExist: Bool
    public let totalFiles: Int
    public let filesFound: Int
    public let filesMissing: Int
    public let missingHashes: [String]
    
    public init(allFilesExist: Bool, totalFiles: Int, filesFound: Int, filesMissing: Int, missingHashes: [String]) {
        self.allFilesExist = allFilesExist
        self.totalFiles = totalFiles
        self.filesFound = filesFound
        self.filesMissing = filesMissing
        self.missingHashes = missingHashes
    }
}

