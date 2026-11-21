"""Placeholder 128 px icons for gear bases that have no model yet (F-71 slots, until F-70 adds them).

Writes assets/textures/ui/icons/<base id>.png. Once a base has a GearVisual, tools/render_item_icons.tscn
renders its real icon over this one.
    python tools/assets/placeholder_gear_icons.py
"""

from pathlib import Path

from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parents[2] / "assets" / "textures" / "ui" / "icons"
SIZE = 128
SCALE = 4
FILL = (74, 82, 72, 255)
DETAIL = (138, 145, 140, 255)
EDGE = (185, 194, 176, 255)
WIDTH = 10


def _canvas() -> tuple[Image.Image, ImageDraw.ImageDraw]:
    image = Image.new("RGBA", (SIZE * SCALE, SIZE * SCALE), (0, 0, 0, 0))
    return image, ImageDraw.Draw(image)


def _cap(draw: ImageDraw.ImageDraw) -> None:
    draw.chord((92, 110, 420, 430), 180, 360, fill=FILL, outline=EDGE, width=WIDTH)
    draw.rounded_rectangle((70, 262, 442, 312), 20, fill=DETAIL, outline=EDGE, width=WIDTH)
    draw.rounded_rectangle((226, 96, 286, 130), 12, fill=DETAIL, outline=EDGE, width=WIDTH)


def _gloves(draw: ImageDraw.ImageDraw) -> None:
    for left in (112, 176, 240, 304):
        draw.rounded_rectangle((left, 70, left + 56, 250), 26, fill=FILL, outline=EDGE, width=WIDTH)
    draw.rounded_rectangle((60, 200, 170, 280), 34, fill=FILL, outline=EDGE, width=WIDTH)
    draw.rounded_rectangle((104, 200, 368, 390), 50, fill=FILL, outline=EDGE, width=WIDTH)
    draw.rounded_rectangle((124, 380, 348, 450), 16, fill=DETAIL, outline=EDGE, width=WIDTH)


def _pack(draw: ImageDraw.ImageDraw) -> None:
    draw.rounded_rectangle((196, 40, 316, 110), 30, outline=EDGE, width=WIDTH * 2)
    draw.rounded_rectangle((106, 84, 406, 456), 60, fill=FILL, outline=EDGE, width=WIDTH)
    draw.rounded_rectangle((146, 270, 366, 420), 30, fill=DETAIL, outline=EDGE, width=WIDTH)
    draw.line((146, 320, 366, 320), fill=EDGE, width=WIDTH)
    draw.rounded_rectangle((136, 130, 376, 200), 24, fill=DETAIL, outline=EDGE, width=WIDTH)


def _boots(draw: ImageDraw.ImageDraw) -> None:
    draw.polygon(
        [(150, 50), (300, 50), (300, 300), (440, 330), (450, 420), (110, 420), (110, 300), (150, 260)],
        fill=FILL,
        outline=EDGE,
        width=WIDTH,
    )
    draw.rounded_rectangle((96, 410, 464, 462), 14, fill=DETAIL, outline=EDGE, width=WIDTH)
    for top in (110, 170, 230):
        draw.line((180, top, 270, top), fill=EDGE, width=WIDTH)


SHAPES = {
    "headgear_cap": _cap,
    "gloves_tactical": _gloves,
    "backpack_pack": _pack,
    "boots_field": _boots,
}


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for base_id, shape in SHAPES.items():
        image, draw = _canvas()
        shape(draw)
        image.resize((SIZE, SIZE), Image.Resampling.LANCZOS).save(OUT / f"{base_id}.png", optimize=True)
        print(f"wrote {base_id}.png")


if __name__ == "__main__":
    main()
