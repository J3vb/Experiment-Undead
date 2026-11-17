"""Generate the original player footstep and landing sounds into assets/audio.

Run: python tools/assets/footstep_sfx.py assets/audio   (needs numpy)
"""

import argparse
from pathlib import Path

import numpy as np
from sfx_common import SAMPLE_RATE, lowpass, save_wav


def timeline(duration: float) -> np.ndarray:
    return np.arange(int(SAMPLE_RATE * duration)) / SAMPLE_RATE


def concrete_step(seed: int) -> np.ndarray:
    rng = np.random.default_rng(seed)
    time = timeline(0.14)
    heel = lowpass(rng.standard_normal(len(time)), 0.25) * np.exp(-time * 70)
    scuff = lowpass(rng.standard_normal(len(time)), 0.5) * np.exp(-((time - 0.035) ** 2) / 0.0002) * 0.4
    thump = np.sin(2 * np.pi * (95 + rng.random() * 25) * time) * np.exp(-time * 45) * 0.8
    return heel + scuff + thump


def metal_step(seed: int) -> np.ndarray:
    rng = np.random.default_rng(seed)
    time = timeline(0.3)
    hit = lowpass(rng.standard_normal(len(time)), 0.45) * np.exp(-time * 90)
    ring = np.zeros(len(time))
    for partial, decay in ((1.0, 14), (1.59, 18), (2.43, 24), (3.71, 30)):
        frequency = (420 + rng.random() * 60) * partial
        ring += np.sin(2 * np.pi * frequency * time + rng.random() * 6) * np.exp(-time * decay) / partial
    thump = np.sin(2 * np.pi * 110 * time) * np.exp(-time * 40) * 0.6
    return hit + ring * 0.5 + thump


def landing() -> np.ndarray:
    rng = np.random.default_rng(31)
    time = timeline(0.35)
    thud = np.sin(2 * np.pi * (70 * time - 30 * time**2)) * np.exp(-time * 16)
    body = lowpass(rng.standard_normal(len(time)), 0.12) * np.exp(-time * 22) * 1.5
    gear = lowpass(rng.standard_normal(len(time)), 0.6) * np.exp(-((time - 0.06) ** 2) / 0.0008) * 0.25
    return thud * 1.4 + body + gear


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path)
    output: Path = parser.parse_args().output
    for index in range(1, 5):
        save_wav(output / f"footstep_concrete_{index}.wav", concrete_step(100 + index))
        save_wav(output / f"footstep_metal_{index}.wav", metal_step(200 + index))
    save_wav(output / "land.wav", landing())


if __name__ == "__main__":
    main()
