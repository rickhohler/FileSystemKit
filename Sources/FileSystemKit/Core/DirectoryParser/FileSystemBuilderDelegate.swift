// FileSystemKit Core Library
// FileSystemBuilderDelegate
//
// Delegate implementation for building FileSystemFolder hierarchy from directory parsing.

import Foundation

/// Delegate implementation for building FileSystemFolder hierarchy
internal final class FileSystemBuilderDelegate: @unchecked Sendable, DirectoryParserDelegate {
    let rootFolder: FileSystemFolder
    let folderMap: NSMutableDictionary
    let options: DirectoryParserOptions
    
    init(rootFolder: FileSystemFolder, folderMap: NSMutableDictionary, options: DirectoryParserOptions) {
        self.rootFolder = rootFolder
        self.folderMap = folderMap
        self.options = options
    }
    
    func processEntry(_ entry: DirectoryEntry) throws -> Bool {
        // Get parent path
        let pathComponents = entry.path.split(separator: "/").map(String.init)
        let parentPath: String
        if pathComponents.count > 1 {
            parentPath = pathComponents.dropLast().joined(separator: "/")
        } else {
            parentPath = ""
        }
        
        // Get or create parent folder
        let parentFolder: FileSystemFolder
        if let existingParent = folderMap[parentPath] as? FileSystemFolder {
            parentFolder = existingParent
        } else {
            // Create missing parent folders
            var currentPath = ""
            var currentFolder = rootFolder
            
            for component in pathComponents.dropLast() {
                let nextPath = currentPath.isEmpty ? component : "\(currentPath)/\(component)"
                if let existingFolder = folderMap[nextPath] as? FileSystemFolder {
                    currentFolder = existingFolder
                } else {
                    let newFolder = FileSystemFolder(name: component, modificationDate: nil)
                    currentFolder.addChild(newFolder)
                    folderMap[nextPath] = newFolder
                    currentFolder = newFolder
                }
                currentPath = nextPath
            }
            
            guard let finalParent = folderMap[parentPath] as? FileSystemFolder else {
                return true  // Skip if we can't create parent
            }
            parentFolder = finalParent
        }
        
        // Add entry to parent folder
        if entry.type == "directory" {
            if let folder = entry.toFileSystemFolder() {
                let entryPath = entry.path
                folderMap[entryPath] = folder
                parentFolder.addChild(folder)
            }
        } else {
            // Regular file, symlink, or special file
            if let fileEntry = entry.toFileSystemEntry() {
                parentFolder.addChild(fileEntry)
            }
        }
        
        return true
    }
    
    func didStartParsing(rootURL: URL) {
        // No-op
    }
    
    func didFinishParsing(rootURL: URL) {
        // No-op
    }
}

