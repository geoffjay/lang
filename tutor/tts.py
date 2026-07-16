"""
Text-to-speech via macOS `say`, which ships with high-quality Japanese voices.

`say` plays straight to the speakers, so there are no temp files or extra deps.
"""
import subprocess

import config


def _rate_for_difficulty(difficulty: int) -> int:
    """Speak slower at low difficulty, up to the base rate at high difficulty."""
    # difficulty 1 -> ~60% speed, difficulty 10 -> 100% speed.
    factor = 0.6 + 0.4 * (max(1, min(10, difficulty)) - 1) / 9
    return max(90, int(config.TTS_BASE_RATE * factor))


def speak(text: str, difficulty: int = 5) -> None:
    if not text.strip():
        return
    rate = _rate_for_difficulty(difficulty)
    try:
        subprocess.run(
            ["say", "-v", config.TTS_VOICE, "-r", str(rate), text],
            check=True,
        )
    except FileNotFoundError:
        print("  (couldn't find `say`; are you on macOS?)")
    except subprocess.CalledProcessError as exc:
        print(f"  (TTS error: {exc})")
