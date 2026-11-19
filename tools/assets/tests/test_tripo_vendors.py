"""The four Lantern Post stall keepers made in Tripo (tools/assets/tripo/vendors.json, F-80 step 3).

Run from the repo root: python -m pytest tools/assets/tests/test_tripo_vendors.py
"""

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import bpy

# isort: split
import character_checks
import character_rig
import check_models
import npc_clips
import pytest
import tripo_rig

MANIFEST = os.path.join(check_models.REPO, "tools", "assets", "tripo", "vendors.json")
with open(MANIFEST, encoding="utf-8") as text:
    ROWS = json.load(text)


def _head_at(height: float):
    """Our armature with the head bone moved to a body `height` tall, and a flat face plate in front."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    arm = character_rig.build_armature()
    drop = character_rig.BONES["head"][2][2] - height
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    for bone in arm.data.edit_bones:
        if bone.name in ("head", "neck"):
            bone.head.z -= drop
            bone.tail.z -= drop
    bpy.ops.object.mode_set(mode="OBJECT")
    bpy.ops.mesh.primitive_grid_add(x_subdivisions=20, y_subdivisions=60, size=1.0)
    face = bpy.context.active_object
    face.rotation_euler = (1.5708, 0.0, 0.0)
    face.location = (0.0, -0.1, height - 0.3)
    bpy.ops.object.transform_apply(location=True, rotation=True)
    return arm, face


@pytest.mark.parametrize("height", [1.80, 1.62])
def test_eyes_follow_the_head_on_shorter_bodies(height):
    arm, face = _head_at(height)
    eyes = tripo_rig.eyes_marker(arm, face)
    assert eyes.matrix_world.translation.z == pytest.approx(tripo_rig.EYE_HEIGHT - (1.80 - height), abs=1e-3)
    assert eyes.matrix_world.translation.y == pytest.approx(-0.1, abs=1e-3)


def test_manifest_lists_the_four_keepers_as_made():
    keepers = ["npc_quartermaster", "npc_gunsmith", "npc_technician", "npc_cordon_liaison"]
    assert [row["name"] for row in ROWS] == keepers
    for row in ROWS:
        assert row["made"] and row["kind"] == "character" and row["folder"] == "characters"
        assert row["name"] in character_checks.JOINTS
        assert row["clips"] == "keeper"


@pytest.mark.parametrize("row", ROWS, ids=[row["name"] for row in ROWS])
def test_committed_keeper_passes_the_character_rules_at_its_height(row):
    path = os.path.join(check_models.REPO, "assets", "models", row["folder"], row["name"] + ".glb")
    objects = check_models.load_glb(path)
    assert character_checks.check(objects, "characters", row["name"]) == []
    assert check_models.check_geometry(objects, "characters") == []
    arm = next(obj for obj in objects if obj.type == "ARMATURE")
    assert len(arm.data.bones) == 22
    arm.data.pose_position = "REST"
    if arm.animation_data:
        arm.animation_data.action = None
    bpy.context.view_layer.update()
    low, high = check_models.bounds([obj for obj in objects if obj.type == "MESH"])
    assert low.z == pytest.approx(0.0, abs=0.01)
    assert high.z - low.z == pytest.approx(row["height"], abs=0.01)
    eyes = next(obj for obj in objects if obj.name == "Eyes").matrix_world.translation.z
    assert 0.06 <= high.z - eyes <= 0.2, "eyes sit just under the top of the head (hair or hat on top)"
    assert sorted(action.name for action in bpy.data.actions) == sorted(npc_clips.CLIPS)
