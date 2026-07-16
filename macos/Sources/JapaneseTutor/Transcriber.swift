import Foundation
import WhisperKit

/// On-device speech-to-text via WhisperKit. Auto-detects the language, so it
/// understands you whether you speak English, Japanese, or a mix of both — the
/// key thing the old Apple-Speech (single-locale) path couldn't do.
actor Transcriber {
    private var kit: WhisperKit?
    private let modelName: String

    init(model: String) {
        self.modelName = model
    }

    /// Load (and download, first time) the Whisper model.
    func load() async throws {
        if kit != nil { return }
        kit = try await WhisperKit(
            model: modelName,
            verbose: false,
            logLevel: .error,
            prewarm: true,
            load: true,
            download: true
        )
    }

    /// Transcribe 16 kHz mono samples. Returns the text and detected language
    /// code (e.g. "en", "ja").
    func transcribe(_ samples: [Float]) async throws -> (text: String, language: String) {
        try await load()
        guard let kit else { return ("", "en") }

        let options = DecodingOptions(
            task: .transcribe,
            language: nil,          // nil + detectLanguage → auto-detect
            detectLanguage: true
        )
        let results = try await kit.transcribe(audioArray: samples, decodeOptions: options)

        let text = results
            .map { $0.text }
            .joined(separator: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let language = results.first?.language ?? "en"
        return (text, language)
    }
}
