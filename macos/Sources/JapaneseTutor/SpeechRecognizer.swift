import AVFoundation
import Foundation
import Speech

/// Wraps SFSpeechRecognizer + AVAudioEngine to capture one spoken utterance at a
/// time. It reports the recognized Japanese text once you pause (silence-based
/// end-of-utterance detection), which is what lets the conversation flow
/// hands-free.
@MainActor
final class SpeechRecognizer {
    enum RecError: LocalizedError {
        case unavailable
        case engine(String)
        var errorDescription: String? {
            switch self {
            case .unavailable: return "Speech recognition is unavailable for Japanese."
            case .engine(let m): return "Audio engine error: \(m)"
            }
        }
    }

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP"))
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var continuation: CheckedContinuation<String, Error>?
    private var silenceTimer: Timer?
    private var latestTranscript = ""
    private var finished = false

    /// Ask for Microphone + Speech Recognition access. Returns true if both granted.
    func requestAuthorization() async -> Bool {
        let speechOK = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status == .authorized)
            }
        }
        let micOK = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                cont.resume(returning: granted)
            }
        }
        return speechOK && micOK
    }

    /// Listen until the speaker pauses, then return the recognized text.
    func listenForUtterance() async throws -> String {
        guard let recognizer, recognizer.isAvailable else { throw RecError.unavailable }

        latestTranscript = ""
        finished = false

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        self.request = request

        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            teardown()
            throw RecError.engine(error.localizedDescription)
        }

        return try await withCheckedThrowingContinuation { cont in
            self.continuation = cont
            self.task = recognizer.recognitionTask(with: request) { [weak self] result, error in
                // Extract value types before hopping to the main actor.
                let transcript = result?.bestTranscription.formattedString
                let isFinal = result?.isFinal ?? false
                let failed = error != nil
                DispatchQueue.main.async {
                    guard let self else { return }
                    if let transcript, !transcript.isEmpty {
                        self.latestTranscript = transcript
                        self.restartSilenceTimer()
                    }
                    if isFinal {
                        self.finish(.success(self.latestTranscript))
                    } else if failed {
                        // A recognition error with text already captured is fine;
                        // otherwise surface "nothing heard" as an empty result.
                        self.finish(.success(self.latestTranscript))
                    }
                }
            }
        }
    }

    /// Abort listening (e.g. the user pressed Stop).
    func cancel() {
        finish(.success(latestTranscript))
    }

    private func restartSilenceTimer() {
        silenceTimer?.invalidate()
        guard !latestTranscript.isEmpty else { return }
        silenceTimer = Timer.scheduledTimer(withTimeInterval: Config.silenceTimeout, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                self?.finish(.success(self?.latestTranscript ?? ""))
            }
        }
    }

    private func finish(_ result: Result<String, Error>) {
        guard !finished else { return }
        finished = true
        teardown()
        continuation?.resume(with: result)
        continuation = nil
    }

    private func teardown() {
        silenceTimer?.invalidate()
        silenceTimer = nil
        request?.endAudio()
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        task?.cancel()
        task = nil
        request = nil
    }
}
