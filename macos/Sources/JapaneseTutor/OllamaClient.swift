import Foundation

/// One conversational turn as returned by the model (structured JSON).
///
/// The reply is no longer forced to be Japanese: it can be English, Japanese,
/// or a mix, decided per-turn by the model based on what you asked and the
/// immersion setting. Support fields (romaji, English gloss) let a learner
/// follow along.
struct Turn: Codable, Equatable {
    let userText: String        // cleaned-up version of what you said (your language)
    let userEnglish: String     // English meaning of it
    let correction: String      // gentle note if you attempted Japanese and slipped
    let intent: String          // meta_question | practice | teaching | greeting | other
    let replyLanguage: String   // english | japanese | mixed (the model's own decision)
    let reply: String           // what あい says — EN / JA / mixed
    let replyRomaji: String     // Hepburn reading for the Japanese parts ("" if none)
    let replyEnglish: String    // English meaning of the reply ("" if already English)
    let newDifficulty: Int

    enum CodingKeys: String, CodingKey {
        case userText = "user_text"
        case userEnglish = "user_english"
        case correction
        case intent
        case replyLanguage = "reply_language"
        case reply
        case replyRomaji = "reply_romaji"
        case replyEnglish = "reply_english"
        case newDifficulty = "new_difficulty"
    }
}

@MainActor
final class OllamaClient {
    let level: String
    private(set) var difficulty: Int
    var immersion: Int          // 0 = English-first teaching … 100 = Japanese immersion
    private var history: [[String: String]] = []

    init(level: String, difficulty: Int, immersion: Int) {
        self.level = level
        self.difficulty = difficulty
        self.immersion = immersion
    }

    func opening() async throws -> Turn {
        try await call(
            userInput: nil,
            userLanguage: nil,
            instruction: "Greet the learner warmly, briefly say you can talk in English "
                + "or Japanese and help them learn, and ask what they'd like to do or talk "
                + "about. Keep it short."
        )
    }

    func respond(_ userText: String, userLanguage: String) async throws -> Turn {
        try await call(userInput: userText, userLanguage: userLanguage, instruction: nil)
    }

    private func systemPrompt() -> String {
        """
        You are あい (Ai), a warm, patient BILINGUAL tutor helping an English speaker \
        learn Japanese. You DEFAULT TO THE LEARNER'S OWN LANGUAGE and only switch to \
        Japanese for practice/immersion. You both teach (explain, answer questions, \
        correct) and converse in Japanese for practice.

        Learner's level: \(level). Japanese difficulty: \(difficulty)/10 (1 = beginner \
        words and set phrases; 10 = natural native-paced Japanese). \
        Immersion dial: \(immersion)/100.

        Decide "intent", then "reply_language", then write "reply" IN THAT LANGUAGE:
        - meta_question (asking ABOUT Japanese or learning: where do I start, how do I \
        say X, what does Y mean, is this right) -> reply_language "english". Explain in \
        English; you may include Japanese examples with readings inside the reply.
        - practice (they speak or attempt Japanese) -> "japanese", or "mixed" with some \
        English scaffolding at low immersion.
        - teaching (introducing new material) -> "mixed": Japanese then a short English gloss.
        - greeting/other asked in English -> "english".

        HARD RULES:
        - If the learner spoke ENGLISH and is NOT actively practicing Japanese phrases, \
        reply in ENGLISH. NEVER answer an English question with an all-Japanese reply.
        - The immersion dial ONLY affects practice conversation, never meta questions. \
        Higher immersion → more Japanese during practice.
        - "reply" MUST be written in the language named by "reply_language".
        - The learner's message was auto-transcribed, so it may have errors — interpret \
        charitably.
        Keep replies short (1-3 sentences) and ask a follow-up to keep the talk going.

        Fields: "user_text" (cleaned up, their language), "user_english" (English \
        meaning; repeat if already English), "correction" (ONE short kind English note \
        if they attempted Japanese and erred, else ""), "intent", "reply_language", \
        "reply", "reply_romaji" (Hepburn for the Japanese portions, "" if none), \
        "reply_english" (English meaning of reply, "" if reply is already all English), \
        "new_difficulty" (+1 if they handled Japanese easily, -1 if they struggled, else \
        unchanged; 1-10, change by at most 1).

        Reply MUST be valid JSON matching the schema. No commentary outside it.
        """
    }

    /// Two example turns that anchor the language-choice behavior — a 7B model
    /// follows demonstrations far more reliably than instructions alone.
    private static let fewShot: [[String: String]] = [
        ["role": "user", "content": "I'm a complete beginner, how should I practice? [spoken language detected: en]"],
        ["role": "assistant", "content": #"{"user_text":"I'm a complete beginner, how should I practice?","user_english":"I'm a complete beginner, how should I practice?","correction":"","intent":"meta_question","reply_language":"english","reply":"Great question! Start with hiragana, then practice simple greetings out loud daily. Want to try a greeting together right now?","reply_romaji":"","reply_english":"","new_difficulty":3}"#],
        ["role": "user", "content": "おはよう [spoken language detected: ja]"],
        ["role": "assistant", "content": #"{"user_text":"おはよう","user_english":"Good morning","correction":"","intent":"practice","reply_language":"japanese","reply":"おはよう！よく眠れた？","reply_romaji":"Ohayou! Yoku nemureta?","reply_english":"Good morning! Did you sleep well?","new_difficulty":3}"#],
    ]

    private static let responseSchema: [String: Any] = [
        "type": "object",
        "properties": [
            "user_text": ["type": "string"],
            "user_english": ["type": "string"],
            "correction": ["type": "string"],
            "intent": ["type": "string", "enum": ["meta_question", "practice", "teaching", "greeting", "other"]],
            "reply_language": ["type": "string", "enum": ["english", "japanese", "mixed"]],
            "reply": ["type": "string"],
            "reply_romaji": ["type": "string"],
            "reply_english": ["type": "string"],
            "new_difficulty": ["type": "integer"],
        ],
        "required": [
            "user_text", "user_english", "correction", "intent", "reply_language",
            "reply", "reply_romaji", "reply_english", "new_difficulty",
        ],
    ]

    private func call(userInput: String?, userLanguage: String?, instruction: String?) async throws -> Turn {
        var messages: [[String: String]] = [["role": "system", "content": systemPrompt()]]
        messages += Self.fewShot
        messages += history
        if let userInput {
            let langHint = userLanguage.map { " [spoken language detected: \($0)]" } ?? ""
            messages.append(["role": "user", "content": userInput + langHint])
        } else if let instruction {
            messages.append(["role": "user", "content": "[system instruction] \(instruction)"])
        }

        let body: [String: Any] = [
            "model": Config.model,
            "messages": messages,
            "stream": false,
            "format": Self.responseSchema,
            "options": ["temperature": 0.3],
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
        history.append(["role": "assistant", "content": turn.reply])
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
