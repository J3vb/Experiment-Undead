"""The lever-action grasp keeps natural proximal directions and distinct digits."""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import bpy

# isort: split
import build_models
import grip_checks
import player_grip_model as grip
import player_lever_grip as lever


def test_fieldhand_index_reaches_forward_without_dorsal_hyperextension():
    grip_checks.assert_index_reach(grip_checks.finger_paths("fieldhand_lever")[0])


def test_fieldhand_lower_digits_remain_separate_beyond_the_mcp_web():
    grip_checks.assert_lower_digits_apart("fieldhand_lever", 0.103)


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
