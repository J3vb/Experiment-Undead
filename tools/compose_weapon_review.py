"""Pair untouched BEFORE/AFTER captures into weapon review plates, without changing their exposure.

python tools/compose_weapon_review.py --before /tmp/before --after /tmp/after --out docs/design/reviews/weapons-date
Inputs are render_turnarounds.py sheets in turnarounds/ and weapon_review.tscn images in booth/.
"""

import argparse
from pathlib import Path

import turnarounds
from PIL import Image, ImageDraw

WIDTH = 800
CAPTION = 32
VIEWS = {
    "overview": ["turnaround", "common_booth", "legendary_booth", "shape_silhouette", "common_10m", "legendary_10m"],
    "first_person": ["common_hip", "legendary_hip", "common_ads", "legendary_ads"],
}


def capture(directory, model, view):
    """Read a full-frame capture or the CURRENT strip from the standard turnaround review sheet."""
    if view == "turnaround":
        source = Image.open(directory / "turnarounds" / f"weapons__{model}.png").convert("RGB")
        source = source.crop((0, 84, source.width, 84 + source.width // 4))
    else:
        source = Image.open(directory / "booth" / f"{model}_{view}.png").convert("RGB")
    return source.resize((WIDTH, round(source.height * WIDTH / source.width)), Image.Resampling.LANCZOS)


def plate(before, after, model, views):
    """Before stays left, after stays right; every row shares resolution and framing."""
    pairs = [(view, capture(before, model, view), capture(after, model, view)) for view in views]
    height = CAPTION + sum(left.height + CAPTION for _, left, _ in pairs)
    result = Image.new("RGB", (WIDTH * 2, height), turnarounds.BACKGROUND)
    draw = ImageDraw.Draw(result)
    font = turnarounds.font(20)
    for x, label in ((12, "BEFORE"), (WIDTH + 12, "AFTER")):
        draw.text((x, 4), f"{model.upper()} / {label}", font=font, fill=turnarounds.TEXT)
    y = CAPTION
    for view, left, right in pairs:
        draw.text((12, y + 4), view.replace("_", " ").upper(), font=font, fill=turnarounds.TEXT)
        y += CAPTION
        result.paste(left, (0, y))
        result.paste(right, (WIDTH, y))
        y += left.height
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--before", type=Path, required=True)
    parser.add_argument("--after", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    for path in sorted((turnarounds.MODELS_DIR / "weapons").glob("*.glb")):
        for name, views in VIEWS.items():
            output = args.out / f"{path.stem}_{name}.png"
            plate(args.before, args.after, path.stem, views).save(output, optimize=True)
            print(output)


if __name__ == "__main__":
    main()
