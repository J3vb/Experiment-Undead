"""Mechanical openings stay recessed while the three guns retain their animation pivots."""

import sys
from pathlib import Path

import bpy
import pytest
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import build_models as models


def build(name):
    models.reset_scene()
    models.MODELS[name][1]()
    bpy.context.view_layer.update()


def cast(part, origin, direction):
    obj = bpy.data.objects[part]
    inverse = obj.matrix_world.inverted()
    hit, point, _normal, _face = obj.ray_cast(inverse @ Vector(origin), inverse.to_3x3() @ Vector(direction))
    return hit, obj.matrix_world @ point


@pytest.mark.parametrize(
    ("name", "at", "depth"),
    [
        ("shotgun_brenner", (0.08, 0.04, 0.02), 0.021),
        ("kestrel_smg", (0.08, 0.02, 0.013), 0.017),
        ("atlas_auto", (0.08, -0.005, 0.03), 0.021),
    ],
)
def test_ejection_port_is_below_the_receiver_face(name, at, depth):
    build(name)
    hit, point = cast("Receiver", at, (-1, 0, 0))
    assert hit
    assert 0.014 < point.x < depth


@pytest.mark.parametrize(
    ("name", "part", "at", "floor"),
    [
        ("shotgun_brenner", "Receiver", (0, 0.65, 0.03), 0.60),
        ("kestrel_smg", "Barrel", (0, 0.38, 0.008), 0.325),
        ("atlas_auto", "Barrel", (0, 0.68, 0.025), 0.60),
    ],
)
def test_muzzle_has_depth_instead_of_a_front_disc(name, part, at, floor):
    build(name)
    hit, point = cast(part, at, (0, -1, 0))
    assert hit
    assert point.y < floor


@pytest.mark.parametrize(
    ("name", "pivot"),
    [
        ("shotgun_brenner", (0, 0.26, -0.005)),
        ("kestrel_smg", (0.0275, 0.022, 0.013)),
        ("atlas_auto", (0.0305, -0.005, 0.03)),
    ],
)
def test_recessed_actions_keep_the_original_bolt_pivot(name, pivot):
    build(name)
    bolt = bpy.data.objects["Bolt"]
    assert (bolt.matrix_world.translation - Vector(pivot)).length < 1e-6
    assert bolt.parent.name == "Receiver"


def test_shield_vents_reveal_the_inner_barrel():
    build("shotgun_brenner")
    hit, point = cast("Receiver", (0.06, 0.178, 0.036), (-1, 0, 0))
    assert hit and 0 < point.x < 0.012
    build("kestrel_smg")
    assert not cast("Receiver", (0.06, 0.155, 0.008), (-1, 0, 0))[0]
    build("atlas_auto")
    assert not cast("Handguard", (0.06, 0.216, 0.036), (-1, 0, 0))[0]
