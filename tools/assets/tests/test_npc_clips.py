"""Stall keeper clips (F-76 step 3): five tracks, closed loops, a blend-safe greet, hands where the clip says.

Run from the repo root: python -m pytest tools/assets/tests/test_npc_clips.py
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import bpy

# isort: split
import character_rig
import npc_clips
import pytest
from mathutils import Vector


def _curves(action):
    return action.layers[0].strips[0].channelbag(action.slots[0]).fcurves


def _rest_rig(scale: float = 1.0):
    """Our rest armature, scaled about the floor like a shorter or taller keeper."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    arm = character_rig.build_armature()
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    for bone in arm.data.edit_bones:
        bone.head *= scale
        bone.tail *= scale
    bpy.ops.object.mode_set(mode="OBJECT")
    return arm


@pytest.fixture(scope="module")
def source():
    arm = _rest_rig()
    npc_clips.build_clips(arm)
    return arm


def _pose_at(arm, clip: str, frame: int) -> None:
    arm.animation_data.action = bpy.data.actions[clip]
    arm.animation_data.action_slot = bpy.data.actions[clip].slots[0]
    bpy.context.scene.frame_set(frame)
    bpy.context.view_layer.update()


def test_source_has_one_nla_track_per_clip(source):
    assert sorted(track.name for track in source.animation_data.nla_tracks) == sorted(npc_clips.CLIPS)
    assert not source.animation_data.use_nla, "the source scene stays in rest pose"
    assert sorted(npc_clips.CLIPS) == ["bench_work", "board_idle", "counter_idle", "desk_work", "greet"]


@pytest.mark.parametrize("name", npc_clips.LOOPS)
def test_loops_end_where_they_start(source, name):
    action = bpy.data.actions[name]
    first, last = action.frame_range
    for curve in _curves(action):
        assert curve.evaluate(first) == pytest.approx(curve.evaluate(last), abs=1e-4), (
            f"{name}: {curve.data_path}[{curve.array_index}] jumps at the loop"
        )


def test_greet_starts_and_ends_in_the_counter_pose(source):
    greet = {(c.data_path, c.array_index): c for c in _curves(bpy.data.actions["greet"])}
    first, last = bpy.data.actions["greet"].frame_range
    for curve in _curves(bpy.data.actions["counter_idle"]):
        start = curve.evaluate(0)
        other = greet[(curve.data_path, curve.array_index)]
        assert other.evaluate(first) == pytest.approx(start, abs=1e-4), f"greet start: {curve.data_path}"
        assert other.evaluate(last) == pytest.approx(start, abs=1e-4), f"greet end: {curve.data_path}"


def test_greet_lifts_the_right_hand(source):
    _pose_at(source, "greet", 0)
    low = source.pose.bones["hand_R"].head.z
    _pose_at(source, "greet", 18)
    assert source.pose.bones["hand_R"].head.z > low + 0.15


def test_board_idle_crosses_the_arms(source):
    _pose_at(source, "board_idle", 0)
    assert source.pose.bones["hand_L"].head.x < 0.0 < source.pose.bones["hand_R"].head.x


def _palm(arm, side: str) -> Vector:
    pbone = arm.pose.bones[f"hand_{side}"]
    local = pbone.bone.matrix_local.to_3x3().inverted() @ npc_clips.rest_palm(pbone.bone)
    return pbone.matrix.to_3x3() @ local


@pytest.mark.parametrize("scale", [1.0, 0.9])
def test_counter_hands_rest_in_front_palms_down_on_any_height(scale):
    arm = _rest_rig(scale)
    arm.animation_data_create()
    npc_clips.build_clip(arm, "counter_idle")
    _pose_at(arm, "counter_idle", 0)
    for side in ("L", "R"):
        hand = arm.pose.bones[f"hand_{side}"].head
        shoulder = arm.pose.bones[f"upperarm_{side}"].head
        assert hand.y < shoulder.y - 0.15 * scale, f"{side} hand reaches forward over the counter"
        assert 0.25 * scale < shoulder.z - hand.z < 0.45 * scale, f"{side} hand is at counter height"
        assert _palm(arm, side).z < -0.6, f"{side} palm faces down"
