import Foundation

/// [custom] Text size of the live transcript shown while recording (Settings → Live Text Size).
/// Large doubles both the font and the transcript area, so the same amount of text stays visible.
enum LiveTranscriptTextSize: String, CaseIterable, Identifiable {
    case standard
    case large

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .standard:
            return String(localized: "Standard (12pt)")
        case .large:
            return String(localized: "Large (24pt)")
        }
    }

    /// Multiplier for the font and the transcript area.
    var scale: CGFloat {
        switch self {
        case .standard: return 1
        case .large: return 2
        }
    }

    var fontSize: CGFloat { 12 * scale }

    /// Height of the scrolling transcript area (about three lines at either size).
    var transcriptHeight: CGFloat { 56 * scale }
}
