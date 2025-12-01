// FileSystemKit Core Library
// DirectoryParser
//
// Reusable directory parser that walks directory trees and collects metadata.
// Uses SpecialFileType from Core/SpecialFileType.swift for special file detection.
// Uses FileMetadataCollector from Core/FileMetadata.swift for metadata collection.
// Uses PathUtilities from Core/PathUtilities.swift for path normalization.

import Foundation

/// Reusable directory parser that walks directory trees and collects metadata
/// Uses SpecialFileType from Core/SpecialFileType.swift for special file detection
/// Uses FileMetadataCollector from Core/FileMetadata.swift for metadata collection
/// Uses PathUtilities from Core/PathUtilities.swift for path normalization
public struct DirectoryParser {
    /// Parse a directory tree and report entries via delegate
    /// - Parameters:
    ///   - rootURL: Root directory URL to parse
    ///   - options: Parsing options
    ///   - delegate: Delegate to receive entry notifications
    ///   - ignoreMatcher: Optional ignore pattern matcher
    /// - Throws: Errors encountered during parsing
    public static func parse(
        rootURL: URL,
        options: DirectoryParserOptions = DirectoryParserOptions(),
        delegate: DirectoryParserDelegate,
        ignoreMatcher: IgnoreMatcher? = nil
    ) throws {
        delegate.didStartParsing(rootURL: rootURL)
        defer {
            delegate.didFinishParsing(rootURL: rootURL)
        }
        
        var visitedCanonicalPaths: Set<String> = []
        let resourceKeys: [URLResourceKey] = [
            .isDirectoryKey,
            .isSymbolicLinkKey,
            .isRegularFileKey,
            .fileSizeKey,
            .contentModificationDateKey,
            .creationDateKey,
            .hasHiddenExtensionKey,
            .isSystemImmutableKey
        ]
        
        var enumeratorOptions: FileManager.DirectoryEnumerationOptions = []
        if options.skipHiddenFiles {
            enumeratorOptions.insert(.skipsHiddenFiles)
        }
        
        let enumerator = FileManager.default.enumerator(
            at: rootURL,
            includingPropertiesForKeys: resourceKeys,
            options: enumeratorOptions,
            errorHandler: { url, error in
                if options.skipPermissionErrors {
                    if options.verbose {
                        print("  Warning: Skipping \(url.path) due to error: \(error.localizedDescription)")
                    }
                    return true
                }
                return false
            }
        )
        
        guard let enumerator = enumerator else {
            throw DirectoryParserError.failedToEnumerate(rootURL)
        }
        
        for case let fileURL as URL in enumerator {
            let relativePath = PathUtilities.relativePath(from: fileURL, baseURL: rootURL, basePath: options.basePath)
            
            // Check ignore patterns
            if let matcher = ignoreMatcher, matcher.shouldIgnore(relativePath) {
                continue
            }
            
            // Get resource values
            guard let resourceValues = try? fileURL.resourceValues(forKeys: Set(resourceKeys)) else {
                if options.skipPermissionErrors {
                    continue
                }
                throw DirectoryParserError.permissionDenied(fileURL)
            }
            
            let isDirectory = resourceValues.isDirectory ?? false
            let isSymlink = resourceValues.isSymbolicLink ?? false
            let isRegularFile = resourceValues.isRegularFile ?? false
            
            // Detect special files using Core/SpecialFileType.swift
            let specialFileType = detectSpecialFileType(at: fileURL)
            
            // Handle symlinks
            if isSymlink {
                let shouldContinue = try EntryProcessor.processSymlink(
                    fileURL: fileURL,
                    relativePath: relativePath,
                    resourceValues: resourceValues,
                    options: options,
                    visitedCanonicalPaths: &visitedCanonicalPaths,
                    delegate: delegate
                )
                if !shouldContinue {
                    continue
                }
                continue
            }
            
            // Handle special files using Core/SpecialFileType.swift
            if let specialType = specialFileType {
                let shouldContinue = try EntryProcessor.processSpecialFile(
                    fileURL: fileURL,
                    relativePath: relativePath,
                    resourceValues: resourceValues,
                    specialType: specialType,
                    options: options,
                    delegate: delegate
                )
                if !shouldContinue {
                    continue
                }
                continue
            }
            
            // Handle directories
            if isDirectory {
                let shouldContinue = try EntryProcessor.processDirectory(
                    fileURL: fileURL,
                    relativePath: relativePath,
                    resourceValues: resourceValues,
                    options: options,
                    delegate: delegate
                )
                if !shouldContinue {
                    continue
                }
                continue
            }
            
            // Handle regular files
            if isRegularFile {
                let shouldContinue = try EntryProcessor.processRegularFile(
                    fileURL: fileURL,
                    relativePath: relativePath,
                    resourceValues: resourceValues,
                    options: options,
                    delegate: delegate
                )
                if !shouldContinue {
                    continue
                }
            }
        }
    }
    
    /// Parse a directory tree and build a FileSystemFolder hierarchy with FileSystemEntry instances
    /// - Parameters:
    ///   - rootURL: Root directory URL to parse
    ///   - options: Parsing options
    ///   - ignoreMatcher: Optional ignore pattern matcher
    /// - Returns: Root FileSystemFolder containing parsed file system hierarchy
    /// - Throws: Errors encountered during parsing
    /// - Note: Special files are included if options.includeSpecialFiles is true
    /// - Note: Files will have chunkIdentifier set to nil (can be set later when storing in ChunkStorage)
    public static func parseToFileSystem(
        rootURL: URL,
        options: DirectoryParserOptions = DirectoryParserOptions(),
        ignoreMatcher: IgnoreMatcher? = nil
    ) throws -> FileSystemFolder {
        let rootFolder = FileSystemFolder(name: rootURL.lastPathComponent, modificationDate: nil)
        let folderMap = NSMutableDictionary()
        folderMap[""] = rootFolder
        
        let delegate = FileSystemBuilderDelegate(rootFolder: rootFolder, folderMap: folderMap, options: options)
        try parse(rootURL: rootURL, options: options, delegate: delegate, ignoreMatcher: ignoreMatcher)
        
        return rootFolder
    }
}

