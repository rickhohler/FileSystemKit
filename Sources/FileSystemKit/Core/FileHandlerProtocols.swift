//
//  FileHandlerProtocols.swift
//  FileSystemKit
//
//  Protocol definitions for file type handlers
//  Clients implement these protocols to register custom handlers
//

import Foundation
import SwiftUI

// MARK: - File Viewer Protocol

/// Protocol for viewing file content
///
/// Implement this protocol to create a custom file viewer.
///
/// ## Example
///
/// ```swift
/// struct MyBASICViewer: FileViewer {
///     var viewerID: String { "my-basic-viewer" }
///     var viewerName: String { "BASIC Program Viewer" }
///     var viewerIcon: String { "doc.text.fill" }
///     var supportedUTIs: [UTI] { [.basicProgram] }
///     var priority: Int { 100 }
///     var isReadOnly: Bool { true }
///     var features: ViewerFeatures { [.search, .export] }
///     
///     func canView(fileType: FileTypeDefinition, data: Data) -> Bool {
///         fileType.uti.conforms(to: .basicProgram)
///     }
///     
///     @MainActor
///     func createView(for data: Data, metadata: FileMetadata) -> AnyView {
///         AnyView(BASICProgramView(data: data))
///     }
/// }
///
/// // Register viewer
/// try await FileTypeRegistry.shared.registerViewer(
///     MyBASICViewer(),
///     for: .basicProgram,
///     priority: 100
/// )
/// ```
public protocol FileViewer: Sendable {
    /// Unique identifier for this viewer
    var viewerID: String { get }
    
    /// Display name shown in UI
    var viewerName: String { get }
    
    /// Icon (SF Symbol name)
    var viewerIcon: String { get }
    
    /// UTIs this viewer can handle
    var supportedUTIs: [UTI] { get }
    
    /// Priority (higher = preferred when multiple viewers available)
    var priority: Int { get }
    
    /// Whether this viewer is read-only
    var isReadOnly: Bool { get }
    
    /// Supported features
    var features: ViewerFeatures { get }
    
    /// Check if can view specific file
    ///
    /// - Parameters:
    ///   - fileType: File type definition
    ///   - data: File data
    /// - Returns: true if this viewer can handle the file
    func canView(fileType: FileTypeDefinition, data: Data) -> Bool
    
    /// Create view for file
    ///
    /// - Parameters:
    ///   - data: File content
    ///   - metadata: File metadata
    /// - Returns: SwiftUI view
    @MainActor
    func createView(for data: Data, metadata: FileHandlerMetadata) -> AnyView
}

/// Viewer feature capabilities
public struct ViewerFeatures: OptionSet, Sendable {
    public let rawValue: UInt
    
    public init(rawValue: UInt) {
        self.rawValue = rawValue
    }
    
    public static let zoom         = ViewerFeatures(rawValue: 1 << 0)
    public static let search       = ViewerFeatures(rawValue: 1 << 1)
    public static let export       = ViewerFeatures(rawValue: 1 << 2)
    public static let print        = ViewerFeatures(rawValue: 1 << 3)
    public static let annotations  = ViewerFeatures(rawValue: 1 << 4)
    public static let livePreview  = ViewerFeatures(rawValue: 1 << 5)
}

// MARK: - File Parser Protocol

/// Protocol for parsing file content into structured data
///
/// Implement this protocol to create a custom file parser.
///
/// ## Example
///
/// ```swift
/// struct ApplesoftBASICParser: FileParser {
///     typealias Output = BASICProgram
///     
///     var parserID: String { "applesoft-parser" }
///     var supportedUTIs: [UTI] { [UTI(identifier: "com.apple.basic.applesoft")] }
///     
///     func parse(_ data: Data) async throws -> BASICProgram {
///         // Parse tokenized BASIC
///         let program = try parseTokenizedBASIC(data)
///         return program
///     }
///     
///     func parse(url: URL) async throws -> BASICProgram {
///         let data = try Data(contentsOf: url)
///         return try await parse(data)
///     }
///     
///     func validate(_ data: Data) async throws -> ValidationResult {
///         // Quick validation
///         guard data.count > 2 else {
///             return ValidationResult(isValid: false, errors: [.invalidFormat], warnings: [])
///         }
///         return ValidationResult(isValid: true, errors: [], warnings: [])
///     }
/// }
///
/// // Register parser
/// try await FileTypeRegistry.shared.registerParser(
///     ApplesoftBASICParser(),
///     for: UTI(identifier: "com.apple.basic.applesoft")
/// )
/// ```
public protocol FileParser: Sendable {
    /// Unique identifier
    var parserID: String { get }
    
    /// UTIs this parser can handle
    var supportedUTIs: [UTI] { get }
    
    /// Output type produced by this parser
    associatedtype Output: Sendable
    
    /// Parse file data
    ///
    /// - Parameter data: Raw file data
    /// - Returns: Parsed output
    /// - Throws: Parser errors
    func parse(_ data: Data) async throws -> Output
    
    /// Parse from URL
    ///
    /// - Parameter url: File URL
    /// - Returns: Parsed output
    /// - Throws: Parser errors
    func parse(url: URL) async throws -> Output
    
    /// Validate without full parse
    ///
    /// - Parameter data: File data to validate
    /// - Returns: Validation result
    /// - Throws: Validation errors
    func validate(_ data: Data) async throws -> FileValidationResult
}

/// Result of file validation
public struct FileValidationResult: Sendable {
    public let isValid: Bool
    public let errors: [FileValidationError]
    public let warnings: [FileValidationWarning]
    
    public init(isValid: Bool, errors: [FileValidationError], warnings: [FileValidationWarning]) {
        self.isValid = isValid
        self.errors = errors
        self.warnings = warnings
    }
}

/// File validation error
public enum FileValidationError: Error, Sendable {
    case invalidFormat
    case corruptedData
    case unsupportedVersion
    case invalidChecksum
    case custom(String)
}

/// File validation warning
public struct FileValidationWarning: Sendable {
    public let message: String
    public let location: Int?
    
    public init(message: String, location: Int? = nil) {
        self.message = message
        self.location = location
    }
}

// MARK: - File Editor Protocol

/// Protocol for editing file content
///
/// Implement this protocol to create a custom file editor.
///
/// ## Example
///
/// ```swift
/// struct BASICEditor: FileEditor {
///     typealias EditOperation = BASICEditOperation
///     
///     var editorID: String { "basic-editor" }
///     var editorName: String { "BASIC Editor" }
///     var supportedUTIs: [UTI] { [.basicProgram] }
///     var supportsUndo: Bool { true }
///     var supportsAutoSave: Bool { true }
///     var supportsCollaboration: Bool { false }
///     
///     @MainActor
///     func createEditor(for data: Data, metadata: FileMetadata) -> AnyView {
///         AnyView(BASICEditorView(data: data))
///     }
///     
///     func apply(operation: EditOperation, to data: Data) async throws -> Data {
///         // Apply edit operation
///         var mutableData = data
///         // ... perform edit
///         return mutableData
///     }
/// }
///
/// // Register editor
/// try await FileTypeRegistry.shared.registerEditor(
///     BASICEditor(),
///     for: .basicProgram
/// )
/// ```
public protocol FileEditor: Sendable {
    /// Unique identifier
    var editorID: String { get }
    
    /// Display name
    var editorName: String { get }
    
    /// UTIs this editor can handle
    var supportedUTIs: [UTI] { get }
    
    /// Edit operation type
    associatedtype EditOperation: Sendable
    
    /// Create editor view
    ///
    /// - Parameters:
    ///   - data: File content
    ///   - metadata: File metadata
    /// - Returns: SwiftUI view for editing
    @MainActor
    func createEditor(for data: Data, metadata: FileHandlerMetadata) -> AnyView
    
    /// Apply edit operation
    ///
    /// - Parameters:
    ///   - operation: Edit operation to apply
    ///   - data: Current file data
    /// - Returns: Modified file data
    /// - Throws: Edit errors
    func apply(operation: EditOperation, to data: Data) async throws -> Data
    
    /// Whether undo/redo is supported
    var supportsUndo: Bool { get }
    
    /// Whether auto-save is supported
    var supportsAutoSave: Bool { get }
    
    /// Whether collaborative editing is supported
    var supportsCollaboration: Bool { get }
}

// MARK: - File Converter Protocol

/// Protocol for converting between file formats
///
/// Implement this protocol to create a custom file converter.
///
/// ## Example
///
/// ```swift
/// struct BASICToTextConverter: FileConverter {
///     var converterID: String { "basic-to-text" }
///     var sourceUTI: UTI { UTI(identifier: "com.apple.basic.applesoft") }
///     var targetUTI: UTI { .plainText }
///     var converterName: String { "BASIC to Text" }
///     var isLossless: Bool { true }
///     var quality: Float { 1.0 }
///     
///     func canConvert(from data: Data) async -> Bool {
///         data.count > 2  // Basic check
///     }
///     
///     func convert(_ data: Data, options: EmptyOptions) async throws -> Data {
///         // Convert tokenized BASIC to text
///         let program = try parseBASIC(data)
///         let text = program.toText()
///         return text.data(using: .utf8)!
///     }
/// }
///
/// // Register converter
/// try await FileTypeRegistry.shared.registerConverter(
///     BASICToTextConverter(),
///     from: UTI(identifier: "com.apple.basic.applesoft"),
///     to: .plainText
/// )
/// ```
public protocol FileConverter: Sendable {
    /// Unique identifier
    var converterID: String { get }
    
    /// Source UTI
    var sourceUTI: UTI { get }
    
    /// Target UTI
    var targetUTI: UTI { get }
    
    /// Display name
    var converterName: String { get }
    
    /// Conversion options type
    associatedtype Options: Sendable = NoConversionOptions
    
    /// Check if can convert specific data
    ///
    /// - Parameter data: Source data
    /// - Returns: true if conversion is possible
    func canConvert(from data: Data) async -> Bool
    
    /// Perform conversion
    ///
    /// - Parameters:
    ///   - data: Source data
    ///   - options: Conversion options
    /// - Returns: Converted data
    /// - Throws: Conversion errors
    func convert(_ data: Data, options: Options) async throws -> Data
    
    /// Whether conversion is lossless
    var isLossless: Bool { get }
    
    /// Estimated quality (0.0-1.0)
    var quality: Float { get }
}

/// No options for converters that don't need configuration
public struct NoConversionOptions: Sendable {
    public init() {}
}

// MARK: - File Validator Protocol

/// Protocol for validating file integrity
///
/// Implement this protocol to create a custom file validator.
///
/// ## Example
///
/// ```swift
/// struct BASICValidator: FileValidator {
///     var validatorID: String { "basic-validator" }
///     var supportedUTIs: [UTI] { [.basicProgram] }
///     
///     func validate(_ data: Data) async throws -> ValidationResult {
///         // Quick validation
///         guard data.count > 2 else {
///             return ValidationResult(isValid: false, errors: [.invalidFormat], warnings: [])
///         }
///         return ValidationResult(isValid: true, errors: [], warnings: [])
///     }
///     
///     func quickValidate(_ data: Data) async -> Bool {
///         data.count > 2
///     }
///     
///     func deepValidate(_ data: Data) async throws -> DeepValidationResult {
///         // Full structural validation
///         // Check line numbers, tokens, etc.
///         return DeepValidationResult(
///             isValid: true,
///             structuralErrors: [],
///             checksumValid: true,
///             estimatedCorruption: 0.0,
///             repairSuggestions: []
///         )
///     }
/// }
///
/// // Register validator
/// try await FileTypeRegistry.shared.registerValidator(
///     BASICValidator(),
///     for: .basicProgram
/// )
/// ```
public protocol FileValidator: Sendable {
    /// Unique identifier
    var validatorID: String { get }
    
    /// UTIs this validator can handle
    var supportedUTIs: [UTI] { get }
    
    /// Validate file
    ///
    /// - Parameter data: File data
    /// - Returns: Validation result
    /// - Throws: Validation errors
    func validate(_ data: Data) async throws -> FileValidationResult
    
    /// Quick validation (magic numbers only)
    ///
    /// - Parameter data: File data
    /// - Returns: true if appears valid
    func quickValidate(_ data: Data) async -> Bool
    
    /// Deep validation (full structure check)
    ///
    /// - Parameter data: File data
    /// - Returns: Detailed validation result
    /// - Throws: Validation errors
    func deepValidate(_ data: Data) async throws -> DeepValidationResult
}

/// Deep validation result
public struct DeepValidationResult: Sendable {
    public let isValid: Bool
    public let structuralErrors: [StructuralError]
    public let checksumValid: Bool
    public let estimatedCorruption: Float  // 0.0-1.0
    public let repairSuggestions: [RepairSuggestion]
    
    public init(
        isValid: Bool,
        structuralErrors: [StructuralError],
        checksumValid: Bool,
        estimatedCorruption: Float,
        repairSuggestions: [RepairSuggestion]
    ) {
        self.isValid = isValid
        self.structuralErrors = structuralErrors
        self.checksumValid = checksumValid
        self.estimatedCorruption = estimatedCorruption
        self.repairSuggestions = repairSuggestions
    }
}

/// Structural error in file
public struct StructuralError: Sendable {
    public let message: String
    public let location: Int
    public let severity: ErrorSeverity
    
    public init(message: String, location: Int, severity: ErrorSeverity) {
        self.message = message
        self.location = location
        self.severity = severity
    }
}

/// Error severity
public enum ErrorSeverity: String, Sendable {
    case critical
    case error
    case warning
}

/// Repair suggestion
public struct RepairSuggestion: Sendable {
    public let message: String
    public let automated: Bool
    
    public init(message: String, automated: Bool) {
        self.message = message
        self.automated = automated
    }
}

// MARK: - File Handler Metadata

/// Metadata associated with a file for handler use
public struct FileHandlerMetadata: Sendable {
    public var title: String?
    public var author: String?
    public var creationDate: Date?
    public var modificationDate: Date?
    public var keywords: [String]
    public var customFields: [String: String]
    
    public init(
        title: String? = nil,
        author: String? = nil,
        creationDate: Date? = nil,
        modificationDate: Date? = nil,
        keywords: [String] = [],
        customFields: [String: String] = [:]
    ) {
        self.title = title
        self.author = author
        self.creationDate = creationDate
        self.modificationDate = modificationDate
        self.keywords = keywords
        self.customFields = customFields
    }
}
