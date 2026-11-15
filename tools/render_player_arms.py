"""Render the committed arms from an inspection-only first-person pose beside gear_fp.jpg.

Run with the Blender Python environment: python tools/render_player_arms.py
This poses the imported skeleton for the picture; it never writes model or viewmodel files.
"""

import argparse
import math
import os
from pathlib import Path

import bpy
from mathutils import Matrix, Vector
from PIL import Image, ImageDraw, ImageFont
from render_weapon_comparison import camera_for, linear, setup_scene

REPO = Path(__file__).resolve().parents[1]


def _basis(direction, dorsal):
    direction = Vector(direction).normalized()
    dorsal = Vector(dorsal)
    dorsal = (dorsal - direction * dorsal.dot(direction)).normalized()
    return Matrix((dorsal.cross(direction), dorsal, direction)).transposed()


def _pose_bone(armature, name, head, direction, dorsal):
    """Place a bone in armature space while retaining its rest length and scale."""
    rest = armature.data.bones[name]
    rotation = _basis(direction, dorsal) @ _basis(rest.tail_local - rest.head_local, (0, 1, 0)).inverted()
    posed = rotation.to_4x4() @ rest.matrix_local
    posed.translation = head
    armature.pose.bones[name].matrix = posed
    bpy.context.view_layer.update()


def _pose_arm(armature, side, shoulder, wrist, bend):
    """Two fixed-length segments place each elbow naturally outside the grip line."""
    shoulder, wrist, bend = Vector(shoulder), Vector(wrist), Vector(bend)
    upper = armature.data.bones["upperarm_" + side].length
    forearm = armature.data.bones["forearm_" + side].length
    direction = (wrist - shoulder).normalized()
    distance = (wrist - shoulder).length
    along = (upper * upper - forearm * forearm + distance * distance) / (2 * distance)
    height = math.sqrt(max(0, upper * upper - along * along))
    bend = (bend - direction * bend.dot(direction)).normalized()
    elbow = shoulder + direction * along + bend * height
    dorsal = (0.7, -0.2, 0.7) if side == "R" else (0, 0, 1)
    _pose_bone(armature, "upperarm_" + side, shoulder, elbow - shoulder, dorsal)
    _pose_bone(armature, "forearm_" + side, elbow, wrist - elbow, dorsal)
    if side == "R":
        _pose_bone(armature, "hand_R", wrist, (0.10, 0.95, -0.30), (0.7, -0.2, 0.7))
    else:
        _pose_bone(armature, "hand_L", wrist, (0.8, 0.45, 0.25), (-0.3, -0.3, 1))


def _import_arms():
    bpy.ops.import_scene.gltf(filepath=str(REPO / "assets/models/characters/player_arms.glb"), disable_bone_shape=True)
    imported = list(bpy.context.selected_objects)
    armature = next(obj for obj in imported if obj.type == "ARMATURE")
    _pose_arm(armature, "R", (0.20, 0.015, -0.21), (0.17, 0.39, -0.055), (1, 0, -0.25))
    _pose_arm(armature, "L", (-0.20, 0.015, -0.21), (0.015, 0.54, -0.14), (-1, 0, -1))
    triangles = sum(len(face.vertices) - 2 for obj in imported if obj.type == "MESH" for face in obj.data.polygons)
    return triangles


def _render(args):
    scene = setup_scene(args.width, args.samples)
    scene.world.node_tree.nodes["Background"].inputs[0].default_value = (*linear("#0A1416"), 1)
    triangles = _import_arms()
    camera = camera_for("first_person")
    camera.data.angle = math.radians(75)
    camera.location.z = 0.015
    camera.rotation_euler = Vector((0, 1, -0.10)).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = str(args.out / "first_person.png")
    bpy.ops.render.render(write_still=True)
    return triangles


def _closeups(args):
    scene = bpy.context.scene
    camera = scene.camera
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 0.22
    scene.render.resolution_y = args.width
    mesh = next(obj for obj in scene.objects if obj.type == "MESH")
    group = mesh.vertex_groups.new(name="InspectionSide")
    mask = mesh.modifiers.new("Inspect one glove", "MASK")
    mask.vertex_group = group.name
    for side, sign, location, target in (
        ("right", -1, (0.40, 0.21, 0.18), (0.18, 0.44, -0.06)),
        ("left", 1, (-0.08, 0.29, 0.14), (0.04, 0.58, -0.13)),
    ):
        group.remove([vertex.index for vertex in mesh.data.vertices])
        group.add([vertex.index for vertex in mesh.data.vertices if sign * vertex.co.x > 0], 1, "REPLACE")
        camera.location = location
        camera.rotation_euler = (Vector(target) - camera.location).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = str(args.out / f"glove_{side}.png")
        bpy.ops.render.render(write_still=True)


def _compare(args, triangles):
    width, height = args.width, round(args.width * 9 / 16)
    background, text = "#0A1416", "#E8ECE6"
    comparison = Image.new("RGB", (width * 2, height + 64), background)
    draw = ImageDraw.Draw(comparison)
    font = ImageFont.truetype(str(REPO / "assets/fonts/AtkinsonHyperlegibleNext.ttf"), max(14, width // 50))
    for index, (path, title) in enumerate(
        (
            (args.out / "first_person.png", f"PLAYER ARMS / {triangles:,} triangles / 75 deg HFOV"),
            (REPO / "docs/design/images/gear_fp.jpg", "DESIGN REFERENCE / gear_fp.jpg"),
        )
    ):
        with Image.open(path) as panel:
            comparison.paste(panel.convert("RGB").resize((width, height)), (index * width, 64))
        draw.text((index * width + 16, 12), title, fill=text, font=font)
    draw.text(
        (16, 36),
        "Inspection pose only; vest cuffs, implant and weapon fitting follow separately.",
        fill=text,
        font=font,
    )
    args.comparison.parent.mkdir(parents=True, exist_ok=True)
    comparison.save(args.comparison, optimize=True)
    print(f"saved {args.comparison}", flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--out", type=Path, default=REPO / "screenshots/player_arms")
    parser.add_argument("--comparison", type=Path, default=REPO / "docs/design/images/player_arms_fp.png")
    parser.add_argument("--width", type=int, default=1280)
    parser.add_argument("--samples", type=int, default=48)
    parser.add_argument("--closeups", action="store_true", help="also inspect each glove at a 0.22 m frame")
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    os.environ.setdefault("OMP_NUM_THREADS", "8")
    triangles = _render(args)
    _compare(args, triangles)
    if args.closeups:
        _closeups(args)


if __name__ == "__main__":
    main()
