"""Each rule in check_models.py gets a model that breaks it on purpose.

Run from the repo root: python -m pytest tools/assets/tests
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import bpy

# isort: split
# bpy must load before bmesh.
import bmesh
import build_models
import character_rig
import check_models
import pytest


def broken(tmp_path, name: str, change=None, folder: str = "") -> list:
    """Builds model `name`, applies `change`, exports it and returns the check errors."""
    rel_path, build = build_models.MODELS[name]
    if folder:
        rel_path = os.path.join(folder, os.path.basename(rel_path))
    build_models.reset_scene()
    build()
    if change:
        change(bpy.data.objects)
        bpy.context.view_layer.update()
    path = str(tmp_path / rel_path)
    build_models.export(path)
    return check_models.check_model(path)


def edit_mesh(obj, edit) -> None:
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    edit(bm)
    bm.to_mesh(obj.data)
    bm.free()


def has(errors: list, text: str) -> bool:
    return any(text in e for e in errors)


@pytest.mark.parametrize("name", list(build_models.MODELS))
def test_committed_model_passes(name):
    path = os.path.join(check_models.REPO, "assets", "models", build_models.MODELS[name][0])
    assert check_models.check_model(path) == []


@pytest.mark.parametrize("name", ["wall_panel", "rifle_ar", "shambler"])
def test_fresh_build_passes(tmp_path, name):
    assert broken(tmp_path, name) == []


def test_flipped_normals(tmp_path):
    errors = broken(
        tmp_path,
        "wall_panel",
        lambda o: edit_mesh(o["Stripe"], lambda bm: bmesh.ops.reverse_faces(bm, faces=bm.faces[:])),
    )
    assert has(errors, "Stripe: a closed part has inward normals")


def test_zero_area_faces(tmp_path):
    def squash(bm):
        for v in bm.verts:
            v.co.z = 0.0

    errors = broken(tmp_path, "wall_panel", lambda o: edit_mesh(o["Seam"], squash))
    assert has(errors, "Seam: has zero-area faces")


def test_triangle_budget(tmp_path):
    def add_dense_sphere(objects):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=64, ring_count=40, radius=0.3, location=(0, 0, 1))
        bpy.context.active_object.data.materials.append(objects["Panel"].data.materials[0])

    assert has(broken(tmp_path, "wall_panel", add_dense_sphere), "budget for kit is 2000")


def test_material_budget(tmp_path):
    def many_materials(objects):
        for i, obj in enumerate(o for o in objects if o.type == "MESH"):
            obj.data.materials[0] = build_models.material(f"Extra{i}", (0.1, 0.1, 0.1, 1.0))
        extra = build_models.box(
            "Extra", (0.1, 0.1, 0.1), (0, 0, 1), build_models.material("Extra9", (0.2, 0.2, 0.2, 1.0))
        )
        extra.data.materials.append(build_models.material("Extra8", (0.3, 0.3, 0.3, 1.0)))

    assert has(broken(tmp_path, "wall_panel", many_materials), "materials, budget for kit is 4")


def test_missing_material(tmp_path):
    assert has(
        broken(tmp_path, "wall_panel", lambda o: o["Seam"].data.materials.clear()), "Seam: every mesh needs a material"
    )


def test_unnamed_material(tmp_path):
    def rename(objects):
        objects["Seam"].data.materials[0] = bpy.data.materials.new("Material.001")

    assert has(broken(tmp_path, "wall_panel", rename), "material 'Material.001' needs a real name")


def test_floating_kit_piece(tmp_path):
    def lift(objects):
        for obj in objects:
            obj.location.z += 0.5

    assert has(broken(tmp_path, "wall_panel", lift), "lowest point is at height 0.500")


def test_off_centre_kit_piece(tmp_path):
    def slide(objects):
        for obj in objects:
            obj.location.x += 0.5

    assert has(broken(tmp_path, "wall_panel", slide), "from the footprint centre")


def test_gun_origin_outside(tmp_path):
    assert has(
        broken(tmp_path, "rifle_ar", lambda o: setattr(o["Receiver"], "location", (0, 2, 0))),
        "origin must sit inside the gun",
    )


def test_gun_facing_backwards(tmp_path):
    def turn(objects):
        objects["Receiver"].rotation_euler.z = math.pi

    assert has(broken(tmp_path, "rifle_ar", turn), "must be at the front of the gun")


def test_zombie_facing_backwards(tmp_path):
    def turn(objects):
        objects["Skeleton"].rotation_euler.z = math.pi

    assert has(broken(tmp_path, "shambler", turn), "Eyes must sit in front of the head")


def test_missing_zombie_bone(tmp_path):
    def rename(objects):
        objects["Skeleton"].data.bones["upperarm_L"].name = "left_upperarm"

    assert has(broken(tmp_path, "shambler", rename), "missing bones upperarm_L")


def test_belly_with_wrong_bone(tmp_path):
    def rebind(objects):
        character_rig.bind_rigid(objects["Belly"], objects["Skeleton"], "spine_02")

    assert has(broken(tmp_path, "bloater", rebind), "Belly must be bound rigidly to spine_01")


def test_eyes_with_wrong_bone_parent(tmp_path):
    def reparent(objects):
        objects["Eyes"].parent_bone = "neck"

    assert has(broken(tmp_path, "shambler", reparent), "Eyes must be a child of the head bone")


@pytest.mark.parametrize(
    ("bound", "pivot", "fails"), [(True, (0, 0, 0), False), (False, (0, 0, 0), True), (True, (0, 0, 0.2), True)]
)
def test_vest_shell_accepts_only_a_skinned_rig_origin(bound, pivot, fails):
    build_models.reset_scene()
    armature = character_rig.build_armature()
    mat = build_models.material("GearFabric", (0.2, 0.2, 0.2, 1))
    shell = build_models.box("Shell", (0.2, 0.2, 0.2), (0, 0, 1.3), mat)
    if bound:
        character_rig.bind(shell, armature)
    build_models.attach(shell, pivot)
    bpy.context.view_layer.update()
    errors = check_models.check_joints({"Shell": shell}, "vest_light")
    assert has(errors, "'Shell' pivot") == fails


def test_unknown_folder(tmp_path):
    assert has(broken(tmp_path, "wall_panel", folder="props"), "unknown model folder 'props'")


def test_model_without_rules(tmp_path):
    path = tmp_path / "kit" / "new_piece.glb"
    build_models.reset_scene()
    build_models.build_wall_panel()
    build_models.export(str(path))
    assert has(check_models.check_model(str(path)), "no rules for 'new_piece'")


def test_main_fails_on_a_bad_model(tmp_path):
    broken(tmp_path, "wall_panel", lambda o: o["Seam"].data.materials.clear())
    assert check_models.main(["--dir", str(tmp_path)]) == 1
    assert check_models.main(["--dir", str(tmp_path / "empty")]) == 1
