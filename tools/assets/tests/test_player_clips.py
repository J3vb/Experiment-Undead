"""Third-person clips: every clip exists by name in the source and the committed glTF, and loops close."""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import bpy

# isort: split
import check_models
import player_clips
import pytest
from player_body_model import build_player


@pytest.fixture(scope="module")
def source():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    build_player()
    return next(obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE")


def _curves(action):
    return action.layers[0].strips[0].channelbag(action.slots[0]).fcurves


def _value(action, path, index, frame):
    for curve in _curves(action):
        if curve.data_path == path and curve.array_index == index:
            return curve.evaluate(frame)
    raise KeyError(path)


def test_source_has_one_nla_track_per_clip(source):
    assert sorted(track.name for track in source.animation_data.nla_tracks) == sorted(player_clips.CLIPS)
    assert not source.animation_data.use_nla, "the source scene stays in rest pose"


@pytest.mark.parametrize("name", player_clips.LOOPS)
def test_loops_end_where_they_start(source, name):
    action = bpy.data.actions[name]
    first, last = action.frame_range
    for curve in _curves(action):
        assert curve.evaluate(first) == pytest.approx(curve.evaluate(last), abs=1e-4), (
            f"{name}: {curve.data_path}[{curve.array_index}] jumps at the loop"
        )


def test_downed_clips_put_the_hips_near_the_floor(source):
    path = 'pose.bones["pelvis"].location'
    rest_height = source.pose.bones["pelvis"].bone.head_local.z
    for name in ("downed_idle", "downed_crawl"):
        # Pelvis location is in bone space, where the bone's Y axis points up.
        assert rest_height + _value(bpy.data.actions[name], path, 1, 0) < 0.35, name
    assert abs(_value(bpy.data.actions["idle"], path, 1, 0)) < 0.05


def test_committed_model_carries_every_clip_and_loads_in_rest_pose():
    objects = check_models.load_glb(os.path.join(check_models.REPO, "assets/models/characters/player.glb"))
    assert sorted(action.name for action in bpy.data.actions) == sorted(player_clips.CLIPS)
    armature = next(obj for obj in objects if obj.type == "ARMATURE")
    assert armature.animation_data.action is None
    assert armature.pose.bones["pelvis"].matrix.translation.z == pytest.approx(0.94, abs=0.01)
