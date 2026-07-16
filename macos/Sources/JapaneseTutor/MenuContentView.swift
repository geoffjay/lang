import SwiftUI

/// The panel shown when you click the menu-bar icon.
struct MenuContentView: View {
    @ObservedObject var controller: ConversationController

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            startStopButton
            statusLine

            if Config.textSupport != "audio", let turn = controller.current {
                Divider()
                transcript(turn)
            }

            Divider()
            Button("Quit") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.borderless)
        }
        .padding(14)
        .frame(width: 340)
    }

    private var header: some View {
        HStack {
            Text("日本語会話").font(.headline)
            Spacer()
            Text("Level \(controller.difficulty)/10")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var startStopButton: some View {
        Button(action: { controller.toggle() }) {
            Label(
                controller.active ? "Stop conversation" : "Start conversation",
                systemImage: controller.active ? "stop.circle.fill" : "mic.circle.fill"
            )
            .frame(maxWidth: .infinity)
        }
        .controlSize(.large)
        .buttonStyle(.borderedProminent)
        .tint(controller.active ? .red : .accentColor)
    }

    private var statusLine: some View {
        Text(controller.statusMessage)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private func transcript(_ turn: Turn) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if !turn.userJapanese.isEmpty {
                turnBlock(label: "あなた", color: .green,
                          jp: turn.userJapanese, romaji: turn.userRomaji, en: turn.userEnglish)
                if Config.textSupport == "full", !turn.correction.isEmpty {
                    Label(turn.correction, systemImage: "lightbulb.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            turnBlock(label: "あい", color: .blue,
                      jp: turn.replyJapanese, romaji: turn.replyRomaji, en: turn.replyEnglish)
        }
    }

    @ViewBuilder
    private func turnBlock(label: String, color: Color, jp: String, romaji: String, en: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2).bold().foregroundStyle(color)
            Text(jp).font(.body)
            if Config.textSupport == "full" {
                Text(romaji).font(.caption).foregroundStyle(.secondary)
            }
            if Config.textSupport == "full" || Config.textSupport == "japanese_english" {
                Text(en).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
