import Foundation

/// [custom] Narrows a Japanese (CJK) correction to the edited term.
/// Upstream segments text on whitespace, so an unspaced Japanese sentence becomes one segment
/// and the whole sentence is the candidate; anything over 32 characters is then dropped.
/// This trims the shared prefix/suffix, widens the core to the surrounding run of the same
/// script (katakana, kanji, latin/digits; never hiragana, which holds particles), and keeps a
/// few characters of context for the reviewer. Foundation-only so it can be unit-tested with
/// plain `swiftc`.
enum CJKCorrectionNarrower {
    struct Narrowed: Equatable {
        let source: String
        let destination: String
        let originalSnippet: String
        let correctedSnippet: String
    }

    enum Outcome: Equatable {
        /// No CJK text: keep the upstream behaviour.
        case notApplicable
        /// CJK edit that is not learnable as a term (pure insertion/deletion or too long).
        case skip
        case narrowed(Narrowed)
    }

    static let contextCharacters = 6
    static let maximumCoreCharacters = 32

    private enum ScriptClass {
        case katakana, kanji, latin, hiragana, other
    }

    static func narrow(source: String, destination: String) -> Outcome {
        guard containsCJK(source) || containsCJK(destination) else { return .notApplicable }

        let s = Array(source)
        let d = Array(destination)
        var prefix = 0
        while prefix < s.count, prefix < d.count, s[prefix] == d[prefix] {
            prefix += 1
        }
        var suffix = 0
        while suffix < s.count - prefix, suffix < d.count - prefix,
            s[s.count - 1 - suffix] == d[d.count - 1 - suffix]
        {
            suffix += 1
        }

        var start = prefix
        var sourceEnd = s.count - suffix
        var destinationEnd = d.count - suffix
        guard start < sourceEnd, start < destinationEnd else { return .skip }

        // Widen left over the shared prefix while it continues the core's script run.
        while start > 0 {
            let shared = scriptClass(s[start - 1])
            guard isExtendable(shared),
                shared == scriptClass(s[start]) || shared == scriptClass(d[start])
            else { break }
            start -= 1
        }
        // Widen right over the shared suffix likewise.
        while sourceEnd < s.count {
            let shared = scriptClass(s[sourceEnd])
            guard isExtendable(shared),
                shared == scriptClass(s[sourceEnd - 1]) || shared == scriptClass(d[destinationEnd - 1])
            else { break }
            sourceEnd += 1
            destinationEnd += 1
        }

        let coreSource = String(s[start..<sourceEnd]).trimmingCharacters(in: .whitespaces)
        let coreDestination = String(d[start..<destinationEnd]).trimmingCharacters(in: .whitespaces)
        guard !coreSource.isEmpty, !coreDestination.isEmpty, coreSource != coreDestination,
            coreSource.count <= maximumCoreCharacters,
            coreDestination.count <= maximumCoreCharacters
        else {
            return .skip
        }

        let left = String(s[max(0, start - contextCharacters)..<start])
        let right = String(s[sourceEnd..<min(s.count, sourceEnd + contextCharacters)])
        return .narrowed(
            Narrowed(
                source: coreSource,
                destination: coreDestination,
                originalSnippet: (left + String(s[start..<sourceEnd]) + right)
                    .trimmingCharacters(in: .whitespaces),
                correctedSnippet: (left + String(d[start..<destinationEnd]) + right)
                    .trimmingCharacters(in: .whitespaces)
            ))
    }

    static func containsCJK(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            switch scalar.value {
            case 0x3040...0x30FF, 0x3400...0x4DBF, 0x4E00...0x9FFF, 0xFF66...0xFF9F, 0x20000...0x2FA1F:
                return true
            default:
                return false
            }
        }
    }

    private static func isExtendable(_ scriptClass: ScriptClass) -> Bool {
        scriptClass == .katakana || scriptClass == .kanji || scriptClass == .latin
    }

    private static func scriptClass(_ character: Character) -> ScriptClass {
        guard let scalar = character.unicodeScalars.first else { return .other }
        switch scalar.value {
        case 0x30A0...0x30FF, 0xFF66...0xFF9F:
            return .katakana
        case 0x3005, 0x3400...0x4DBF, 0x4E00...0x9FFF, 0x20000...0x2FA1F:
            return .kanji
        case 0x3040...0x309F:
            return .hiragana
        case 0x30...0x39, 0x41...0x5A, 0x61...0x7A, 0xFF10...0xFF19, 0xFF21...0xFF3A, 0xFF41...0xFF5A:
            return .latin
        default:
            return .other
        }
    }
}
