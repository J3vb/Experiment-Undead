"""Side-by-side review sheet: shipped body, trial body and the trial face, same turnaround lighting.

python tools/assets/body_trial/compare.py          # after build.py
"""

import argparse
import math
import os
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

import bpy
import render_turnarounds
import turnarounds
from PIL import Image, ImageDraw

REVIEW = turnarounds.REPO / "docs/design/reviews/player-body-trial"
SHIPPED = turnarounds.MODELS_DIR / "characters/player.glb"
TRIAL = REVIEW / "characters/player.glb"
HEAD_HEIGHT = 1.675  # metres, middle of the face


def _pose(clip: str, frame: int) -> None:
    """Show one frame of a clip instead of the rest pose."""
    armature = next(obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE")
    armature.animation_data_create()
    armature.animation_data.action = bpy.data.actions[clip]
    bpy.context.scene.frame_set(frame)


def _strip(path: Path, args, directory: str, zoom: float = 1.0, clip: str = "") -> tuple:
    scene = render_turnarounds.setup_scene(args.size, args.samples)
    root, size, triangles = render_turnarounds.import_model(path)
    if clip:
        _pose(clip, 8)
    if zoom > 1.0:
        scene.camera.data.ortho_scale /= zoom
        lift = (HEAD_HEIGHT - size.z / 2) * root.scale.z
        scene.camera.location.z += lift * math.cos(render_turnarounds.ELEVATION)
        scene.camera.location.y -= lift * math.sin(render_turnarounds.ELEVATION) * 0
    panels = []
    for _caption, degrees in turnarounds.VIEWS:
        root.rotation_euler = (0, 0, math.radians(degrees))
        scene.render.filepath = os.path.join(directory, f"{degrees}.png")
        bpy.ops.render.render(write_still=True)
        panels.append(Image.open(scene.render.filepath).convert("RGB"))
    return turnarounds.make_strip(panels, [caption for caption, _ in turnarounds.VIEWS]), triangles


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--size", type=int, default=384, help="pixels per square panel")
    parser.add_argument("--samples", type=int, default=48, help="CPU Cycles samples per pixel")
    args = parser.parse_args()
    rows = []
    with tempfile.TemporaryDirectory(prefix="body-trial-") as directory:
        for label, path, zoom, clip in (
            ("SHIPPED BODY", SHIPPED, 1.0, ""),
            ("TRIAL BODY", TRIAL, 1.0, ""),
            ("TRIAL FACE", TRIAL, 5.0, ""),
            ("TRIAL BODY, RUN CLIP", TRIAL, 1.0, "run"),
        ):
            strip, triangles = _strip(path, args, directory, zoom, clip)
            rows.append((f"{label} / {triangles:,} triangles", strip))
            strip.save(REVIEW / (label.lower().replace(",", "").replace(" ", "_") + ".png"), optimize=True)
    with Image.open(turnarounds.IMAGES_DIR / "player_gear_concept.jpg") as concept:
        width = rows[0][1].width
        rows.append(("LOOK TARGET: player_gear_concept.jpg", concept.convert("RGB").resize((width, width * 9 // 16))))
    band = 34
    sheet = Image.new(
        "RGB", (rows[0][1].width, sum(strip.height + band for _label, strip in rows)), turnarounds.BACKGROUND
    )
    draw, top = ImageDraw.Draw(sheet), 0
    for label, strip in rows:
        draw.text((10, top + 6), label, fill=turnarounds.TEXT, font=turnarounds.font(20))
        sheet.paste(strip, (0, top + band))
        top += strip.height + band
    sheet.save(REVIEW / "comparison.jpg", quality=88)
    print(f"wrote {REVIEW / 'comparison.jpg'}")


if __name__ == "__main__":
    main()
