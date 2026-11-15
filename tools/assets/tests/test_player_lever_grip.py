"""The lever-action grasp keeps natural proximal directions and distinct digits."""

import math
import os
import sys
from itertools import pairwise

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import bpy

# isort: split
import build_models
import player_grip_model as grip
import player_lever_grip as lever
from mathutils import Vector


def _paths():
    across, _along, _inward = grip._frame(-1)
    root = Vector((-0.675, -0.017, 0.985))
    return [
        grip._finger_path(root + across * (index - 1.5) * 0.016, -1, 0.032, index, "fieldhand_lever")
        for index in range(4)
    ]


def test_fieldhand_index_reaches_forward_without_dorsal_hyperextension():
    across, along, inward = grip._frame(-1)
    index = _paths()[0]
    for station in (1, 2, 3):
        direction = (index[station] - index[0]).normalized()
        extension = math.degrees(math.atan2(-direction.dot(inward), direction.dot(along)))
        abduction = math.degrees(math.atan2(direction.dot(across), direction.dot(along)))
        assert -75 < extension < 30
        assert abs(abduction) < 30


def test_fieldhand_lower_digits_remain_separate_beyond_the_mcp_web():
    paths = _paths()
    for index in (1, 2):
        first, second = paths[index : index + 2]
        first_radii = grip._finger_radii(0.032, index, "fieldhand_lever")
        second_radii = grip._finger_radii(0.032, index + 1, "fieldhand_lever")
        for first_row in range(5, 14):
            for second_row in range(5, 14):
                distance = (first[first_row] - second[second_row]).length
                assert distance > first_radii[first_row] + second_radii[second_row] + 0.0005
    assert all(sum((p - q).length for p, q in pairwise(path)) < 0.103 for path in paths)


def test_thumb_finishes_on_the_actual_stock_comb():
    """A collision-free thumb can still hover; its distal skin must reach the wood."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    build_models.MODELS["fieldhand_lever"][1]()
    bpy.context.view_layer.update()
    stock = bpy.data.objects["Stock"]
    points = lever.thumb_path()
    radii = (0.014, 0.014, 0.013, 0.012, 0.011, 0.010, 0.008, 0.006, 0.004, 0.002)
    thumb = grip._grip_tube("ProbeThumb", points, radii, stock.data.materials[0], -1)
    distances = []
    for vertex in list(thumb.data.vertices)[-12:]:
        point = stock.matrix_world.inverted() @ lever._gun(thumb.matrix_world @ vertex.co)
        hit, nearest, normal, _face = stock.closest_point_on_mesh(point)
        assert hit and (point - nearest).dot(normal) >= -1e-6
        distances.append((point - nearest).length)
    assert min(distances) < 0.004, "the downward thumb hook must touch the stock instead of hovering above it"
