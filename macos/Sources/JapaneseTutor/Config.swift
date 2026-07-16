import Foundation

/// Central configuration. Values can be overridden with environment variables
/// (handy when launching from a terminal for debugging).
enum Config {
    private static func env(_ key: String, _ fallback: String) -> String {
        ProcessInfo.processInfo.environment[key] ?? fallback
    }

    // Ollama (the conversation brain)
    static let ollamaHost = env("OLLAMA_HOST", "http://127.0.0.1:11434")
    static let model = env("JP_TUTOR_MODEL", "qwen2.5:7b")

    // Learner profile
    static let level = env("JP_TUTOR_LEVEL", "some basics")
    /// "full" | "japanese_english" | "japanese" | "audio"
    static let textSupport = env("JP_TUTOR_TEXT", "full")
    static let startDifficulty = Int(env("JP_TUTOR_DIFFICULTY", "3")) ?? 3

    // Text-to-speech
    static let voicePreference = env("JP_TUTOR_VOICE", "Kyoko")

    // How long a pause (seconds) counts as "you've finished your turn".
    static let silenceTimeout: TimeInterval = Double(env("JP_TUTOR_SILENCE", "1.3")) ?? 1.3
}
