// FileSystemKit - SNUG Ignore Pattern Matching
// Support for .snugignore files and exclusion patterns

import Foundation

/// Pattern matcher for ignore rules (similar to .gitignore)
public struct SnugIgnoreMatcher: Sendable {
    private let patterns: [IgnorePattern]
    
    public init(patterns: [String]) {
        self.patterns = patterns.map { IgnorePattern(pattern: $0) }
    }
    
    /// Load ignore patterns from a file
    public init(ignoreFile: URL) throws {
        let content = try String(contentsOf: ignoreFile, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") } // Skip empty lines and comments
        
        self.patterns = lines.map { IgnorePattern(pattern: $0) }
    }
    
    /// Check if a path should be ignored
    public func shouldIgnore(_ path: String) -> Bool {
        for pattern in patterns {
            if pattern.matches(path) {
                return !pattern.isNegation // Negation patterns return false (don't ignore)
            }
        }
        return false
    }
    
    /// Check if a URL should be ignored
    public func shouldIgnore(_ url: URL, relativeTo baseURL: URL) -> Bool {
        let relativePath = url.path.replacingOccurrences(of: baseURL.path, with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return shouldIgnore(relativePath)
    }
}

/// Individual ignore pattern
private struct IgnorePattern {
    let pattern: String
    let isNegation: Bool
    let isDirectory: Bool
    let isGlob: Bool
    
    init(pattern: String) {
        var p = pattern.trimmingCharacters(in: .whitespaces)
        
        // Check for negation (!)
        if p.hasPrefix("!") {
            self.isNegation = true
            p = String(p.dropFirst())
        } else {
            self.isNegation = false
        }
        
        // Check if it's a directory pattern (ends with /)
        if p.hasSuffix("/") {
            self.isDirectory = true
            p = String(p.dropLast())
        } else {
            self.isDirectory = false
        }
        
        // Check if it's a glob pattern (contains * or ?)
        self.isGlob = p.contains("*") || p.contains("?")
        
        self.pattern = p
    }
    
    func matches(_ path: String) -> Bool {
        let normalizedPath = path.replacingOccurrences(of: "\\", with: "/")
        
        // Simple exact match
        if !isGlob && !isDirectory {
            return normalizedPath == pattern || normalizedPath.hasSuffix("/" + pattern)
        }
        
        // Directory pattern: match if path is in or under this directory
        if isDirectory {
            if normalizedPath.hasPrefix(pattern + "/") || normalizedPath == pattern {
                return true
            }
            // Also check if any component matches
            let components = normalizedPath.components(separatedBy: "/")
            return components.contains(pattern)
        }
        
        // Glob pattern matching
        if isGlob {
            return matchesGlob(pattern: pattern, path: normalizedPath)
        }
        
        // Simple prefix/suffix match
        return normalizedPath.hasPrefix(pattern) || normalizedPath.hasSuffix(pattern)
    }
    
    private func matchesGlob(pattern: String, path: String) -> Bool {
        // Convert glob pattern to regex
        var regexPattern = pattern
            .replacingOccurrences(of: ".", with: "\\.")
            .replacingOccurrences(of: "*", with: ".*")
            .replacingOccurrences(of: "?", with: ".")
        
        // Match anywhere in path
        regexPattern = ".*" + regexPattern + ".*"
        
        guard let regex = try? NSRegularExpression(pattern: regexPattern, options: []) else {
            return false
        }
        
        let range = NSRange(location: 0, length: path.utf16.count)
        return regex.firstMatch(in: path, options: [], range: range) != nil
    }
}

/// Default ignore patterns (common build artifacts and version control)
public extension SnugIgnoreMatcher {
    static let defaultPatterns: [String] = [
        // Version control
        ".git/",
        ".svn/",
        ".hg/",
        ".bzr/",
        // Build artifacts
        ".build/",
        "build/",
        "dist/",
        "target/",
        "*.o",
        "*.a",
        "*.so",
        "*.dylib",
        "*.dll",
        "*.exe",
        "*.swiftmodule",
        "*.swiftdoc",
        "*.dSYM/",
        // Dependencies
        "node_modules/",
        ".venv/",
        "venv/",
        "__pycache__/",
        "*.pyc",
        "*.pyo",
        // IDE
        ".idea/",
        ".vscode/",
        "*.swp",
        "*.swo",
        "*~",
        // OS
        ".DS_Store",
        "Thumbs.db",
        // Archives (to avoid recursive archiving)
        "*.snug",
        "*.zip",
        "*.tar",
        "*.tar.gz",
        "*.tgz",
        "*.gz"
    ]
    
    /// Create matcher with default patterns
    static func `default`() -> SnugIgnoreMatcher {
        return SnugIgnoreMatcher(patterns: defaultPatterns)
    }
}

