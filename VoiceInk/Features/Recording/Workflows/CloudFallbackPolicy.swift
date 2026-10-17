import Foundation
import os

/// [custom] Falls back from a cloud transcription provider (e.g. Soniox) to a downloaded
/// local Whisper model when the cloud request fails, and supports a "local only" mode.
@MainActor
final class CloudFallbackPolicy {
    static let shared = CloudFallbackPolicy()

    nonisolated static let localOnlyKey = "CustomLocalOnlyMode"
    nonisolated static let fallbackEnabledKey = "CustomCloudFallbackEnabled"
    nonisolated static let preferredLocalModelKey = "CustomFallbackLocalModelName"
    nonisolated static let defaultPreferredLocalModel = "ggml-large-v3-turbo"

    private var core = CloudFallbackCore()
    private let defaults: UserDefaults
    private let logger = Logger(subsystem: "com.prakashjoshipax.voiceink", category: "CloudFallbackPolicy")

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var isLocalOnly: Bool {
        defaults.bool(forKey: Self.localOnlyKey)
    }

    var isFallbackEnabled: Bool {
        defaults.object(forKey: Self.fallbackEnabledKey) as? Bool ?? true
    }

    static func isCloud(_ provider: ModelProvider) -> Bool {
        switch provider {
        case .whisper, .fluidAudio, .transcribeCpp, .nativeApple:
            return false
        default:
            return true
        }
    }

    func localModel(in usableModels: [any TranscriptionModel]) -> (any TranscriptionModel)? {
        let localModels = usableModels.filter { $0.provider == .whisper }
        let preferred = defaults.string(forKey: Self.preferredLocalModelKey) ?? Self.defaultPreferredLocalModel
        guard
            let name = CloudFallbackCore.pickLocalModelName(
                preferred: preferred, available: localModels.map(\.name))
        else {
            return nil
        }
        return localModels.first { $0.name == name }
    }

    /// Recording start: returns a local configuration when in local-only mode or while the
    /// cloud provider is suspended after a recent failure. Returns nil to keep the configuration.
    func routedConfiguration(
        _ configuration: TranscriptionRuntimeConfiguration,
        usableModels: [any TranscriptionModel]
    ) -> TranscriptionRuntimeConfiguration? {
        let local = localModel(in: usableModels)
        let route = core.route(
            isCloud: Self.isCloud(configuration.model.provider),
            localOnly: isLocalOnly,
            hasLocalModel: local != nil,
            now: Date()
        )
        guard route == .local, let local else { return nil }
        logger.notice(
            "Routing \(configuration.model.displayName, privacy: .public) to local \(local.displayName, privacy: .public) localOnly=\(self.isLocalOnly, privacy: .public)"
        )
        return localConfiguration(from: configuration, model: local)
    }

    /// Transcription error: returns a local configuration to retry with, or nil to rethrow.
    func fallbackConfiguration(
        for configuration: TranscriptionRuntimeConfiguration,
        error: Error,
        usableModels: [any TranscriptionModel]
    ) -> TranscriptionRuntimeConfiguration? {
        let isCloud = Self.isCloud(configuration.model.provider)
        let isCancellation = error is CancellationError
        if isCloud, !isCancellation {
            core.recordCloudFailure(now: Date())
        }
        let local = localModel(in: usableModels)
        guard
            core.shouldFallback(
                isCloud: isCloud,
                fallbackEnabled: isFallbackEnabled,
                hasLocalModel: local != nil,
                isCancellation: isCancellation
            ),
            let local
        else {
            return nil
        }
        logger.error(
            "Cloud transcription failed (\(error.localizedDescription, privacy: .public)); falling back to \(local.displayName, privacy: .public)"
        )
        return localConfiguration(from: configuration, model: local)
    }

    func recordSuccess(for provider: ModelProvider) {
        guard Self.isCloud(provider) else { return }
        core.recordCloudSuccess()
    }

    private func localConfiguration(
        from configuration: TranscriptionRuntimeConfiguration,
        model: any TranscriptionModel
    ) -> TranscriptionRuntimeConfiguration {
        TranscriptionRuntimeConfiguration(
            mode: configuration.mode,
            model: model,
            language: TranscriptionLanguageSupport.validLanguageOrFallback(
                configuration.language, for: model, realtimeEnabled: false),
            isRealtimeEnabled: false
        )
    }
}
