//
//  FileTypeRegistry.swift
//  FileSystemKit
//
//  Central registry for file types with handler management
//

import Foundation

/// Errors that can occur during file type registration
public enum FileTypeRegistryError: Error, LocalizedError {
    case duplicateShortID(String)
    case duplicateUTI(String)
    case duplicateHandler(handlerType: String, uti: String)
    case invalidShortID(String)
    case fileTypeNotFound(String)
    case handlerNotFound(String)
    
    public var errorDescription: String? {
        switch self {
        case .duplicateShortID(let id):
            return "File type with shortID '\(id)' is already registered. Use allowOverride: true to replace."
        case .duplicateUTI(let uti):
            return "File type with UTI '\(uti)' is already registered. Use allowOverride: true to replace."
        case .duplicateHandler(let type, let uti):
            return "\(type) for UTI '\(uti)' is already registered. Use allowOverride: true to replace."
        case .invalidShortID(let id):
            return "Invalid shortID '\(id)'. Must be 3-8 lowercase alphanumeric characters."
        case .fileTypeNotFound(let id):
            return "File type '\(id)' not found in registry."
        case .handlerNotFound(let id):
            return "Handler '\(id)' not found in registry."
        }
    }
}

/// Central registry for file types and their handlers
///
/// Thread-safe actor-based registry that manages file type definitions and associated handlers
/// (viewers, parsers, editors, converters, validators).
///
/// ## Safety Features
///
/// - Prevents accidental overwrites (must use `allowOverride: true`)
/// - Validates short IDs before registration
/// - Thread-safe via actor isolation
///
/// ## Usage
///
/// Register a file type:
/// ```swift
/// let registry = FileTypeRegistry.shared
///
/// // This succeeds
/// try await registry.register(fileType: myType)
///
/// // This throws FileTypeRegistryError.duplicateShortID
/// try await registry.register(fileType: anotherTypeWithSameShortID)
///
/// // This succeeds (explicit override)
/// try await registry.register(fileType: updatedType, allowOverride: true)
/// ```
public actor FileTypeRegistry {
    /// Shared singleton instance
    public static let shared = FileTypeRegistry()
    
    // MARK: - Storage
    
    /// File types indexed by short ID (primary key)
    private var fileTypesByShortID: [String: FileTypeDefinition] = [:]
    
    /// File types indexed by UTI identifier (secondary key)
    private var fileTypesByUTI: [String: FileTypeDefinition] = [:]
    
    /// File types indexed by extension
    private var fileTypesByExtension: [String: [FileTypeDefinition]] = [:]
    
    // TODO: Handler storage (will be added in next phase)
    // private var viewers: [String: [any FileViewer]] = [:]
    // private var parsers: [String: any FileParser] = [:]
    // etc.
    
    private init() {}
    
    // MARK: - File Type Registration
    
    /// Register a file type
    ///
    /// - Parameters:
    ///   - fileType: File type definition to register
    ///   - allowOverride: If true, replaces existing registration. If false, throws error on duplicate.
    /// - Throws: `FileTypeRegistryError` if duplicate exists and allowOverride is false
    public func register(
        fileType: FileTypeDefinition,
        allowOverride: Bool = false
    ) throws {
        // Validate short ID format
        try validateShortID(fileType.shortID)
        
        // Check for duplicates
        if !allowOverride {
            if fileTypesByShortID[fileType.shortID] != nil {
                throw FileTypeRegistryError.duplicateShortID(fileType.shortID)
            }
            
            if fileTypesByUTI[fileType.uti.identifier] != nil {
                throw FileTypeRegistryError.duplicateUTI(fileType.uti.identifier)
            }
        }
        
        // Remove old registrations if overriding
        if allowOverride {
            removeFileType(shortID: fileType.shortID)
            removeFileType(uti: fileType.uti.identifier)
        }
        
        // Register by short ID (primary index)
        fileTypesByShortID[fileType.shortID] = fileType
        
        // Register by UTI (secondary index)
        fileTypesByUTI[fileType.uti.identifier] = fileType
        
        // Register by extensions
        for ext in fileType.extensions {
            if fileTypesByExtension[ext] == nil {
                fileTypesByExtension[ext] = []
            }
            fileTypesByExtension[ext]?.append(fileType)
        }
    }
    
    /// Register multiple file types
    ///
    /// - Parameters:
    ///   - fileTypes: Array of file type definitions
    ///   - allowOverride: If true, replaces existing registrations
    /// - Throws: `FileTypeRegistryError` if any duplicate exists and allowOverride is false
    public func register(
        fileTypes: [FileTypeDefinition],
        allowOverride: Bool = false
    ) throws {
        for fileType in fileTypes {
            try register(fileType: fileType, allowOverride: allowOverride)
        }
    }
    
    /// Unregister a file type by short ID
    ///
    /// - Parameter shortID: Short identifier of file type to remove
    /// - Returns: true if file type was found and removed
    @discardableResult
    public func unregister(shortID: String) -> Bool {
        guard let fileType = fileTypesByShortID[shortID] else {
            return false
        }
        
        removeFileType(shortID: shortID)
        removeFileType(uti: fileType.uti.identifier)
        
        return true
    }
    
    // MARK: - File Type Lookup
    
    /// Get file type by short ID (primary lookup)
    ///
    /// - Parameter shortID: Short identifier (3-8 chars)
    /// - Returns: File type definition if found
    public func fileType(for shortID: String) -> FileTypeDefinition? {
        fileTypesByShortID[shortID]
    }
    
    /// Get file type by UTI
    ///
    /// - Parameter uti: Uniform Type Identifier
    /// - Returns: File type definition if found
    public func fileType(for uti: UTI) -> FileTypeDefinition? {
        fileTypesByUTI[uti.identifier]
    }
    
    /// Get all file types for an extension
    ///
    /// - Parameter extension: File extension (without dot)
    /// - Returns: Array of matching file types (may be empty)
    public func fileTypes(for extension: String) -> [FileTypeDefinition] {
        let normalized = `extension`.lowercased()
        return fileTypesByExtension[normalized] ?? []
    }
    
    /// Get all file types conforming to a base UTI
    ///
    /// - Parameter baseUTI: Base UTI to check conformance against
    /// - Returns: Array of file types that conform to the base UTI
    public func fileTypes(conformingTo baseUTI: UTI) -> [FileTypeDefinition] {
        fileTypesByUTI.values.filter { $0.uti.conforms(to: baseUTI) }
    }
    
    /// Get all registered file types
    ///
    /// - Returns: Array of all file type definitions
    public func allFileTypes() -> [FileTypeDefinition] {
        Array(fileTypesByShortID.values)
    }
    
    /// Get UTI from short ID
    ///
    /// - Parameter shortID: Short identifier
    /// - Returns: Full UTI if file type is registered
    public func uti(for shortID: String) -> UTI? {
        fileTypesByShortID[shortID]?.uti
    }
    
    /// Get short ID from UTI
    ///
    /// - Parameter uti: Uniform Type Identifier
    /// - Returns: Short ID if file type is registered
    public func shortID(for uti: UTI) -> String? {
        fileTypesByUTI[uti.identifier]?.shortID
    }
    
    /// Check if file type is registered
    ///
    /// - Parameter shortID: Short identifier to check
    /// - Returns: true if registered
    public func isRegistered(shortID: String) -> Bool {
        fileTypesByShortID[shortID] != nil
    }
    
    /// Check if UTI is registered
    ///
    /// - Parameter uti: UTI to check
    /// - Returns: true if registered
    public func isRegistered(uti: UTI) -> Bool {
        fileTypesByUTI[uti.identifier] != nil
    }
    
    // MARK: - Handler Registration
    
    /// Viewers indexed by UTI identifier
    private var viewersByUTI: [String: [(viewer: any FileViewer, priority: Int)]] = [:]
    
    /// Parsers indexed by UTI identifier
    private var parsersByUTI: [String: any FileParser] = [:]
    
    /// Editors indexed by UTI identifier
    private var editorsByUTI: [String: any FileEditor] = [:]
    
    /// Converters indexed by source->target UTI pair
    private var converters: [String: any FileConverter] = [:]
    
    /// Validators indexed by UTI identifier
    private var validatorsByUTI: [String: any FileValidator] = [:]
    
    /// Register a viewer for a UTI
    ///
    /// - Parameters:
    ///   - viewer: Viewer implementation
    ///   - uti: UTI to register for
    ///   - priority: Priority (higher = preferred, default 100)
    ///   - allowOverride: Allow replacing existing viewer
    /// - Throws: FileTypeRegistryError if duplicate and not allowing override
    public func registerViewer(
        _ viewer: any FileViewer,
        for uti: UTI,
        priority: Int = 100,
        allowOverride: Bool = false
    ) throws {
        let key = uti.identifier
        
        if !allowOverride {
            // Check if viewer with same ID already registered
            if let existing = viewersByUTI[key]?.first(where: { $0.viewer.viewerID == viewer.viewerID }) {
                throw FileTypeRegistryError.duplicateHandler(
                    handlerType: "Viewer '\(viewer.viewerID)'",
                    uti: key
                )
            }
        }
        
        // Remove existing if override
        if allowOverride {
            viewersByUTI[key]?.removeAll { $0.viewer.viewerID == viewer.viewerID }
        }
        
        // Add viewer
        if viewersByUTI[key] == nil {
            viewersByUTI[key] = []
        }
        viewersByUTI[key]?.append((viewer: viewer, priority: priority))
        
        // Sort by priority (highest first)
        viewersByUTI[key]?.sort { $0.priority > $1.priority }
    }
    
    /// Register a parser for a UTI
    ///
    /// - Parameters:
    ///   - parser: Parser implementation
    ///   - uti: UTI to register for
    ///   - allowOverride: Allow replacing existing parser
    /// - Throws: FileTypeRegistryError if duplicate and not allowing override
    public func registerParser(
        _ parser: any FileParser,
        for uti: UTI,
        allowOverride: Bool = false
    ) throws {
        let key = uti.identifier
        
        if !allowOverride && parsersByUTI[key] != nil {
            throw FileTypeRegistryError.duplicateHandler(
                handlerType: "Parser",
                uti: key
            )
        }
        
        parsersByUTI[key] = parser
    }
    
    /// Register an editor for a UTI
    ///
    /// - Parameters:
    ///   - editor: Editor implementation
    ///   - uti: UTI to register for
    ///   - allowOverride: Allow replacing existing editor
    /// - Throws: FileTypeRegistryError if duplicate and not allowing override
    public func registerEditor(
        _ editor: any FileEditor,
        for uti: UTI,
        allowOverride: Bool = false
    ) throws {
        let key = uti.identifier
        
        if !allowOverride && editorsByUTI[key] != nil {
            throw FileTypeRegistryError.duplicateHandler(
                handlerType: "Editor",
                uti: key
            )
        }
        
        editorsByUTI[key] = editor
    }
    
    /// Register a converter between two UTIs
    ///
    /// - Parameters:
    ///   - converter: Converter implementation
    ///   - sourceUTI: Source UTI
    ///   - targetUTI: Target UTI
    ///   - allowOverride: Allow replacing existing converter
    /// - Throws: FileTypeRegistryError if duplicate and not allowing override
    public func registerConverter(
        _ converter: any FileConverter,
        from sourceUTI: UTI,
        to targetUTI: UTI,
        allowOverride: Bool = false
    ) throws {
        let key = "\(sourceUTI.identifier)->\(targetUTI.identifier)"
        
        if !allowOverride && converters[key] != nil {
            throw FileTypeRegistryError.duplicateHandler(
                handlerType: "Converter",
                uti: key
            )
        }
        
        converters[key] = converter
    }
    
    /// Register a validator for a UTI
    ///
    /// - Parameters:
    ///   - validator: Validator implementation
    ///   - uti: UTI to register for
    ///   - allowOverride: Allow replacing existing validator
    /// - Throws: FileTypeRegistryError if duplicate and not allowing override
    public func registerValidator(
        _ validator: any FileValidator,
        for uti: UTI,
        allowOverride: Bool = false
    ) throws {
        let key = uti.identifier
        
        if !allowOverride && validatorsByUTI[key] != nil {
            throw FileTypeRegistryError.duplicateHandler(
                handlerType: "Validator",
                uti: key
            )
        }
        
        validatorsByUTI[key] = validator
    }
    
    // MARK: - Handler Lookup
    
    /// Get best viewer for a UTI (highest priority)
    ///
    /// Checks conformance hierarchy - if no viewer for specific UTI,
    /// checks parent types.
    ///
    /// - Parameter uti: UTI to get viewer for
    /// - Returns: Viewer if found
    public func viewer(for uti: UTI) -> (any FileViewer)? {
        // Check direct match first
        if let viewers = viewersByUTI[uti.identifier], let first = viewers.first {
            return first.viewer
        }
        
        // Check conforming types
        for parentUTI in uti.conformsTo {
            if let viewer = viewer(for: parentUTI) {
                return viewer
            }
        }
        
        return nil
    }
    
    /// Get all viewers for a UTI (sorted by priority)
    ///
    /// - Parameter uti: UTI to get viewers for
    /// - Returns: Array of viewers
    public func allViewers(for uti: UTI) -> [any FileViewer] {
        var result: [any FileViewer] = []
        
        // Get direct viewers
        if let viewers = viewersByUTI[uti.identifier] {
            result.append(contentsOf: viewers.map(\.viewer))
        }
        
        // Get viewers for conforming types
        for parentUTI in uti.conformsTo {
            result.append(contentsOf: allViewers(for: parentUTI))
        }
        
        return result
    }
    
    /// Get parser for a UTI
    ///
    /// - Parameter uti: UTI to get parser for
    /// - Returns: Parser if found
    public func parser(for uti: UTI) -> (any FileParser)? {
        // Check direct match
        if let parser = parsersByUTI[uti.identifier] {
            return parser
        }
        
        // Check conforming types
        for parentUTI in uti.conformsTo {
            if let parser = parser(for: parentUTI) {
                return parser
            }
        }
        
        return nil
    }
    
    /// Get editor for a UTI
    ///
    /// - Parameter uti: UTI to get editor for
    /// - Returns: Editor if found
    public func editor(for uti: UTI) -> (any FileEditor)? {
        // Check direct match
        if let editor = editorsByUTI[uti.identifier] {
            return editor
        }
        
        // Check conforming types
        for parentUTI in uti.conformsTo {
            if let editor = editor(for: parentUTI) {
                return editor
            }
        }
        
        return nil
    }
    
    /// Get converter from one UTI to another
    ///
    /// - Parameters:
    ///   - sourceUTI: Source UTI
    ///   - targetUTI: Target UTI
    /// - Returns: Converter if found
    public func converter(from sourceUTI: UTI, to targetUTI: UTI) -> (any FileConverter)? {
        let key = "\(sourceUTI.identifier)->\(targetUTI.identifier)"
        return converters[key]
    }
    
    /// Get validator for a UTI
    ///
    /// - Parameter uti: UTI to get validator for
    /// - Returns: Validator if found
    public func validator(for uti: UTI) -> (any FileValidator)? {
        // Check direct match
        if let validator = validatorsByUTI[uti.identifier] {
            return validator
        }
        
        // Check conforming types
        for parentUTI in uti.conformsTo {
            if let validator = validator(for: parentUTI) {
                return validator
            }
        }
        
        return nil
    }

    
    // MARK: - Statistics
    
    /// Get registration statistics
    public func statistics() -> RegistryStatistics {
        RegistryStatistics(
            totalFileTypes: fileTypesByShortID.count,
            totalExtensions: fileTypesByExtension.count,
            averageExtensionsPerType: Double(fileTypesByExtension.values.map(\.count).reduce(0, +)) / Double(max(1, fileTypesByExtension.count))
        )
    }
    
    // MARK: - Private Helpers
    
    private func validateShortID(_ shortID: String) throws {
        guard shortID.count >= 3 && shortID.count <= 8 else {
            throw FileTypeRegistryError.invalidShortID(shortID)
        }
        
        guard shortID.allSatisfy({ $0.isLowercase || $0.isNumber }) else {
            throw FileTypeRegistryError.invalidShortID(shortID)
        }
    }
    
    private func removeFileType(shortID: String) {
        guard let fileType = fileTypesByShortID.removeValue(forKey: shortID) else {
            return
        }
        
        // Remove from extension index
        for ext in fileType.extensions {
            fileTypesByExtension[ext]?.removeAll { $0.shortID == shortID }
            if fileTypesByExtension[ext]?.isEmpty == true {
                fileTypesByExtension.removeValue(forKey: ext)
            }
        }
    }
    
    private func removeFileType(uti: String) {
        fileTypesByUTI.removeValue(forKey: uti)
    }
}

/// Registry statistics
public struct RegistryStatistics: Sendable {
    public let totalFileTypes: Int
    public let totalExtensions: Int
    public let averageExtensionsPerType: Double
}

// MARK: - Convenience Extensions

public extension FileTypeRegistry {
    /// Register file type with error handling for development
    ///
    /// Provides clear error messages when registration fails
    @available(*, deprecated, message: "Use register(fileType:allowOverride:) instead")
    func registerWithLogging(fileType: FileTypeDefinition, allowOverride: Bool = false) {
        do {
            try register(fileType: fileType, allowOverride: allowOverride)
            print("✅ Registered file type: \(fileType.shortID) (\(fileType.displayName))")
        } catch {
            print("❌ Failed to register file type: \(error.localizedDescription)")
        }
    }
}
