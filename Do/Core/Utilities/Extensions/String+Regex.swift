//
//  String+Regex.swift
//  Do
//
//  String extension for regex pattern matching
//

import Foundation

extension String {
    /// Check if the string matches a regex pattern
    /// - Parameter pattern: The regex pattern to match
    /// - Returns: True if the string matches the pattern
    func matches(pattern: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return false
        }
        let range = NSRange(location: 0, length: self.utf16.count)
        return regex.firstMatch(in: self, options: [], range: range) != nil
    }
    
    /// Static method for pattern matching (for compatibility with existing code)
    /// - Parameters:
    ///   - string: The string to check
    ///   - pattern: The regex pattern to match
    /// - Returns: True if the string matches the pattern
    static func matches(_ string: String, pattern: String) -> Bool {
        return string.matches(pattern: pattern)
    }
}


