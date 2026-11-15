# Generates the placeholder sound effects in assets/audio (all original, no licences needed).
# Run: python3 tools/generate_sfx.py assets/audio   (needs numpy)
import os
import sys
import wave

import numpy as np

SR = 44100
out = sys.argv[1]
rng = np.random.default_rng(7)


def save(name, x):
    x = np.clip(x / (np.max(np.abs(x)) + 1e-9) * 0.9, -1, 1)
    with wave.open(os.path.join(out, name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())


def t(d):
    return np.arange(int(SR * d)) / SR


def lowpass(x, a):
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += a * (v - acc)
        y[i] = acc
    return y


# Rifle shot: sharp crack + low thump + noisy tail
tt = t(0.45)
crack = rng.standard_normal(len(tt)) * np.exp(-tt * 60)
thump = np.sin(2 * np.pi * (90 * tt - 60 * tt**2)) * np.exp(-tt * 18)
tail = lowpass(rng.standard_normal(len(tt)), 0.08) * np.exp(-tt * 7) * 2.5
save("rifle_fire.wav", crack * 0.9 + thump * 1.2 + tail)

# Dry fire click
tt = t(0.08)
save(
    "dry_fire.wav",
    rng.standard_normal(len(tt)) * np.exp(-tt * 300) + np.sin(2 * np.pi * 2400 * tt) * np.exp(-tt * 200) * 0.5,
)

# Reload: mag out click, pause, mag in clack, bolt
tt = t(1.4)
x = np.zeros(len(tt))


def click(at, freq, decay, amp):
    i = int(at * SR)
    n = int(0.12 * SR)
    s = np.arange(n) / SR
    seg = (rng.standard_normal(n) * 0.6 + np.sin(2 * np.pi * freq * s)) * np.exp(-s * decay) * amp
    x[i : i + n] += seg[: len(x) - i]


click(0.05, 1800, 90, 0.7)
click(0.75, 900, 60, 1.0)
click(1.15, 1400, 70, 0.9)
click(1.22, 2200, 120, 0.6)
save("reload.wav", x)

# Hitmarker tick
tt = t(0.06)
save("hitmarker.wav", np.sin(2 * np.pi * 3200 * tt) * np.exp(-tt * 90))


# Zombie groans: vocal-ish buzz with formant wobble
def groan(dur, f0, seed):
    r = np.random.default_rng(seed)
    tt = t(dur)
    f = f0 * (
        1 + 0.15 * np.sin(2 * np.pi * 1.3 * tt + r.random() * 6) + 0.05 * r.standard_normal(len(tt)).cumsum() / 400
    )
    ph = 2 * np.pi * np.cumsum(f) / SR
    buzz = np.sign(np.sin(ph)) * 0.5 + np.sin(ph * 2) * 0.3 + np.sin(ph * 3) * 0.2
    breath = lowpass(r.standard_normal(len(tt)), 0.2) * 0.8
    env = np.sin(np.pi * tt / dur) ** 0.6
    return lowpass(buzz + breath, 0.12) * env


save("zombie_groan_1.wav", groan(1.6, 70, 1))
save("zombie_groan_2.wav", groan(1.2, 95, 2))
save("zombie_groan_3.wav", groan(2.0, 60, 3))

# Zombie attack swipe
tt = t(0.35)
save("zombie_attack.wav", lowpass(rng.standard_normal(len(tt)), 0.3) * np.sin(np.pi * tt / 0.35) ** 2)

# Player hurt thud
tt = t(0.3)
save(
    "player_hurt.wav",
    np.sin(2 * np.pi * (120 * tt - 100 * tt**2)) * np.exp(-tt * 12)
    + lowpass(rng.standard_normal(len(tt)), 0.1) * np.exp(-tt * 20),
)

# Wave start: low ominous drone hit
tt = t(3.0)
drone = sum(np.sin(2 * np.pi * f * tt) * a for f, a in [(55, 1), (82.4, 0.6), (110, 0.4), (58, 0.5)])
save("wave_start.wav", drone * np.exp(-tt * 1.2) * np.minimum(tt * 20, 1))

# Machine noise uses its own sequence, leaving weapon sounds unchanged.
weapon_rng = rng
rng = np.random.default_rng(17)

# Purchase: two bright notes and a register latch
x = np.zeros(len(t(0.5)))
for at, freq in [(0.0, 1046.5), (0.12, 1568.0)]:
    s = t(0.32)
    i = int(at * SR)
    x[i : i + len(s)] += (
        (np.sin(2 * np.pi * freq * s) + 0.3 * np.sin(2 * np.pi * freq * 2 * s))
        * np.exp(-s * 15)
        * np.minimum(s * 500, 1)
    )
click(0.27, 2400, 120, 0.35)
save("buy.wav", x)

# Denied: short, low electrical buzz
tt = t(0.24)
save("denied.wav", lowpass(np.sign(np.sin(2 * np.pi * 95 * tt)), 0.15) * np.sin(np.pi * tt / 0.24) ** 0.5)

# Heavy door: latch impact, scraping metal and a final stop
tt = t(1.2)
x = lowpass(rng.standard_normal(len(tt)), 0.07) * np.sin(np.pi * tt / 1.2) * 1.8
x += (np.sin(2 * np.pi * 125 * tt) + 0.3 * np.sin(2 * np.pi * 730 * tt)) * np.sin(np.pi * tt / 1.2) * 0.3
click(0.0, 160, 45, 1.0)
click(1.08, 95, 45, 1.0)
save("door_open.wav", x)

# Power: deep clunk followed by a rising transformer hum
tt = t(2.0)
hum = np.sin(2 * np.pi * (45 * tt + 22 * tt**2)) + 0.3 * np.sin(2 * np.pi * (90 * tt + 44 * tt**2))
x = hum * np.minimum(np.maximum(tt - 0.15, 0) * 2, 1) * np.minimum((2 - tt) * 4, 1) * 0.45
x += np.sin(2 * np.pi * 55 * tt) * np.exp(-tt * 22)
click(0.0, 100, 40, 1.0)
save("power_on.wav", x)

# Wood splitting: sharp crack with a short resonant body
tt = t(0.3)
x = rng.standard_normal(len(tt)) * np.exp(-tt * 65)
x += (np.sin(2 * np.pi * 370 * tt) + 0.5 * np.sin(2 * np.pi * 610 * tt)) * np.exp(-tt * 24) * 0.5
save("plank_tear.wav", x)

# Repair: two hammer knocks
x = np.zeros(len(t(0.55)))
click(0.0, 260, 55, 1.0)
click(0.27, 310, 60, 0.85)
save("plank_repair.wav", x)

# Power-up: rising, shimmering harmonics
tt = t(1.1)
phase = 2 * np.pi * (420 * tt + 600 * tt**2)
shimmer = sum(np.sin(phase * f) / f for f in [1, 1.5, 2, 3])
save("power_up.wav", shimmer * (0.75 + 0.25 * np.sin(2 * np.pi * 19 * tt)) * np.sin(np.pi * tt / 1.1))

# Round cleared: low brass-like chord, a soft attack and decaying overtones
tt = t(2.0)
brass = sum(sum(np.sin(2 * np.pi * f * h * tt) / h for h in range(1, 7)) for f in [65.4, 82.4, 98.0])
save("round_end.wav", lowpass(brass, 0.12) * np.minimum(tt * 12, 1) * np.exp(-tt * 1.8) * np.minimum((2 - tt) * 8, 1))
rng = weapon_rng

# Shotgun blast: heavier, lower boom than the rifle, then the pump racking
tt = t(0.9)
boom = np.sin(2 * np.pi * (60 * tt - 30 * tt**2)) * np.exp(-tt * 9)
blast = lowpass(rng.standard_normal(len(tt)), 0.25) * np.exp(-tt * 25) * 1.5
tail = lowpass(rng.standard_normal(len(tt)), 0.05) * np.exp(-tt * 5) * 3.0
x = boom * 1.4 + blast + tail
click(0.55, 700, 70, 0.25)
click(0.68, 1100, 90, 0.2)
save("shotgun_fire.wav", x)

# Kestrel SMG: a short, higher crack with a quick mechanical snap.
tt = t(0.18)
crack = rng.standard_normal(len(tt)) * np.exp(-tt * 95)
thump = np.sin(2 * np.pi * (180 * tt - 80 * tt**2)) * np.exp(-tt * 38)
snap = np.sin(2 * np.pi * 2100 * tt) * np.exp(-tt * 160)
tail = lowpass(rng.standard_normal(len(tt)), 0.18) * np.exp(-tt * 30)
save("kestrel_fire.wav", crack + thump * 0.55 + snap * 0.3 + tail * 0.7)

# Talon shot: heavier crack and a longer reverberant tail than the rifle.
tt = t(0.75)
crack = rng.standard_normal(len(tt)) * np.exp(-tt * 45)
thump = np.sin(2 * np.pi * (75 * tt - 40 * tt**2)) * np.exp(-tt * 14)
tail = lowpass(rng.standard_normal(len(tt)), 0.07) * np.exp(-tt * 5) * 3.0
save("talon_fire.wav", crack * 1.3 + thump * 1.5 + tail)

# Hollis .44: a deep, round magnum boom with a short ring from the cylinder gap.
tt = t(0.8)
crack = rng.standard_normal(len(tt)) * np.exp(-tt * 50)
boom = np.sin(2 * np.pi * (70 * tt - 35 * tt**2)) * np.exp(-tt * 11)
ring = np.sin(2 * np.pi * 1450 * tt) * np.exp(-tt * 40)
tail = lowpass(rng.standard_normal(len(tt)), 0.06) * np.exp(-tt * 5.5) * 3.0
save("hollis_fire.wav", crack * 1.2 + boom * 1.6 + ring * 0.15 + tail)

# Mako PDW: very short, light snap so three-round bursts stay crisp.
tt = t(0.14)
crack = rng.standard_normal(len(tt)) * np.exp(-tt * 120)
thump = np.sin(2 * np.pi * (210 * tt - 90 * tt**2)) * np.exp(-tt * 45)
snap = np.sin(2 * np.pi * 2600 * tt) * np.exp(-tt * 190)
tail = lowpass(rng.standard_normal(len(tt)), 0.2) * np.exp(-tt * 38)
save("mako_fire.wav", crack + thump * 0.45 + snap * 0.35 + tail * 0.6)

# Atlas Auto: a shotgun boom cut short for fast follow-up shots, plus the action cycling.
tt = t(0.42)
boom = np.sin(2 * np.pi * (65 * tt - 40 * tt**2)) * np.exp(-tt * 12)
blast = lowpass(rng.standard_normal(len(tt)), 0.28) * np.exp(-tt * 30) * 1.5
tail = lowpass(rng.standard_normal(len(tt)), 0.06) * np.exp(-tt * 9) * 2.5
x = boom * 1.3 + blast + tail
click(0.09, 900, 110, 0.18)
save("atlas_fire.wav", x)

# Halberd LMG: a mid, chesty report that stacks well at 600 rpm.
tt = t(0.3)
crack = rng.standard_normal(len(tt)) * np.exp(-tt * 75)
thump = np.sin(2 * np.pi * (110 * tt - 60 * tt**2)) * np.exp(-tt * 22)
tail = lowpass(rng.standard_normal(len(tt)), 0.1) * np.exp(-tt * 14) * 2.0
save("halberd_fire.wav", crack + thump * 1.3 + tail)

# Corvid .338: the biggest crack in the game, a long rolling tail and the bolt cycling after.
tt = t(1.3)
crack = rng.standard_normal(len(tt)) * np.exp(-tt * 38)
thump = np.sin(2 * np.pi * (60 * tt - 25 * tt**2)) * np.exp(-tt * 9)
tail = lowpass(rng.standard_normal(len(tt)), 0.05) * np.exp(-tt * 3.2) * 3.5
x = crack * 1.4 + thump * 1.8 + tail
click(0.8, 650, 80, 0.3)
click(1.0, 950, 90, 0.25)
save("corvid_fire.wav", x)

# Siphon: a low pressure pulse and falling coil tone; energy, without a bullet crack.
tt = t(0.8)
pulse = np.sin(2 * np.pi * (75 * tt - 20 * tt**2)) * np.exp(-tt * 9)
coil = np.sin(2 * np.pi * (560 * tt - 210 * tt**2)) * np.exp(-tt * 5)
breath = lowpass(np.random.default_rng(73).standard_normal(len(tt)), 0.035) * np.exp(-tt * 6)
save("siphon_fire.wav", (pulse * 1.3 + coil * 0.45 + breath * 0.6) * np.minimum(tt * 500, 1))
