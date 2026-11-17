"""Generate the original Fieldhand and Ironwood reports without changing existing sounds."""

import argparse
from pathlib import Path

import numpy as np
from sfx_common import SAMPLE_RATE, lowpass, save_wav


def report(duration: float, frequency: float, decay: float, seed: int) -> np.ndarray:
    rng = np.random.default_rng(seed)
    time = np.arange(int(SAMPLE_RATE * duration)) / SAMPLE_RATE
    crack = rng.standard_normal(len(time)) * np.exp(-time * 48)
    body = np.sin(2 * np.pi * (frequency * time - 25 * time**2)) * np.exp(-time * 11)
    tail = lowpass(rng.standard_normal(len(time)), 0.06) * np.exp(-time * decay)
    return crack * 1.2 + body * 1.6 + tail * 3


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, default=Path(__file__).resolve().parents[2] / "assets/audio")
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    fieldhand = report(0.7, 100, 7, 151)
    start = int(0.3 * SAMPLE_RATE)
    time = np.arange(int(0.1 * SAMPLE_RATE)) / SAMPLE_RATE
    fieldhand[start : start + len(time)] += np.sin(2 * np.pi * 1100 * time) * np.exp(-time * 90) * 0.25
    save_wav(args.out / "fieldhand_fire.wav", fieldhand)
    save_wav(args.out / "ironwood_fire.wav", report(1.15, 55, 3.6, 152))


if __name__ == "__main__":
    main()
