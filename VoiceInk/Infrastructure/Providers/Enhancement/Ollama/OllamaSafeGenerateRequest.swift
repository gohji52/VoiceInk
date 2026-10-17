import Foundation

/// [custom] Builds Ollama `/api/generate` requests with an explicit context size and keep-alive.
/// LLMkit's `OllamaGenerationOptions` cannot set `num_ctx` / `keep_alive`; without them Ollama
/// picks a VRAM-based default context (256K on a 64GB Mac) and keeps the model resident.
/// Foundation-only so it can be unit-tested with plain `swiftc`.
enum OllamaSafeGenerateRequest {
    /// Short prompts (enhancement, Auto Learn review) fit comfortably in 8K tokens.
    static let defaultContextLength = 8192
    /// Unload the model shortly after dictation stops instead of keeping it resident.
    static let defaultKeepAlive = "2m"

    struct Body: Encodable, Equatable {
        struct Options: Encodable, Equatable {
            let temperature: Double
            let numCtx: Int

            enum CodingKeys: String, CodingKey {
                case temperature
                case numCtx = "num_ctx"
            }
        }

        let model: String
        let prompt: String
        let system: String
        let stream: Bool
        let think: Bool
        let keepAlive: String
        let options: Options

        enum CodingKeys: String, CodingKey {
            case model, prompt, system, stream, think, options
            case keepAlive = "keep_alive"
        }
    }

    struct Response: Decodable {
        let response: String
    }

    static func make(
        baseURL: URL,
        model: String,
        prompt: String,
        systemPrompt: String,
        temperature: Double,
        contextLength: Int = defaultContextLength,
        keepAlive: String = defaultKeepAlive,
        timeout: TimeInterval
    ) throws -> URLRequest {
        var request = URLRequest(url: baseURL.appendingPathComponent("api/generate"))
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            Body(
                model: model,
                prompt: prompt,
                system: systemPrompt,
                stream: false,
                think: false,
                keepAlive: keepAlive,
                options: .init(temperature: temperature, numCtx: contextLength)
            )
        )
        return request
    }
}
