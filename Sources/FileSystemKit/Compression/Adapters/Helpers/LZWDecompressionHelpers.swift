// FileSystemKit Core Library
// LZW Decompression Helpers (shared by ARC and StuffIt adapters)

import Foundation

/// Bit-level reader for LZW decompression
internal struct BitReader {
    let data: Data
    var bitOffset: Int = 0
    
    init(data: Data) {
        self.data = data
    }
    
    /// Read a variable-width code (9-12 bits typically)
    mutating func readCode(width: Int) -> Int? {
        guard width >= 9 && width <= 12 else { return nil }
        
        var code: Int = 0
        var bitsRead = 0
        
        while bitsRead < width {
            let byteIndex = bitOffset / 8
            let bitIndex = bitOffset % 8
            
            guard byteIndex < data.count else { return nil }
            
            let byte = data[byteIndex]
            let bit = (byte >> (7 - bitIndex)) & 1
            code = (code << 1) | Int(bit)
            
            bitOffset += 1
            bitsRead += 1
        }
        
        return code
    }
}

/// LZW decompressor for ARC format
internal struct LZWDecompressor {
    let data: Data
    var dictionary: [Int: [UInt8]] = [:]
    var nextCode: Int
    let initialCodeWidth: Int
    var currentCodeWidth: Int
    
    init(data: Data, initialCodeWidth: Int = 9) {
        self.data = data
        self.initialCodeWidth = initialCodeWidth
        self.currentCodeWidth = initialCodeWidth
        
        // Initialize dictionary with single-byte codes (0-255)
        for i in 0..<256 {
            dictionary[i] = [UInt8(i)]
        }
        nextCode = 256
    }
    
    mutating func decompress() throws -> Data {
        var reader = BitReader(data: data)
        var output: [UInt8] = []
        var previousCode: Int? = nil
        
        while true {
            guard let code = reader.readCode(width: currentCodeWidth) else {
                break
            }
            
            // Check for clear code (typically 256) - reset dictionary
            if code == 256 {
                // Reset dictionary
                dictionary.removeAll()
                for i in 0..<256 {
                    dictionary[i] = [UInt8(i)]
                }
                nextCode = 256
                currentCodeWidth = initialCodeWidth
                previousCode = nil
                continue
            }
            
            // Check for end code (typically 257)
            if code == 257 {
                break
            }
            
            var entry: [UInt8]
            
            if let dictEntry = dictionary[code] {
                // Code exists in dictionary
                entry = dictEntry
            } else if let prev = previousCode, let prevEntry = dictionary[prev] {
                // Special case: code not in dictionary yet
                // This happens when encoder outputs code before adding it to dictionary
                entry = prevEntry + [prevEntry[0]]
            } else {
                throw CompressionError.decompressionFailed
            }
            
            // Output the entry
            output.append(contentsOf: entry)
            
            // Add new dictionary entry
            if let prev = previousCode, let prevEntry = dictionary[prev] {
                let newEntry = prevEntry + [entry[0]]
                dictionary[nextCode] = newEntry
                nextCode += 1
                
                // Increase code width if needed
                if nextCode >= (1 << currentCodeWidth) && currentCodeWidth < 12 {
                    currentCodeWidth += 1
                }
            }
            
            previousCode = code
        }
        
        return Data(output)
    }
}

