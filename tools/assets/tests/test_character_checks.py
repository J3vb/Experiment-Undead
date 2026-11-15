"""Tiny in-memory character and gear meshes exercise the shared model checks."""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import bpy

# isort: split
# bpy must load before bmesh.
import bmesh
import character_checks
import character_rig
import check_models
import gear_paint
import pytest
from mathutils import Vector


@pytest.fixture(autouse=True)
def scene(monkeypatch):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for stem in ("test_gear", "test_character", "charm_test", "implant_test", "player_arms"):
        monkeypatch.setitem(character_checks.JOINTS, stem, {})
        monkeypatch.setitem(check_models.JOINTS, stem, {})


def cube(name="Gear", at=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=0.2, location=at)
    obj = bpy.context.object
    obj.data.materials.append(bpy.data.materials.new(name))
    gear_paint.zone(obj, gear_paint.ZONE_MAIN)
    bpy.context.view_layer.update()
    return obj


def check(monkeypatch, folder="gear", stem="test_gear"):
    objects = list(bpy.context.scene.objects)
    monkeypatch.setattr(check_models, "load_glb", lambda _path: objects)
    return check_models.check_model(f"{folder}/{stem}.glb")


def character():
    obj = cube("Body", at=(0, 0, 0.1))
    armature = character_rig.build_armature()
    character_rig.bind_rigid(obj, armature, "pelvis")
    eyes = bpy.data.objects.new("Eyes", None)
    bpy.context.collection.objects.link(eyes)
    eyes.parent = armature
    eyes.parent_type = "BONE"
    eyes.parent_bone = "head"
    bpy.context.view_layer.update()
    head = armature.matrix_world @ armature.data.bones["head"].head_local
    eyes.matrix_world.translation = head + Vector((0, -0.1, 0))
    bpy.context.view_layer.update()
    return obj, armature, eyes


def glow_cube(face_count):
    obj = cube()
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.subdivide_edges(bm, edges=list(bm.edges), cuts=9, use_grid_fill=True)
    bm.to_mesh(obj.data)
    bm.free()
    gear_paint.zone(obj, gear_paint.ZONE_MAIN)
    gear_paint.zone(obj, gear_paint.ZONE_GLOW, faces=list(range(face_count)))
    return obj


@pytest.mark.parametrize(("face_count", "fails"), [(60, True), (24, False)])
def test_glow_limit_uses_surface_area(monkeypatch, face_count, fails):
    obj = glow_cube(face_count)
    assert gear_paint.zone_shares(obj)[gear_paint.ZONE_GLOW] == pytest.approx(face_count / 600)
    errors = check(monkeypatch)
    assert bool(errors) == fails, errors
    if fails:
        assert any("maximum is 5%" in error for error in errors)


def test_gear_origin_can_be_above_floor(monkeypatch):
    cube(at=(0, 0, 0.08))
    assert check(monkeypatch) == []


@pytest.mark.parametrize(("share", "fails"), [(0.04, False), (0.05, False), (0.1, True)])
def test_glow_share_combines_meshes_and_world_scale(monkeypatch, share, fails):
    cube()
    glow = cube()
    glow.scale = (math.sqrt(share / (1 - share)),) * 3
    gear_paint.zone(glow, gear_paint.ZONE_GLOW)
    bpy.context.view_layer.update()
    errors = check(monkeypatch)
    assert any("maximum is 5%" in error for error in errors) == fails


@pytest.mark.parametrize(("at", "fails"), [((0.14, 0, 0), False), ((0.14, 0.14, 0), True)])
def test_gear_origin_uses_distance_to_bounds(monkeypatch, at, fails):
    cube(at=at)
    errors = check(monkeypatch)
    assert any("gear origin" in error for error in errors) == fails


def test_missing_zone_fails(monkeypatch):
    obj = cube()
    obj.data.color_attributes.remove(obj.data.color_attributes["Color"])
    assert any("every face needs a zone" in error for error in check(monkeypatch))


def test_mixed_zone_face_fails(monkeypatch):
    obj = cube()
    obj.data.color_attributes["Color"].data[0].color[3] = gear_paint.ZONE_GLOW
    assert any("every face needs a zone" in error for error in check(monkeypatch))


def test_material_needs_known_finish_prefix(monkeypatch):
    cube("Paint")
    assert any("Body* or Gear* finish" in error for error in check(monkeypatch))


def test_valid_character_passes(monkeypatch):
    character()
    assert check(monkeypatch, "characters", "test_character") == []


def test_exported_character_passes_without_importer_bone_mesh(tmp_path):
    character()
    path = tmp_path / "characters" / "test_character.glb"
    path.parent.mkdir()
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", export_yup=True)
    assert check_models.check_model(str(path)) == []
    assert [obj.name for obj in bpy.context.scene.objects if obj.type == "MESH"] == ["Cube"]


@pytest.mark.parametrize("folder", ["characters", "gear"])
def test_missing_bone_fails(monkeypatch, folder):
    _obj, armature, _eyes = character()
    bpy.context.view_layer.objects.active = armature
    bpy.ops.object.mode_set(mode="EDIT")
    armature.data.edit_bones.remove(armature.data.edit_bones["sock_back"])
    bpy.ops.object.mode_set(mode="OBJECT")
    stem = "test_character" if folder == "characters" else "test_gear"
    assert any("missing bones sock_back" in error for error in check(monkeypatch, folder, stem))


def test_wrong_bone_parent_fails(monkeypatch):
    _obj, armature, _eyes = character()
    bpy.context.view_layer.objects.active = armature
    bpy.ops.object.mode_set(mode="EDIT")
    armature.data.edit_bones["sock_back"].parent = armature.data.edit_bones["neck"]
    bpy.ops.object.mode_set(mode="OBJECT")
    assert any("bone 'sock_back' has the wrong parent" in error for error in check(monkeypatch, "gear", "test_gear"))


def test_weights_summing_to_point_eight_fail(monkeypatch):
    obj, _armature, _eyes = character()
    obj.vertex_groups["pelvis"].add([0], 0.8, "REPLACE")
    assert any("weights sum to 0.800" in error for error in check(monkeypatch, "characters", "test_character"))


def test_more_than_four_weights_fail(monkeypatch):
    obj, _armature, _eyes = character()
    for name in ("pelvis", "spine_01", "spine_02", "spine_03", "neck"):
        group = obj.vertex_groups.get(name) or obj.vertex_groups.new(name=name)
        group.add([0], 0.2, "REPLACE")
    assert any("more than 4 bone weights" in error for error in check(monkeypatch, "characters", "test_character"))


def test_socket_weights_fail(monkeypatch):
    obj, _armature, _eyes = character()
    obj.vertex_groups["pelvis"].remove([0])
    obj.vertex_groups.new(name="sock_back").add([0], 1.0, "REPLACE")
    assert any("socket or unknown bone" in error for error in check(monkeypatch, "characters", "test_character"))


@pytest.mark.parametrize("folder", ["characters", "gear"])
def test_unknown_stem_points_to_character_checks(folder):
    errors = check_models.check_model(f"{folder}/unknown.glb")
    assert errors == ["no rules for 'unknown', add it to character_checks.py"]


def test_facing_backwards_fails(monkeypatch):
    _obj, _armature, eyes = character()
    eyes.matrix_world.translation.y = 0.2
    bpy.context.view_layer.update()
    assert any("in front of the head" in error for error in check(monkeypatch, "characters", "test_character"))


def test_eyes_need_head_bone_parent(monkeypatch):
    _obj, _armature, eyes = character()
    eyes.parent_bone = "neck"
    assert any("child of the head bone" in error for error in check(monkeypatch, "characters", "test_character"))


def test_characters_need_an_armature(monkeypatch):
    cube("Body", at=(0, 0, 0.1))
    assert any("exactly one armature" in error for error in check(monkeypatch, "characters", "test_character"))


def test_character_feet_need_floor(monkeypatch):
    obj, _armature, _eyes = character()
    obj.location.z += 0.1
    bpy.context.view_layer.update()
    assert any("feet must be at z = 0" in error for error in check(monkeypatch, "characters", "test_character"))


@pytest.mark.parametrize(("stem", "cap"), [("charm_test", 800), ("implant_test", 1_500), ("player_arms", 8_000)])
def test_per_stem_triangle_caps(monkeypatch, stem, cap):
    obj = cube()
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.subdivide_edges(bm, edges=list(bm.edges), cuts=30, use_grid_fill=True)
    bm.to_mesh(obj.data)
    bm.free()
    errors = check(monkeypatch, stem=stem)
    assert any(f"budget for '{stem}' is {cap}" in error for error in errors)
