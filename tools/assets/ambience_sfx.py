"""Generate the original Halcyon Labs ambience beds and one-shots into assets/audio/ambience.

Run: python tools/assets/ambience_sfx.py assets/audio/ambience   (needs numpy and ffmpeg)
Beds are seamless 20 s Ogg loops; one-shots are short WAVs.
"""

import argparse
import subprocess
import wave
from pathlib import Path

import numpy as np

SAMPLE_RATE = 44100
LOOP_SECONDS = 20.0
FADE_SECONDS = 2.0


def lowpass(samples: np.ndarray, amount: float) -> np.ndarray:
    filtered = np.zeros_like(samples)
    value = 0.0
    for index, sample in enumerate(samples):
        value += amount * (sample - value)
        filtered[index] = value
    return filtered


def timeline(duration: float) -> np.ndarray:
    return np.arange(int(SAMPLE_RATE * duration)) / SAMPLE_RATE


def hum(frequency: float, time: np.ndarray) -> np.ndarray:
    # Whole cycles per loop keep tones continuous across the loop point.
    return np.sin(2 * np.pi * round(frequency * LOOP_SECONDS) / LOOP_SECONDS * time)


def seamless(samples: np.ndarray) -> np.ndarray:
    """Fold the extra FADE_SECONDS at the end over the start so the loop has no seam."""
    length = int(SAMPLE_RATE * LOOP_SECONDS)
    fade = len(samples) - length
    ramp = np.linspace(0.0, 1.0, fade)
    looped = samples[:length].copy()
    looped[:fade] = samples[:fade] * ramp + samples[length:] * (1.0 - ramp)
    return looped


def noise_bed(seed: int, amount: float) -> np.ndarray:
    rng = np.random.default_rng(seed)
    return lowpass(rng.standard_normal(int(SAMPLE_RATE * (LOOP_SECONDS + FADE_SECONDS))), amount)


def base_bed() -> np.ndarray:
    time = timeline(LOOP_SECONDS)
    air = seamless(noise_bed(11, 0.02)) * 3
    buzz = sum(hum(60 * harmonic, time) / harmonic**1.5 for harmonic in (1, 2, 3, 5)) * 0.08
    return air + buzz


def corridor_bed() -> np.ndarray:
    time = timeline(LOOP_SECONDS)
    air = seamless(noise_bed(12, 0.04)) * 2
    tube = sum(hum(120 * harmonic, time) / harmonic for harmonic in (1, 2, 3, 4, 6)) * 0.12
    flutter = 1 + 0.3 * hum(0.25, time)
    return air + tube * flutter


def mess_hall_bed() -> np.ndarray:
    time = timeline(LOOP_SECONDS)
    rumble = seamless(noise_bed(13, 0.006)) * 8
    hvac = seamless(noise_bed(14, 0.08)) * (1 + 0.4 * hum(0.1, time))
    drone = (hum(48, time) + 0.5 * hum(96, time)) * 0.15
    return rumble + hvac + drone


def labs_bed() -> np.ndarray:
    rng = np.random.default_rng(15)
    time = timeline(LOOP_SECONDS)
    fans = seamless(noise_bed(16, 0.15)) + (hum(840, time) + 0.6 * hum(1260, time)) * 0.03
    bubbles = np.zeros(len(time))
    for start in rng.uniform(0, LOOP_SECONDS - 0.2, 70):
        index = int(start * SAMPLE_RATE)
        blip = timeline(0.06)
        frequency = rng.uniform(300, 700)
        sound = np.sin(2 * np.pi * (frequency * blip + 2500 * blip**2)) * np.exp(-blip * 70) * 0.25
        bubbles[index : index + len(sound)] += sound
    return fans + bubbles + hum(55, time) * 0.1


def drip() -> np.ndarray:
    time = timeline(0.5)
    plink = np.sin(2 * np.pi * (1400 * time + 1800 * time**2)) * np.exp(-time * 40)
    echo = np.roll(plink, int(0.11 * SAMPLE_RATE)) * 0.3
    return plink + echo


def vent_clang() -> np.ndarray:
    rng = np.random.default_rng(21)
    time = timeline(1.2)
    ring = sum(np.sin(2 * np.pi * 180 * ratio * time) * np.exp(-time * (3 + ratio * 2)) for ratio in (1, 2.7, 4.1))
    hit = lowpass(rng.standard_normal(len(time)), 0.3) * np.exp(-time * 30)
    return lowpass(ring + hit, 0.2)


def distant_groan() -> np.ndarray:
    rng = np.random.default_rng(22)
    time = timeline(1.8)
    pitch = 85 * (1 + 0.12 * np.sin(2 * np.pi * 0.9 * time) + 0.05 * rng.standard_normal(len(time)).cumsum() / 600)
    voice = np.sign(np.sin(2 * np.pi * np.cumsum(pitch) / SAMPLE_RATE)) * np.sin(np.pi * time / time[-1]) ** 2
    return lowpass(lowpass(voice, 0.04), 0.06)


def save_ogg(path: Path, samples: np.ndarray) -> None:
    samples = samples / (np.max(np.abs(samples)) + 1e-9) * 0.7
    pcm = (samples * 32767).astype("<i2").tobytes()
    command = ["ffmpeg", "-v", "error", "-y", "-fflags", "+bitexact", "-f", "s16le", "-ar", str(SAMPLE_RATE)]
    command += ["-ac", "1", "-i", "pipe:0", "-c:a", "libvorbis", "-q:a", "4", "-flags:a", "+bitexact", str(path)]
    subprocess.run(command, input=pcm, check=True)


def save_wav(path: Path, samples: np.ndarray) -> None:
    normalized = samples / (np.max(np.abs(samples)) + 1e-9) * 0.9
    with wave.open(str(path), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(SAMPLE_RATE)
        output.writeframes((normalized * 32767).astype(np.int16).tobytes())


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path)
    output: Path = parser.parse_args().output
    output.mkdir(parents=True, exist_ok=True)
    save_ogg(output / "halcyon_base.ogg", base_bed())
    save_ogg(output / "halcyon_corridor.ogg", corridor_bed())
    save_ogg(output / "halcyon_mess_hall.ogg", mess_hall_bed())
    save_ogg(output / "halcyon_labs.ogg", labs_bed())
    save_wav(output / "drip.wav", drip())
    save_wav(output / "vent_clang.wav", vent_clang())
    save_wav(output / "distant_groan.wav", distant_groan())


if __name__ == "__main__":
    main()
