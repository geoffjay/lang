# Japanese Tutor — macOS menu-bar app

A native, hands-free **bilingual** conversation tutor. Click the menu-bar icon
to start; it listens, detects when you pause, and replies — **in English,
Japanese, or a mix, decided per turn**. Ask "where do I start?" in English and
you get an English answer; practice in Japanese and it responds in Japanese.
Click again to stop.

Fully native, no Python:

| Stage | Technology |
|-------|-----------|
| Speech → text | **WhisperKit** (on-device Whisper, **auto-detects English vs Japanese**, even mixed) |
| End-of-turn | Energy-based voice-activity detection (our own silence timer) |
| Reply + language choice | **Ollama** `qwen2.5:7b` — decides `intent` → `reply_language` → reply |
| Text → speech | **AVSpeechSynthesizer**, split by script: Kyoko for Japanese, an English voice for English |
| UI | **SwiftUI** `MenuBarExtra` with an English↔Japanese immersion slider |

The menu-bar icon reflects state: 💬 idle · 〰️ listening · … thinking · 🔊 speaking.

## Why WhisperKit instead of Apple's Speech framework

`SFSpeechRecognizer` is locked to a single locale, so when you spoke English it
tried to force it into Japanese and produced garbage. WhisperKit auto-detects
the language (and handles code-switching within a sentence), which is what makes
a genuinely bilingual learning conversation possible.

## The immersion slider

A slider in the menu (0 = English-first teaching … 100 = Japanese immersion)
sets how much Japanese あい leans on **during practice**. Meta/learning questions
asked in English are always answered in English regardless — the dial doesn't
override your need to understand.

## Requirements

- macOS 14+ (built on 26.x, Apple Silicon)
- Swift toolchain (Command Line Tools is enough — no full Xcode)
- [Ollama](https://ollama.com) running with `qwen2.5:7b`

## Build & run

```bash
cd macos
./run.sh        # builds the .app if needed, then launches it
```

- **First conversation:** macOS asks for **Microphone** access — click Allow.
  (No Speech Recognition prompt anymore — Whisper runs on-device.)
- **First transcription** downloads the Whisper model (`base`, a few hundred MB)
  to `~/Library/Application Support/…/huggingface`. Offline after that.
- Make sure Ollama is up (`ollama serve`); the panel tells you if it can't reach it.

## Configuration (environment variables)

```bash
JP_TUTOR_WHISPER=small ./run.sh      # more accurate STT (slower)
JP_TUTOR_IMMERSION=60 ./run.sh       # starting immersion %
JP_TUTOR_VAD=0.02 ./run.sh           # raise if it cuts you off / noisy mic
JP_TUTOR_SILENCE=1.6 ./run.sh        # wait longer before ending your turn
JP_TUTOR_EN_VOICE=Alex ./run.sh      # English TTS voice
JP_TUTOR_VOICE=Reed ./run.sh         # Japanese TTS voice
JP_TUTOR_MODEL=qwen2.5:3b ./run.sh   # faster brain
```

## How turn-taking works

While in a conversation: **listen → transcribe → think → speak → listen**. An
energy-based silence timer (`JP_TUTOR_SILENCE`, default 1.2s) decides you've
finished, so you never press anything. It stops listening while あい speaks so it
doesn't hear itself.

## Progress

Difficulty (1–10) and immersion persist in
`~/Library/Application Support/JapaneseTutor/session.json`. Delete it to reset.

## Notes / limitations

- Ad-hoc-signed local build; rebuilding changes the signature, so macOS may
  re-ask for mic permission after a rebuild.
- `qwen2.5:7b` reliably follows the language rules thanks to two built-in
  few-shot examples + low temperature. A smaller model may be less consistent.
