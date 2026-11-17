"""Trial build of the survivor body, kept apart from the shipped player model.

python tools/assets/body_trial/build.py            # build, check and export the .glb
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy
import character_rig as rig
import extremities
import gear_paint as paint
import head
import outfit
import textures
from mathutils import Matrix

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
OUT = os.path.join(REPO, "docs", "design", "reviews", "player-body-trial", "characters", "player.glb")


def materials() -> dict:
    from build_models import material, srgb

    return {
        "skin": material("BodySkin", srgb("#8F6A50"), roughness=0.62),
        "hair": material("BodyHair", srgb("#1E1915"), roughness=0.85),
        "cloth": material("BodyCloth", srgb("#2F393B"), roughness=0.9),
        "rubber": material("BodyRubber", srgb("#1C2122"), roughness=0.78),
    }


def _bind(parts: list, armature, zone: float, bone: str | None = None, blend: float = 0.14) -> list:
    for obj in parts:
        textures.tag(obj)
        paint.zone(obj, zone)
        if bone:
            rig.bind_rigid(obj, armature, bone)
        else:
            rig.bind(obj, armature, blend=blend)
    return parts


def _eyes_marker(armature) -> None:
    eyes = bpy.data.objects.new("Eyes", None)
    bpy.context.collection.objects.link(eyes)
    eyes.parent, eyes.parent_type, eyes.parent_bone = armature, "BONE", "head"
    bpy.context.view_layer.update()
    eyes.matrix_world = Matrix.Translation((0, -0.115, head.EYE[1]))


def build_player_trial(clips: bool = True) -> None:
    """Same 22 bones, facing and scale as the shipped body, so it can stand in for it."""
    from build_models import join_into

    mats = materials()
    armature = rig.build_armature()
    face = head.build_head(mats)
    parts = _bind(face["skin"] + face["hair"] + face["eyes"], armature, paint.ZONE_ACCENT, "head")
    parts += _bind([head.build_neck(mats)], armature, paint.ZONE_ACCENT, blend=0.06)
    clothes = outfit.build_outfit(mats)
    parts += _bind(clothes["cloth"], armature, paint.ZONE_MAIN)
    for sign in (1, -1):
        parts += _bind(clothes["arms"][sign], armature, paint.ZONE_MAIN)
        parts += _bind(extremities.build_glove(mats, sign), armature, paint.ZONE_ACCENT, blend=0.05)
        parts += _bind(extremities.build_boot(mats, sign), armature, paint.ZONE_ACCENT, blend=0.06)
    join_into(parts[0], parts[1:])
    parts[0].name = "Body"
    _eyes_marker(armature)
    if clips:
        import player_clips

        player_clips.build_clips(armature)


def main() -> None:
    import build_models
    import check_models
    import finish

    build_models.reset_scene()
    build_player_trial()
    finish.SMOOTH_ANGLE = math.radians(60.0)  # a soft body, not a hard-edged prop
    finish.finish()
    textures.bake(bpy.data.objects["Body"])
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=OUT,
        export_format="GLB",
        export_yup=True,
        export_apply=True,
        export_vertex_color="ACTIVE",
        export_image_format="JPEG",
        export_jpeg_quality=88,
    )
    errors = check_models.check_model(OUT)
    for error in errors:
        print("check failed:", error)
    sys.exit(1 if errors else 0)


if __name__ == "__main__":
    main()
