"""Builds the town NPCs on the survivor body and bakes their texture maps into the game .glb (ADR 0016).

python tools/assets/town_npcs/build.py quartermaster            # build, bake, check, export npc_quartermaster.glb
python tools/assets/town_npcs/build.py quartermaster --out DIR  # somewhere else
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "player_body"))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy
import costume
import looks
import textures
from player_body.build import OUT, build_body, strip_icc

NPCS = {"quartermaster": (looks.QUARTERMASTER, costume.build_quartermaster)}


def build_npc(name: str) -> None:
    look, dress = NPCS[name]
    build_body(look, dress, costume.CLOTH_BONES)


def builder(name: str):
    """A no-argument build function for build_models.MODELS (no maps, for the checks)."""
    return lambda: build_npc(name)


def main(argv: list) -> None:
    import argparse

    import build_models
    import check_models
    import finish

    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("name", choices=sorted(NPCS))
    parser.add_argument("--out", default=OUT)
    args = parser.parse_args(argv)
    path = os.path.join(args.out, "characters", f"npc_{args.name}.glb")
    build_models.reset_scene()
    build_npc(args.name)
    finish.SMOOTH_ANGLE = math.radians(60.0)  # a soft body, like the player
    finish.finish()
    textures.bake(bpy.data.objects["Body"], NPCS[args.name][0]["textures"])
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        export_yup=True,
        export_apply=True,
        export_vertex_color="ACTIVE",
        export_image_format="JPEG",
        export_jpeg_quality=88,
    )
    strip_icc(path)
    errors = check_models.check_model(path)
    for error in errors:
        print("check failed:", error)
    sys.exit(1 if errors else 0)


if __name__ == "__main__":
    main(sys.argv[1:])
