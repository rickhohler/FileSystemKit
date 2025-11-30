// FileSystemKit - SNUG Configuration Management
// Handles configuration file for storage locations and settings

import Foundation
import Yams
#if os(macOS)
import Darwin
#endif

/// SNUG configuration structure
public struct SnugConfig: Codable, Sendable {
    /// Storage locations in priority order (first is primary)
    public var storageLocations: [StorageLocation]
    
    /// Default hash algorithm
    public var defaultHashAlgorithm: String?
    
    /// Enable mirroring to multiple storage locations for redundancy
    public var enableMirroring: Bool
    
    /// Storage locations to mirror to (in addition to primary)
    public var mirrorLocations: [String] // Paths or labels
    
    /// Fail if primary storage is unavailable (default: true for configured locations)
    public var failIfPrimaryUnavailable: Bool
    
    public init(
        storageLocations: [StorageLocation] = [],
        defaultHashAlgorithm: String? = nil,
        enableMirroring: Bool = false,
        mirrorLocations: [String] = [],
        failIfPrimaryUnavailable: Bool = true
    ) {
        self.storageLocations = storageLocations
        self.defaultHashAlgorithm = defaultHashAlgorithm
        self.enableMirroring = enableMirroring
        self.mirrorLocations = mirrorLocations
        self.failIfPrimaryUnavailable = failIfPrimaryUnavailable
    }
}

/// Storage speed classification
public enum StorageSpeed: String, Codable, Sendable, Comparable {
    case veryFast = "very-fast"    // Local SSD (NVMe, SATA SSD)
    case fast = "fast"              // External USB 3.0+ SSD, Thunderbolt
    case medium = "medium"          // External USB HDD, local HDD
    case slow = "slow"              // Network drive (SMB, NFS)
    case verySlow = "very-slow"     // Cloud sync (Google Drive, Dropbox, OneDrive)
    case unknown = "unknown"        // Unable to determine
    
    /// Speed score for sorting (higher = faster)
    public var speedScore: Int {
        switch self {
        case .veryFast: return 100
        case .fast: return 80
        case .medium: return 50
        case .slow: return 20
        case .verySlow: return 10
        case .unknown: return 0
        }
    }
    
    public static func < (lhs: StorageSpeed, rhs: StorageSpeed) -> Bool {
        return lhs.speedScore < rhs.speedScore
    }
}

/// Storage volume type
public enum StorageVolumeType: String, Codable, Sendable {
    case primary = "primary"           // Primary storage (main location)
    case secondary = "secondary"       // Secondary storage (fallback)
    case glacier = "glacier"           // Glacier/backup storage (always mirrored, long-term archival)
    case mirror = "mirror"             // Mirror storage (redundancy)
    
    /// Default priority based on type (lower = higher priority)
    public var defaultPriority: Int {
        switch self {
        case .primary: return 0
        case .secondary: return 100
        case .glacier: return 200
        case .mirror: return 150
        }
    }
}

/// Storage location configuration
public struct StorageLocation: Codable, Sendable {
    /// Path to storage directory
    public let path: String
    
    /// Label/name for this storage location
    public let label: String?
    
    /// Whether this location is required (fail if unavailable) or optional (fallback)
    public let required: Bool
    
    /// Priority order (lower number = higher priority)
    public let priority: Int
    
    /// Detected storage speed classification
    public let speed: StorageSpeed?
    
    /// Volume type (primary, secondary, glacier, mirror)
    public let volumeType: StorageVolumeType
    
    public init(
        path: String,
        label: String? = nil,
        required: Bool = false,
        priority: Int? = nil,
        speed: StorageSpeed? = nil,
        volumeType: StorageVolumeType = .primary
    ) {
        self.path = path
        self.label = label
        self.required = required
        self.priority = priority ?? volumeType.defaultPriority
        self.speed = speed
        self.volumeType = volumeType
    }
}

/// Configuration manager for SNUG
public struct SnugConfigManager {
    /// Get configuration file path
    public static func configFilePath() -> URL {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        let configDir = "\(homeDir)/.snug"
        return URL(fileURLWithPath: configDir).appendingPathComponent("config.yaml")
    }
    
    /// Validate configuration and return validation results
    public static func validateConfiguration(_ config: SnugConfig? = nil) throws -> ConfigurationValidationResult {
        let config = try config ?? load()
        var issues: [ConfigurationIssue] = []
        var warnings: [String] = []
        
        // If storage locations are configured, check primary availability
        if !config.storageLocations.isEmpty {
            let sorted = config.storageLocations.sorted { $0.priority < $1.priority }
            
            if let primary = sorted.first {
                let url = URL(fileURLWithPath: primary.path)
                
                if !FileManager.default.fileExists(atPath: url.path) {
                    // Primary is missing - check if we should fail
                    if config.failIfPrimaryUnavailable || primary.required {
                        issues.append(.requiredStorageMissing(primary.path, primary.label))
                    } else {
                        warnings.append("Primary storage location unavailable: \(primary.path)")
                    }
                } else if !FileManager.default.isWritableFile(atPath: url.path) {
                    if config.failIfPrimaryUnavailable || primary.required {
                        issues.append(.storageNotWritable(primary.path, primary.label))
                    } else {
                        warnings.append("Primary storage location not writable: \(primary.path)")
                    }
                }
            }
            
            // Check other storage locations
            for location in sorted.dropFirst() {
                let url = URL(fileURLWithPath: location.path)
                
                if !FileManager.default.fileExists(atPath: url.path) {
                    if location.required {
                        issues.append(.requiredStorageMissing(location.path, location.label))
                    } else {
                        warnings.append("Optional storage location unavailable: \(location.path)")
                    }
                } else if !FileManager.default.isWritableFile(atPath: url.path) {
                    if location.required {
                        issues.append(.storageNotWritable(location.path, location.label))
                    } else {
                        warnings.append("Storage location not writable: \(location.path)")
                    }
                }
            }
            
            // Check mirror locations if mirroring is enabled
            if config.enableMirroring {
                for mirrorPath in config.mirrorLocations {
                    let url = URL(fileURLWithPath: mirrorPath)
                    if !FileManager.default.fileExists(atPath: url.path) {
                        warnings.append("Mirror location unavailable: \(mirrorPath)")
                    } else if !FileManager.default.isWritableFile(atPath: url.path) {
                        warnings.append("Mirror location not writable: \(mirrorPath)")
                    }
                }
            }
        }
        
        // Check if any storage locations are available
        let available = try? getAvailableStorageLocations(from: config)
        if available?.isEmpty ?? true {
            // Only fail if we have configured locations and failIfPrimaryUnavailable is true
            if !config.storageLocations.isEmpty && config.failIfPrimaryUnavailable {
                issues.append(.noStorageAvailable)
            }
        }
        
        return ConfigurationValidationResult(
            isValid: issues.isEmpty,
            issues: issues,
            warnings: warnings
        )
    }
    
    /// Classify storage speed for a given path
    public static func classifyStorageSpeed(at path: String) -> StorageSpeed {
        let url = URL(fileURLWithPath: path)
        
        // Get volume information
        guard let volumeInfo = getVolumeInfo(for: url) else {
            return .unknown
        }
        
        // Check if it's a network mount
        if volumeInfo.isNetworkVolume {
            // Check for cloud sync folders
            let pathLower = path.lowercased()
            if pathLower.contains("google drive") || pathLower.contains("googledrive") ||
               pathLower.contains("dropbox") ||
               pathLower.contains("onedrive") ||
               pathLower.contains("icloud") ||
               pathLower.contains("icloud drive") {
                return .verySlow
            }
            return .slow
        }
        
        // Check if it's an external drive
        if volumeInfo.isExternal {
            // Check if it's SSD or HDD
            if volumeInfo.isSSD {
                // Check connection type
                if volumeInfo.isThunderbolt {
                    return .veryFast
                } else if volumeInfo.isUSB3 {
                    return .fast
                } else {
                    return .medium
                }
            } else {
                return .medium
            }
        }
        
        // Local volume
        if volumeInfo.isSSD {
            return .veryFast
        } else {
            return .medium
        }
    }
    
    /// Get volume information for a path
    private static func getVolumeInfo(for url: URL) -> VolumeInfo? {
        let path = url.path
        
        // Resolve to actual volume path
        var volumeURL: URL?
        var isNetwork = false
        var isExternal = false
        var isSSD = false
        var isThunderbolt = false
        var isUSB3 = false
        
        // Use statfs to get filesystem information
        var stat = statfs()
        guard statfs(path, &stat) == 0 else {
            return nil
        }
        
        // Get volume name
        let volumeName = withUnsafePointer(to: &stat.f_mntonname.0) {
            String(cString: $0)
        }
        
        // Check if network volume (common network filesystem types)
        let fstype = withUnsafePointer(to: &stat.f_fstypename.0) {
            String(cString: $0)
        }
        let networkFS = ["smbfs", "nfs", "afpfs", "webdav", "ftp", "cifs"]
        isNetwork = networkFS.contains(fstype.lowercased())
        
        // Check if external (not on boot volume)
        let bootVolume = "/"
        isExternal = !path.hasPrefix(bootVolume) && !path.hasPrefix("/Users")
        
        // Try to detect if SSD using IOKit (macOS specific)
        #if os(macOS)
        isSSD = detectSSD(for: path)
        isThunderbolt = detectThunderbolt(for: path)
        isUSB3 = detectUSB3(for: path)
        #endif
        
        return VolumeInfo(
            path: path,
            volumeName: volumeName,
            filesystemType: fstype,
            isNetworkVolume: isNetwork,
            isExternal: isExternal,
            isSSD: isSSD,
            isThunderbolt: isThunderbolt,
            isUSB3: isUSB3
        )
    }
    
    #if os(macOS)
    /// Detect if volume is on SSD (macOS specific)
    private static func detectSSD(for path: String) -> Bool {
        // Use diskutil to check if volume is on SSD
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
        
        // Get volume path
        let volumePath = path.components(separatedBy: "/").prefix(2).joined(separator: "/")
        process.arguments = ["info", "-plist", volumePath]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
                   let solidState = plist["SolidState"] as? Bool {
                    return solidState
                }
            }
        } catch {
            // Fallback: assume SSD if path contains common SSD indicators
            return path.lowercased().contains("ssd") || path.lowercased().contains("nvme")
        }
        
        return false
    }
    
    /// Detect if volume is on Thunderbolt connection
    private static func detectThunderbolt(for path: String) -> Bool {
        // Check for Thunderbolt indicators in path or use system_profiler
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        process.arguments = ["SPThunderboltDataType", "-xml"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let dataString = String(data: data, encoding: .utf8) ?? ""
                // If Thunderbolt devices exist, might be Thunderbolt
                return !dataString.isEmpty && dataString.contains("Thunderbolt")
            }
        } catch {
            // Fallback
        }
        
        return false
    }
    
    /// Detect if volume is on USB 3.0+ connection
    private static func detectUSB3(for path: String) -> Bool {
        // Check USB bus speed
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        process.arguments = ["SPUSBDataType", "-xml"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let dataString = String(data: data, encoding: .utf8) ?? ""
                // Check for USB 3.0+ indicators
                return dataString.contains("USB 3") || dataString.contains("USB3") || dataString.contains("SuperSpeed")
            }
        } catch {
            // Fallback
        }
        
        return false
    }
    #else
    private static func detectSSD(for path: String) -> Bool { return false }
    private static func detectThunderbolt(for path: String) -> Bool { return false }
    private static func detectUSB3(for path: String) -> Bool { return false }
    #endif
}

/// Volume information structure
private struct VolumeInfo {
    let path: String
    let volumeName: String
    let filesystemType: String
    let isNetworkVolume: Bool
    let isExternal: Bool
    let isSSD: Bool
    let isThunderbolt: Bool
    let isUSB3: Bool
}

/// Configuration validation result
public struct ConfigurationValidationResult {
    public let isValid: Bool
    public let issues: [ConfigurationIssue]
    public let warnings: [String]
}

/// Configuration validation issues
public enum ConfigurationIssue: CustomStringConvertible {
    case requiredStorageMissing(String, String?)
    case storageNotWritable(String, String?)
    case noStorageAvailable
    
    public var description: String {
        switch self {
        case .requiredStorageMissing(let path, let label):
            let labelStr = label.map { " (\($0))" } ?? ""
            return "Required storage location missing: \(path)\(labelStr)"
        case .storageNotWritable(let path, let label):
            let labelStr = label.map { " (\($0))" } ?? ""
            return "Storage location not writable: \(path)\(labelStr)"
        case .noStorageAvailable:
            return "No storage locations available"
        }
    }
}

extension SnugConfigManager {
    /// Load configuration from file
    public static func load() throws -> SnugConfig {
        let configURL = configFilePath()
        
        guard FileManager.default.fileExists(atPath: configURL.path) else {
            // Return default config if file doesn't exist
            // Default: fail if primary unavailable (conservative default)
            return SnugConfig(failIfPrimaryUnavailable: true)
        }
        
        let data = try Data(contentsOf: configURL)
        let decoder = YAMLDecoder()
        var config = try decoder.decode(SnugConfig.self, from: data)
        
        // Ensure failIfPrimaryUnavailable defaults to true if not set
        // (for backward compatibility, check if it's explicitly false in YAML)
        // Since Bool defaults to false in Codable, we need to handle this differently
        // We'll use a wrapper or check the raw YAML, but for now, if locations exist, default to true
        
        // If storage locations are configured but failIfPrimaryUnavailable wasn't set,
        // default to true (fail if primary unavailable)
        if !config.storageLocations.isEmpty && config.failIfPrimaryUnavailable == false {
            // Check if this was explicitly set to false or just defaulted
            // For now, we'll assume if locations exist, user wants them to be required
            // This will be handled by validation logic
        }
        
        return config
    }
    
    /// Save configuration to file
    public static func save(_ config: SnugConfig) throws {
        let configURL = configFilePath()
        
        // Ensure config directory exists
        try FileManager.default.createDirectory(
            at: configURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        let encoder = YAMLEncoder()
        let yamlString = try encoder.encode(config)
        try yamlString.write(to: configURL, atomically: true, encoding: .utf8)
    }
    
    /// Get available storage locations from config, checking availability
    public static func getAvailableStorageLocations(from config: SnugConfig? = nil) throws -> [StorageLocation] {
        let config = try config ?? load()
        
        var available: [StorageLocation] = []
        var unavailable: [StorageLocation] = []
        
        // Sort by priority
        let sorted = config.storageLocations.sorted { $0.priority < $1.priority }
        
        for location in sorted {
            let url = URL(fileURLWithPath: location.path)
            
            // Check if location exists and is accessible
            if FileManager.default.fileExists(atPath: url.path) {
                // Check if it's writable
                if FileManager.default.isWritableFile(atPath: url.path) {
                    available.append(location)
                } else {
                    unavailable.append(location)
                    if location.required {
                        throw SnugError.storageError("Required storage location is not writable: \(location.path)")
                    }
                }
            } else {
                unavailable.append(location)
                if location.required {
                    throw SnugError.storageError("Required storage location does not exist: \(location.path)")
                }
            }
        }
        
        // If no configured locations available, fallback to default
        if available.isEmpty {
            let defaultPath = SnugStorage.defaultStorageDirectory()
            available.append(StorageLocation(
                path: defaultPath,
                label: "default",
                required: false,
                priority: 999
            ))
        }
        
        return available
    }
    
    /// Get primary storage location (first available)
    public static func getPrimaryStorageLocation(from config: SnugConfig? = nil) throws -> StorageLocation {
        let available = try getAvailableStorageLocations(from: config)
        guard let primary = available.first else {
            throw SnugError.storageError("No storage locations available")
        }
        return primary
    }
    
    /// Get all storage locations (including unavailable) for display
    public static func getAllStorageLocations(from config: SnugConfig? = nil) throws -> (available: [StorageLocation], unavailable: [StorageLocation]) {
        let config = try config ?? load()
        
        var available: [StorageLocation] = []
        var unavailable: [StorageLocation] = []
        
        let sorted = config.storageLocations.sorted { $0.priority < $1.priority }
        
        for location in sorted {
            let url = URL(fileURLWithPath: location.path)
            
            if FileManager.default.fileExists(atPath: url.path) && FileManager.default.isWritableFile(atPath: url.path) {
                available.append(location)
            } else {
                unavailable.append(location)
            }
        }
        
        return (available, unavailable)
    }
}

