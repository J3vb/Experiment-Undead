"""The trial survivor body keeps the shipped body's contract: bones, scale, budget and materials."""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "body_trial"))

import bpy
import character_checks
import character_rig
import check_models
import numpy as np
import pytest
import surface
from build import build_player_trial


@pytest.fixture(scope="module")
def trial():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    build_player_trial()
    bpy.context.view_layer.update()
    return list(bpy.context.scene.objects)


def test_trial_passes_the_character_rules(trial):
    assert character_checks.check(trial, "characters", "player") == []
    assert check_models.check_geometry(trial, "characters") == []


def test_trial_scale_budget_and_materials(trial):
    meshes = [obj for obj in trial if obj.type == "MESH"]
    low, high = check_models.bounds(meshes)
    assert 1.75 <= high.z - low.z <= 1.85
    triangles = sum(len(face.vertices) - 2 for obj in meshes for face in obj.data.polygons)
    assert 8_000 <= triangles <= 16_000
    assert {mat.name for obj in meshes for mat in obj.data.materials} == {
        "BodySkin",
        "BodyHair",
        "BodyCloth",
        "BodyRubber",
    }


def test_trial_uses_the_shared_bones_and_clips(trial):
    armature = next(obj for obj in trial if obj.type == "ARMATURE")
    assert set(armature.data.bones.keys()) == set(character_rig.BONES)
    assert {"idle", "run", "reload"} <= set(bpy.data.actions.keys())


def test_spline_passes_through_its_keys():
    values = surface.spline([0.0, 1.0, 3.0], [[0.0], [2.0], [1.0]], np.asarray([0.0, 1.0, 3.0]))
    assert values[:, 0] == pytest.approx([0.0, 2.0, 1.0])


def test_tube_front_and_side_follow_the_angle():
    tube = surface.Tube((0, 0, 0), (0, 0, 1), (1, 0, 0), [(0, 0, 0, 0.2, 0.1, 0.3, 2.0), (1, 0, 0, 0.2, 0.1, 0.3, 2.0)])
    front, side, back = tube.surface(np.asarray([0.0, 0.25, 0.5]), np.full(3, 0.5))
    assert front == pytest.approx([0, -0.1, 0.5], abs=1e-6)
    assert side == pytest.approx([0.2, 0, 0.5], abs=1e-6)
    assert back == pytest.approx([0, 0.3, 0.5], abs=1e-6)
