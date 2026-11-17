"""Generate the Halcyon Labs painted sign textures into assets/textures/signs.

Run: python tools/assets/sign_decals.py assets/textures/signs   (pure Python, no extra packages)
Stencil letters are drawn from strokes on a 4 x 6 grid, then aged (chipped, grimy, faded, some blood).
The output is byte-identical every run.
"""

import argparse
import math
from pathlib import Path

from story_decals import BLOOD, PAINT, noise, save_png, segment_distance

HAZARD = (194, 117, 52)
LETTER_W = 4.0
LETTER_H = 6.0
GAP = 1.6

GLYPHS = {
    "A": [((0, 6), (0, 1.5)), ((0, 1.5), (2, 0)), ((2, 0), (4, 1.5)), ((4, 1.5), (4, 6)), ((0, 3.4), (4, 3.4))],
    "B": [
        ((0, 0), (0, 6)),
        ((0, 0), (3, 0)),
        ((3, 0), (3.6, 1.4)),
        ((3.6, 1.4), (3, 2.8)),
        ((0, 2.8), (3, 2.8)),
        ((3, 2.8), (4, 4.3)),
        ((4, 4.3), (3, 6)),
        ((3, 6), (0, 6)),
    ],
    "C": [((4, 0), (0.8, 0)), ((0.8, 0), (0, 1)), ((0, 1), (0, 5)), ((0, 5), (0.8, 6)), ((0.8, 6), (4, 6))],
    "D": [
        ((0, 0), (0, 6)),
        ((0, 0), (2.8, 0)),
        ((2.8, 0), (4, 1.4)),
        ((4, 1.4), (4, 4.6)),
        ((4, 4.6), (2.8, 6)),
        ((2.8, 6), (0, 6)),
    ],
    "E": [((4, 0), (0, 0)), ((0, 0), (0, 6)), ((0, 6), (4, 6)), ((0, 3), (3, 3))],
    "G": [
        ((4, 0), (0.8, 0)),
        ((0.8, 0), (0, 1)),
        ((0, 1), (0, 5)),
        ((0, 5), (0.8, 6)),
        ((0.8, 6), (4, 6)),
        ((4, 6), (4, 3.4)),
        ((4, 3.4), (2.2, 3.4)),
    ],
    "H": [((0, 0), (0, 6)), ((4, 0), (4, 6)), ((0, 3), (4, 3))],
    "I": [((2, 0), (2, 6)), ((0.6, 0), (3.4, 0)), ((0.6, 6), (3.4, 6))],
    "K": [((0, 0), (0, 6)), ((4, 0), (0.6, 3.2)), ((1.6, 2.4), (4, 6))],
    "L": [((0, 0), (0, 6)), ((0, 6), (4, 6))],
    "M": [((0, 6), (0, 0)), ((0, 0), (2, 3)), ((2, 3), (4, 0)), ((4, 0), (4, 6))],
    "N": [((0, 6), (0, 0)), ((0, 0), (4, 6)), ((4, 6), (4, 0))],
    "O": [
        ((0.8, 0), (3.2, 0)),
        ((3.2, 0), (4, 1)),
        ((4, 1), (4, 5)),
        ((4, 5), (3.2, 6)),
        ((3.2, 6), (0.8, 6)),
        ((0.8, 6), (0, 5)),
        ((0, 5), (0, 1)),
        ((0, 1), (0.8, 0)),
    ],
    "P": [
        ((0, 6), (0, 0)),
        ((0, 0), (3.2, 0)),
        ((3.2, 0), (4, 0.9)),
        ((4, 0.9), (4, 2.3)),
        ((4, 2.3), (3.2, 3.2)),
        ((3.2, 3.2), (0, 3.2)),
    ],
    "R": [
        ((0, 6), (0, 0)),
        ((0, 0), (3.2, 0)),
        ((3.2, 0), (4, 0.9)),
        ((4, 0.9), (4, 2.3)),
        ((4, 2.3), (3.2, 3.2)),
        ((3.2, 3.2), (0, 3.2)),
        ((2, 3.2), (4, 6)),
    ],
    "S": [
        ((4, 0), (0.8, 0)),
        ((0.8, 0), (0, 0.9)),
        ((0, 0.9), (0, 2.2)),
        ((0, 2.2), (0.8, 3)),
        ((0.8, 3), (3.2, 3)),
        ((3.2, 3), (4, 3.8)),
        ((4, 3.8), (4, 5.1)),
        ((4, 5.1), (3.2, 6)),
        ((3.2, 6), (0, 6)),
    ],
    "T": [((0, 0), (4, 0)), ((2, 0), (2, 6))],
    "U": [((0, 0), (0, 5)), ((0, 5), (0.8, 6)), ((0.8, 6), (3.2, 6)), ((3.2, 6), (4, 5)), ((4, 5), (4, 0))],
    "W": [((0, 0), (0.6, 6)), ((0.6, 6), (2, 2.6)), ((2, 2.6), (3.4, 6)), ((3.4, 6), (4, 0))],
    "Y": [((0, 0), (2, 3)), ((4, 0), (2, 3)), ((2, 3), (2, 6))],
    "1": [((0.8, 1.2), (2.2, 0)), ((2.2, 0), (2.2, 6)), ((0.8, 6), (3.6, 6))],
    "2": [
        ((0, 0.8), (0.8, 0)),
        ((0.8, 0), (3.2, 0)),
        ((3.2, 0), (4, 0.9)),
        ((4, 0.9), (4, 2.2)),
        ((4, 2.2), (0, 6)),
        ((0, 6), (4, 6)),
    ],
    "3": [
        ((0, 0), (4, 0)),
        ((4, 0), (1.8, 2.6)),
        ((1.8, 2.6), (3.2, 2.6)),
        ((3.2, 2.6), (4, 3.6)),
        ((4, 3.6), (4, 5)),
        ((4, 5), (3.2, 6)),
        ((3.2, 6), (0, 6)),
    ],
    "4": [((3, 6), (3, 0)), ((3, 0), (0, 4.2)), ((0, 4.2), (4, 4.2))],
    ">": [((0.6, 0.6), (3, 3)), ((3, 3), (0.6, 5.4))],
    "-": [((0.6, 3), (3.4, 3))],
    " ": [],
}

## Room id -> (area code, name as in docs/design/maps.md, sector).
ROOMS = {
    "loading_dock": ("A1", "LOADING DOCK", "A"),
    "guard_post": ("A2", "GUARD POST", "A"),
    "mess_hall": ("A3", "MESS HALL", "A"),
    "main_corridor": ("A4", "MAIN CORRIDOR", "A"),
    "generator_hall": ("B1", "GENERATOR HALL", "B"),
    "labs": ("B2", "LABS", "B"),
    "coolant_tunnel": ("B3", "COOLANT TUNNEL", "B"),
    "containment_wing": ("C1", "CONTAINMENT WING", "C"),
}
BLOODIED = ("mess_hall", "guard_post", "containment_wing")
SIGN_SIZE = (768, 192)


def text_strokes(text: str, left: float, top: float, height: float, radius: float) -> list:
    scale = height / LETTER_H
    strokes = []
    x = left
    for char in text:
        for (ax, ay), (bx, by) in GLYPHS[char]:
            strokes.append(((x + ax * scale, top + ay * scale), (x + bx * scale, top + by * scale), radius))
        x += (LETTER_W + GAP) * scale
    return strokes


def text_width(text: str, height: float) -> float:
    return len(text) * (LETTER_W + GAP) * height / LETTER_H - GAP * height / LETTER_H


def rasterize(size: tuple, strokes: list) -> list:
    width, height = size
    alpha = [0.0] * (width * height)
    for a, b, radius in strokes:
        x0 = max(0, int(min(a[0], b[0]) - radius - 2))
        x1 = min(width, int(max(a[0], b[0]) + radius + 3))
        y0 = max(0, int(min(a[1], b[1]) - radius - 2))
        y1 = min(height, int(max(a[1], b[1]) + radius + 3))
        for y in range(y0, y1):
            row = y * width
            for x in range(x0, x1):
                edge = radius - segment_distance(x + 0.5, y + 0.5, a, b)
                value = min(1.0, edge / 1.5 + 0.5)
                if value > alpha[row + x]:
                    alpha[row + x] = value
    return alpha


def smooth_noise(x: float, y: float, cell: float, seed: int) -> float:
    gx, gy = x / cell, y / cell
    ix, iy = math.floor(gx), math.floor(gy)
    fx, fy = gx - ix, gy - iy
    fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
    top = noise(ix, iy, seed) * (1 - fx) + noise(ix + 1, iy, seed) * fx
    bottom = noise(ix, iy + 1, seed) * (1 - fx) + noise(ix + 1, iy + 1, seed) * fx
    return top * (1 - fy) + bottom * fy


def blood_mask(size: tuple, seed: int) -> list:
    width, height = size
    drops = []
    for i in range(5):
        x = 0.15 * width + 0.7 * width * noise(i, 3, seed)
        y = 0.1 * height + 0.5 * height * noise(i, 7, seed)
        length = 0.15 * height + 0.5 * height * noise(i, 11, seed)
        drops.append(((x, y), (x + 2, y + length), 2.5 + 3.0 * noise(i, 13, seed)))
    splat_x, splat_y = width * (0.2 + 0.6 * noise(1, 1, seed)), height * 0.3
    drops.append(((splat_x, splat_y), (splat_x + 18, splat_y + 6), 14.0))
    return rasterize(size, drops)


def age(size: tuple, alpha: list, color: tuple, seed: int, bloodied: bool) -> bytes:
    width, height = size
    blood = blood_mask(size, seed) if bloodied else None
    rows = bytearray()
    for y in range(height):
        rows.append(0)
        for x in range(width):
            i = y * width + x
            paint = alpha[i] * (0.62 + 0.25 * smooth_noise(x, y, 40.0, seed))
            paint *= 1.0 - 0.35 * noise(x, y, seed)
            if smooth_noise(x, y, 9.0, seed + 1) > 0.8:
                paint *= 0.12
            out = color
            if blood is not None and blood[i] > 0.0:
                cover = blood[i] * (0.55 + 0.45 * smooth_noise(x, y, 6.0, seed + 2))
                out = tuple(round(c * (1 - cover) + bc * cover) for c, bc in zip(color, BLOOD, strict=True))
                paint = max(paint, cover * 0.9)
            rows.extend((*out, round(255 * min(1.0, paint))))
    return bytes(rows)


def room_sign(code: str, name: str, sector: str) -> list:
    width, height = SIGN_SIZE
    strokes = text_strokes(code, 16, 24, 96, 8.0)
    left = 16 + text_width(code, 96) + 40
    name_height = min(64.0, (width - left - 16) / text_width(name, 1.0))
    strokes += text_strokes(name, left, 24 + (64 - name_height) * 0.5, name_height, max(3.0, name_height * 0.085))
    strokes += text_strokes("HALCYON LABS - SECTOR " + sector + "  >>", left, 112, 22, 2.4)
    strokes.append(((16, height - 22), (width - 16, height - 22), 3.0))
    return strokes


def hex_corner(cx: float, cy: float, r: float, i: int) -> tuple:
    angle = math.radians(60 * i - 90)
    return (cx + r * math.cos(angle), cy + r * math.sin(angle))


def oriel_logo() -> list:
    cx, cy = 112.0, 128.0
    strokes = [(hex_corner(cx, cy, 86.0, i), hex_corner(cx, cy, 86.0, i + 1), 16.0) for i in range(6) if i != 1]
    strokes += [(hex_corner(cx, cy, 40.0, i), hex_corner(cx, cy, 40.0, i + 1), 6.0) for i in range(6)]
    strokes += text_strokes("ORIEL", 236, 64, 72, 7.0)
    strokes += text_strokes("BIOTECHNIC", 240, 168, 32, 3.2)
    return strokes


def research_sign() -> list:
    strokes = text_strokes("HALCYON", 24, 28, 84, 8.0)
    strokes += text_strokes("RESEARCH", 28, 136, 32, 3.2)
    strokes.append(((24, 178), (488, 178), 3.0))
    return strokes


def lane_line() -> list:
    return [((6, 16), (250, 16), 9.0)]


def build(out_dir: Path) -> list:
    out_dir.mkdir(parents=True, exist_ok=True)
    jobs = [("oriel_logo", (640, 256), oriel_logo(), PAINT, 41, False)]
    jobs.append(("lane_line", (256, 32), lane_line(), HAZARD, 43, False))
    jobs.append(("halcyon_research", (512, 192), research_sign(), PAINT, 45, False))
    for index, (room, (code, name, sector)) in enumerate(ROOMS.items()):
        jobs.append(("sign_" + room, SIGN_SIZE, room_sign(code, name, sector), PAINT, 50 + index, room in BLOODIED))
    written = []
    for name, size, strokes, color, seed, bloodied in jobs:
        path = out_dir / (name + ".png")
        save_png(path, size, age(size, rasterize(size, strokes), color, seed, bloodied))
        written.append(path)
    return written


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("out_dir", type=Path)
    for path in build(parser.parse_args().out_dir):
        print("wrote", path)


if __name__ == "__main__":
    main()
