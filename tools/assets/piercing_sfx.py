"""Generate the original Fieldhand and Ironwood reports without changing existing sounds."""

import argparse
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


def report(duration: float, frequency: float, decay: float, seed: int) -> np.ndarray:
    rng = np.random.default_rng(seed)
    time = np.arange(int(SAMPLE_RATE * duration)) / SAMPLE_RATE
    crack = rng.standard_normal(len(time)) * np.exp(-time * 48)
    body = np.sin(2 * np.pi * (frequency * time - 25 * time**2)) * np.exp(-time * 11)
    tail = lowpass(rng.standard_normal(len(time)), 0.06) * np.exp(-time * decay)
    return crack * 1.2 + body * 1.6 + tail * 3


def save(path: Path, samples: np.ndarray) -> None:
    normalized = samples / (np.max(np.abs(samples)) + 1e-9) * 0.9
    with wave.open(str(path), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(SAMPLE_RATE)
        output.writeframes((normalized * 32767).astype(np.int16).tobytes())


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, default=Path(__file__).resolve().parents[2] / "assets/audio")
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    fieldhand = report(0.7, 100, 7, 151)
    start = int(0.3 * SAMPLE_RATE)
    time = np.arange(int(0.1 * SAMPLE_RATE)) / SAMPLE_RATE
    fieldhand[start : start + len(time)] += np.sin(2 * np.pi * 1100 * time) * np.exp(-time * 90) * 0.25
    save(args.out / "fieldhand_fire.wav", fieldhand)
    save(args.out / "ironwood_fire.wav", report(1.15, 55, 3.6, 152))


if __name__ == "__main__":
    main()
