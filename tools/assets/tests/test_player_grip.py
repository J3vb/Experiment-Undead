"""Grip sweeps remain untwisted, closed and seated through the finger bends."""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import bpy

# isort: split
import bmesh
import pytest
from mathutils import Vector
from player_arms_model import (
    GRIP_HALVES,
    _finger_pad,
    _finger_path,
    _finger_radii,
    _frame,
    _grip_centre,
    _grip_tube,
    _thumb_path,
)


def test_mako_ring_finger_triangles_clear_the_actual_beveled_stop():
    import build_models
    import mako_model
    import player_support_grips as support
    from mathutils.bvhtree import BVHTree

    bpy.ops.wm.read_factory_settings(use_empty=True)
    mako_model.build(build_models)
    bpy.context.view_layer.update()
    stop = bpy.data.objects["Foregrip"]
    stop.data.calc_loop_triangles()
    obstacle = BVHTree.FromPolygons(
        [stop.matrix_world @ vertex.co for vertex in stop.data.vertices],
        [tuple(face.vertices) for face in stop.data.loop_triangles],
        all_triangles=True,
    )
    across, _along, _inward = _frame(1)
    root = Vector((0.675, -0.012, 0.985)) + across * 0.008
    points = _finger_path(root, 1, 0.045, 2, "mako_pdw")
    finger = _grip_tube("RingContact", points, _finger_radii(0.045, 2), stop.data.materials[0], 1)
    finger.data.calc_loop_triangles()
    surface = BVHTree.FromPolygons(
        [support._mako_gun(finger.matrix_world @ vertex.co) for vertex in finger.data.vertices],
        [tuple(face.vertices) for face in finger.data.loop_triangles],
        all_triangles=True,
    )
    assert not surface.overlap(obstacle), "positive sampled distances must not hide a crossing triangle"


@pytest.fixture
def material():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    return bpy.data.materials.new("BodyRubber")


def assert_closed(obj):
    surface = bmesh.new()
    try:
        surface.from_mesh(obj.data)
        assert all(edge.is_manifold for edge in surface.edges)
        assert all(face.calc_area() > 1e-10 for face in surface.faces)
        assert surface.calc_volume(signed=True) > 0
    finally:
        surface.free()


@pytest.mark.parametrize("sign", (-1, 1))
def test_grip_sweep_keeps_ring_correspondence_through_the_turn(material, sign):
    points = _finger_path(Vector((sign * 0.675, -0.017, 0.985)), sign, 0.032, 0)
    obj = _grip_tube("Finger", points, [0.009] * len(points), material, sign)
    across, _along, _inward = _frame(sign)
    for index, point in enumerate(points):
        tangent = (points[min(index + 1, len(points) - 1)] - points[max(0, index - 1)]).normalized()
        width = (across - tangent * across.dot(tangent)).normalized()
        outer = obj.data.vertices[index * 12].co - point
        opposite = obj.data.vertices[index * 12 + 6].co - point
        assert outer.length == pytest.approx(0.009, abs=1e-6)
        assert outer.dot(tangent) == pytest.approx(0, abs=1e-6)
        assert outer.dot(width) == pytest.approx(0.009, abs=1e-6), "ring correspondence must not flip through a bend"
        assert (outer + opposite).length < 1e-6
    assert_closed(obj)


@pytest.mark.parametrize(("gap", "joint"), [(0.045, 3), (0.045, 6), (0.032, 4), (0.032, 10)])
@pytest.mark.parametrize("sign", (-1, 1))
def test_finger_reinforcement_intersects_the_rubber_instead_of_floating(material, sign, gap, joint):
    points = _finger_path(Vector((sign * 0.675, -0.014, 0.985)), sign, gap, 1)
    radii = _finger_radii(gap, 1)
    finger = _grip_tube("Finger", points, radii, material, sign)
    pad = _finger_pad(points, radii, joint, sign, material)
    bpy.context.view_layer.update()
    distances = []
    for vertex in pad.data.vertices:
        hit, nearest, normal, _face = finger.closest_point_on_mesh(vertex.co)
        assert hit
        distances.append((vertex.co - nearest).dot(normal))
    assert min(distances) < -0.0003
    assert max(distances) > 0.0003
    assert max(abs(distance) for distance in distances) < 0.003
    assert_closed(pad)


@pytest.mark.parametrize(("gap", "joint"), [(0.045, 3), (0.045, 6), (0.032, 4), (0.032, 10)])
@pytest.mark.parametrize("sign", (-1, 1))
def test_finger_pad_centre_roof_remains_visible_above_the_rubber(material, sign, gap, joint):
    points = _finger_path(Vector((sign * 0.675, -0.014, 0.985)), sign, gap, 1)
    radii = _finger_radii(gap, 1)
    finger = _grip_tube("Finger", points, radii, material, sign)
    pad = _finger_pad(points, radii, joint, sign, material)
    bpy.context.view_layer.update()
    across, _along, _inward = _frame(sign)
    tangent = (points[joint + 1] - points[joint - 1]).normalized()
    outward = tangent.cross(across) * sign
    ray = points[joint] + outward * 0.03
    hit_pad, pad_top, _normal, _face = pad.ray_cast(ray, -outward)
    hit_rubber, rubber_top, _normal, _face = finger.ray_cast(ray, -outward)
    assert hit_pad and hit_rubber
    assert (pad_top - rubber_top).dot(outward) > 0.0005, "a buried centre roof exposes a hole in the reinforcement"


@pytest.mark.parametrize("diameter", (0.032, 0.045))
def test_opposed_thumb_keeps_tip_gap_while_the_clear_bore_fits_the_weapon(diameter):
    root = Vector((0.675, -0.014, 0.985))
    across, along, _inward = _frame(1)
    points = _finger_path(root, 1, diameter, 0)
    centre = _grip_centre(root, 1, diameter)
    thumb = _thumb_path(points[-1], centre, 1, diameter)
    assert (points[-1] - thumb[-1]).length == pytest.approx(diameter, abs=1e-6)
    assert (points[-1] - thumb[-1]).dot(across) == pytest.approx(0, abs=1e-6)
    # The handguard is 66 mm wide; a 45 mm marker gap cannot be its bore diameter.
    assert GRIP_HALVES[diameter][0] * 2 > diameter
    assert (points[-1] - centre).dot(along) > 0, "fingers curl around the front of the grip"
