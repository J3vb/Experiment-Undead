"""Rear harness straps must actually terminate in the cummerbund on every frame."""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import bpy
import pytest
import vest_model
from mathutils import Vector
from mathutils.bvhtree import BVHTree


def surface(obj):
    obj.data.calc_loop_triangles()
    points = [obj.matrix_world @ vertex.co for vertex in obj.data.vertices]
    faces = [tuple(triangle.vertices) for triangle in obj.data.loop_triangles]
    return points, faces, BVHTree.FromPolygons(points, faces, all_triangles=True)


@pytest.mark.parametrize("frame", (0, 1, 2), ids=("light", "medium", "heavy"))
def test_rear_shoulder_straps_overlap_the_cummerbund(monkeypatch, frame):
    parts = []

    def capture(objects, _armature, body):
        for obj in objects:
            vest_model._clearance(obj, body)
        parts.extend(objects)

    bpy.ops.wm.read_factory_settings(use_empty=True)
    monkeypatch.setattr(vest_model, "_finish", capture)
    vest_model._build(frame)
    bpy.context.view_layer.update()
    straps = [obj for obj in parts if obj.name.startswith("ShoulderWebbing")]
    belts = [surface(obj)[2] for obj in parts if obj.name.startswith("Cummerbund")]
    assert len(straps) == 2 and len(belts) == 2
    for strap in straps:
        points, faces, tree = surface(strap)
        contacts = [
            sum((points[index] for index in faces[triangle]), Vector()) / 3
            for belt in belts
            for triangle, _other in tree.overlap(belt)
        ]
        assert any(point.y > 0.10 and 1.15 < point.z < 1.23 for point in contacts), (
            strap.name,
            "rear webbing must join the waist harness, not hang above it",
        )
