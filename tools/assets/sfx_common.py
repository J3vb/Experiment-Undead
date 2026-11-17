"""Shared helpers for the generated sound scripts in tools/assets."""

import wave
from pathlib import Path

import numpy as np

SAMPLE_RATE = 44100


def lowpass(samples: np.ndarray, amount: float) -> np.ndarray:
    filtered = np.zeros_like(samples)
    value = 0.0
    for index, sample in enumerate(samples):
        value += amount * (sample - value)
        filtered[index] = value
    return filtered


def save_wav(path: Path, samples: np.ndarray) -> None:
    normalized = samples / (np.max(np.abs(samples)) + 1e-9) * 0.9
    with wave.open(str(path), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(SAMPLE_RATE)
        output.writeframes((normalized * 32767).astype(np.int16).tobytes())
