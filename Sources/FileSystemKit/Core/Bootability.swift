// FileSystemKit Core Library
// Bootability Types
//
// This file defines types for describing disk bootability and boot instructions.

import Foundation

// MARK: - BootabilityState

/// Represents the bootability state of a disk image
public enum BootabilityState: String, Codable, Sendable {
    /// Disk is bootable and can be booted directly
    case bootable = "bootable"
    
    /// Disk is not bootable (data-only disk)
    case notBootable = "not_bootable"
    
    /// Bootability cannot be determined
    case unknown = "unknown"
}

// MARK: - BootInstructions

/// Instructions for booting a disk image
///
/// Provides information about how to boot a disk, including required system disks
/// and boot procedures.
///
/// ## Usage
///
/// ```swift
/// let instructions = BootInstructions(
///     state: .notBootable,
///     requiredSystemDisk: "DOS 3.3",
///     instructions: "You must boot system disk DOS 3.3 before loading this disk"
/// )
/// ```
public struct BootInstructions: Codable, Sendable {
    /// Bootability state
    public let state: BootabilityState
    
    /// Required system disk or operating system (e.g., "DOS 3.3", "ProDOS", "SOS")
    /// nil if no system disk is required (disk is bootable) or unknown
    public let requiredSystemDisk: String?
    
    /// Human-readable boot instructions
    /// Examples:
    /// - "Boot from this disk directly"
    /// - "You must boot system disk DOS 3.3 before loading this disk"
    /// - "Requires ProDOS system disk to be booted first"
    public let instructions: String?
    
    /// Additional boot-related metadata
    /// Can include platform-specific boot information
    public let metadata: [String: String]
    
    public init(
        state: BootabilityState,
        requiredSystemDisk: String? = nil,
        instructions: String? = nil,
        metadata: [String: String] = [:]
    ) {
        self.state = state
        self.requiredSystemDisk = requiredSystemDisk
        self.instructions = instructions
        self.metadata = metadata
    }
    
    /// Convenience initializer for bootable disks
    public static func bootable(instructions: String? = nil) -> BootInstructions {
        BootInstructions(
            state: .bootable,
            requiredSystemDisk: nil,
            instructions: instructions ?? "Boot from this disk directly",
            metadata: [:]
        )
    }
    
    /// Convenience initializer for non-bootable disks that require a system disk
    public static func requiresSystemDisk(
        _ systemDisk: String,
        instructions: String? = nil
    ) -> BootInstructions {
        let defaultInstructions = "You must boot system disk \(systemDisk) before loading this disk"
        return BootInstructions(
            state: .notBootable,
            requiredSystemDisk: systemDisk,
            instructions: instructions ?? defaultInstructions,
            metadata: [:]
        )
    }
    
    /// Convenience initializer for unknown bootability
    public static func unknown() -> BootInstructions {
        BootInstructions(
            state: .unknown,
            requiredSystemDisk: nil,
            instructions: nil,
            metadata: [:]
        )
    }
}

