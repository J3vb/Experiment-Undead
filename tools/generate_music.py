## Generates original, sample-aligned music. Run: python tools/generate_music.py
## Requires numpy and ffmpeg (Vorbis encoder); writes assets/audio/music/.
from pathlib import Path
import subprocess

import numpy as np

SR = 44100
OUT = Path(__file__).resolve().parents[1] / "assets/audio/music"
rng = np.random.default_rng(73)


def tone(frequency, t, length):
    # Whole cycles keep the drone continuous across the loop boundary.
    return np.sin(2 * np.pi * round(frequency * length) / length * t)


def save(name, samples):
    samples *= 0.35 / max(np.max(np.abs(samples)), 1e-9)
    pcm = (samples * 32767).astype("<i2").tobytes()
    subprocess.run([
        "ffmpeg", "-v", "error", "-y", "-fflags", "+bitexact",
        "-f", "s16le", "-ar", str(SR), "-ac", "1", "-i", "pipe:0",
        "-fflags", "+bitexact", "-c:a", "libvorbis", "-q:a", "6", "-flags:a", "+bitexact",
        str(OUT / f"{name}.ogg"),
    ], input=pcm, check=True)


def add(loop, at, sound):
    indices = (int(round(at * SR)) + np.arange(len(sound))) % len(loop)
    loop[indices] += sound


def combat():
    beat = 60 / 100
    length = 64 * beat
    t = np.arange(round(length * SR)) / SR
    bed = sum(tone(f, t, length) * a for f, a in [(73.416, 1), (110, .25), (146.832, .2)])
    bed *= .6 + .15 * np.cos(2 * np.pi * t / length)
    bed += tone(36.708, t, length) * (.5 + .5 * np.cos(2 * np.pi * t / beat)) ** 4 * .4
    spectrum = np.fft.rfft(rng.standard_normal(len(t)))
    frequencies = np.fft.rfftfreq(len(t), 1 / SR)
    texture = np.fft.irfft(spectrum / (1 + (frequencies / 350) ** 4), n=len(t))
    bed += texture * (.3 + .2 * np.cos(2 * np.pi * t / (length / 2)))
    drive = np.zeros(len(t))
    s = np.arange(round(.5 * SR)) / SR
    attack = np.minimum(s * 1200, 1)
    kick = np.sin(2 * np.pi * (48 * s + 65 * (1 - np.exp(-s * 30)) / 30)) * np.exp(-s * 14)
    snare = (rng.standard_normal(len(s)) * .4 + np.sin(2 * np.pi * 853 * s) * .3) * np.exp(-s * 22)
    tick = rng.standard_normal(len(s)) * np.exp(-s * 160) * .18
    for step in range(128):
        add(drive, step * beat / 2, tick * attack)
        if step % 8 in (0, 3, 4):
            add(drive, step * beat / 2, kick * attack)
        if step % 8 in (2, 6):
            add(drive, step * beat / 2, snare * attack)
        note = [73.416, 73.416, 87.307, 65.406][(step // 8) % 4]
        bass = (np.sin(2 * np.pi * note * s) + .2 * np.sin(2 * np.pi * note * 2 * s))
        add(drive, step * beat / 2, bass * attack * np.exp(-s * 12) * .5)
    save("halcyon_bed", bed)
    save("halcyon_drive", drive)


def breather():
    length = 40 * 60 / 70
    t = np.arange(round(length * SR)) / SR
    pad = np.zeros(len(t))
    for f, a in [(130.813, 1), (164.814, .6), (195.998, .5), (261.626, .2)]:
        pad += tone(f, t, length) * a * (.65 + .35 * np.cos(2 * np.pi * t / length))
    save("breather", pad)


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    combat()
    breather()
