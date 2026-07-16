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

    // Speech-to-text (WhisperKit). "base" is a good speed/accuracy balance;
    // "small" is more accurate but slower. Whisper auto-detects the language.
    static let whisperModel = env("JP_TUTOR_WHISPER", "base")

    // Learner profile
    static let level = env("JP_TUTOR_LEVEL", "some basics")
    /// "full" | "japanese_english" | "japanese" | "audio"
    static let textSupport = env("JP_TUTOR_TEXT", "full")
    static let startDifficulty = Int(env("JP_TUTOR_DIFFICULTY", "3")) ?? 3
    /// 0 = English-first teaching … 100 = Japanese-only immersion.
    static let startImmersion = Int(env("JP_TUTOR_IMMERSION", "30")) ?? 30

    // Text-to-speech voices (see `say -v '?'`).
    static let voicePreference = env("JP_TUTOR_VOICE", "Kyoko")          // Japanese
    static let englishVoicePreference = env("JP_TUTOR_EN_VOICE", "Samantha")

    // Voice-activity detection / end-of-utterance tuning.
    /// RMS level above which a frame counts as speech.
    static let vadThreshold: Float = Float(env("JP_TUTOR_VAD", "0.012")) ?? 0.012
    /// Seconds of trailing silence that mean "you've finished your turn".
    static let silenceTimeout: Double = Double(env("JP_TUTOR_SILENCE", "1.2")) ?? 1.2
    /// Give up waiting for speech after this many seconds of initial silence.
    static let noSpeechTimeout: Double = 8.0
    /// Hard cap on a single utterance.
    static let maxUtterance: Double = 30.0
}
