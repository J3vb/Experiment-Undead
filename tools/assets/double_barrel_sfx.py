"""Generate the two original double-barrel reports without rebuilding existing audio."""

import sys
import wave
from pathlib import Path

import numpy as np

RATE = 44100


def lowpass(samples: np.ndarray, coefficient: float) -> np.ndarray:
    result = np.zeros_like(samples)
    value = 0.0
    for index, sample in enumerate(samples):
        value += coefficient * (sample - value)
        result[index] = value
    return result


def report(duration: float, frequency: float, seed: int) -> np.ndarray:
    rng = np.random.default_rng(seed)
    time = np.arange(int(RATE * duration)) / RATE
    crack = lowpass(rng.standard_normal(len(time)), 0.35) * np.exp(-time * 28)
    punch = np.sin(2 * np.pi * (frequency * time - 28 * time**2)) * np.exp(-time * 10)
    hammer = np.sin(2 * np.pi * 1900 * time) * np.exp(-time * 175) * 0.18
    tail = lowpass(rng.standard_normal(len(time)), 0.06) * np.exp(-time * 6) * 2.3
    return crack * 1.6 + punch * 1.6 + hammer + tail


def save(path: Path, samples: np.ndarray) -> None:
    samples = samples / (np.max(np.abs(samples)) + 1e-9) * 0.9
    with wave.open(str(path), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes((samples * 32767).astype("<i2").tobytes())


def main() -> None:
    destination = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("assets/audio")
    destination.mkdir(parents=True, exist_ok=True)
    save(destination / "coachman_fire.wav", report(0.72, 58, 201))
    save(destination / "grubber_fire.wav", report(0.48, 74, 202))


if __name__ == "__main__":
    main()
