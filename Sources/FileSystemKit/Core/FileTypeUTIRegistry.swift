//
//  FileTypeUTIRegistry.swift
//  FileSystemKit
//
//  Extensible registry for file type UTI generation.
//  Allows RetroboxFS and other packages to register vintage file types.
//

import Foundation
import DesignAlgorithmsKit

/// Protocol for providing UTI generation logic for file types.
///
/// Implementations register file types with their UTI generation logic,
/// allowing the registry to generate UTIs for files based on their type category,
/// file system context, and other metadata.
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public protocol FileTypeUTIProvider: Sendable {
    /// Generate UTI for a file type category.
    ///
    /// - Parameters:
    ///   - fileTypeCategory: The file type category (e.g., .text, .basic, .binary)
    ///   - fileSystemFormat: Optional file system format context (e.g., .appleDOS33, .proDOS)
    ///   - fileSystemVersion: Optional file system version (e.g., "3.3", "2.4")
    ///   - fileExtension: Optional file extension (e.g., "bas", "bin", "txt")
    /// - Returns: UTI string, or nil if this provider doesn't handle this type
    func generateUTI(
        for fileTypeCategory: FileTypeCategory,
        fileSystemFormat: FileSystemFormat?,
        fileSystemVersion: String?,
        fileExtension: String?
    ) -> String?
    
    /// Check if this provider can handle the given file type category.
    ///
    /// - Parameter fileTypeCategory: The file type category to check
    /// - Returns: true if this provider can generate UTIs for this category
    func canHandle(fileTypeCategory: FileTypeCategory) -> Bool
}

/// Registry for file type UTI generation.
///
/// This registry allows RetroboxFS and other packages to register vintage file types
/// with their UTI generation logic. The registry queries registered providers in order
/// to generate UTIs for files.
///
/// ## Usage
///
/// Register a provider:
/// ```swift
/// FileTypeUTIRegistry.shared.register(AppleIIFileTypeUTIProvider())
/// ```
///
/// Generate a UTI:
/// ```swift
/// let uti = FileTypeUTIRegistry.shared.generateUTI(
///     for: .basic,
///     fileSystemFormat: .appleDOS33,
///     fileSystemVersion: "3.3",
///     fileExtension: "bas"
/// )
/// // Returns: "com.apple.file.basic.dos33.v3.3"
/// ```
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public class FileTypeUTIRegistry {
    /// Lock for thread-safe initialization
    nonisolated private static let lock = NSLock()
    
    /// Shared singleton instance (lazy, thread-safe)
    /// Uses Static struct pattern to avoid static initialization order issues
    public static var shared: FileTypeUTIRegistry {
        lock.lock()
        defer { lock.unlock() }
        
        struct Static {
            nonisolated(unsafe) static var instance: FileTypeUTIRegistry?
        }
        
        if Static.instance == nil {
            Static.instance = FileTypeUTIRegistry()
            // Register default provider
            Static.instance?.register(DefaultFileTypeUTIProvider())
        }
        
        return Static.instance!
    }
    
    /// Registered UTI providers (ordered by registration)
    private var providers: [FileTypeUTIProvider] = []
    private let providersLock = NSLock()
    
    /// TypeRegistry from DesignAlgorithmsKit for type storage
    private let typeRegistry = TypeRegistry.shared
    
    private init() {}
    
    /// Register a file type UTI provider.
    ///
    /// Providers are queried in registration order. The first provider that returns
    /// a non-nil UTI will be used.
    /// Uses DesignAlgorithmsKit.TypeRegistry internally for type storage.
    ///
    /// - Parameter provider: The provider to register
    public func register(_ provider: FileTypeUTIProvider) {
        providersLock.lock()
        defer { providersLock.unlock() }
        providers.append(provider)
        
        // Register provider type in TypeRegistry using provider type name as key
        let providerKey = String(describing: type(of: provider))
        typeRegistry.register(type(of: provider), key: providerKey)
    }
    
    /// Generate UTI for a file type.
    ///
    /// Queries registered providers in order until one returns a non-nil UTI.
    ///
    /// - Parameters:
    ///   - fileTypeCategory: The file type category
    ///   - fileSystemFormat: Optional file system format context
    ///   - fileSystemVersion: Optional file system version
    ///   - fileExtension: Optional file extension
    /// - Returns: UTI string, or nil if no provider can generate one
    public func generateUTI(
        for fileTypeCategory: FileTypeCategory,
        fileSystemFormat: FileSystemFormat? = nil,
        fileSystemVersion: String? = nil,
        fileExtension: String? = nil
    ) -> String? {
        providersLock.lock()
        let currentProviders = providers
        providersLock.unlock()
        
        for provider in currentProviders {
            if let uti = provider.generateUTI(
                for: fileTypeCategory,
                fileSystemFormat: fileSystemFormat,
                fileSystemVersion: fileSystemVersion,
                fileExtension: fileExtension
            ) {
                return uti
            }
        }
        
        return nil
    }
    
    /// Get all registered providers.
    ///
    /// - Returns: Array of registered providers
    public func allProviders() -> [FileTypeUTIProvider] {
        providersLock.lock()
        defer { providersLock.unlock() }
        return providers
    }
}

/// Default file type UTI provider.
///
/// Provides basic UTI generation for standard file type categories.
/// This is registered by default and provides fallback UTIs.
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public struct DefaultFileTypeUTIProvider: FileTypeUTIProvider {
    public init() {}
    
    public func canHandle(fileTypeCategory: FileTypeCategory) -> Bool {
        return true // Default provider handles all categories
    }
    
    public func generateUTI(
        for fileTypeCategory: FileTypeCategory,
        fileSystemFormat: FileSystemFormat?,
        fileSystemVersion: String?,
        fileExtension: String?
    ) -> String? {
        var components = ["com", "apple", "file"]
        
        // Add file type category
        let categoryComponent: String
        switch fileTypeCategory {
        case .text:
            categoryComponent = "text"
        case .basic:
            categoryComponent = "basic"
        case .binary:
            categoryComponent = "binary"
        case .assembly:
            categoryComponent = "binary" // Assembly files are binary executables
        case .data:
            categoryComponent = "data"
        case .unknown:
            categoryComponent = "unknown"
        }
        components.append(categoryComponent)
        
        // Add file system format context if available
        if let fileSystemFormat = fileSystemFormat {
            let formatComponent = normalizeFileSystemFormat(fileSystemFormat.rawValue)
            components.append(formatComponent)
            
            // Add version if available
            if let version = fileSystemVersion, !version.isEmpty {
                let normalizedVersion = normalizeVersion(version)
                components.append(normalizedVersion)
            }
        }
        
        return components.joined(separator: ".")
    }
    
    /// Normalize file system format name for UTI
    private func normalizeFileSystemFormat(_ format: String) -> String {
        var normalized = format.lowercased()
        
        // Handle special cases
        if normalized.hasPrefix("apple-dos-") {
            // Extract version and convert to dos33, dos32, dos31
            if let versionMatch = normalized.range(of: #"3\.\d+"#, options: .regularExpression) {
                let version = String(normalized[versionMatch])
                normalized = "dos\(version.replacingOccurrences(of: ".", with: ""))"
            } else {
                normalized = "dos33" // Default fallback
            }
        } else if normalized == "prodos" {
            normalized = "prodos"
        } else if normalized == "ucsd-pascal" {
            normalized = "pascal"
        } else if normalized == "apple-ii-cpm" {
            normalized = "cpm"
        } else {
            // Remove common prefixes and normalize
            normalized = normalized
                .replacingOccurrences(of: "apple-", with: "")
                .replacingOccurrences(of: "apple", with: "")
                .replacingOccurrences(of: "-", with: "")
                .replacingOccurrences(of: "_", with: "")
        }
        
        return normalized
    }
    
    /// Normalize version string for UTI
    private func normalizeVersion(_ version: String) -> String {
        var normalized = version.trimmingCharacters(in: .whitespaces)
        
        // Ensure version starts with "v"
        if !normalized.hasPrefix("v") {
            normalized = "v\(normalized)"
        }
        
        // Ensure dots are used (not dashes or other separators)
        normalized = normalized.replacingOccurrences(of: "-", with: ".")
        
        return normalized
    }
}

