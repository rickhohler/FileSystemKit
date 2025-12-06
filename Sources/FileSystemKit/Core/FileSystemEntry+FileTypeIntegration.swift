//
//  FileSystemEntry+FileTypeIntegration.swift
//  FileSystemKit
//
//  FileSystemEntry extensions for new file type system integration
//

import Foundation
import SwiftUI

// MARK: - FileSystemEntryMetadata Extensions

public extension FileSystemEntryMetadata {
    /// Get full file type definition from registry
    ///
    /// - Returns: File type definition if fileTypeID is set and registered
    func fileTypeDefinition() async -> FileTypeDefinition? {
        guard let id = fileTypeID else { return nil }
        return await FileTypeRegistry.shared.fileType(for: id)
    }
    
    /// Get UTI from file type ID
    ///
    /// - Returns: UTI if fileTypeID is set and registered
    func uti() async -> UTI? {
        guard let id = fileTypeID else { return nil }
        return await FileTypeRegistry.shared.uti(for: id)
    }
    
    /// Get default viewer for this file's type
    ///
    /// - Returns: Viewer if one is registered for this file type
    func defaultViewer() async -> (any FileViewer)? {
        guard let uti = await uti() else { return nil }
        return await FileTypeRegistry.shared.viewer(for: uti)
    }
    
    /// Get all available viewers for this file's type
    ///
    /// - Returns: Array of viewers sorted by priority
    func availableViewers() async -> [any FileViewer] {
        guard let uti = await uti() else { return [] }
        return await FileTypeRegistry.shared.allViewers(for: uti)
    }
    
    /// Get parser for this file's type
    ///
    /// - Returns: Parser if one is registered for this file type
    func parser() async -> (any FileParser)? {
        guard let uti = await uti() else { return nil }
        return await FileTypeRegistry.shared.parser(for: uti)
    }
    
    /// Get editor for this file's type
    ///
    /// - Returns: Editor if one is registered for this file type
    func editor() async -> (any FileEditor)? {
        guard let uti = await uti() else { return nil }
        return await FileTypeRegistry.shared.editor(for: uti)
    }
    
    /// Get validator for this file's type
    ///
    /// - Returns: Validator if one is registered for this file type
    func validator() async -> (any FileValidator)? {
        guard let uti = await uti() else { return nil }
        return await FileTypeRegistry.shared.validator(for: uti)
    }
    
    /// Check if file can be converted to target type
    ///
    /// - Parameter targetUTI: Target UTI
    /// - Returns: true if converter is registered
    func canConvert(to targetUTI: UTI) async -> Bool {
        guard let sourceUTI = await uti() else { return false }
        let converter = await FileTypeRegistry.shared.converter(from: sourceUTI, to: targetUTI)
        return converter != nil
    }
    
    /// Get file type capabilities
    ///
    /// - Returns: Capabilities if file type is registered
    func capabilities() async -> FileTypeCapabilities? {
        guard let definition = await fileTypeDefinition() else { return nil }
        return definition.capabilities
    }
}

// MARK: - FileSystemEntry Extensions

public extension FileSystemEntry {
    /// Detect and assign file type using detection engine
    ///
    /// Reads file data and runs detection, then sets fileTypeID in metadata.
    ///
    /// - Parameter diskData: Disk data to read file from
    /// - Returns: Detection result if successful
    /// - Throws: File I/O errors
    @discardableResult
    func detectFileType(from diskData: RawDiskData) async throws -> FileTypeDetectionEngine.DetectionResult? {
        // Read file data (use small sample for detection)
        guard let location = metadata.location else {
            return nil
        }
        
        let sampleSize = min(512, location.length)
        guard sampleSize > 0 else { return nil }
        
        let data = try diskData.readData(at: location.offset, length: sampleSize)
        
        // Get extension
        let ext = (name as NSString).pathExtension
        let fileExtension: String? = ext.isEmpty ? nil : ext
        
        // Run detection
        let detection = await FileTypeDetectionEngine.shared.detect(
            data: data,
            extension: fileExtension,
            hint: nil
        )
        
        // Assign fileTypeID if detected
        if let result = detection {
            metadata.fileTypeID = result.fileType.shortID
        }
        
        return detection
    }
    
    /// Create view for file using registered viewer
    ///
    /// - Parameter diskData: Disk data to read file from
    /// - Returns: SwiftUI view if viewer is available
    /// - Throws: File I/O errors
    @MainActor
    func createView(from diskData: RawDiskData) async throws -> AnyView? {
        guard let viewer = await metadata.defaultViewer() else {
            return nil
        }
        
        let data = try readData(from: diskData)
        
        let handlerMetadata = FileHandlerMetadata(
            title: name,
            author: nil,
            creationDate: modificationDate,
            modificationDate: modificationDate,
            keywords: [],
            customFields: metadata.attributes.compactMapValues { "\($0)" }
        )
        
        return viewer.createView(for: data, metadata: handlerMetadata)
    }
    
    /// Parse file content using registered parser
    ///
    /// - Parameter diskData: Disk data to read file from
    /// - Returns: Parsed content (type-erased)
    /// - Throws: Parser or I/O errors
    func parseContent(from diskData: RawDiskData) async throws -> Any? {
        guard let parser = await metadata.parser() else {
            return nil
        }
        
        let _ = try readData(from: diskData)
        
        // Since parser has associated type, we can't directly call parse
        // Caller must cast parser to specific type and call parse
        // This is a limitation of Swift's type system with existentials
        
        return parser  // Return parser for caller to use
    }
    
    /// Convert file to another format
    ///
    /// - Parameters:
    ///   - targetUTI: Target UTI
    ///   - diskData: Disk data to read file from
    /// - Returns: Converted data if converter is available
    /// - Throws: Conversion or I/O errors
    func convert(to targetUTI: UTI, from diskData: RawDiskData) async throws -> Data? {
        guard let sourceUTI = await metadata.uti() else { return nil }
        
        guard await FileTypeRegistry.shared.converter(
            from: sourceUTI,
            to: targetUTI
        ) != nil else {
            return nil
        }
        
        let _ = try readData(from: diskData)
        
        // Similar issue with associated types - return converter for caller
        return nil  // Placeholder - needs type-specific handling
    }
    
    /// Validate file integrity
    ///
    /// - Parameter diskData: Disk data to read file from
    /// - Returns: Validation result if validator is available
    /// - Throws: Validation or I/O errors
    func validate(from diskData: RawDiskData) async throws -> FileValidationResult? {
        guard let validator = await metadata.validator() else {
            return nil
        }
        
        let data = try readData(from: diskData)
        return try await validator.validate(data)
    }
    
    /// Quick validate (magic numbers only)
    ///
    /// - Parameter diskData: Disk data to read file from
    /// - Returns: true if file appears valid
    /// - Throws: I/O errors
    func quickValidate(from diskData: RawDiskData) async throws -> Bool {
        guard let validator = await metadata.validator() else {
            return true  // No validator means can't validate (assume OK)
        }
        
        // Read small sample for quick validation
        guard let location = metadata.location else {
            return true
        }
        
        let sampleSize = min(512, location.length)
        guard sampleSize > 0 else { return true }
        
        let data = try diskData.readData(at: location.offset, length: sampleSize)
        return await validator.quickValidate(data)
    }
}

// MARK: - FileSystemFolder Extensions

public extension FileSystemFolder {
    /// Detect file types for all files in this folder
    ///
    /// - Parameter diskData: Disk data to read files from
    /// - Returns: Number of files successfully detected
    func detectAllFileTypes(from diskData: RawDiskData) async -> Int {
        var count = 0
        
        for file in getFiles() {
            if let _ = try? await file.detectFileType(from: diskData) {
                count += 1
            }
        }
        
        // Recursively process subfolders
        for subfolder in getFolders() {
            count += await subfolder.detectAllFileTypes(from: diskData)
        }
        
        return count
    }
    
    /// Get all files of a specific type
    ///
    /// - Parameter uti: UTI to filter by
    /// - Returns: Files matching the UTI
    func files(ofType uti: UTI) async -> [FileSystemEntry] {
        var result: [FileSystemEntry] = []
        
        for file in getFiles() {
            if let fileUTI = await file.metadata.uti(),
               fileUTI.conforms(to: uti) {
                result.append(file)
            }
        }
        
        // Recursively search subfolders
        for subfolder in getFolders() {
            result.append(contentsOf: await subfolder.files(ofType: uti))
        }
        
        return result
    }
    
    /// Get all files with a specific capability
    ///
    /// - Parameter capability: Capability to check for
    /// - Returns: Files with this capability
    func files(withCapability capability: FileTypeCapabilities) async -> [FileSystemEntry] {
        var result: [FileSystemEntry] = []
        
        for file in getFiles() {
            if let capabilities = await file.metadata.capabilities(),
               capabilities.contains(capability) {
                result.append(file)
            }
        }
        
        // Recursively search subfolders
        for subfolder in getFolders() {
            result.append(contentsOf: await subfolder.files(withCapability: capability))
        }
        
        return result
    }
}
