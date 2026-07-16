import SwiftUI

/// The panel shown when you click the menu-bar icon.
struct MenuContentView: View {
    @ObservedObject var controller: ConversationController

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            startStopButton
            immersionControl
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
        .frame(width: 360)
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

    private var immersionControl: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text("English").font(.caption2).foregroundStyle(.secondary)
                Slider(
                    value: Binding(
                        get: { Double(controller.immersion) },
                        set: { controller.immersion = Int($0) }
                    ),
                    in: 0...100, step: 5
                )
                Text("日本語").font(.caption2).foregroundStyle(.secondary)
            }
            Text("Immersion \(controller.immersion)% — how much Japanese あい leans on.")
                .font(.caption2).foregroundStyle(.secondary)
        }
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
            if !turn.userText.isEmpty {
                turnBlock(
                    label: "あなた", color: .green,
                    main: turn.userText,
                    romaji: nil,
                    english: turn.userEnglish == turn.userText ? nil : turn.userEnglish
                )
                if Config.textSupport == "full", !turn.correction.isEmpty {
                    Label(turn.correction, systemImage: "lightbulb.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            turnBlock(
                label: "あい", color: .blue,
                main: turn.reply,
                romaji: turn.replyRomaji.isEmpty ? nil : turn.replyRomaji,
                english: turn.replyEnglish.isEmpty ? nil : turn.replyEnglish
            )
        }
    }

    @ViewBuilder
    private func turnBlock(label: String, color: Color, main: String, romaji: String?, english: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2).bold().foregroundStyle(color)
            Text(main).font(.body).fixedSize(horizontal: false, vertical: true)
            if Config.textSupport == "full", let romaji {
                Text(romaji).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if Config.textSupport == "full" || Config.textSupport == "japanese_english", let english {
                Text(english).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
