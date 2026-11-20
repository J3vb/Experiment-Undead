"""Draws the launcher icon (Fenlight star on fog background) into launcher/src-tauri/icons/."""

import math
from pathlib import Path

from PIL import Image, ImageDraw

SIZE = 256
FOG = (10, 20, 22, 255)
BIO_GREEN = (141, 255, 58, 255)
OUT = Path(__file__).resolve().parents[2] / "launcher" / "src-tauri" / "icons"


def draw() -> Image.Image:
    image = Image.new("RGBA", (SIZE, SIZE), FOG)
    pen = ImageDraw.Draw(image)
    centre = SIZE / 2
    points = []
    for index in range(16):
        radius = SIZE * (0.46 if index % 4 == 0 else 0.22 if index % 2 == 0 else 0.1)
        angle = math.pi * 2 * index / 16 - math.pi / 2
        points.append((centre + radius * math.cos(angle), centre + radius * math.sin(angle)))
    pen.polygon(points, fill=BIO_GREEN)
    hole = SIZE * 0.07
    pen.ellipse([centre - hole, centre - hole, centre + hole, centre + hole], fill=FOG)
    return image


def main() -> None:
    image = draw()
    image.save(OUT / "icon.png")
    image.save(OUT / "icon.ico", sizes=[(16, 16), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])


if __name__ == "__main__":
    main()
