import Foundation

/// One conversational turn as returned by the model (structured JSON).
struct Turn: Codable, Equatable {
    let userJapanese: String
    let userRomaji: String
    let userEnglish: String
    let correction: String
    let replyJapanese: String
    let replyRomaji: String
    let replyEnglish: String
    let newDifficulty: Int

    enum CodingKeys: String, CodingKey {
        case userJapanese = "user_japanese"
        case userRomaji = "user_romaji"
        case userEnglish = "user_english"
        case correction
        case replyJapanese = "reply_japanese"
        case replyRomaji = "reply_romaji"
        case replyEnglish = "reply_english"
        case newDifficulty = "new_difficulty"
    }
}

/// Talks to the local Ollama server, forcing structured JSON output and
/// tracking conversation history + difficulty (ported from the Python version).
@MainActor
final class OllamaClient {
    let level: String
    private(set) var difficulty: Int
    private var history: [[String: String]] = []

    init(level: String, difficulty: Int) {
        self.level = level
        self.difficulty = difficulty
    }

    func opening() async throws -> Turn {
        try await call(
            userInput: nil,
            instruction: "Start the conversation with a friendly greeting and one "
                + "simple question to get things going."
        )
    }

    func respond(_ userJapanese: String) async throws -> Turn {
        try await call(userInput: userJapanese, instruction: nil)
    }

    private func systemPrompt() -> String {
        """
        You are あい (Ai), a warm, encouraging Japanese conversation partner for an \
        English speaker learning to SPEAK Japanese through casual voice conversation.

        Learner's self-described level: \(level).
        Current difficulty setting: \(difficulty) out of 10 (1 = absolute beginner \
        words and set phrases spoken slowly; 10 = fully natural native-paced speech).

        Follow these rules every turn:
        - Keep your spoken reply short: 1-2 natural sentences at difficulty \(difficulty).
        - Have a real conversation. React to what they said and ask ONE follow-up \
        question so the talk keeps flowing.
        - Match vocabulary and grammar to the current difficulty.
        - The learner's message was auto-transcribed from speech, so it may contain \
        recognition errors. Interpret it charitably.
        - In "correction", give ONE short, kind note in English about a mistake they \
        made. If they did fine, use an empty string. Never be harsh.
        - Adjust "new_difficulty": +1 if they handled this turn easily, -1 if they \
        clearly struggled, otherwise keep it the same. Stay within 1-10 and change by \
        at most 1 per turn.
        - "user_japanese" = a cleaned-up, correctly written version of what they meant \
        to say. "user_romaji"/"user_english" translate that.
        - "reply_japanese" MUST be written ENTIRELY in Japanese (kana/kanji only) with \
        no English words and no romaji mixed in — it is read aloud by a Japanese voice.
        - Romaji must be Hepburn style. Reply MUST be valid JSON matching the schema.
        """
    }

    private static let responseSchema: [String: Any] = [
        "type": "object",
        "properties": [
            "user_japanese": ["type": "string"],
            "user_romaji": ["type": "string"],
            "user_english": ["type": "string"],
            "correction": ["type": "string"],
            "reply_japanese": ["type": "string"],
            "reply_romaji": ["type": "string"],
            "reply_english": ["type": "string"],
            "new_difficulty": ["type": "integer"],
        ],
        "required": [
            "user_japanese", "user_romaji", "user_english", "correction",
            "reply_japanese", "reply_romaji", "reply_english", "new_difficulty",
        ],
    ]

    private func call(userInput: String?, instruction: String?) async throws -> Turn {
        var messages: [[String: String]] = [["role": "system", "content": systemPrompt()]]
        messages += history
        if let userInput {
            messages.append(["role": "user", "content": userInput])
        } else if let instruction {
            messages.append(["role": "user", "content": "[system instruction] \(instruction)"])
        }

        let body: [String: Any] = [
            "model": Config.model,
            "messages": messages,
            "stream": false,
            "format": Self.responseSchema,
            "options": ["temperature": 0.7],
        ]

        guard let url = URL(string: "\(Config.ollamaHost)/api/chat") else {
            throw TutorError.message("Bad Ollama URL")
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        req.timeoutInterval = 180

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            throw TutorError.message("Ollama returned an error response.")
        }

        guard
            let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let message = obj["message"] as? [String: Any],
            let content = message["content"] as? String,
            let contentData = content.data(using: .utf8)
        else {
            throw TutorError.message("Unexpected response shape from Ollama.")
        }

        let turn = try JSONDecoder().decode(Turn.self, from: contentData)

        if let userInput {
            history.append(["role": "user", "content": userInput])
        }
        history.append(["role": "assistant", "content": turn.replyJapanese])
        if history.count > 32 {
            history = Array(history.suffix(32))
        }
        difficulty = max(1, min(10, turn.newDifficulty))
        return turn
    }

    /// Verify Ollama is reachable and the configured model is installed.
    static func checkReady() async -> (Bool, String) {
        guard let url = URL(string: "\(Config.ollamaHost)/api/tags") else {
            return (false, "Bad Ollama URL.")
        }
        do {
            let (data, resp) = try await URLSession.shared.data(from: url)
            guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
                return (false, "Ollama isn't responding. Start it with: ollama serve")
            }
            let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let modelDicts = (obj?["models"] as? [[String: Any]]) ?? []
            let models: [String] = modelDicts.compactMap { $0["name"] as? String }
            let want = Config.model
            let wantBase = String(want.split(separator: ":").first ?? Substring(want))
            var matched = false
            for name in models {
                let base = String(name.split(separator: ":").first ?? Substring(name))
                if name == want || base == wantBase {
                    matched = true
                    break
                }
            }
            if !matched {
                return (false, "Model \(Config.model) not found. Run: ollama pull \(Config.model)")
            }
            return (true, "ok")
        } catch {
            return (false, "Can't reach Ollama at \(Config.ollamaHost). Start it with: ollama serve")
        }
    }
}

enum TutorError: LocalizedError {
    case message(String)
    var errorDescription: String? {
        switch self { case .message(let m): return m }
    }
}
