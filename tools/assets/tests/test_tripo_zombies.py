"""Tripo zombies (tools/assets/tripo/zombies.json, F-28 step 1, F-86): intake `--kind zombie` output passes the rules.

Run from the repo root: python -m pytest tools/assets/tests/test_tripo_zombies.py
"""

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import bpy

# isort: split
import check_models
import pytest
import tripo_intake
import zombie_checks

MANIFEST = os.path.join(check_models.REPO, "tools", "assets", "tripo", "zombies.json")
with open(MANIFEST, encoding="utf-8") as text:
    ROWS = json.load(text)


def _model(row):
    return os.path.join(check_models.REPO, "assets", "models", row["folder"], row["name"] + ".glb")


def test_zombie_kind_matches_the_zombie_folder_budget():
    budget, _size, height = tripo_intake.KINDS["zombie"]
    assert budget == check_models.BUDGETS["zombies"][0]
    assert height == 1.7


def test_manifest_rows_are_zombies_with_rules():
    assert [row["name"] for row in ROWS] == ["glower", "shambler", "shambler_guard", "bloater", "crawler"]
    for row in ROWS:
        assert row["kind"] == "zombie" and row["folder"] == "zombies"
        assert row["name"] in zombie_checks.JOINTS and row["name"] in zombie_checks.TRIANGLES


@pytest.mark.parametrize("row", ROWS, ids=[row["name"] for row in ROWS])
def test_committed_zombie_passes_every_model_rule(row):
    assert check_models.check_model(_model(row)) == []


@pytest.mark.parametrize("row", ROWS, ids=[row["name"] for row in ROWS])
def test_committed_zombie_is_placed_with_head_center_behind_the_eyes(row):
    objects = check_models.load_glb(_model(row))
    nodes = {obj.name: obj for obj in objects}
    arm = next(obj for obj in objects if obj.type == "ARMATURE")
    assert len(arm.data.bones) == 22
    assert [obj.name for obj in objects if obj.type == "MESH"] == ["Body"]
    assert nodes["Body"].data.materials[0].name.startswith(zombie_checks.BAKED)
    low, high = check_models.bounds([nodes["Body"]])
    assert low.z == pytest.approx(0.0, abs=0.01)
    if row.get("crawler"):
        assert high.z - low.z < 0.8, "the Crawler lies prone"
        assert nodes["Crawler"].parent_bone == "pelvis", "ZombieRig finds the crawl rest by this marker"
        body = nodes["Body"]
        groups = {g.index: g.name for g in body.vertex_groups}
        weighted = {groups[e.group] for v in body.data.vertices for e in v.groups if e.weight > 0.0}
        assert not any(name.startswith(("thigh_", "shin_", "foot_")) for name in weighted), "no legs left"
    else:
        assert high.z - low.z == pytest.approx(row["height"], abs=0.01)
    center = nodes["HeadCenter"]
    assert center.parent == arm and center.parent_type == "BONE" and center.parent_bone == "head"
    eyes = nodes["Eyes"].matrix_world.translation
    assert center.matrix_world.translation.y > eyes.y, "HeadCenter sits behind the eyes (Godot -Z)"
    assert center.matrix_world.translation.z == pytest.approx(eyes.z, abs=0.02)


def test_baked_zombie_rules_want_one_body_mesh_and_only_the_baked_material():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.mesh.primitive_cube_add()
    cube = bpy.context.active_object
    cube.name = "Torso"
    cube.data.materials.append(bpy.data.materials.new(zombie_checks.BAKED))
    cube.data.materials.append(bpy.data.materials.new("ZombieSkin"))
    errors = zombie_checks._check_baked([cube], [cube])
    assert any("one mesh named 'Body'" in error for error in errors)
    assert any("only the ZombieBaked material" in error for error in errors)
    assert any("HeadCenter" in error for error in errors)
