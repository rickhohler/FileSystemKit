//
//  FileSystemKit.swift
//  FileSystemKit
//
//  Main module file with initialization
//

import Foundation

/// FileSystemKit version
public let version = "1.0.0"

/// Initialize FileSystemKit module
///
/// Call this during app startup to register all file types.
/// This registers disk images and vintage file formats with the FileTypeMetadataRegistry.
///
/// ## Usage
/// ```swift
/// import FileSystemKit
///
/// @main
/// struct MyApp: App {
///     init() {
///         Task {
///             await FileSystemKit.initialize()
///         }
///     }
/// }
/// ```
public func initialize() async {
    // Register vintage file types (disk images, archives, etc.)
    await VintageFileTypeRegistrations.register()
    
    // Register example types (for demonstration/testing)
    // Uncomment if needed:
    // await FileTypeMetadataExamples.registerExamples()
}
