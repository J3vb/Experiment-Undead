"""Generate the original zombie death, footstep and Bloater gurgle sounds into assets/audio.

Run: python tools/assets/zombie_sfx.py assets/audio   (needs numpy)
"""

import argparse
from pathlib import Path

import numpy as np
from sfx_common import SAMPLE_RATE, lowpass, save_wav


def timeline(duration: float) -> np.ndarray:
    return np.arange(int(SAMPLE_RATE * duration)) / SAMPLE_RATE


def voice(time: np.ndarray, pitch: np.ndarray) -> np.ndarray:
    phase = 2 * np.pi * np.cumsum(pitch) / SAMPLE_RATE
    return np.sign(np.sin(phase)) * 0.5 + np.sin(phase * 2) * 0.3 + np.sin(phase * 3) * 0.2


def bubbles(rng: np.random.Generator, time: np.ndarray, rate: float) -> np.ndarray:
    out = np.zeros(len(time))
    for start in np.sort(rng.random(int(rate * time[-1])) * time[-1]):
        local = time - start
        mask = local >= 0
        frequency = 180 + rng.random() * 320
        out[mask] += np.sin(2 * np.pi * frequency * local[mask] * (1 + local[mask] * 6)) * np.exp(-local[mask] * 60)
    return out


def shambler_death(seed: int) -> np.ndarray:
    rng = np.random.default_rng(seed)
    duration = 1.1 + rng.random() * 0.3
    time = timeline(duration)
    pitch = (95 + rng.random() * 20) * (1 - 0.45 * time / duration)
    groan = lowpass(voice(time, pitch), 0.1) * np.sin(np.pi * np.minimum(time / duration, 1.0)) ** 0.5
    gurgle = lowpass(bubbles(rng, time, 22), 0.4) * np.clip((time - 0.35) / 0.4, 0, 1) * 0.5
    breath = lowpass(rng.standard_normal(len(time)), 0.15) * np.exp(-time * 2.5) * 0.4
    thud_time = np.maximum(time - duration * 0.78, 0)
    thud = np.sin(2 * np.pi * 60 * thud_time) * np.exp(-thud_time * 18) * (time > duration * 0.78) * 0.8
    return groan + gurgle + breath + thud


def bloater_death(seed: int) -> np.ndarray:
    rng = np.random.default_rng(seed)
    time = timeline(1.6)
    burst = lowpass(rng.standard_normal(len(time)), 0.35) * np.exp(-time * 14) * 1.6
    thump = np.sin(2 * np.pi * (48 * time - 10 * time**2)) * np.exp(-time * 9) * 1.2
    splatter = lowpass(bubbles(rng, time, 45), 0.5) * np.exp(-time * 3) * 0.6
    hiss = lowpass(rng.standard_normal(len(time)), 0.7) * np.clip(time / 0.2, 0, 1) * np.exp(-time * 1.4) * 0.25
    return burst + thump + splatter + hiss


def bloater_gurgle(seed: int) -> np.ndarray:
    rng = np.random.default_rng(seed)
    duration = 1.8 + rng.random() * 0.8
    time = timeline(duration)
    pitch = (52 + rng.random() * 10) * (1 + 0.1 * np.sin(2 * np.pi * 0.7 * time + rng.random() * 6))
    belly = lowpass(voice(time, pitch), 0.06)
    slosh = lowpass(bubbles(rng, time, 14), 0.3) * 0.7
    envelope = np.sin(np.pi * time / duration) ** 0.7
    return (belly + slosh) * envelope


def shambler_step(seed: int) -> np.ndarray:
    rng = np.random.default_rng(seed)
    time = timeline(0.4)
    scrape = lowpass(rng.standard_normal(len(time)), 0.35) * np.exp(-((time - 0.16) ** 2) / 0.006) * 0.6
    heel = lowpass(rng.standard_normal(len(time)), 0.2) * np.exp(-time * 55)
    thump = np.sin(2 * np.pi * (85 + rng.random() * 20) * time) * np.exp(-time * 40) * 0.7
    return heel + scrape + thump


def bloater_step(seed: int) -> np.ndarray:
    rng = np.random.default_rng(seed)
    time = timeline(0.45)
    thud = np.sin(2 * np.pi * (52 + rng.random() * 8) * time) * np.exp(-time * 14) * 1.4
    body = lowpass(rng.standard_normal(len(time)), 0.1) * np.exp(-time * 25) * 1.2
    splat = lowpass(bubbles(rng, time, 30), 0.5) * np.exp(-time * 12) * 0.5
    return thud + body + splat


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path)
    output: Path = parser.parse_args().output
    for index in range(1, 4):
        save_wav(output / f"zombie_death_{index}.wav", shambler_death(300 + index))
        save_wav(output / f"bloater_gurgle_{index}.wav", bloater_gurgle(400 + index))
    for index in range(1, 3):
        save_wav(output / f"bloater_death_{index}.wav", bloater_death(500 + index))
    for index in range(1, 5):
        save_wav(output / f"zombie_step_{index}.wav", shambler_step(600 + index))
        save_wav(output / f"bloater_step_{index}.wav", bloater_step(700 + index))


if __name__ == "__main__":
    main()
