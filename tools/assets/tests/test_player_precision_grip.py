"""The higher precision-stock grasp keeps normal reach and distinct digits."""

import os
import sys
from itertools import pairwise

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import bpy

# isort: split
import grip_checks
import player_grip_model as grip
from mathutils import Vector


def _paths():
    return grip_checks.finger_paths("corvid_338")


def test_corvid_index_reaches_forward_without_dorsal_hyperextension():
    grip_checks.assert_index_reach(_paths()[0])


def test_corvid_lower_digits_remain_separate_beyond_the_mcp_web():
    grip_checks.assert_lower_digits_apart("corvid_338", 0.110)


def test_corvid_index_and_thumb_do_not_stretch_to_bridge_a_low_palm():
    index = _paths()[0]
    thumb = grip._thumb_path(index[-1], Vector((-0.675, -0.054, 0.985)), -1, 0.032, "corvid_338")
    assert sum((p - q).length for p, q in pairwise(index)) < 0.105
    assert sum((p - q).length for p, q in pairwise(thumb)) < 0.110


def test_corvid_each_lower_finger_ring_stays_seated_against_the_actual_stock(
    monkeypatch,
):
    import build_models
    import corvid_model
    import player_arms_model as arms
    import player_precision_grip as precision
    from mathutils.bvhtree import BVHTree

    bpy.ops.wm.read_factory_settings(use_empty=True)
    stock = []
    original = build_models.join_into

    def capture(target, pieces):
        if target.name == "Stock":
            stock.append(
                BVHTree.FromPolygons(
                    [target.matrix_world @ vertex.co for vertex in target.data.vertices],
                    [list(face.vertices) for face in target.data.polygons],
                )
            )
        return original(target, pieces)

    monkeypatch.setattr(build_models, "join_into", capture)
    corvid_model.build(build_models)
    assert len(stock) == 1
    mat = arms._materials()["rubber"]
    for index, points in enumerate(_paths()[1:], 1):
        radii = grip._finger_radii(0.032, index, "corvid_338")
        finger = grip._grip_tube("ContactProbe", points, radii, mat, -1)
        for station in range(14):
            ring = list(finger.data.vertices)[station * 12 : (station + 1) * 12]
            distance = min(stock[0].find_nearest(precision._gun(finger.matrix_world @ vertex.co))[3] for vertex in ring)
            assert 0.0005 < distance < 0.004, (
                "a curled finger must contact the shaft along its arc, not hang clear of it"
            )
