// FileSystemKit Core Library
// DirectoryParserDelegate
//
// Delegate protocol for handling directory parsing events.

import Foundation

/// Delegate protocol for handling directory parsing events
public protocol DirectoryParserDelegate: Sendable {
    /// Called when a directory entry is discovered
    /// - Parameter entry: The discovered directory entry
    /// - Returns: true to continue parsing, false to stop
    /// - Throws: Error to abort parsing
    func processEntry(_ entry: DirectoryEntry) throws -> Bool
    
    /// Called when parsing starts
    /// - Parameter rootURL: Root directory URL being parsed
    func didStartParsing(rootURL: URL)
    
    /// Called when parsing completes
    /// - Parameter rootURL: Root directory URL that was parsed
    func didFinishParsing(rootURL: URL)
}

