"""Render a town NPC behind the Trader stall under the stall lamp, beside the hub concept art, for a look card.

Uses the bpy environment from tools/assets/requirements.txt, plus Pillow:
    python tools/render_npc_booth.py npc_quartermaster --out screenshots/npc_booth.jpg
"""

import argparse
import sys
from pathlib import Path

import bpy
from mathutils import Vector
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
import turnarounds
from render_weapon_comparison import linear

MODELS = turnarounds.MODELS_DIR
CONCEPT_CROP = (330, 330, 650, 720)  # the Trader stall in lantern_post_concept.jpg
STALL = (("town/stall_frame.glb", (0, 0, 0)), ("town/trader_goods.glb", (0, -1.0, 1.03)))
NPC_AT = (0.55, -0.45, 0.0)  # behind the counter, facing the street (Blender -Y)
SHOTS = (
    ("booth", (1.4, -3.4, 1.6), (0.4, -0.5, 1.3), 32),
    ("face", (0.8, -1.7, 1.62), (0.55, -0.5, 1.56), 60),
)


def _import(path: Path, at) -> None:
    bpy.ops.import_scene.gltf(filepath=str(path), disable_bone_shape=True)
    for obj in bpy.context.selected_objects:
        if obj.type == "ARMATURE" and obj.animation_data:
            obj.animation_data.action = None
        if obj.parent is None:
            obj.location = Vector(at) + obj.location


def _light(name, kind, at, energy, colour, size=0.3):
    data = bpy.data.lights.new(name, kind)
    data.energy, data.color = energy, linear(colour)
    if kind == "AREA":
        data.size = size
    light = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(light)
    light.location = at
    light.rotation_euler = (Vector((0, -0.4, 1.0)) - Vector(at)).to_track_quat("-Z", "Y").to_euler()


def setup(npc: str, size: tuple, samples: int):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine, scene.cycles.device, scene.cycles.samples = "CYCLES", "CPU", samples
    scene.cycles.use_denoising, scene.cycles.seed = True, 7
    scene.render.resolution_x, scene.render.resolution_y = size
    scene.view_settings.view_transform = "AgX"
    world = bpy.data.worlds.new("Night")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (*linear("#0E1A24"), 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.6
    scene.world = world
    for path, at in STALL:
        _import(MODELS / path, at)
    _import(MODELS / "characters" / f"{npc}.glb", NPC_AT)
    _light("StallLamp", "POINT", (0, -0.6, 2.45), 90, "#FF9A42")
    _light("Street", "AREA", (1.5, -3.0, 1.8), 70, "#CDEEE8", 2.0)
    _light("Moon", "AREA", (-3, 2, 4), 120, "#8FB4D8", 3.0)
    camera = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
    scene.collection.objects.link(camera)
    scene.camera = camera
    return scene, camera


def render(scene, camera, at, look, lens, path: Path) -> Image.Image:
    camera.location, camera.data.lens = at, lens
    camera.rotation_euler = (Vector(look) - Vector(at)).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)
    return Image.open(path).convert("RGB")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("npc")
    parser.add_argument("--out", type=Path, default=turnarounds.REPO / "screenshots/npc_booth.jpg")
    parser.add_argument("--samples", type=int, default=64)
    args = parser.parse_args()
    height = 900
    scene, camera = setup(args.npc, (720, height), args.samples)
    shots = [render(scene, camera, at, look, lens, args.out.with_name(f"{name}.png")) for name, at, look, lens in SHOTS]
    concept = Image.open(turnarounds.IMAGES_DIR / "lantern_post_concept.jpg").crop(CONCEPT_CROP)
    concept = concept.resize((round(concept.width * height / concept.height), height), Image.LANCZOS)
    sheet = Image.new("RGB", (concept.width + 720 * len(shots), height + 40), turnarounds.BACKGROUND)
    draw = ImageDraw.Draw(sheet)
    x = 0
    for image, caption in zip([concept, *shots], ["CONCEPT", "BOOTH", "FACE"], strict=True):
        sheet.paste(image, (x, 40))
        draw.text((x + 10, 8), caption, fill=turnarounds.TEXT, font=turnarounds.font(22))
        x += image.width
    sheet.save(args.out, quality=90)
    print(f"wrote {args.out}")


if __name__ == "__main__":
    main()
