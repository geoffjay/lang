import AVFoundation
import Foundation

/// Text-to-speech via AVSpeechSynthesizer, using a Japanese voice (Kyoko by
/// default — the same voices as the `say` command). Speaks slower at low
/// difficulty and awaits completion so the conversation loop can resume
/// listening only after the reply has finished playing.
@MainActor
final class Speaker: NSObject, AVSpeechSynthesizerDelegate {
    private let synth = AVSpeechSynthesizer()
    private var continuation: CheckedContinuation<Void, Never>?
    private let voice: AVSpeechSynthesisVoice?

    override init() {
        let jaVoices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == "ja-JP" }
        self.voice = jaVoices.first(where: { $0.name.contains(Config.voicePreference) }) ?? jaVoices.first
        super.init()
        synth.delegate = self
    }

    func speak(_ text: String, difficulty: Int) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            self.continuation = cont
            let utterance = AVSpeechUtterance(string: trimmed)
            utterance.voice = voice
            utterance.rate = Self.rate(for: difficulty)
            synth.speak(utterance)
        }
    }

    func stop() {
        if synth.isSpeaking {
            synth.stopSpeaking(at: .immediate)
        }
        resume()
    }

    /// Map difficulty 1–10 to a speech rate. Slow for beginners, up to the
    /// normal default at high difficulty.
    static func rate(for difficulty: Int) -> Float {
        let d = Float(max(1, min(10, difficulty)))
        return 0.38 + 0.12 * (d - 1) / 9  // 0.38 (slow) -> 0.50 (≈ default)
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
