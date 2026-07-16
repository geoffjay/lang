"""
Central configuration for the Japanese conversation tutor.

Everything you might want to tweak lives here. Values can also be overridden
with environment variables so you don't have to edit code.
"""
import os

# ---------------------------------------------------------------------------
# Ollama (the "brain" that generates replies)
# ---------------------------------------------------------------------------
OLLAMA_HOST = os.environ.get("OLLAMA_HOST", "http://127.0.0.1:11434")
OLLAMA_MODEL = os.environ.get("JP_TUTOR_MODEL", "qwen2.5:7b")

# ---------------------------------------------------------------------------
# Speech-to-text (Whisper)
# ---------------------------------------------------------------------------
# Model sizes, smallest -> largest: tiny, base, small, medium, large-v3
# "small" is a good speed/accuracy balance for Japanese on a Mac CPU.
WHISPER_MODEL = os.environ.get("JP_TUTOR_WHISPER", "small")
WHISPER_COMPUTE_TYPE = os.environ.get("JP_TUTOR_WHISPER_COMPUTE", "int8")
SAMPLE_RATE = 16000  # Whisper expects 16 kHz mono audio

# ---------------------------------------------------------------------------
# Text-to-speech (macOS `say`)
# ---------------------------------------------------------------------------
# Run `say -v '?' | grep ja_JP` to see all Japanese voices.
TTS_VOICE = os.environ.get("JP_TUTOR_VOICE", "Kyoko")
# Words per minute. Beginners benefit from slower speech; this is scaled down
# further at low difficulty (see tutor/tts.py).
TTS_BASE_RATE = int(os.environ.get("JP_TUTOR_RATE", "150"))

# ---------------------------------------------------------------------------
# Learner profile
# ---------------------------------------------------------------------------
# One of: "complete beginner", "some basics", "intermediate"
LEVEL = os.environ.get("JP_TUTOR_LEVEL", "some basics")

# How much on-screen help to show:
#   "full"           -> Japanese + romaji + English (+ corrections)
#   "japanese_english" -> Japanese + English
#   "japanese"       -> Japanese text only
#   "audio"          -> no text at all
TEXT_SUPPORT = os.environ.get("JP_TUTOR_TEXT", "full")

# Starting difficulty on a 1-10 scale (only used the very first time you run;
# after that the saved value in data/session.json is used).
START_DIFFICULTY = int(os.environ.get("JP_TUTOR_DIFFICULTY", "3"))

# ---------------------------------------------------------------------------
# Persistence
# ---------------------------------------------------------------------------
DATA_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "data")
SESSION_FILE = os.path.join(DATA_DIR, "session.json")
