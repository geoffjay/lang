import Foundation

/// Persisted progress so the tutor "grows with you" across launches.
struct Session: Codable {
    var difficulty: Int
    var immersion: Int
    var totalTurns: Int
    var transcript: [Entry]

    struct Entry: Codable {
        let time: String
        let heard: String
        let reply: String
    }

    private static var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("JapaneseTutor", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("session.json")
    }

    static func load() -> Session {
        guard let data = try? Data(contentsOf: fileURL),
              let session = try? JSONDecoder().decode(Session.self, from: data)
        else {
            return Session(
                difficulty: Config.startDifficulty,
                immersion: Config.startImmersion,
                totalTurns: 0,
                transcript: []
            )
        }
        return session
    }

    mutating func record(userText: String, turn: Turn) {
        totalTurns += 1
        difficulty = turn.newDifficulty
        let stamp = ISO8601DateFormatter().string(from: Date())
        transcript.append(Entry(time: stamp, heard: userText, reply: turn.reply))
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        try? data.write(to: Self.fileURL)
    }
}
