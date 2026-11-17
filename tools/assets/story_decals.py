"""Generate the Halcyon Labs story decal textures into assets/textures/story.

Run: python tools/assets/story_decals.py assets/textures/story   (pure Python, no extra packages)
Each decal is a small RGBA PNG drawn from soft-edged strokes; the output is byte-identical every run.
"""

import argparse
import math
import struct
import zlib
from pathlib import Path

BLOOD = (58, 12, 9)
PAINT = (185, 194, 176)
SCRATCH = (150, 158, 150)
BIO_GREEN = (141, 255, 58)


def noise(x: int, y: int, seed: int) -> float:
    value = math.sin(x * 12.9898 + y * 78.233 + seed * 37.719) * 43758.5453
    return value - math.floor(value)


def segment_distance(px: float, py: float, a: tuple, b: tuple) -> float:
    ax, ay = a
    bx, by = b
    dx, dy = bx - ax, by - ay
    length = dx * dx + dy * dy
    t = 0.0 if length == 0 else max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / length))
    return math.hypot(px - ax - t * dx, py - ay - t * dy)


def stroke_alpha(px: float, py: float, strokes: list) -> float:
    alpha = 0.0
    for a, b, radius in strokes:
        edge = radius - segment_distance(px, py, a, b)
        alpha = max(alpha, 0.0, min(1.0, edge / 1.5 + 0.5))
    return alpha


def render(size: tuple, color: tuple, strokes: list, seed: int, grain: float) -> bytes:
    width, height = size
    rows = bytearray()
    for y in range(height):
        rows.append(0)
        for x in range(width):
            alpha = stroke_alpha(x + 0.5, y + 0.5, strokes)
            alpha *= 1.0 - grain * noise(x, y, seed)
            rows.extend((*color, round(255 * alpha)))
    return bytes(rows)


def save_png(path: Path, size: tuple, pixels: bytes) -> None:
    def chunk(kind: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))

    header = struct.pack(">IIBBBBB", size[0], size[1], 8, 6, 0, 0, 0)
    body = chunk(b"IHDR", header) + chunk(b"IDAT", zlib.compress(pixels, 9)) + chunk(b"IEND", b"")
    path.write_bytes(b"\x89PNG\r\n\x1a\n" + body)


def blood_smear() -> list:
    strokes = [((40 + i * 8, 70 + i * 3), (200 + i * 4, 60 + i * 5), 9 - i) for i in range(6)]
    strokes += [((x, 80), (x + 2, 80 + length), 2.5) for x, length in ((70, 90), (115, 140), (150, 70), (185, 110))]
    return strokes


def drag_trail() -> list:
    strokes = []
    for i in range(14):
        x = 20 + i * 34
        strokes.append(((x, 64 + 18 * math.sin(i * 0.7)), (x + 40, 64 + 18 * math.sin(i * 0.7 + 0.7)), 14 - i * 0.6))
    return strokes


def scratch_marks() -> list:
    return [((60 + i * 34, 30 + i * 6), (110 + i * 30, 230 - i * 4), 3.0) for i in range(4)]


def tally_marks() -> list:
    strokes = []
    for group in range(5):
        left = 20 + group * 98
        strokes += [((left + i * 16, 60), (left + i * 16 + 3, 190), 4.0) for i in range(4)]
        strokes.append(((left - 10, 170), (left + 66, 80), 4.0))
    return strokes


def wick_symbol() -> list:
    circle = [
        ((128 + 80 * math.cos(a), 150 + 80 * math.sin(a)), (128 + 80 * math.cos(b), 150 + 80 * math.sin(b)), 6.0)
        for a, b in ((i * math.pi / 12, (i + 1) * math.pi / 12) for i in range(24))
    ]
    wick = [((128, 240), (128, 40), 6.0)]
    flame = [
        ((128, 40), (110, 14), 5.0),
        ((128, 40), (146, 14), 5.0),
        ((110, 14), (128, 0), 4.0),
        ((146, 14), (128, 0), 4.0),
    ]
    return circle + wick + flame


def leak_pool() -> list:
    return [
        ((128 + 60 * math.cos(i), 128 + 40 * math.sin(i * 1.3)), (128, 128), 40 + 12 * math.sin(i * 2.1))
        for i in range(7)
    ]


DECALS = {
    "blood_smear.png": ((256, 256), BLOOD, blood_smear, 0.35),
    "drag_trail.png": ((512, 128), BLOOD, drag_trail, 0.45),
    "scratch_marks.png": ((256, 256), SCRATCH, scratch_marks, 0.3),
    "tally_marks.png": ((512, 256), PAINT, tally_marks, 0.4),
    "wick_symbol.png": ((256, 256), PAINT, wick_symbol, 0.45),
    "leak_pool.png": ((256, 256), BIO_GREEN, leak_pool, 0.25),
}


def build(output: Path) -> list[Path]:
    output.mkdir(parents=True, exist_ok=True)
    written = []
    for seed, (name, (size, color, shape, grain)) in enumerate(DECALS.items()):
        path = output / name
        save_png(path, size, render(size, color, shape(), seed, grain))
        written.append(path)
    return written


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path)
    build(parser.parse_args().output)


if __name__ == "__main__":
    main()
