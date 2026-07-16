import AVFoundation
import Foundation
import SwiftUI

/// Orchestrates the whole conversation: permissions, loading the speech model,
/// the greeting, and the hands-free listen → transcribe → think → speak loop.
@MainActor
final class ConversationController: ObservableObject {
    @Published private(set) var state: AppState = .idle
    @Published private(set) var active = false
    @Published private(set) var difficulty: Int
    @Published var immersion: Int {
        didSet {
            ollama.immersion = immersion
            session.immersion = immersion
            session.save()
        }
    }
    @Published private(set) var current: Turn?
    @Published private(set) var statusMessage = "Click to start a conversation."

    private let capture = AudioCapture()
    private let transcriber: Transcriber
    private let speaker = Speaker()
    private var ollama: OllamaClient
    private var session: Session
    private var loop: Task<Void, Never>?

    init() {
        let saved = Session.load()
        session = saved
        difficulty = saved.difficulty
        immersion = saved.immersion
        ollama = OllamaClient(level: Config.level, difficulty: saved.difficulty, immersion: saved.immersion)
        transcriber = Transcriber(model: Config.whisperModel)
    }

    func toggle() {
        if active { stop() } else { start() }
    }

    private func start() {
        active = true
        loop = Task { await run() }
    }

    func stop() {
        active = false
        capture.cancel()
        speaker.stop()
        loop?.cancel()
        loop = nil
        state = .idle
        statusMessage = "Stopped. Click to start again."
    }

    private func setError(_ message: String) {
        state = .error(message)
        statusMessage = message
        active = false
    }

    private func run() async {
        let (ready, message) = await OllamaClient.checkReady()
        guard ready else { setError(message); return }

        let micOK = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            AVCaptureDevice.requestAccess(for: .audio) { cont.resume(returning: $0) }
        }
        guard micOK else {
            setError("Grant Microphone access in System Settings › Privacy & Security.")
            return
        }

        state = .thinking
        statusMessage = "Loading the speech model (first run downloads it)…"
        do {
            try await transcriber.load()
        } catch {
            setError("Couldn't load the speech model: \(error.localizedDescription)")
            return
        }

        // Opening greeting.
        statusMessage = "あい is greeting you…"
        do {
            let turn = try await ollama.opening()
            current = turn
            difficulty = ollama.difficulty
            guard active else { return }
            state = .speaking
            await speaker.speak(turn.reply, difficulty: difficulty)
        } catch {
            setError(error.localizedDescription)
            return
        }

        // Hands-free conversation loop.
        while active && !Task.isCancelled {
            state = .listening
            statusMessage = "Listening… speak in English or Japanese."

            let samples: [Float]
            do {
                samples = try await capture.captureUtterance()
            } catch {
                if !active { break }
                statusMessage = "Mic error: \(error.localizedDescription)"
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                continue
            }
            guard active else { break }
            if samples.isEmpty { continue }

            state = .thinking
            statusMessage = "Transcribing…"
            let heard: String
            let language: String
            do {
                (heard, language) = try await transcriber.transcribe(samples)
            } catch {
                statusMessage = "Transcription error: \(error.localizedDescription)"
                continue
            }
            let text = heard.trimmingCharacters(in: .whitespacesAndNewlines)
            if text.isEmpty { continue }
            guard active else { break }

            statusMessage = "Thinking…"
            do {
                let turn = try await ollama.respond(text, userLanguage: language)
                current = turn
                difficulty = ollama.difficulty
                session.record(userText: text, turn: turn)
                session.save()

                guard active else { break }
                state = .speaking
                statusMessage = "あい is speaking…"
                await speaker.speak(turn.reply, difficulty: difficulty)
            } catch {
                statusMessage = "Error: \(error.localizedDescription)"
                try? await Task.sleep(nanoseconds: 1_500_000_000)
            }
        }

        state = .idle
        session.save()
    }
}
