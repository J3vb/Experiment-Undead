"""Generate the original Halcyon Labs ambience beds, one-shots and sound-spot loops into assets/audio/ambience.

Run: python tools/assets/ambience_sfx.py assets/audio/ambience   (needs numpy and ffmpeg)
Beds are seamless 20 s Ogg loops; one-shots are short WAVs.
"""

import argparse
import subprocess
from pathlib import Path

import numpy as np
from sfx_common import SAMPLE_RATE, lowpass, save_wav

LOOP_SECONDS = 20.0
FADE_SECONDS = 2.0


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


def highpass(samples: np.ndarray, amount: float) -> np.ndarray:
    return samples - lowpass(samples, amount)


def spark_crackle() -> np.ndarray:
    rng = np.random.default_rng(31)
    time = timeline(0.45)
    crackle = np.zeros(len(time))
    for start in np.sort(rng.uniform(0, 0.3, 14)):
        index = int(start * SAMPLE_RATE)
        snap = rng.standard_normal(int(0.02 * SAMPLE_RATE)) * np.exp(-timeline(0.02) * 300) * rng.uniform(0.3, 1)
        crackle[index : index + len(snap)] += snap
    buzz = np.sign(np.sin(2 * np.pi * 120 * time)) * np.exp(-time * 12) * 0.15
    return highpass(crackle, 0.2) + buzz


def steam_hiss() -> np.ndarray:
    time = timeline(LOOP_SECONDS)
    hiss = seamless(highpass(noise_bed(32, 0.9), 0.15))
    return hiss * (1 + 0.2 * hum(0.3, time) + 0.1 * hum(1.7, time))


def machine_hum() -> np.ndarray:
    time = timeline(LOOP_SECONDS)
    motor = sum(hum(50 * harmonic, time) / harmonic for harmonic in (1, 2, 3, 4, 6, 8)) * 0.3
    rattle = seamless(noise_bed(33, 0.05)) * (1 + 0.5 * hum(25, time)) * 0.6
    return motor * (1 + 0.05 * hum(0.5, time)) + rattle


def klaxon() -> np.ndarray:
    time = timeline(1.6)
    tone = np.where((time // 0.4) % 2 == 0, 440.0, 554.0)
    wave_ = np.sign(np.sin(2 * np.pi * np.cumsum(tone) / SAMPLE_RATE))
    envelope = np.clip(time / 0.02, 0, 1) * np.clip((time[-1] - time) / 0.2, 0, 1)
    return lowpass(lowpass(wave_, 0.15), 0.3) * envelope


def pa_crackle() -> np.ndarray:
    """A dead PA speaker keying up: a pop, two seconds of crackling carrier with a muffled hum, a pop."""
    rng = np.random.default_rng(35)
    time = timeline(2.2)
    carrier = highpass(lowpass(rng.standard_normal(len(time)), 0.35), 0.05) * 0.25
    gate = np.repeat(rng.uniform(0.2, 1.0, len(time) // 1100 + 1), 1100)[: len(time)]
    garble = lowpass(np.sign(np.sin(2 * np.pi * 180 * time)) * (0.5 + 0.5 * np.sin(2 * np.pi * 3.1 * time)), 0.05)
    crackle = np.zeros(len(time))
    for start in rng.uniform(0.1, 2.0, 40):
        index = int(start * SAMPLE_RATE)
        snap = rng.standard_normal(int(0.008 * SAMPLE_RATE)) * rng.uniform(0.3, 0.9)
        crackle[index : index + len(snap)] += snap
    envelope = np.clip(time / 0.03, 0, 1) * np.clip((time[-1] - time) / 0.08, 0, 1)
    pops = np.zeros(len(time))
    for at in (0.0, 2.1):
        index = int(at * SAMPLE_RATE)
        pop = timeline(0.03)
        pops[index : index + len(pop)] += np.sin(2 * np.pi * 90 * pop) * np.exp(-pop * 120) * 0.8
    return (carrier * gate + garble * 0.2 * gate + crackle * 0.4) * envelope + pops


def drip_loop() -> np.ndarray:
    rng = np.random.default_rng(34)
    length = int(SAMPLE_RATE * LOOP_SECONDS)
    loop = np.zeros(length)
    one = drip()
    starts = np.arange(0.4, LOOP_SECONDS - 0.6, 1.1)
    for start in starts + rng.uniform(-0.25, 0.25, len(starts)):
        index = int(start * SAMPLE_RATE)
        loop[index : index + len(one)] += one[: length - index] * rng.uniform(0.5, 1.0)
    return loop


def save_ogg(path: Path, samples: np.ndarray) -> None:
    samples = samples / (np.max(np.abs(samples)) + 1e-9) * 0.7
    pcm = (samples * 32767).astype("<i2").tobytes()
    command = ["ffmpeg", "-v", "error", "-y", "-fflags", "+bitexact", "-f", "s16le", "-ar", str(SAMPLE_RATE)]
    command += ["-ac", "1", "-i", "pipe:0", "-c:a", "libvorbis", "-q:a", "4", "-flags:a", "+bitexact", str(path)]
    subprocess.run(command, input=pcm, check=True)


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
    save_wav(output / "spark_crackle.wav", spark_crackle())
    save_wav(output / "klaxon.wav", klaxon())
    save_wav(output / "pa_crackle.wav", pa_crackle())
    save_ogg(output / "steam_hiss.ogg", steam_hiss())
    save_ogg(output / "machine_hum.ogg", machine_hum())
    save_ogg(output / "drip_loop.ogg", drip_loop())


if __name__ == "__main__":
    main()
