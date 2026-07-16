import Foundation
import SwiftUI

/// Orchestrates the whole conversation: permissions, the greeting, and the
/// hands-free listen → think → speak → listen loop until the user stops.
@MainActor
final class ConversationController: ObservableObject {
    @Published private(set) var state: AppState = .idle
    @Published private(set) var active = false
    @Published private(set) var difficulty: Int
    @Published private(set) var current: Turn?
    @Published private(set) var statusMessage = "Click to start a conversation."

    private let recognizer = SpeechRecognizer()
    private let speaker = Speaker()
    private var ollama: OllamaClient
    private var session: Session
    private var loop: Task<Void, Never>?

    init() {
        let saved = Session.load()
        session = saved
        difficulty = saved.difficulty
        ollama = OllamaClient(level: Config.level, difficulty: saved.difficulty)
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
        recognizer.cancel()
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

        let authorized = await recognizer.requestAuthorization()
        guard authorized else {
            setError("Grant Microphone and Speech Recognition access in System Settings › Privacy & Security.")
            return
        }

        // Opening greeting.
        state = .thinking
        statusMessage = "あい is greeting you…"
        do {
            let turn = try await ollama.opening()
            current = turn
            difficulty = ollama.difficulty
            guard active else { return }
            state = .speaking
            await speaker.speak(turn.replyJapanese, difficulty: difficulty)
        } catch {
            setError(error.localizedDescription)
            return
        }

        // Hands-free conversation loop.
        while active && !Task.isCancelled {
            state = .listening
            statusMessage = "Listening… just start talking."

            let heard: String
            do {
                heard = try await recognizer.listenForUtterance()
            } catch {
                if !active { break }
                statusMessage = "Didn't catch that — try again."
                continue
            }
            guard active else { break }

            let text = heard.trimmingCharacters(in: .whitespacesAndNewlines)
            if text.isEmpty { continue }

            state = .thinking
            statusMessage = "Thinking…"
            do {
                let turn = try await ollama.respond(text)
                current = turn
                difficulty = ollama.difficulty
                session.record(userText: text, turn: turn)
                session.save()

                guard active else { break }
                state = .speaking
                statusMessage = "あい is speaking…"
                await speaker.speak(turn.replyJapanese, difficulty: difficulty)
            } catch {
                statusMessage = "Error: \(error.localizedDescription)"
                try? await Task.sleep(nanoseconds: 1_500_000_000)
            }
        }

        state = .idle
        session.save()
    }
}
