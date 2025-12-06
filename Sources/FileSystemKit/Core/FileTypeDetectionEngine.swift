//
//  FileTypeDetectionEngine.swift
//  FileSystemKit
//
//  Multi-strategy file type detection engine
//

import Foundation

/// File type detection engine using multiple strategies
///
/// Detects file types using a layered approach:
/// 1. Magic number/signature matching (highest confidence)
/// 2. File extension matching (medium confidence)
/// 3. UTI hint (user-provided guidance)
///
/// ## Usage
///
/// ```swift
/// let engine = FileTypeDetectionEngine.shared
/// let data = try Data(contentsOf: fileURL)
///
/// if let result = await engine.detect(
///     data: data,
///     extension: "bas",
///     hint: nil
/// ) {
///     print("Detected: \(result.uti.identifier)")
///     print("Confidence: \(result.confidence)")
///     print("Strategy: \(result.strategy)")
/// }
/// ```
public actor FileTypeDetectionEngine {
    /// Shared singleton instance
    public static let shared = FileTypeDetectionEngine()
    
    /// Detection strategy used
    public enum DetectionStrategy: String, Sendable {
        case magicNumber      // Content-based signature (highest confidence)
        case `extension`      // Extension-based (medium confidence)
        case heuristic        // Pattern analysis (low confidence)
        case userHint         // User-provided hint
    }
    
    /// Detection result
    public struct DetectionResult: Sendable {
        /// Detected UTI
        public let uti: UTI
        
        /// File type definition
        public let fileType: FileTypeDefinition
        
        /// Confidence score (0.0-1.0)
        public let confidence: Float
        
        /// Strategy used for detection
        public let strategy: DetectionStrategy
        
        /// Additional metadata from detection
        public let metadata: [String: String]
        
        public init(
            uti: UTI,
            fileType: FileTypeDefinition,
            confidence: Float,
            strategy: DetectionStrategy,
            metadata: [String: String] = [:]
        ) {
            self.uti = uti
            self.fileType = fileType
            self.confidence = confidence
            self.strategy = strategy
            self.metadata = metadata
        }
    }
    
    private init() {}
    
    /// Detect file type using all available strategies
    ///
    /// Detection order:
    /// 1. User hint (if provided and valid)
    /// 2. Magic number matching
    /// 3. Extension matching
    /// 4. Heuristic analysis (future)
    ///
    /// - Parameters:
    ///   - data: File content
    ///   - extension: File extension (optional)
    ///   - hint: User-provided UTI hint (optional)
    /// - Returns: Detection result if successful
    public func detect(
        data: Data,
        extension fileExtension: String? = nil,
        hint: UTI? = nil
    ) async -> DetectionResult? {
        let registry = FileTypeRegistry.shared
        
        // Strategy 1: User hint (if provided and registered)
        if let hint = hint {
            if let fileType = await registry.fileType(for: hint) {
                return DetectionResult(
                    uti: hint,
                    fileType: fileType,
                    confidence: 0.9,  // High but not perfect (user could be wrong)
                    strategy: .userHint
                )
            }
        }
        
        // Strategy 2: Magic number matching (highest confidence)
        if let result = await detectByMagicNumber(data: data) {
            return result
        }
        
        // Strategy 3: Extension matching
        if let ext = fileExtension?.lowercased(),
           let result = await detectByExtension(extension: ext, data: data) {
            return result
        }
        
        // Strategy 4: Heuristic analysis (future implementation)
        // Could add content analysis, statistical methods, etc.
        
        return nil
    }
    
    /// Detect file type by magic number/signature
    ///
    /// Checks all registered file types with magic numbers,
    /// prioritized by detection priority.
    ///
    /// - Parameter data: File content
    /// - Returns: Detection result if match found
    private func detectByMagicNumber(data: Data) async -> DetectionResult? {
        let registry = FileTypeRegistry.shared
        let allTypes = await registry.allFileTypes()
        
        // Sort by priority (highest first)
        let sortedTypes = allTypes.sorted { $0.priority > $1.priority }
        
        for fileType in sortedTypes {
            guard !fileType.magicNumbers.isEmpty else { continue }
            
            // Check each magic pattern
            for pattern in fileType.magicNumbers {
                if pattern.matches(data: data) {
                    return DetectionResult(
                        uti: fileType.uti,
                        fileType: fileType,
                        confidence: pattern.confidence,
                        strategy: .magicNumber,
                        metadata: ["pattern": "signature_match"]
                    )
                }
            }
        }
        
        return nil
    }
    
    /// Detect file type by extension
    ///
    /// If multiple types match the extension, prefer:
    /// 1. Types with magic numbers that match the data
    /// 2. Types with higher priority
    ///
    /// - Parameters:
    ///   - extension: File extension (without dot)
    ///   - data: File content (for disambiguation)
    /// - Returns: Detection result if match found
    private func detectByExtension(extension ext: String, data: Data) async -> DetectionResult? {
        let registry = FileTypeRegistry.shared
        let candidates = await registry.fileTypes(for: ext)
        
        guard !candidates.isEmpty else {
            return nil
        }
        
        // If only one candidate, return it
        if candidates.count == 1 {
            let fileType = candidates[0]
            return DetectionResult(
                uti: fileType.uti,
                fileType: fileType,
                confidence: 0.7,  // Medium confidence (extension only)
                strategy: .extension,
                metadata: ["extension": ext]
            )
        }
        
        // Multiple candidates - try to disambiguate
        
        // 1. Check if any have matching magic numbers
        for fileType in candidates {
            for pattern in fileType.magicNumbers {
                if pattern.matches(data: data) {
                    return DetectionResult(
                        uti: fileType.uti,
                        fileType: fileType,
                        confidence: 0.9,  // High confidence (extension + magic)
                        strategy: .magicNumber,
                        metadata: ["extension": ext, "disambiguated": "true"]
                    )
                }
            }
        }
        
        // 2. Use highest priority type
        let sorted = candidates.sorted { $0.priority > $1.priority }
        let fileType = sorted[0]
        
        return DetectionResult(
            uti: fileType.uti,
            fileType: fileType,
            confidence: 0.6,  // Lower confidence (ambiguous extension)
            strategy: .extension,
            metadata: ["extension": ext, "ambiguous": "true", "candidates": "\(candidates.count)"]
        )
    }
}

// MARK: - Convenience Methods

public extension FileTypeDetectionEngine {
    /// Detect file type from URL
    ///
    /// Reads file content and extracts extension automatically
    ///
    /// - Parameters:
    ///   - url: File URL
    ///   - hint: Optional UTI hint
    /// - Returns: Detection result if successful
    /// - Throws: File I/O errors
    func detect(url: URL, hint: UTI? = nil) async throws -> DetectionResult? {
        let data = try Data(contentsOf: url)
        let ext = url.pathExtension
        
        return await detect(
            data: data,
            extension: ext.isEmpty ? nil : ext,
            hint: hint
        )
    }
    
    /// Quick detect (magic number only, no extension fallback)
    ///
    /// Faster than full detection when extension not available
    ///
    /// - Parameter data: File content
    /// - Returns: Detection result if magic number found
    func quickDetect(data: Data) async -> DetectionResult? {
        await detectByMagicNumber(data: data)
    }
}
