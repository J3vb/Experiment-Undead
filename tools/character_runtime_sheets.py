#!/usr/bin/env python3
"""Pair fixed-camera legacy/runtime weapon captures into review PNG sheets."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

VIEWS = ("hip_common", "hip_legendary", "ads_common", "ads_legendary")
CELL = (640, 360)
HEADER = 40
CONTACTS = (
    "brenner_trench_r",
    "fieldhand_lever_r",
    "corvid_338_r",
    "halberd_lmg_l",
    "ironwood_50_l",
    "siphon_l",
    "hollis_44_l",
    "pistol_service_l",
    "wren_mp_r",
    "mako_pdw_l",
)


def compose(before: Path, after: Path, output: Path) -> list[Path]:
    """Require all eight source images; preserve identical framing within each row."""
    weapons = sorted(path.name.removesuffix("_hip_common.png") for path in before.glob("*_hip_common.png"))
    if not weapons:
        raise ValueError(f"No runtime captures in {before}")
    output.mkdir(parents=True, exist_ok=True)
    saved = []
    font = ImageFont.load_default(size=20)
    for weapon in weapons:
        sheet = Image.new("RGB", (CELL[0] * 2, CELL[1] * len(VIEWS) + HEADER), "#10191c")
        draw = ImageDraw.Draw(sheet)
        for column, (folder, label) in enumerate(((before, "BEFORE / LEGACY HANDS"), (after, "AFTER / RUNTIME ARMS"))):
            draw.text((column * CELL[0] + 16, 10), label, fill="#D9D9D2", font=font)
            for row, view in enumerate(VIEWS):
                source = folder / f"{weapon}_{view}.png"
                with Image.open(source) as image:
                    if image.size != (1280, 720):
                        raise ValueError(f"Unexpected capture size {image.size}: {source}")
                    cell = image.convert("RGB").resize(CELL, Image.Resampling.LANCZOS)
                sheet.paste(cell, (column * CELL[0], HEADER + row * CELL[1]))
        path = output / f"runtime_{weapon}.png"
        sheet.save(path, optimize=True)
        saved.append(path)
    return saved


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("before", type=Path)
    parser.add_argument("after", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--contacts", action="store_true", help="Also pair tailored grip closeups.")
    args = parser.parse_args()
    for path in compose(args.before, args.after, args.output):
        print(path)
    if args.contacts:
        print(compose_contacts(args.after, args.output))


def compose_contacts(after: Path, output: Path) -> Path:
    """Keep the source captions and framing in a compact supplemental contact sheet."""
    rows = (len(CONTACTS) + 1) // 2
    sheet = Image.new("RGB", (CELL[0] * 2, CELL[1] * rows), "#10191c")
    for index, name in enumerate(CONTACTS):
        with Image.open(after / f"{name}.png") as image:
            if image.size != (1280, 720):
                raise ValueError(f"Unexpected contact capture size {image.size}: {name}")
            cell = image.convert("RGB").resize(CELL, Image.Resampling.LANCZOS)
        sheet.paste(cell, ((index % 2) * CELL[0], (index // 2) * CELL[1]))
    path = output / "runtime_contacts.png"
    sheet.save(path, optimize=True)
    return path


if __name__ == "__main__":
    main()
