import Foundation

/// [custom] Regex patterns for filler-word removal that also work for Japanese.
/// Japanese text has no spaces, so `\b` never matches inside a sentence like "あのー今日は".
/// Non-ASCII filler words therefore match anywhere and also swallow a following Japanese comma.
/// Foundation-only so it can be unit-tested with plain `swiftc`.
enum FillerWordPattern {
    static func pattern(for fillerWord: String) -> String {
        let escaped = NSRegularExpression.escapedPattern(for: fillerWord)
        if fillerWord.unicodeScalars.allSatisfy(\.isASCII) {
            return "\\b\(escaped)\\b[,.]?"
        }
        return "\(escaped)[、，,]?"
    }

    /// Longer words first so "えーと" is removed whole instead of leaving "と" after "えー".
    static func ordered(_ fillerWords: [String]) -> [String] {
        fillerWords.enumerated()
            .sorted { lhs, rhs in
                lhs.element.count != rhs.element.count
                    ? lhs.element.count > rhs.element.count
                    : lhs.offset < rhs.offset
            }
            .map(\.element)
    }
}
