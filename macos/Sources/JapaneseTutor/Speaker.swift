import AVFoundation
import Foundation

/// Text-to-speech that handles mixed English/Japanese replies: it splits the
/// text into runs by script and speaks each run with the right voice — Kyoko
/// for Japanese, an English voice for English — so a sentence like
/// "「おはよう」means good morning" sounds natural instead of Kyoko mangling
/// the English.
@MainActor
final class Speaker: NSObject, AVSpeechSynthesizerDelegate {
    private let synth = AVSpeechSynthesizer()
    private var continuation: CheckedContinuation<Void, Never>?
    private let japaneseVoice: AVSpeechSynthesisVoice?
    private let englishVoice: AVSpeechSynthesisVoice?

    override init() {
        let voices = AVSpeechSynthesisVoice.speechVoices()
        let ja = voices.filter { $0.language == "ja-JP" }
        let en = voices.filter { $0.language.hasPrefix("en") }
        japaneseVoice = ja.first(where: { $0.name.contains(Config.voicePreference) }) ?? ja.first
        englishVoice = en.first(where: { $0.name.contains(Config.englishVoicePreference) }) ?? en.first
        super.init()
        synth.delegate = self
    }

    /// Speak a possibly-mixed-language string, awaiting completion.
    func speak(_ text: String, difficulty: Int) async {
        for run in Self.segment(text) {
            await speakRun(run, difficulty: difficulty)
        }
    }

    func stop() {
        if synth.isSpeaking {
            synth.stopSpeaking(at: .immediate)
        }
        resume()
    }

    private func speakRun(_ run: Run, difficulty: Int) async {
        let trimmed = run.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            self.continuation = cont
            let utterance = AVSpeechUtterance(string: run.text)
            if run.isJapanese {
                utterance.voice = japaneseVoice
                utterance.rate = Self.japaneseRate(for: difficulty)
            } else {
                utterance.voice = englishVoice
                utterance.rate = 0.5  // normal, clear pace for explanations
            }
            synth.speak(utterance)
        }
    }

    /// Slow Japanese for beginners, up to normal at high difficulty.
    static func japaneseRate(for difficulty: Int) -> Float {
        let d = Float(max(1, min(10, difficulty)))
        return 0.38 + 0.12 * (d - 1) / 9
    }

    // MARK: - Script segmentation

    struct Run {
        var text: String
        var isJapanese: Bool
    }

    /// Split text into consecutive runs of Japanese vs non-Japanese script.
    /// Neutral characters (spaces, digits, ASCII punctuation) stick to the
    /// current run so we don't fragment speech.
    static func segment(_ text: String) -> [Run] {
        var runs: [Run] = []
        var current = ""
        var currentIsJapanese: Bool?

        for scalar in text.unicodeScalars {
            let classification = classify(scalar)
            switch classification {
            case .neutral:
                current.unicodeScalars.append(scalar)
            case .japanese, .latin:
                let isJP = (classification == .japanese)
                if currentIsJapanese == nil {
                    currentIsJapanese = isJP
                    current.unicodeScalars.append(scalar)
                } else if currentIsJapanese == isJP {
                    current.unicodeScalars.append(scalar)
                } else {
                    if !current.isEmpty { runs.append(Run(text: current, isJapanese: currentIsJapanese!)) }
                    current = String(scalar)
                    currentIsJapanese = isJP
                }
            }
        }
        if !current.isEmpty {
            runs.append(Run(text: current, isJapanese: currentIsJapanese ?? false))
        }
        return runs
    }

    private enum Script { case japanese, latin, neutral }

    private static func classify(_ s: Unicode.Scalar) -> Script {
        let v = s.value
        // Hiragana, Katakana, CJK, halfwidth katakana, Japanese punctuation.
        if (0x3040...0x30FF).contains(v)      // hiragana + katakana
            || (0x3400...0x4DBF).contains(v)  // CJK ext A
            || (0x4E00...0x9FFF).contains(v)  // CJK unified
            || (0xFF66...0xFF9D).contains(v)  // halfwidth katakana
            || (0x3000...0x303F).contains(v)  // CJK symbols & punctuation
            || (0xFF01...0xFF60).contains(v)  // fullwidth forms
        {
            return .japanese
        }
        if (0x41...0x5A).contains(v) || (0x61...0x7A).contains(v) || (0xC0...0x24F).contains(v) {
            return .latin
        }
        return .neutral
    }

    private func resume() {
        continuation?.resume()
        continuation = nil
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.resume() }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.resume() }
    }
}
