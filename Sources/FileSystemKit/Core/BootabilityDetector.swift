// FileSystemKit Core Library
// Bootability Detector Protocol and Registry
//
// This file defines the protocol for bootability detection and a registry for managing detectors.
// Vintage-specific implementations register themselves to provide bootability detection for their platforms.

import Foundation

// MARK: - BootabilityDetector Protocol

/// Protocol for bootability detectors that can analyze disk images and determine bootability
///
/// Bootability detectors analyze raw disk data to determine:
/// - Whether a disk is bootable (contains boot code)
/// - Whether a disk requires a system disk to be booted first
/// - Specific boot instructions for the disk
///
/// ## Usage
///
/// ```swift
/// struct MyBootabilityDetector: BootabilityDetector {
///     static var supportedFormats: [FileSystemFormat] { [.appleDOS33, .proDOS] }
///     
///     static func detectBootability(
///         in diskData: RawDiskData,
///         fileSystemFormat: FileSystemFormat?
///     ) -> BootInstructions {
///         // Analyze disk data and return boot instructions
///     }
/// }
///
/// // Register the detector
/// BootabilityDetectorRegistry.shared.register(MyBootabilityDetector.self)
/// ```
public protocol BootabilityDetector: Sendable {
    /// File system formats this detector can handle
    static var supportedFormats: [FileSystemKit.FileSystemFormat] { get }
    
    /// Detect bootability for a disk image
    /// - Parameters:
    ///   - diskData: Raw disk data to analyze
    ///   - fileSystemFormat: Detected file system format (optional, for generating boot instructions)
    /// - Returns: BootInstructions with bootability state and instructions
    static func detectBootability(
        in diskData: RawDiskData,
        fileSystemFormat: FileSystemKit.FileSystemFormat?
    ) -> BootInstructions
}

// MARK: - BootabilityDetectorRegistry

/// Thread-safe registry for bootability detectors
/// Uses NSLock for synchronization to support concurrent access
///
/// ## Usage
///
/// Register a detector:
/// ```swift
/// BootabilityDetectorRegistry.shared.register(AppleIIBootabilityDetector.self)
/// ```
///
/// Find a detector for a file system format:
/// ```swift
/// if let detector = BootabilityDetectorRegistry.shared.findDetector(for: .appleDOS33) {
///     let instructions = detector.detectBootability(in: diskData, fileSystemFormat: .appleDOS33)
/// }
/// ```
public final class BootabilityDetectorRegistry: @unchecked Sendable {
    /// Shared singleton instance (lazy initialization to avoid static initialization order issues)
    // Protected by lock, so marked as nonisolated(unsafe) for concurrency safety
    nonisolated(unsafe) private static var _shared: BootabilityDetectorRegistry?
    nonisolated private static let lock = NSLock()
    
    /// Shared singleton instance (lazy)
    public static var shared: BootabilityDetectorRegistry {
        lock.lock()
        defer { lock.unlock() }
        if _shared == nil {
            _shared = BootabilityDetectorRegistry()
        }
        return _shared!
    }
    
    /// Lock for thread-safe access
    private let lock = NSLock()
    
    /// Registered detectors by file system format
    /// Multiple detectors can be registered for the same format (first match wins)
    private var detectors: [FileSystemFormat: [any BootabilityDetector.Type]] = [:]
    
    /// Registered detectors in order of registration (for priority)
    private var detectorOrder: [any BootabilityDetector.Type] = []
    
    private init() {
        // Private initializer for singleton
    }
    
    /// Register a bootability detector
    /// - Parameter detector: The detector type to register
    /// Thread-safe: Can be called concurrently
    ///
    /// If multiple detectors are registered for the same format, they are tried in registration order.
    public func register(_ detector: any BootabilityDetector.Type) {
        lock.lock()
        defer { lock.unlock() }
        
        // Add to ordered list if not already registered
        if !detectorOrder.contains(where: { type(of: $0) == type(of: detector) }) {
            detectorOrder.append(detector)
        }
        
        // Register for each supported format
        for format in detector.supportedFormats {
            if detectors[format] == nil {
                detectors[format] = []
            }
            // Only add if not already registered for this format
            if !detectors[format]!.contains(where: { type(of: $0) == type(of: detector) }) {
                detectors[format]!.append(detector)
            }
        }
    }
    
    /// Find a detector for a specific file system format
    /// - Parameter format: The file system format
    /// - Returns: The first registered detector for the format, or `nil` if none found
    /// Thread-safe: Can be called concurrently
    public func findDetector(for format: FileSystemFormat) -> (any BootabilityDetector.Type)? {
        lock.lock()
        defer { lock.unlock() }
        
        // Return first detector registered for this format
        return detectors[format]?.first
    }
    
    /// Find all detectors for a specific file system format
    /// - Parameter format: The file system format
    /// - Returns: Array of all registered detectors for the format
    /// Thread-safe: Can be called concurrently
    public func findDetectors(for format: FileSystemFormat) -> [any BootabilityDetector.Type] {
        lock.lock()
        defer { lock.unlock() }
        
        return detectors[format] ?? []
    }
    
    /// Detect bootability using registered detectors
    /// - Parameters:
    ///   - diskData: Raw disk data to analyze
    ///   - fileSystemFormat: Detected file system format (optional)
    /// - Returns: BootInstructions with bootability state and instructions
    /// Thread-safe: Can be called concurrently
    ///
    /// This method tries registered detectors in order until one returns a non-unknown result,
    /// or returns unknown if no detectors are registered or all return unknown.
    public func detectBootability(
        in diskData: RawDiskData,
        fileSystemFormat: FileSystemFormat?
    ) -> BootInstructions {
        lock.lock()
        defer { lock.unlock() }
        
        // If we have a file system format, try format-specific detectors first
        if let format = fileSystemFormat,
           let detector = detectors[format]?.first {
            let instructions = detector.detectBootability(in: diskData, fileSystemFormat: format)
            // If detector returns a definitive result, use it
            if instructions.state != .unknown {
                return instructions
            }
        }
        
        // Try all detectors in registration order
        for detector in detectorOrder {
            let instructions = detector.detectBootability(in: diskData, fileSystemFormat: fileSystemFormat)
            // If detector returns a definitive result, use it
            if instructions.state != .unknown {
                return instructions
            }
        }
        
        // No detector found or all returned unknown
        return .unknown()
    }
    
    /// Get all registered detectors
    /// - Returns: Array of all registered detector types
    public func allDetectors() -> [any BootabilityDetector.Type] {
        lock.lock()
        defer { lock.unlock() }
        return detectorOrder
    }
}

