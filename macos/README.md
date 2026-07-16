# Japanese Tutor — macOS menu-bar app

A native, hands-free version of the conversation tutor. Click the menu-bar icon
to start talking; it listens, detects when you pause, replies in Japanese, and
speaks the reply back — then listens again. Click again to stop. No terminal,
no Enter presses.

Fully native, no Python:

| Stage | Technology |
|-------|-----------|
| Speech → text | Apple **SFSpeechRecognizer** (Japanese, on-device when available) |
| Reply + difficulty | **Ollama** `qwen2.5:7b` over HTTP (structured JSON) |
| Text → speech | **AVSpeechSynthesizer** (Kyoko, same voices as `say`) |
| UI | **SwiftUI** `MenuBarExtra` |

The menu-bar icon reflects state: 💬 idle · 〰️ listening · … thinking · 🔊 speaking.

## Requirements

- macOS 14+ (built on 26.x, Apple Silicon)
- Swift toolchain (Command Line Tools is enough — no full Xcode needed)
- [Ollama](https://ollama.com) running with `qwen2.5:7b` pulled
  (the Python project's `../setup.sh` already did this)

## Build & run

```bash
cd macos
./run.sh        # builds the .app if needed, then launches it
```

On the **first conversation** macOS will ask for **Microphone** and **Speech
Recognition** access — click Allow. If you miss the prompt, enable them under
System Settings › Privacy & Security.

Make sure Ollama is up first (`ollama serve`); the app tells you in its panel if
it can't reach it.

## Configuration

Same knobs as the Python version, via environment variables. Because a
double-clicked `.app` doesn't inherit your shell environment, set them when
launching from a terminal:

```bash
JP_TUTOR_TEXT=japanese ./run.sh      # less on-screen help
JP_TUTOR_VOICE=Reed ./run.sh         # different Japanese voice
JP_TUTOR_SILENCE=1.8 ./run.sh        # wait longer before treating a pause as "done"
JP_TUTOR_MODEL=qwen2.5:3b ./run.sh   # faster brain
```

## How turn-taking works

While in a conversation the app runs a loop: **listen → think → speak → listen**.
It uses a silence timer (`JP_TUTOR_SILENCE`, default 1.3s) to decide you've
finished your turn, so you never press anything. It stops listening while あい is
speaking so it doesn't hear itself.

## Progress

Difficulty (1–10) and a transcript persist in
`~/Library/Application Support/JapaneseTutor/session.json`, so each session
picks up where the last left off. Delete that file to reset.

## Notes / limitations

- **On-device recognition:** if the Japanese on-device speech asset isn't
  installed, macOS falls back to server-based recognition (needs a network
  connection). Everything else stays local.
- This is an ad-hoc-signed local build. Rebuilding changes the signature, so
  macOS may re-ask for mic/speech permission after a rebuild.
