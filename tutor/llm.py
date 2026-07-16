"""
The conversation brain: talks to a local Ollama model and returns a structured
turn (Japanese reply + romaji + English + gentle correction + difficulty).
"""
import json

import requests

import config

# We ask Ollama to constrain the model's output to this exact JSON shape.
RESPONSE_SCHEMA = {
    "type": "object",
    "properties": {
        "user_japanese": {"type": "string"},
        "user_romaji": {"type": "string"},
        "user_english": {"type": "string"},
        "correction": {"type": "string"},
        "reply_japanese": {"type": "string"},
        "reply_romaji": {"type": "string"},
        "reply_english": {"type": "string"},
        "new_difficulty": {"type": "integer"},
    },
    "required": [
        "user_japanese",
        "user_romaji",
        "user_english",
        "correction",
        "reply_japanese",
        "reply_romaji",
        "reply_english",
        "new_difficulty",
    ],
}

SYSTEM_TEMPLATE = """\
You are あい (Ai), a warm, encouraging Japanese conversation partner for an \
English speaker learning to SPEAK Japanese through casual voice conversation.

Learner's self-described level: {level}.
Current difficulty setting: {difficulty} out of 10 (1 = absolute beginner \
words and set phrases spoken slowly; 10 = fully natural native-paced speech).

Follow these rules every turn:
- Keep your spoken reply short: 1-2 natural sentences at difficulty {difficulty}.
- Have a real conversation. React to what they said and ask ONE follow-up \
question so the talk keeps flowing.
- Match vocabulary and grammar to the current difficulty. Do not show off with \
hard words at low difficulty.
- The learner's message was auto-transcribed from speech, so it may contain \
recognition errors or be a bit garbled. Interpret it charitably.
- In "correction", give ONE short, kind note in English about a mistake they \
made (grammar, word choice, or a more natural phrasing). If they did fine, use \
an empty string. Never be harsh.
- Adjust "new_difficulty": +1 if they handled this turn easily, -1 if they \
clearly struggled, otherwise keep it the same. Stay within 1-10 and change by \
at most 1 per turn.
- "user_japanese" = a cleaned-up, correctly written version of what they meant \
to say. "user_romaji"/"user_english" translate that.
- "reply_japanese" MUST be written ENTIRELY in Japanese (kana/kanji only) with \
no English words and no romaji mixed in — it is read aloud by a Japanese \
voice, so any English breaks it. Put English only in "reply_english".
- Romaji must be Hepburn style. Reply MUST be valid JSON matching the schema."""


class Conversation:
    def __init__(self, level: str, difficulty: int):
        self.level = level
        self.difficulty = difficulty
        # Rolling chat history of plain Japanese turns for natural context.
        self.history: list[dict] = []

    def _system_prompt(self) -> str:
        return SYSTEM_TEMPLATE.format(level=self.level, difficulty=self.difficulty)

    def opening_line(self) -> dict:
        """Generate a greeting to kick off the conversation (no user input yet)."""
        return self._call(
            user_japanese_input=None,
            instruction="Start the conversation with a friendly greeting and one "
            "simple question to get things going.",
        )

    def respond(self, user_japanese: str) -> dict:
        """Given what the learner said (in Japanese), produce the next turn."""
        return self._call(user_japanese_input=user_japanese)

    def _call(self, user_japanese_input: str | None, instruction: str | None = None) -> dict:
        messages = [{"role": "system", "content": self._system_prompt()}]
        messages.extend(self.history)

        if user_japanese_input is not None:
            messages.append({"role": "user", "content": user_japanese_input})
        elif instruction is not None:
            messages.append({"role": "user", "content": f"[system instruction] {instruction}"})

        payload = {
            "model": config.OLLAMA_MODEL,
            "messages": messages,
            "stream": False,
            "format": RESPONSE_SCHEMA,
            "options": {"temperature": 0.7},
        }

        resp = requests.post(
            f"{config.OLLAMA_HOST}/api/chat", json=payload, timeout=180
        )
        resp.raise_for_status()
        content = resp.json()["message"]["content"]
        turn = json.loads(content)

        # Persist the natural-language turn into history for future context.
        if user_japanese_input is not None:
            self.history.append({"role": "user", "content": user_japanese_input})
        self.history.append({"role": "assistant", "content": turn["reply_japanese"]})

        # Keep history from growing unbounded; keep the last ~16 turns.
        if len(self.history) > 32:
            self.history = self.history[-32:]

        # Clamp difficulty defensively in case the model gets creative.
        nd = int(turn.get("new_difficulty", self.difficulty))
        self.difficulty = max(1, min(10, nd))
        turn["new_difficulty"] = self.difficulty
        return turn


def check_ready() -> tuple[bool, str]:
    """Verify Ollama is up and the configured model is available."""
    try:
        resp = requests.get(f"{config.OLLAMA_HOST}/api/tags", timeout=5)
        resp.raise_for_status()
    except requests.RequestException as exc:
        return False, (
            f"Could not reach Ollama at {config.OLLAMA_HOST}.\n"
            f"  Start it with:  ollama serve\n  ({exc})"
        )
    models = [m["name"] for m in resp.json().get("models", [])]
    want = config.OLLAMA_MODEL
    # Accept an exact match, or the same name with/without a ":tag" suffix.
    matched = any(m == want or m.split(":")[0] == want.split(":")[0] for m in models)
    if not matched:
        return False, (
            f"Model '{want}' not found in Ollama.\n"
            f"  Pull it with:  ollama pull {want}\n"
            f"  Installed models: {', '.join(models) or '(none)'}"
        )
    return True, "ok"
