# 日本語会話 — Japanese Conversation Tutor

A local, voice-driven Japanese conversation partner. You speak, it listens,
replies in Japanese, plays the reply back as audio, and gently corrects you —
and it gets harder as you get better. Everything runs on your machine.

## How it works

```
🎙  your voice
     │
     ▼
faster-whisper  ── speech → Japanese text (local, on CPU)
     │
     ▼
Ollama (qwen2.5:7b)  ── generates a reply + romaji + English + a correction,
     │                    and nudges the difficulty up or down each turn
     ▼
macOS `say` (Kyoko)  ── Japanese text → speech
     │
     ▼
🔊  the reply, spoken back to you
```

Your difficulty level and a full transcript are saved in `data/session.json`,
so each session picks up where the last one left off.

## Requirements

- macOS (uses the built-in `say` command for Japanese text-to-speech)
- [Ollama](https://ollama.com) installed
- Python 3.10+

## Setup (one time)

1. Start Ollama in its own terminal:
   ```bash
   ollama serve
   ```
2. Run setup (creates a virtualenv, installs deps, pulls the model):
   ```bash
   ./setup.sh
   ```

## Run

```bash
./run.sh
```

- **Enter** — start recording your voice
- **Enter** again — stop recording (it transcribes, replies, and speaks)
- **q** then Enter — quit

The first run also downloads the Whisper model (~500 MB for `small`), cached
under `~/.cache/huggingface`.

## Tuning

Everything is in `config.py`, and most values accept an environment-variable
override, e.g.:

```bash
JP_TUTOR_MODEL=qwen2.5:3b ./run.sh     # smaller/faster brain
JP_TUTOR_WHISPER=medium ./run.sh       # more accurate speech recognition
JP_TUTOR_VOICE=Reed ./run.sh           # different Japanese voice
JP_TUTOR_TEXT=japanese ./run.sh        # less on-screen help (more immersive)
```

List the Japanese voices you have with:
```bash
say -v '?' | grep ja_JP
```

## Reset your progress

Delete `data/session.json` to start over from the beginning.
```
