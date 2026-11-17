"""Tileable surface texture sets for the map materials (albedo, normal, ORM).

Every pattern is built from periodic pieces (FFT noise, wrapped cells, integer
tile grids), so each set repeats without a seam. The albedo is a near-grey
detail map: the material's base colour tints it, so the map keeps the
palette values the lightmap was baked with. ORM packs ambient occlusion (R),
roughness (G) and a metal mask (B) that the material's metallic value scales.

    python tools/assets/surface_textures.py [set ...]

writes assets/textures/halcyon/<set>_{albedo,normal,orm}.png and decal_<name>.png (ORM at half size: it
holds only soft detail, and the folder must stay small without Git LFS). The script is
the source; never edit the PNGs by hand.
"""

import struct
import sys
import zlib
from pathlib import Path

import numpy as np

OUT = Path(__file__).resolve().parents[2] / "assets" / "textures" / "halcyon"


# Periodic building blocks ----------------------------------------------------


def _freqs(n: int) -> np.ndarray:
    f = np.fft.fftfreq(n) * n
    return np.sqrt(f[:, None] ** 2 + f[None, :] ** 2)


def fbm(n: int, low: float, high: float, seed: int, beta: float = 2.0) -> np.ndarray:
    """Noise from `low` to `high` features per tile, scaled 0..1. Periodic by construction."""
    rng = np.random.default_rng(seed)
    f = _freqs(n)
    band = (f >= low) & (f <= high)
    amp = np.where(band, 1.0 / np.maximum(f, 1.0) ** (beta * 0.5), 0.0)
    spectrum = np.fft.fft2(rng.standard_normal((n, n))) * amp
    out = np.real(np.fft.ifft2(spectrum))
    return (out - out.min()) / (out.max() - out.min() + 1e-9)


def blur(a: np.ndarray, sigma: float) -> np.ndarray:
    """Gaussian blur that wraps around the edges."""
    f = np.fft.fftfreq(a.shape[0])
    g = np.exp(-2.0 * (np.pi * sigma) ** 2 * (f[:, None] ** 2 + f[None, :] ** 2))
    return np.real(np.fft.ifft2(np.fft.fft2(a) * g))


def streaks(n: int, low: float, high: float, seed: int, stretch: float) -> np.ndarray:
    """Noise smeared along u (rows of fine lines), scaled 0..1. Periodic."""
    f = np.fft.fftfreq(n)
    smear = np.exp(-2.0 * (np.pi * stretch) ** 2 * f[None, :] ** 2)
    out = np.real(np.fft.ifft2(np.fft.fft2(fbm(n, low, high, seed)) * smear))
    return (out - out.min()) / (out.max() - out.min() + 1e-9)


def coords(n: int) -> tuple[np.ndarray, np.ndarray]:
    """u (columns) and v (rows) in 0..1, pixel centres."""
    t = (np.arange(n) + 0.5) / n
    return np.meshgrid(t, t)


def grid_lines(n: int, count: int, width: float) -> np.ndarray:
    """1 on the lines of a count x count grid, fading out over width (tile fractions)."""
    u, v = coords(n)
    fu = (u * count) % 1.0
    fv = (v * count) % 1.0
    d = np.minimum(np.minimum(fu, 1.0 - fu), np.minimum(fv, 1.0 - fv)) / count
    return np.clip(1.0 - d / width, 0.0, 1.0)


def per_cell(n: int, count: int, seed: int) -> np.ndarray:
    """One random value 0..1 per grid cell."""
    rng = np.random.default_rng(seed)
    table = rng.random((count, count))
    u, v = coords(n)
    return table[(v * count).astype(int) % count, (u * count).astype(int) % count]


def spots(n: int, count: int, radius: float, seed: int) -> np.ndarray:
    """count round spots with wrapped distance, 1 inside, soft rim; radius in tile fractions."""
    rng = np.random.default_rng(seed)
    u, v = coords(n)
    out = np.zeros((n, n))
    for x, y in rng.random((count, 2)):
        dx = np.abs(u - x)
        dy = np.abs(v - y)
        d = np.hypot(np.minimum(dx, 1.0 - dx), np.minimum(dy, 1.0 - dy))
        out = np.maximum(out, np.clip((radius - d) / (radius * 0.35), 0.0, 1.0))
    return out


# Height to maps ----------------------------------------------------------------


def normal_from_height(height: np.ndarray, strength: float) -> np.ndarray:
    """Tangent-space normal map (OpenGL / Godot +Y) from a 0..1 height field."""
    dx = (np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)) * strength
    dy = (np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)) * strength
    nrm = np.stack([-dx, dy, np.ones_like(height)], axis=-1)
    nrm /= np.linalg.norm(nrm, axis=-1, keepdims=True)
    return nrm * 0.5 + 0.5


def occlusion(height: np.ndarray, radius: float, amount: float) -> np.ndarray:
    """Darkens dips below their surroundings."""
    cavity = np.clip(blur(height, radius) - height, 0.0, None)
    return np.clip(1.0 - cavity * amount, 0.0, 1.0)


# Surface sets ------------------------------------------------------------------
# Each returns (albedo grey 0..1 or RGB, height 0..1, roughness 0..1, metallic, normal strength).


def ceiling_tile(n: int) -> tuple:
    """Acoustic ceiling tiles: 2 x 2 per repeat, recessed grid, pinhole speckle, tired tiles."""
    lines = grid_lines(n, 2, 0.012)
    tint = per_cell(n, 2, 11)
    pores = (fbm(n, 180, n // 4, 12) > 0.66).astype(float)
    sag = fbm(n, 2, 6, 13)
    height = (1.0 - lines) * 0.8 + sag * 0.15 - pores * 0.05
    albedo = (0.86 + tint * 0.1 - pores * 0.12) * (1.0 - lines * 0.55) * (0.94 + sag * 0.06)
    rough = 0.9 + pores * 0.05
    return albedo, height, rough, 0.0, 6.0


def painted_concrete(n: int) -> tuple:
    """Painted block wall: mortar courses, roller marks, chipped paint showing concrete."""
    u, v = coords(n)
    courses = np.clip((np.abs((v * 8.0) % 1.0 - 0.5) * 2.0 - 0.92) / 0.08, 0.0, 1.0)
    offset = np.floor(v * 8.0) % 2 * 0.5
    joints = np.clip((np.abs((u * 4.0 + offset) % 1.0 - 0.5) * 2.0 - 0.96) / 0.04, 0.0, 1.0)
    mortar = np.maximum(courses, joints)
    mottle = fbm(n, 2, 16, 21)
    pores = fbm(n, 120, n // 4, 22)
    chips = np.clip((fbm(n, 6, 60, 23) - 0.7) * 12.0, 0.0, 1.0)
    height = 0.7 - mortar * 0.35 + pores * 0.06 - chips * 0.12 + mottle * 0.05
    albedo = (0.8 + mottle * 0.2 - pores * 0.1) * (1.0 - mortar * 0.35) * (1.0 - chips * 0.45)
    rough = 0.7 + chips * 0.2 + mortar * 0.15
    return albedo, height, rough, 0.0, 5.0


def raw_concrete(n: int) -> tuple:
    """Cast concrete: board-form seams, tie holes, blotchy cement and air pockets."""
    _u, v = coords(n)
    seams = np.clip(1.0 - np.abs((v * 2.0) % 1.0 - 0.5) * 2.0 / 0.006, 0.0, 1.0)
    boards = np.floor(v * 8.0) % 2 * 0.03
    ties = spots(n, 1, 0.018, 32)
    ties = np.maximum(ties, np.roll(np.roll(ties, n // 2, axis=0), n // 2, axis=1))
    blotch = fbm(n, 1, 10, 33)
    grain = fbm(n, 80, n // 4, 34)
    pockets = (fbm(n, 60, 200, 35) > 0.72).astype(float)
    height = 0.6 + grain * 0.12 - pockets * 0.15 - seams * 0.2 - ties * 0.5 + blotch * 0.05
    albedo = (
        (0.62 + blotch * 0.38 + boards - grain * 0.16)
        * (1.0 - pockets * 0.45)
        * (1.0 - ties * 0.7)
        * (1.0 - seams * 0.4)
    )
    rough = 0.88 + grain * 0.1
    return albedo, height, rough, 0.0, 7.0


def steel_plate(n: int) -> tuple:
    """Diamond tread plate: raised lozenges in a herringbone, worn bright where boots go."""
    u, v = coords(n)
    k = 16.0
    a = (u * k + v * k) % 1.0 - 0.5
    b = (u * k - v * k) % 1.0 - 0.5
    flip = (np.floor(u * k) + np.floor(v * k)) % 2
    major = np.where(flip > 0, a, b)
    minor = np.where(flip > 0, b, a)
    lozenge = np.clip(1.0 - (np.abs(major) / 0.42) ** 2 - (np.abs(minor) / 0.12) ** 2, 0.0, 1.0)
    wear = fbm(n, 2, 12, 41)
    scratches = fbm(n, 90, n // 4, 42)
    rust = np.clip((fbm(n, 3, 30, 43) - 0.68) * 8.0, 0.0, 1.0)
    height = 0.4 + np.sqrt(lozenge) * 0.45 + scratches * 0.04
    albedo = (0.7 + lozenge * wear * 0.3 + scratches * 0.1) * (1.0 - rust * 0.45)
    rough = 0.55 - lozenge * wear * 0.25 + rust * 0.35 + scratches * 0.1
    metal = 1.0 - rust
    return albedo, height, rough, metal, 9.0


def linoleum(n: int) -> tuple:
    """Canteen linoleum: 30 cm checker of two greys, scuffs, lifted seams and a waxed sheen."""
    tiles = per_cell(n, 4, 51) * 0.08
    u, v = coords(n)
    checker = ((np.floor(u * 4) + np.floor(v * 4)) % 2) * 0.22
    seams = grid_lines(n, 4, 0.003)
    scuffs = np.clip((fbm(n, 20, 120, 52) - 0.6) * 5.0, 0.0, 1.0)
    flecks = (fbm(n, 150, n // 4, 53) > 0.7).astype(float)
    height = 0.6 - seams * 0.3 + flecks * 0.02
    albedo = (0.72 + checker + tiles - flecks * 0.06) * (1.0 - scuffs * 0.25) * (1.0 - seams * 0.5)
    rough = 0.35 + scuffs * 0.35 + seams * 0.3
    return albedo, height, rough, 0.0, 4.0


def clinic_tile(n: int) -> tuple:
    """Lab tiles: small 10 cm glazed squares, grey grout, a few cracked and stained tiles."""
    lines = grid_lines(n, 12, 0.0025)
    tint = per_cell(n, 12, 61)
    cracked = (per_cell(n, 12, 62) > 0.94).astype(float) * (fbm(n, 30, 120, 63) > 0.62)
    dirt = fbm(n, 2, 20, 64)
    height = 0.7 - lines * 0.45 - cracked * 0.2
    albedo = (0.92 + tint * 0.06) * (1.0 - lines * 0.55) * (1.0 - cracked * 0.5) * (0.9 + dirt * 0.1)
    rough = 0.18 + lines * 0.7 + cracked * 0.5 + dirt * 0.1
    return albedo, height, rough, 0.0, 6.0


def grating(n: int) -> tuple:
    """Bar grating floor: load bars one way, cross rods the other, dark pit showing through."""
    u, v = coords(n)
    bars = np.clip(1.0 - np.abs((u * 20.0) % 1.0 - 0.5) * 2.0 / 0.22, 0.0, 1.0)
    rods = np.clip(1.0 - np.abs((v * 5.0) % 1.0 - 0.5) * 2.0 / 0.08, 0.0, 1.0)
    metal_part = np.maximum(bars, rods)
    solid = np.clip(metal_part * 3.0, 0.0, 1.0)
    wear = fbm(n, 4, 40, 71)
    rust = np.clip((fbm(n, 4, 40, 72) - 0.6) * 6.0, 0.0, 1.0) * solid
    height = solid * (0.7 + rods * 0.15) + wear * 0.03
    albedo = solid * (0.65 + wear * 0.3) * (1.0 - rust * 0.4) + (1.0 - solid) * 0.06
    rough = 0.5 + rust * 0.4 + (1.0 - solid) * 0.4
    return albedo, height, rough, solid * (1.0 - rust), 10.0


def sealed_concrete(n: int) -> tuple:
    """Dock floor: sealed concrete slabs with saw cuts, tyre marks and oil stains."""
    u, _v = coords(n)
    cuts = grid_lines(n, 1, 0.003)
    cement = fbm(n, 1, 12, 81)
    grain = fbm(n, 80, n // 4, 82)
    tyres = np.clip(1.0 - np.abs(((u + fbm(n, 1, 3, 83) * 0.2) * 3.0) % 1.0 - 0.5) * 2.0 / 0.18, 0.0, 1.0)
    oil = np.clip((fbm(n, 2, 14, 84) - 0.7) * 6.0, 0.0, 1.0)
    height = 0.6 + grain * 0.08 - cuts * 0.4
    albedo = (0.72 + cement * 0.25 - grain * 0.08) * (1.0 - tyres * 0.18) * (1.0 - oil * 0.45) * (1.0 - cuts * 0.6)
    rough = 0.6 + grain * 0.15 - oil * 0.35 + cuts * 0.3
    return albedo, height, rough, 0.0, 5.0


def painted_metal(n: int) -> tuple:
    """Painted steel sheet: orange-peel paint, scratches and chips down to bare metal."""
    peel = fbm(n, 60, n // 4, 91)
    mottle = fbm(n, 2, 12, 92)
    scratch = np.clip((streaks(n, 20, n // 4, 93, 12.0) - 0.8) * 10.0, 0.0, 1.0)
    chips = np.clip((fbm(n, 3, 24, 94) - 0.76) * 10.0, 0.0, 1.0)
    bare = np.maximum(chips, scratch * 0.6)
    height = 0.7 + peel * 0.05 - chips * 0.15 - scratch * 0.05
    albedo = (0.85 + mottle * 0.15 - peel * 0.05) * (1.0 - bare * 0.3)
    rough = 0.55 + peel * 0.1 + mottle * 0.1 - bare * 0.2
    return albedo, height, rough, bare, 5.0


def brushed_steel(n: int) -> tuple:
    """Brushed steel: fine grain along one direction, light smudges."""
    grain = streaks(n, 30, n // 4, 101, 40.0)
    smudge = fbm(n, 2, 10, 102)
    height = 0.5 + grain * 0.1
    albedo = 0.8 + grain * 0.15 + smudge * 0.05
    rough = 0.35 + grain * 0.15 + smudge * 0.2
    return albedo, height, rough, 1.0, 3.0


def rubber(n: int) -> tuple:
    """Rubber matting and hoses: dense stipple, dusty dips."""
    stipple = fbm(n, 40, n // 4, 111)
    dust = fbm(n, 2, 16, 112)
    height = stipple
    albedo = 0.8 + dust * 0.2 - stipple * 0.1
    rough = 0.85 + (1.0 - stipple) * 0.1
    return albedo, height, rough, 0.0, 4.0


def smudge(n: int) -> tuple:
    """Glass grime: fingerprints and dried drips, mostly clear."""
    marks = np.clip((fbm(n, 3, 40, 121) - 0.55) * 3.0, 0.0, 1.0)
    height = np.full((n, n), 0.5)
    albedo = 1.0 - marks * 0.35
    rough = 0.05 + marks * 0.5
    return albedo, height, rough, 0.0, 0.0


def specimen_fluid(n: int) -> tuple:
    """Tank fluid: murky swirls and bubbles, used as both colour and glow."""
    murk = fbm(n, 2, 20, 131)
    bubbles = spots(n, 24, 0.02, 132)
    height = np.full((n, n), 0.5)
    albedo = 0.45 + murk * 0.4 + bubbles * 0.15
    return albedo, height, 0.1, 0.0, 0.0


SETS = {
    "ceiling_tile": (ceiling_tile, 1024),
    "painted_concrete": (painted_concrete, 1024),
    "raw_concrete": (raw_concrete, 1024),
    "steel_plate": (steel_plate, 1024),
    "linoleum": (linoleum, 1024),
    "clinic_tile": (clinic_tile, 1024),
    "grating": (grating, 1024),
    "sealed_concrete": (sealed_concrete, 1024),
    "painted_metal": (painted_metal, 512),
    "brushed_steel": (brushed_steel, 512),
    "rubber": (rubber, 512),
    "smudge": (smudge, 256),
    "specimen_fluid": (specimen_fluid, 256),
}


# Decals ----------------------------------------------------------------------------
# Each returns linear RGB and alpha (n x n x 4), written as decal_<name>.png.

SODIUM = np.array([1.0, 0.33, 0.054])  # look-rules sodium #FF9A42, linear
STAIN = np.array([0.09, 0.06, 0.03])


def hazard(n: int) -> np.ndarray:
    """Worn hazard stripes in sodium and near-black, painted across door sills."""
    u, v = coords(n)
    stripe = ((u * 4.0 + v) % 1.0) < 0.5
    colour = np.where(stripe[..., None], SODIUM * 0.55, np.array([0.012, 0.013, 0.013]))
    wear = fbm(n, 2, 24, 141) * 0.8 + fbm(n, 30, 90, 142) * 0.2
    edge = np.minimum(np.minimum(v, 1.0 - v), np.minimum(u, 1.0 - u))
    alpha = np.clip((wear - 0.3) * 4.0, 0.0, 1.0) * np.clip(edge * 30.0, 0.0, 1.0) * 0.9
    return np.concatenate([colour, alpha[..., None]], axis=-1)


def water_stain(n: int) -> np.ndarray:
    """Dried puddle: brown tide-mark rings around a faint centre."""
    u, v = coords(n)
    r = np.hypot(u - 0.5, v - 0.5) * 2.0 + (fbm(n, 2, 10, 151) - 0.5) * 0.5
    rings = np.clip(1.0 - np.abs((r * 3.0) % 1.0 - 0.85) / 0.08, 0.0, 1.0) * (r < 0.95)
    alpha = np.clip(rings * 0.7 + (r < 0.9) * 0.15, 0.0, 1.0) * np.clip((0.95 - r) * 10.0, 0.0, 1.0)
    colour = np.broadcast_to(STAIN, (n, n, 3))
    return np.concatenate([colour, alpha[..., None]], axis=-1)


def scuffs(n: int) -> np.ndarray:
    """Boot and trolley scuffs: dark streaks with soft ends."""
    u, v = coords(n)
    marks = np.clip((streaks(n, 6, 60, 161, 30.0) - 0.62) * 6.0, 0.0, 1.0)
    fade = np.clip(np.minimum(u, 1.0 - u) * 6.0, 0.0, 1.0) * np.clip(np.minimum(v, 1.0 - v) * 6.0, 0.0, 1.0)
    colour = np.broadcast_to(np.array([0.015, 0.016, 0.016]), (n, n, 3))
    return np.concatenate([colour, (marks * fade * 0.8)[..., None]], axis=-1)


DECALS = {
    "hazard": (hazard, 256),
    "water_stain": (water_stain, 256),
    "scuffs": (scuffs, 256),
}


def build_decal(name: str) -> np.ndarray:
    make, n = DECALS[name]
    rgba = np.clip(make(n), 0.0, 1.0)
    rgba[..., :3] = rgba[..., :3] ** (1.0 / 2.2)
    return np.round(rgba * 255.0).astype(np.uint8)


def build(name: str) -> dict[str, np.ndarray]:
    """The three maps of one set as uint8 RGB arrays."""
    make, n = SETS[name]
    albedo, height, rough, metal, strength = make(n)
    albedo = np.clip(albedo, 0.0, 1.0)
    if albedo.ndim == 2:
        albedo = np.repeat(albedo[..., None], 3, axis=-1)
    ao = occlusion(height, 3.0, 6.0)
    full = lambda a: np.clip(np.broadcast_to(a, height.shape), 0.0, 1.0)  # noqa: E731
    orm = np.stack([ao, full(rough), full(metal)], -1)
    to8 = lambda a: np.round(np.clip(a, 0.0, 1.0) * 255.0).astype(np.uint8)  # noqa: E731
    return {
        "albedo": to8(albedo ** (1.0 / 2.2)),
        "normal": to8(normal_from_height(height, strength)),
        "orm": to8(orm.reshape(n // 2, 2, n // 2, 2, 3).mean(axis=(1, 3))),
    }


def write_png(path: Path, rgb: np.ndarray) -> None:
    """8-bit RGB or RGBA PNG with the Sub filter on every row (small and dependency-free)."""
    h, w, channels = rgb.shape
    filtered = rgb.astype(np.int16)
    filtered[:, 1:] -= rgb[:, :-1].astype(np.int16)
    packed = (filtered % 256).astype(np.uint8).reshape(h, w * channels)
    rows = np.concatenate([np.ones((h, 1), np.uint8), packed], axis=1)

    def chunk(tag: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data))

    header = struct.pack(">IIBBBBB", w, h, 8, 6 if channels == 4 else 2, 0, 0, 0)
    body = zlib.compress(rows.tobytes(), 9)
    path.write_bytes(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header) + chunk(b"IDAT", body) + chunk(b"IEND", b""))


def main(names: list[str]) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for name in names or [*SETS, *DECALS]:
        if name in DECALS:
            write_png(OUT / f"decal_{name}.png", build_decal(name))
        else:
            for kind, rgb in build(name).items():
                write_png(OUT / f"{name}_{kind}.png", rgb)
        print("wrote", name)


if __name__ == "__main__":
    main(sys.argv[1:])
