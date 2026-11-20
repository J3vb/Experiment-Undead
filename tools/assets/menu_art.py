"""Draws the front-end art (F-87): the FENLIGHT logo with green Fenlight veins and the menu brush stroke.

Run from the repo root: python tools/assets/menu_art.py
Writes assets/ui/fenlight_logo.png and assets/ui/brush_stroke.png. Same seed, same pixels.
"""

import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

REPO = Path(__file__).resolve().parents[2]
FONT = REPO / "tools" / "assets" / "fonts" / "BebasNeue-Regular.ttf"
OUT = REPO / "assets" / "ui"
SEED = 87

LOGO_SIZE = (1600, 560)
LETTER = (226, 230, 224)
GRIME = (120, 128, 124)
BIO_GREEN = (141, 255, 58)
BRUSH_SIZE = (1024, 128)
BRUSH = (217, 102, 43)


def _noise(rng: np.random.Generator, size: tuple, blur: float) -> np.ndarray:
    """Smooth noise in 0..1, size (w, h)."""
    raw = Image.fromarray((rng.random((size[1], size[0])) * 255).astype(np.uint8))
    smooth = np.asarray(raw.filter(ImageFilter.GaussianBlur(blur)), dtype=np.float32)
    lo, hi = smooth.min(), smooth.max()
    return (smooth - lo) / max(hi - lo, 1.0)


def _letters(size: tuple) -> tuple:
    """White-on-black mask of the word and its bounding box."""
    mask = Image.new("L", size, 0)
    pen = ImageDraw.Draw(mask)
    font = ImageFont.truetype(str(FONT), 360)
    x = 40
    for char in "FENLIGHT":
        pen.text((x, 40), char, font=font, fill=255)
        x += pen.textlength(char, font=font) + 22
    return mask, mask.getbbox()


def _drips(rng: np.random.Generator, mask: Image.Image, box: tuple) -> None:
    """Thin melt drips hanging from the bottom edge of the letters."""
    pixels = np.asarray(mask)
    pen = ImageDraw.Draw(mask)
    for _ in range(26):
        x = int(rng.integers(box[0] + 8, box[2] - 8))
        column = np.nonzero(pixels[:, x] > 128)[0]
        if column.size == 0:
            continue
        top = int(column.max())
        length = float(rng.uniform(10, 46))
        width = float(rng.uniform(2.5, 6.0))
        for step in range(int(length)):
            w = width * (1.0 - step / length) + 0.6
            pen.ellipse([x - w / 2, top + step - w / 2, x + w / 2, top + step + w / 2], fill=255)


def _erode(rng: np.random.Generator, mask: Image.Image) -> np.ndarray:
    """Chipped, scratched paint: knock holes and streaks out of the letters."""
    alpha = np.asarray(mask, dtype=np.float32) / 255.0
    size = mask.size
    blotch = _noise(rng, size, 6.0)
    speck = rng.random((size[1], size[0]))
    streak = np.repeat(_noise(rng, (size[0], 1), 1.5), size[1], axis=0)
    holes = (blotch > 0.78) | (speck > 0.985) | ((streak > 0.86) & (blotch > 0.55))
    alpha[holes] *= 0.15
    return alpha


def _vein(pen: ImageDraw.ImageDraw, rng: np.random.Generator, start: tuple, angle: float, length: float, width: float):
    """One crooked vein that forks as it goes, like a lightning crack."""
    x, y = start
    steps = int(length / 6)
    for step in range(steps):
        angle += float(rng.normal(0.0, 0.28))
        angle = min(max(angle, math.pi * 0.2), math.pi * 0.8)
        nx, ny = x + math.cos(angle) * 6, y + math.sin(angle) * 6
        w = max(width * (1.0 - step / steps), 1.0)
        pen.line([(x, y), (nx, ny)], fill=255, width=round(w))
        if width > 2.5 and rng.random() < 0.09:
            _vein(pen, rng, (nx, ny), angle + float(rng.choice([-0.7, 0.7])), length * 0.5, w * 0.6)
        x, y = nx, ny


def _veins(rng: np.random.Generator, size: tuple, box: tuple) -> Image.Image:
    """Green veins growing down out of the middle letters, with a soft glow."""
    lines = Image.new("L", size, 0)
    pen = ImageDraw.Draw(lines)
    centre = (box[0] + box[2]) / 2
    for _ in range(8):
        x = float(rng.normal(centre, (box[2] - box[0]) * 0.12))
        _vein(pen, rng, (x, box[3] - 90), math.pi / 2 + float(rng.normal(0, 0.3)), float(rng.uniform(150, 240)), 9.0)
    glow = lines.filter(ImageFilter.GaussianBlur(16))
    core = np.asarray(lines, dtype=np.float32) / 255.0
    halo = np.asarray(glow, dtype=np.float32) / 255.0 * 2.6
    rgba = np.zeros((size[1], size[0], 4), dtype=np.float32)
    rgba[..., :3] = BIO_GREEN
    rgba[..., :3] = rgba[..., :3] * (1.0 - core[..., None] * 0.5) + 255.0 * core[..., None] * 0.5
    rgba[..., 3] = np.clip(np.maximum(core, halo * 0.7), 0.0, 1.0) * 255.0
    return Image.fromarray(rgba.astype(np.uint8), "RGBA")


def draw_logo() -> Image.Image:
    rng = np.random.default_rng(SEED)
    mask, box = _letters(LOGO_SIZE)
    _drips(rng, mask, box)
    alpha = _erode(rng, mask)
    shade = np.linspace(0.0, 1.0, LOGO_SIZE[1], dtype=np.float32)[:, None] ** 2
    grime = _noise(rng, LOGO_SIZE, 3.0)[..., None] * 0.35 + shade[..., None] * 0.45
    colour = np.array(LETTER, dtype=np.float32) * (1.0 - grime) + np.array(GRIME, dtype=np.float32) * grime
    letters = np.dstack([colour, alpha[..., None] * 255.0]).astype(np.uint8)
    word = Image.fromarray(letters, "RGBA")
    shadow = Image.new("RGBA", LOGO_SIZE, (0, 0, 0, 0))
    shadow.putalpha(Image.fromarray((alpha * 200).astype(np.uint8)).filter(ImageFilter.GaussianBlur(10)))
    logo = Image.alpha_composite(shadow, _veins(rng, LOGO_SIZE, box))
    logo = Image.alpha_composite(logo, word)
    return logo.crop(logo.getbbox())


def draw_brush() -> Image.Image:
    """A rough paint stroke: solid middle, ragged top and bottom, dry bristle streaks at the right end."""
    rng = np.random.default_rng(SEED + 1)
    w, h = BRUSH_SIZE
    xs = np.linspace(0.0, 1.0, w, dtype=np.float32)[None, :]
    ys = np.linspace(-1.0, 1.0, h, dtype=np.float32)[:, None]
    top = 0.72 + (_noise(rng, (w, 1), 10.0) - 0.5) * 0.3 + (_noise(rng, (w, 1), 1.5) - 0.5) * 0.06
    bottom = 0.72 + (_noise(rng, (w, 1), 10.0) - 0.5) * 0.3 + (_noise(rng, (w, 1), 1.5) - 0.5) * 0.06
    body = np.where(ys < 0, -ys < top, ys < bottom).astype(np.float32)
    bristles = np.repeat(_noise(rng, (1, h), 1.5), w, axis=1)
    dry = np.clip((xs - 0.55) / 0.45, 0.0, 1.0)
    reach = 1.0 - dry * 1.6 + bristles * 1.1
    left = np.clip((xs - 0.01 - _noise(rng, (1, h), 2.0) * 0.03) * 60.0, 0.0, 1.0)
    grain = 0.88 + _noise(rng, (w, h), 1.0) * 0.12
    alpha = body * np.clip(reach, 0.0, 1.0) * left * grain
    rgba = np.zeros((h, w, 4), dtype=np.float32)
    rgba[..., :3] = np.array(BRUSH, dtype=np.float32) * (0.85 + bristles[..., None] * 0.2)
    rgba[..., 3] = np.clip(alpha, 0.0, 1.0) * 255.0
    return Image.fromarray(np.clip(rgba, 0, 255).astype(np.uint8), "RGBA")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    draw_logo().save(OUT / "fenlight_logo.png", optimize=True)
    draw_brush().save(OUT / "brush_stroke.png", optimize=True)


if __name__ == "__main__":
    main()
