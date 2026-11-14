# Generates the placeholder sound effects in assets/audio (all original, no licences needed).
# Run: python3 tools/generate_sfx.py assets/audio   (needs numpy)
import numpy as np, wave, sys, os
SR = 44100
out = sys.argv[1]
rng = np.random.default_rng(7)

def save(name, x):
    x = np.clip(x / (np.max(np.abs(x)) + 1e-9) * 0.9, -1, 1)
    with wave.open(os.path.join(out, name), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())

def t(d): return np.arange(int(SR * d)) / SR

def lowpass(x, a):
    y = np.zeros_like(x); acc = 0.0
    for i, v in enumerate(x):
        acc += a * (v - acc); y[i] = acc
    return y

# Rifle shot: sharp crack + low thump + noisy tail
tt = t(0.45)
crack = rng.standard_normal(len(tt)) * np.exp(-tt * 60)
thump = np.sin(2 * np.pi * (90 * tt - 60 * tt**2)) * np.exp(-tt * 18)
tail = lowpass(rng.standard_normal(len(tt)), 0.08) * np.exp(-tt * 7) * 2.5
save("rifle_fire.wav", crack * 0.9 + thump * 1.2 + tail)

# Dry fire click
tt = t(0.08)
save("dry_fire.wav", rng.standard_normal(len(tt)) * np.exp(-tt * 300) + np.sin(2*np.pi*2400*tt) * np.exp(-tt*200) * 0.5)

# Reload: mag out click, pause, mag in clack, bolt
tt = t(1.4)
x = np.zeros(len(tt))
def click(at, freq, decay, amp):
    i = int(at * SR); n = int(0.12 * SR); s = np.arange(n) / SR
    seg = (rng.standard_normal(n) * 0.6 + np.sin(2*np.pi*freq*s)) * np.exp(-s * decay) * amp
    x[i:i+n] += seg[:len(x)-i]
click(0.05, 1800, 90, 0.7)
click(0.75, 900, 60, 1.0)
click(1.15, 1400, 70, 0.9)
click(1.22, 2200, 120, 0.6)
save("reload.wav", x)

# Hitmarker tick
tt = t(0.06)
save("hitmarker.wav", np.sin(2*np.pi*3200*tt) * np.exp(-tt * 90))

# Zombie groans: vocal-ish buzz with formant wobble
def groan(dur, f0, seed):
    r = np.random.default_rng(seed)
    tt = t(dur)
    f = f0 * (1 + 0.15 * np.sin(2*np.pi*1.3*tt + r.random()*6) + 0.05 * r.standard_normal(len(tt)).cumsum() / 400)
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
save("player_hurt.wav", np.sin(2*np.pi*(120*tt - 100*tt**2)) * np.exp(-tt*12) + lowpass(rng.standard_normal(len(tt)), 0.1) * np.exp(-tt*20))

# Wave start: low ominous drone hit
tt = t(3.0)
drone = sum(np.sin(2*np.pi*f*tt) * a for f, a in [(55, 1), (82.4, 0.6), (110, 0.4), (58, 0.5)])
save("wave_start.wav", drone * np.exp(-tt * 1.2) * np.minimum(tt * 20, 1))
