import Foundation

/// Lightweight markdown cleanup helper used across Genie flows.
enum MarkdownFormatter {
    static func cleanMarkdown(_ text: String) -> String {
        text
            .replacingOccurrences(of: "```", with: "")
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "__", with: "")
            .replacingOccurrences(of: "\r", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
