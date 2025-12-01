// FileSystemKit - SNUG Archive Creation
// Hash Computation Utilities
//
// NOTE: This file has been refactored. Hash computation now uses FileSystemKit's core
// HashComputation implementation from FileSystemKit/Sources/FileSystemKit/Core/HashComputation.swift
//
// This file is kept for backward compatibility but now delegates to the core implementation.

import Foundation

/// Hash computation utilities for SnugArchiver
/// Delegates to FileSystemKit's core HashComputation for unified implementation
internal struct SnugHashComputation {
    /// Compute hash for data using specified algorithm
    static func computeHash(data: Data, algorithm: String) throws -> String {
        return try HashComputation.computeHashHex(data: data, algorithm: algorithm)
    }
}

