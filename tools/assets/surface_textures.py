"""Tileable surface texture sets for the map materials (albedo, normal, ORM).

Every pattern is built from periodic pieces (FFT noise, wrapped cells, integer
tile grids), so each set repeats without a seam. The albedo is a near-grey
detail map: the material's base colour tints it, so the map keeps the
palette values the lightmap was baked with. ORM packs ambient occlusion (R),
roughness (G) and a metal mask (B) that the material's metallic value scales.

    python tools/assets/surface_textures.py [set ...]

writes assets/textures/halcyon/<set>_{albedo,normal,orm}.png (ORM at half size: it
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


SETS = {
    "ceiling_tile": (ceiling_tile, 1024),
    "painted_concrete": (painted_concrete, 1024),
    "raw_concrete": (raw_concrete, 1024),
}


def build(name: str) -> dict[str, np.ndarray]:
    """The three maps of one set as uint8 RGB arrays."""
    make, n = SETS[name]
    albedo, height, rough, metal, strength = make(n)
    albedo = np.clip(albedo, 0.0, 1.0)
    if albedo.ndim == 2:
        albedo = np.repeat(albedo[..., None], 3, axis=-1)
    ao = occlusion(height, 3.0, 6.0)
    orm = np.stack([ao, np.clip(np.broadcast_to(rough, height.shape), 0.0, 1.0), np.full_like(height, metal)], -1)
    to8 = lambda a: np.round(np.clip(a, 0.0, 1.0) * 255.0).astype(np.uint8)  # noqa: E731
    return {
        "albedo": to8(albedo ** (1.0 / 2.2)),
        "normal": to8(normal_from_height(height, strength)),
        "orm": to8(orm.reshape(n // 2, 2, n // 2, 2, 3).mean(axis=(1, 3))),
    }


def write_png(path: Path, rgb: np.ndarray) -> None:
    """8-bit RGB PNG with the Sub filter on every row (small and dependency-free)."""
    h, w, _ = rgb.shape
    filtered = rgb.astype(np.int16)
    filtered[:, 1:] -= rgb[:, :-1].astype(np.int16)
    rows = np.concatenate([np.ones((h, 1), np.uint8), (filtered % 256).astype(np.uint8).reshape(h, w * 3)], axis=1)

    def chunk(tag: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data))

    header = struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)
    body = zlib.compress(rows.tobytes(), 9)
    path.write_bytes(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header) + chunk(b"IDAT", body) + chunk(b"IEND", b""))


def main(names: list[str]) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for name in names or list(SETS):
        for kind, rgb in build(name).items():
            write_png(OUT / f"{name}_{kind}.png", rgb)
        print("wrote", name)


if __name__ == "__main__":
    main(sys.argv[1:])
