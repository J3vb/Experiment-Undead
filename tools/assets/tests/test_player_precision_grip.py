"""The higher precision-stock grasp keeps normal reach and distinct digits."""

import math
import os
import sys
from itertools import pairwise

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import bpy

# isort: split
import player_grip_model as grip
from mathutils import Vector


def _paths():
    across, _along, _inward = grip._frame(-1)
    root = Vector((-0.675, -0.017, 0.985))
    return [
        grip._finger_path(root + across * (index - 1.5) * 0.016, -1, 0.032, index, "corvid_338") for index in range(4)
    ]


def test_corvid_index_reaches_forward_without_dorsal_hyperextension():
    across, along, inward = grip._frame(-1)
    index = _paths()[0]
    for station in (1, 2, 3):
        direction = (index[station] - index[0]).normalized()
        extension = math.degrees(math.atan2(-direction.dot(inward), direction.dot(along)))
        abduction = math.degrees(math.atan2(direction.dot(across), direction.dot(along)))
        assert -75 < extension < 30
        assert abs(abduction) < 30


def test_corvid_lower_digits_remain_separate_beyond_the_mcp_web():
    paths = _paths()
    for index in (1, 2):
        first, second = paths[index : index + 2]
        first_radii = grip._finger_radii(0.032, index, "corvid_338")
        second_radii = grip._finger_radii(0.032, index + 1, "corvid_338")
        for first_row in range(5, 14):
            for second_row in range(5, 14):
                distance = (first[first_row] - second[second_row]).length
                assert distance > first_radii[first_row] + second_radii[second_row] + 0.0005
    assert all(sum((p - q).length for p, q in pairwise(path)) < 0.110 for path in paths)


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
