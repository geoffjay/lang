"""
Speech-to-text using faster-whisper, forced to Japanese.

The model is downloaded automatically the first time you run (a few hundred MB
for "small"), then cached under ~/.cache/huggingface.
"""
import numpy as np
from faster_whisper import WhisperModel

import config


class Transcriber:
    def __init__(self):
        print(f"Loading Whisper model '{config.WHISPER_MODEL}' (first run downloads it)...")
        self.model = WhisperModel(
            config.WHISPER_MODEL,
            device="cpu",
            compute_type=config.WHISPER_COMPUTE_TYPE,
        )

    def transcribe(self, audio: np.ndarray) -> str:
        """Return the recognized Japanese text (empty string if nothing heard)."""
        if audio.size == 0:
            return ""
        segments, _info = self.model.transcribe(
            audio,
            language="ja",
            beam_size=5,
            # A gentle nudge so Whisper leans toward natural conversational output.
            initial_prompt="日本語の会話です。",
        )
        text = "".join(segment.text for segment in segments).strip()
        return text
