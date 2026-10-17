import Foundation

/// [custom] Pure decision logic for cloud → local transcription fallback.
/// Has no app dependencies so it can be unit-tested with plain `swiftc`
/// (see `bench/tests/` in the parent repository).
struct CloudFallbackCore {
    enum Route: Equatable {
        case asConfigured
        case local
    }

    /// How long to skip the cloud provider after a failure, so each recording
    /// does not wait for another timeout while the network or provider is down.
    var suspendDuration: TimeInterval = 300
    private(set) var suspendedUntil: Date?

    /// Decides at recording start whether to bypass the cloud provider.
    func route(isCloud: Bool, localOnly: Bool, hasLocalModel: Bool, now: Date) -> Route {
        guard isCloud, hasLocalModel else { return .asConfigured }
        if localOnly { return .local }
        if let suspendedUntil, now < suspendedUntil { return .local }
        return .asConfigured
    }

    /// Decides after a transcription error whether to retry with the local model.
    func shouldFallback(isCloud: Bool, fallbackEnabled: Bool, hasLocalModel: Bool, isCancellation: Bool) -> Bool {
        isCloud && fallbackEnabled && hasLocalModel && !isCancellation
    }

    mutating func recordCloudFailure(now: Date) {
        suspendedUntil = now.addingTimeInterval(suspendDuration)
    }

    mutating func recordCloudSuccess() {
        suspendedUntil = nil
    }

    /// Picks the local model: the preferred one if downloaded, otherwise the best available.
    static func pickLocalModelName(preferred: String, available: [String]) -> String? {
        if available.contains(preferred) { return preferred }
        return available.first { $0.contains("large-v3-turbo") }
            ?? available.first { $0.contains("large") }
            ?? available.first
    }
}
