"""Builds the survivor player body and bakes its texture maps into the game .glb (ADR 0015).

python tools/assets/player_body/build.py            # build, bake, check and export assets/models/characters/player.glb
python tools/assets/player_body/build.py --out DIR  # somewhere else
"""

import json
import math
import os
import struct
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
OUT = os.path.join(REPO, "assets", "models")


def materials() -> dict:
    from build_models import material, srgb

    return {
        "skin": material("BodySkin", srgb("#8F6A50"), roughness=0.62),
        "hair": material("BodyHair", srgb("#1E1915"), roughness=0.85),
        "cloth": material("BodyCloth", srgb("#2F393B"), roughness=0.9),
        "rubber": material("BodyRubber", srgb("#1C2122"), roughness=0.78),
    }


TORSO = ("pelvis", "spine_01", "spine_02", "spine_03", "neck", "clavicle_L", "clavicle_R")
ARM = ("clavicle_{s}", "upperarm_{s}", "forearm_{s}")
# Clothes follow only the bones named here ({s} is the part's side), so a pocket moves with the
# cloth under it and the jacket skirt never chases a leg.
CLOTH_BONES = {
    **dict.fromkeys(("Jacket", "JacketHem", "Placket", "BackYoke", "ChestPocket", "PocketFlap", "HipPocket"), TORSO),
    **dict.fromkeys(("Snap", "HoodRoll", "HoodPouch"), TORSO),
    **dict.fromkeys(("ScarfLow", "ScarfHigh"), ("spine_03", "neck")),
    "Pelvis": ("pelvis",),
    "Leg": ("pelvis", "thigh_{s}", "shin_{s}"),
    **dict.fromkeys(("CargoPocket", "CargoFlap"), ("thigh_{s}",)),
    **dict.fromkeys(("KneePad", "KneeStrap"), ("shin_{s}",)),
    **dict.fromkeys(("Sleeve", "ElbowPatch"), ARM),
    "ArmPocket": ("upperarm_{s}",),
    "CuffBand": ("forearm_{s}",),
}


def _skin_to(obj, armature, bones: tuple, blend: float) -> None:
    """Like character_rig.bind, but only among the named bones."""
    world = armature.matrix_world
    segments = [(b, world @ b.head_local, world @ b.tail_local) for b in armature.data.bones if b.name in bones]
    rig._prepare_binding(obj, armature)
    groups = {bone.name: obj.vertex_groups.new(name=bone.name) for bone, _head, _tail in segments}
    for vertex in obj.data.vertices:
        for bone, weight in rig._weights(obj.matrix_world @ vertex.co, segments, blend).items():
            groups[bone].add([vertex.index], weight, "REPLACE")


def _bind(parts: list, armature, zone: float, bone: str | None = None, blend: float = 0.14) -> list:
    for obj in parts:
        textures.tag(obj)
        paint.zone(obj, zone)
        cloth = CLOTH_BONES.get(obj.name.split(".")[0])
        if cloth:
            side = "L" if sum(vertex.co.x for vertex in obj.data.vertices) > 0 else "R"
            _skin_to(obj, armature, tuple(name.format(s=side) for name in cloth), 0.12)
        elif bone:
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


def build_player(clips: bool = True) -> None:
    """Survivor body on the shared 22 bones, facing -Y, 1.8 m tall."""
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


def _without_icc(jpeg: bytes) -> bytes:
    """Drop ICC profile (APP2) segments: Godot's JPEG loader rejects them, and the maps are plain sRGB/data."""
    out, i = bytearray(jpeg[:2]), 2
    while jpeg[i + 1] != 0xDA:  # start of scan: the rest is image data
        length = struct.unpack(">H", jpeg[i + 2 : i + 4])[0]
        if jpeg[i + 1] != 0xE2:
            out += jpeg[i : i + 2 + length]
        i += 2 + length
    return bytes(out + jpeg[i:])


def strip_icc(path: str) -> None:
    """Rewrite the .glb with every embedded JPEG cleaned, laying the buffer views out again."""
    with open(path, "rb") as glb:
        data = glb.read()
    json_length = struct.unpack("<I", data[12:16])[0]
    document = json.loads(data[20 : 20 + json_length])
    binary = data[28 + json_length :]
    images = {image["bufferView"] for image in document.get("images", [])}
    packed = bytearray()
    for index, view in enumerate(document["bufferViews"]):
        start = view.get("byteOffset", 0)
        chunk = binary[start : start + view["byteLength"]]
        if index in images:
            chunk = _without_icc(chunk)
        view["byteOffset"], view["byteLength"] = len(packed), len(chunk)
        packed += chunk + b"\0" * (-len(chunk) % 4)
    document["buffers"][0]["byteLength"] = len(packed)
    text = json.dumps(document, separators=(",", ":")).encode()
    text += b" " * (-len(text) % 4)
    total = 12 + 8 + len(text) + 8 + len(packed)
    with open(path, "wb") as glb:
        glb.write(struct.pack("<III", 0x46546C67, 2, total))
        glb.write(struct.pack("<II", len(text), 0x4E4F534A) + text)
        glb.write(struct.pack("<II", len(packed), 0x004E4942) + packed)


def main(argv: list) -> None:
    import argparse

    import build_models
    import check_models
    import finish

    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--out", default=OUT)
    path = os.path.join(parser.parse_args(argv).out, "characters", "player.glb")
    build_models.reset_scene()
    build_player()
    finish.SMOOTH_ANGLE = math.radians(60.0)  # a soft body, not a hard-edged prop
    finish.finish()
    textures.bake(bpy.data.objects["Body"])
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
