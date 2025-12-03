// FileSystemKit Core Library
// File Extension Registry
//
// This file implements a general-purpose file extension registry system.
// FileSystemKit is the base library for all files and directories, so this
// registry provides extension-to-type mapping that can be used by all projects.

import Foundation

// MARK: - FileExtensionRegistry

/// Registry for mapping file extensions to types/identifiers.
/// Provides a general-purpose extension registration system that can be used
/// by FileSystemKit and packages that extend it.
///
/// ## Usage Example
/// ```swift
/// let registry = await FileExtensionRegistry.shared
///
/// // Register an extension mapping
/// await registry.register(fileExtension: "dmg", type: "disk-image", category: "mac")
/// await registry.register(fileExtension: "iso", type: "disk-image", category: "optical")
///
/// // Look up by extension
/// if let type = await registry.type(forExtension: "dmg") {
///     print("Type: \(type)")
/// }
///
/// // Get all extensions for a type
/// let extensions = await registry.extensions(forType: "disk-image")
/// ```
public actor FileExtensionRegistry {
    /// Shared singleton instance (lazy initialization to avoid static initialization order issues)
    // Protected by lock, so marked as nonisolated(unsafe) for concurrency safety
    nonisolated(unsafe) private static var _shared: FileExtensionRegistry?
    nonisolated private static let lock = NSLock()
    
    /// Shared singleton instance (lazy)
    public static var shared: FileExtensionRegistry {
        lock.lock()
        defer { lock.unlock() }
        if _shared == nil {
            _shared = FileExtensionRegistry()
        }
        return _shared!
    }
    
    /// Extension to type mapping (extension -> type)
    private var extensionToType: [String: String] = [:]
    
    /// Type to extensions mapping (type -> Set<extension>)
    private var typeToExtensions: [String: Set<String>] = [:]
    
    /// Extension to category mapping (extension -> category)
    private var extensionToCategory: [String: String] = [:]
    
    /// Category to extensions mapping (category -> Set<extension>)
    private var categoryToExtensions: [String: Set<String>] = [:]
    
    /// Extension metadata (extension -> metadata)
    private var extensionMetadata: [String: ExtensionMetadata] = [:]
    
    private init() {
        // Private initializer for singleton
    }
    
    /// Register a file extension mapping
    /// - Parameters:
    ///   - fileExtension: File extension (with or without leading dot, will be normalized)
    ///   - type: Type identifier (e.g., "disk-image", "compression", "file-system")
    ///   - category: Optional category (e.g., "mac", "vintage", "modern")
    ///   - metadata: Optional metadata about the extension
    public func register(
        fileExtension: String,
        type: String,
        category: String? = nil,
        metadata: ExtensionMetadata? = nil
    ) {
        let normalizedExt = normalizeExtension(fileExtension)
        
        // Register extension -> type mapping
        extensionToType[normalizedExt] = type
        
        // Register type -> extensions mapping
        if typeToExtensions[type] == nil {
            typeToExtensions[type] = []
        }
        typeToExtensions[type]?.insert(normalizedExt)
        
        // Register category if provided
        if let category = category {
            extensionToCategory[normalizedExt] = category
            
            if categoryToExtensions[category] == nil {
                categoryToExtensions[category] = []
            }
            categoryToExtensions[category]?.insert(normalizedExt)
        }
        
        // Store metadata if provided
        if let metadata = metadata {
            extensionMetadata[normalizedExt] = metadata
        }
    }
    
    /// Register multiple extensions for a type
    /// - Parameters:
    ///   - extensions: Array of file extensions
    ///   - type: Type identifier
    ///   - category: Optional category
    ///   - metadata: Optional metadata (applied to all extensions)
    public func register(
        extensions: [String],
        type: String,
        category: String? = nil,
        metadata: ExtensionMetadata? = nil
    ) {
        for ext in extensions {
            register(fileExtension: ext, type: type, category: category, metadata: metadata)
        }
    }
    
    /// Get type identifier for an extension
    /// - Parameter fileExtension: File extension (with or without leading dot)
    /// - Returns: Type identifier, or nil if not registered
    public func type(forExtension fileExtension: String) -> String? {
        let normalizedExt = normalizeExtension(fileExtension)
        return extensionToType[normalizedExt]
    }
    
    /// Get all extensions for a type
    /// - Parameter type: Type identifier
    /// - Returns: Set of extensions registered for this type
    public func extensions(forType type: String) -> Set<String> {
        return typeToExtensions[type] ?? []
    }
    
    /// Get category for an extension
    /// - Parameter fileExtension: File extension
    /// - Returns: Category, or nil if not registered
    public func category(forExtension fileExtension: String) -> String? {
        let normalizedExt = normalizeExtension(fileExtension)
        return extensionToCategory[normalizedExt]
    }
    
    /// Get all extensions for a category
    /// - Parameter category: Category identifier
    /// - Returns: Set of extensions in this category
    public func extensions(forCategory category: String) -> Set<String> {
        return categoryToExtensions[category] ?? []
    }
    
    /// Get metadata for an extension
    /// - Parameter fileExtension: File extension
    /// - Returns: Extension metadata, or nil if not registered
    public func metadata(forExtension fileExtension: String) -> ExtensionMetadata? {
        let normalizedExt = normalizeExtension(fileExtension)
        return extensionMetadata[normalizedExt]
    }
    
    /// Check if an extension is registered
    /// - Parameter fileExtension: File extension
    /// - Returns: True if extension is registered
    public func isRegistered(fileExtension: String) -> Bool {
        let normalizedExt = normalizeExtension(fileExtension)
        return extensionToType[normalizedExt] != nil
    }
    
    /// Get all registered extensions
    /// - Returns: Set of all registered extensions
    public func allExtensions() -> Set<String> {
        return Set(extensionToType.keys)
    }
    
    /// Get all registered types
    /// - Returns: Set of all registered type identifiers
    public func allTypes() -> Set<String> {
        return Set(typeToExtensions.keys)
    }
    
    /// Get all registered categories
    /// - Returns: Set of all registered categories
    public func allCategories() -> Set<String> {
        return Set(categoryToExtensions.keys)
    }
    
    /// Unregister an extension
    /// - Parameter fileExtension: File extension to unregister
    public func unregister(fileExtension: String) {
        let normalizedExt = normalizeExtension(fileExtension)
        
        // Remove from extension -> type mapping
        if let type = extensionToType[normalizedExt] {
            extensionToType.removeValue(forKey: normalizedExt)
            
            // Remove from type -> extensions mapping
            typeToExtensions[type]?.remove(normalizedExt)
            if typeToExtensions[type]?.isEmpty == true {
                typeToExtensions.removeValue(forKey: type)
            }
        }
        
        // Remove from category mappings
        if let category = extensionToCategory[normalizedExt] {
            extensionToCategory.removeValue(forKey:normalizedExt)
            categoryToExtensions[category]?.remove(normalizedExt)
            if categoryToExtensions[category]?.isEmpty == true {
                categoryToExtensions.removeValue(forKey: category)
            }
        }
        
        // Remove metadata
        extensionMetadata.removeValue(forKey: normalizedExt)
    }
    
    /// Clear all registrations
    public func clear() {
        extensionToType.removeAll()
        typeToExtensions.removeAll()
        extensionToCategory.removeAll()
        categoryToExtensions.removeAll()
        extensionMetadata.removeAll()
    }
    
    // MARK: - Private Helpers
    
    /// Normalize extension: remove leading dot, lowercase
    private func normalizeExtension(_ fileExtension: String) -> String {
        return fileExtension.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
    }
}

// MARK: - ExtensionMetadata

/// Metadata about a file extension
public struct ExtensionMetadata: Sendable {
    /// Description of the extension/format
    public let description: String?
    
    /// MIME type, if applicable
    public let mimeType: String?
    
    /// Whether this is a common/well-known extension
    public let isCommon: Bool
    
    /// Additional metadata dictionary
    public let additionalInfo: [String: String]
    
    public init(
        description: String? = nil,
        mimeType: String? = nil,
        isCommon: Bool = false,
        additionalInfo: [String: String] = [:]
    ) {
        self.description = description
        self.mimeType = mimeType
        self.isCommon = isCommon
        self.additionalInfo = additionalInfo
    }
}

// MARK: - Convenience Extensions

extension FileExtensionRegistry {
    /// Register extensions from a dictionary mapping extensions to types
    /// - Parameter mappings: Dictionary of extension -> type mappings
    public func register(mappings: [String: String]) {
        for (ext, type) in mappings {
            register(fileExtension: ext, type: type)
        }
    }
    
    /// Register extensions from a dictionary mapping types to extension arrays
    /// - Parameter mappings: Dictionary of type -> [extensions] mappings
    public func register(typeMappings: [String: [String]]) {
        for (type, extensions) in typeMappings {
            register(extensions: extensions, type: type)
        }
    }
}

