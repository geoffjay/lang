"""
Microphone capture for push-to-talk recording.

We record raw float32 mono audio at 16 kHz straight into memory, which is
exactly what faster-whisper wants to consume, so no temp files are needed.
"""
import queue

import numpy as np
import sounddevice as sd

import config


class Recorder:
    """Records microphone audio between start() and stop() calls."""

    def __init__(self, sample_rate: int = config.SAMPLE_RATE):
        self.sample_rate = sample_rate
        self._q: "queue.Queue[np.ndarray]" = queue.Queue()
        self._stream: sd.InputStream | None = None

    def _callback(self, indata, frames, time_info, status):  # noqa: ARG002
        # `status` flags things like input overflow; we surface them but keep going.
        if status:
            print(f"  (audio warning: {status})")
        self._q.put(indata.copy())

    def start(self) -> None:
        # Drain anything left from a previous take.
        while not self._q.empty():
            self._q.get_nowait()
        self._stream = sd.InputStream(
            samplerate=self.sample_rate,
            channels=1,
            dtype="float32",
            callback=self._callback,
        )
        self._stream.start()

    def stop(self) -> np.ndarray:
        """Stop recording and return a 1-D float32 array of the whole take."""
        assert self._stream is not None, "stop() called before start()"
        self._stream.stop()
        self._stream.close()
        self._stream = None

        chunks = []
        while not self._q.empty():
            chunks.append(self._q.get_nowait())
        if not chunks:
            return np.zeros(0, dtype=np.float32)
        return np.concatenate(chunks, axis=0).flatten()
