"""Authored grip frames preserve chirality and scale when placed around a weapon."""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import bpy

# isort: split
import player_grip_frames as frames
import pytest
from mathutils import Quaternion, Vector


@pytest.mark.parametrize("sign", (-1, 1))
@pytest.mark.parametrize("offset", ((0.03, -0.02, 0.01), (-0.01, 0.04, -0.02), (0, 0, 0.05)))
def test_frame_conversion_rotates_both_hands_without_reflecting_or_scaling(sign, offset):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    origin = Vector((sign * 0.675, -0.057, 0.985))
    target = Vector((0.012, 0.210, -0.028))
    axes = frames.rest_frame(sign)
    rotation = Quaternion((0, 0, 1), math.pi / 2)
    target_axes = tuple(rotation @ axis for axis in axes)
    point = origin + Vector(offset)
    placed = frames.transform(point, origin, target, axes, target_axes)
    reference = bpy.data.objects.new("ExpectedRotation", None)
    bpy.context.collection.objects.link(reference)
    reference.location = target
    reference.rotation_euler.z = math.pi / 2
    bpy.context.view_layer.update()
    expected = reference.matrix_world @ Vector(offset)
    assert (placed - expected).length < 1e-7
    restored = frames.transform(placed, target, origin, target_axes, axes)
    assert (restored - point).length < 1e-7
