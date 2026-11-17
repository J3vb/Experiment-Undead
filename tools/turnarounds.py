"""Turnaround sheets for review: layout, style-guide references and image diffs.

No Blender here, so tests run with plain Python (numpy + Pillow).
tools/render_turnarounds.py renders the panels and calls these functions.
"""

from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

REPO = Path(__file__).resolve().parents[1]
MODELS_DIR = REPO / "assets/models"
APPROVED_DIR = REPO / "docs/design/turnarounds"
IMAGES_DIR = REPO / "docs/design/images"
FONT = REPO / "assets/fonts/AtkinsonHyperlegibleNext.ttf"

# Style-guide render each model category should be judged against.
REFERENCES = {
    "zombies": "style_lineup.jpg",
    "weapons": "style_corridor.jpg",
    "kit": "style_corridor.jpg",
    "props": "style_corridor.jpg",
    "dressing": "style_corridor.jpg",
    "doors": "style_corridor.jpg",
    "machines": "style_corridor.jpg",
    "characters": "gear_sets.jpg",
    "gear": "gear_sets.jpg",
    "town": "style_hub.jpg",
}
VIEWS = (("FRONT", 0), ("3/4", 45), ("SIDE", 90), ("BACK", 180))

PIXEL_TOLERANCE = 24  # per channel, 0-255: ignores render noise
CHANGED_FRACTION = 0.002  # more than 0.2% of pixels moved = the model looks different
BACKGROUND = (10, 20, 22)  # #0A1416
TEXT = (232, 236, 230)  # #E8ECE6
DIM_TEXT = (150, 160, 156)
HIGHLIGHT = (141, 255, 58)  # #8DFF3A


def find_models(models_dir=MODELS_DIR):
    """Every committed .glb as (category, name, path), so new models are covered without a list."""
    return [(path.parent.name, path.stem, path) for path in sorted(models_dir.glob("*/*.glb"))]


def reference_for(category, images_dir=IMAGES_DIR):
    """The style-guide image for a category, or None if there is none yet."""
    name = REFERENCES.get(category)
    if name is None or not (images_dir / name).is_file():
        return None
    return images_dir / name


def approved_path(category, name, approved_dir=APPROVED_DIR):
    return approved_dir / category / f"{name}.png"


def font(size):
    return ImageFont.truetype(str(FONT), size)


def make_strip(panels, captions):
    """Turnaround panels side by side, each with its view name in the corner."""
    width, height = panels[0].size
    strip = Image.new("RGB", (width * len(panels), height), BACKGROUND)
    draw = ImageDraw.Draw(strip)
    caption_font = font(max(10, height // 18))
    for index, (panel, caption) in enumerate(zip(panels, captions, strict=True)):
        strip.paste(panel.convert("RGB"), (index * width, 0))
        draw.text((index * width + 8, 6), caption, fill=DIM_TEXT, font=caption_font)
    return strip


def compare(current, approved):
    """Return (fraction of pixels that changed, diff picture) for two renders."""
    if approved is None:
        return None, None
    if approved.size != current.size:
        return 1.0, current.convert("RGB")
    now = np.asarray(current.convert("RGB"), dtype=np.int16)
    before = np.asarray(approved.convert("RGB"), dtype=np.int16)
    changed = np.abs(now - before).max(axis=2) > PIXEL_TOLERANCE
    diff = (before * 0.35).astype(np.uint8)
    diff[changed] = HIGHLIGHT
    return float(changed.mean()), Image.fromarray(diff)


def status(fraction):
    if fraction is None:
        return "new"
    return "changed" if fraction > CHANGED_FRACTION else "same"


def make_sheet(title, subtitle, rows, reference_path):
    """One review image: current, approved and diff strips, then the style-guide reference."""
    width = rows[0][1].width
    header = 56
    blocks = [(label, image) for label, image in rows if image is not None]
    if reference_path is not None:
        with Image.open(reference_path) as reference:
            scaled = reference.convert("RGB").resize((width, round(reference.height * width / reference.width)))
        blocks.append((f"STYLE GUIDE: {reference_path.name}", scaled))
    height = header + sum(image.height + 28 for _, image in blocks)
    sheet = Image.new("RGB", (width, height), BACKGROUND)
    draw = ImageDraw.Draw(sheet)
    draw.text((10, 6), title, fill=TEXT, font=font(24))
    draw.text((10, 34), subtitle, fill=DIM_TEXT, font=font(14))
    y = header
    for label, image in blocks:
        draw.text((10, y + 5), label, fill=DIM_TEXT, font=font(14))
        sheet.paste(image, (0, y + 28))
        y += image.height + 28
    return sheet


def summary_table(results):
    """Markdown for the CI job summary. results: dicts with model, status, fraction, triangles."""
    lines = [
        "## Model turnarounds",
        "",
        (
            "Sheets are in the `turnarounds` artifact. Approve a change by running "
            "`python tools/render_turnarounds.py --approve` and committing `docs/design/turnarounds/`."
        ),
        "",
        "| Model | Status | Pixels changed | Triangles |",
        "|---|---|---|---|",
    ]
    for result in results:
        fraction = result["fraction"]
        changed = "-" if fraction is None else f"{fraction:.3%}"
        lines.append(f"| {result['model']} | {result['status']} | {changed} | {result['triangles']:,} |")
    return "\n".join(lines) + "\n"
