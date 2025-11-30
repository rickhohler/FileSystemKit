// FileSystemKit Core Library
// Special File Type Detection
//
// This module provides detection and classification of special file types
// (block devices, character devices, sockets, FIFOs) using POSIX stat().
// This functionality is reusable across different archive and file system types.

import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

// MARK: - SpecialFileType

/// Information about special file types detected via stat()
/// 
/// Special files are non-regular files that represent devices, sockets, or named pipes.
/// This information is useful for archiving systems that need to preserve metadata
/// about these special file types.
public struct SpecialFileType: Sendable {
    /// True if this is a block device
    public let isBlockDevice: Bool
    
    /// True if this is a character device
    public let isCharacterDevice: Bool
    
    /// True if this is a socket
    public let isSocket: Bool
    
    /// True if this is a FIFO (named pipe)
    public let isFIFO: Bool
    
    /// Initialize with detected file type flags
    public init(isBlockDevice: Bool, isCharacterDevice: Bool, isSocket: Bool, isFIFO: Bool) {
        self.isBlockDevice = isBlockDevice
        self.isCharacterDevice = isCharacterDevice
        self.isSocket = isSocket
        self.isFIFO = isFIFO
    }
    
    /// Check if this is any type of special file
    public var isSpecialFile: Bool {
        return isBlockDevice || isCharacterDevice || isSocket || isFIFO
    }
    
    /// Get the special file type string identifier for use in archive entries
    /// - Returns: Type string ("block-device", "character-device", "socket", "fifo") or nil if not a special file
    public var typeString: String? {
        // These are mutually exclusive, so we check in priority order
        // Using separate if statements to avoid compiler warnings about unreachable code
        if isBlockDevice {
            return "block-device"
        }
        if isCharacterDevice {
            return "character-device"
        }
        if isSocket {
            return "socket"
        }
        if isFIFO {
            return "fifo"
        }
        return nil
    }
    
    /// Get human-readable file type description
    public var description: String {
        // These are mutually exclusive, so we check in priority order
        // Using separate if statements to avoid compiler warnings about unreachable code
        if isBlockDevice {
            return "block device"
        }
        if isCharacterDevice {
            return "character device"
        }
        if isSocket {
            return "socket"
        }
        if isFIFO {
            return "FIFO"
        }
        return "unknown special file"
    }
}

// MARK: - Special File Detection

/// Detect special file types using stat() system call
/// 
/// This function uses POSIX stat() to determine if a file is a special file type
/// (block device, character device, socket, or FIFO). This information cannot
/// be determined using URLResourceValues alone.
///
/// - Parameter url: File URL to check
/// - Returns: SpecialFileType with detected file types, or nil if not a special file or detection fails
/// 
/// - Note: Returns nil if stat() fails (file doesn't exist, permission denied, etc.)
/// - Note: Returns nil if the file is a regular file, directory, or symlink
public func detectSpecialFileType(at url: URL) -> SpecialFileType? {
    let path = url.path
    
    // Use stat() to get file type information
    var statInfo = stat()
    guard stat(path, &statInfo) == 0 else {
        // stat() failed - file might not exist or we don't have permission
        // Return nil to indicate we couldn't determine special file status
        return nil
    }
    
    // Check file mode for special file types
    // S_IFMT is the bit mask for file type bits
    let fileMode = statInfo.st_mode & S_IFMT
    
    let isBlockDevice = fileMode == S_IFBLK
    let isCharacterDevice = fileMode == S_IFCHR
    let isSocket = fileMode == S_IFSOCK
    let isFIFO = fileMode == S_IFIFO
    
    // Only return info if it's actually a special file
    if isBlockDevice || isCharacterDevice || isSocket || isFIFO {
        return SpecialFileType(
            isBlockDevice: isBlockDevice,
            isCharacterDevice: isCharacterDevice,
            isSocket: isSocket,
            isFIFO: isFIFO
        )
    }
    
    return nil
}

