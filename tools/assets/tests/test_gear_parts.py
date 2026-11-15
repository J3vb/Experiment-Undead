"""Curved shoulder shells and rear identification bands remain solid and readable."""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import bpy

# isort: split
import bmesh
import build_models
import check_models
import gear_paint
import gear_parts
import pytest
from mathutils import Vector

PROFILES = (
    [(0.165, 1.551, 0.72), (0.19, 1.568, 0.96), (0.24, 1.565, 1), (0.29, 1.53, 0.9), (0.32, 1.49, 0.7)],
    [(0.15, 1.575, 0.75), (0.20, 1.595, 0.96), (0.28, 1.58, 1), (0.35, 1.52, 0.95), (0.39, 1.45, 0.8)],
)


@pytest.fixture
def material():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    return build_models.material("GearWebbing", build_models.srgb("#1C2122"))


def assert_solid(obj):
    mesh = bmesh.new()
    mesh.from_mesh(obj.data)
    assert all(edge.is_manifold for edge in mesh.edges), "every edge joins exactly two faces"
    bmesh.ops.triangulate(mesh, faces=mesh.faces[:])
    assert all(face.calc_area() > 1e-10 for face in mesh.faces)
    assert all(volume > 1e-9 for volume in check_models.shell_volumes(mesh)), "outward-facing closed components"
    mesh.free()


def vertical_hit(obj, x, y, above):
    origin, direction = Vector((x, y, 2 if above else 1)), Vector((0, 0, -1 if above else 1))
    hit, point, _normal, _face = obj.ray_cast(origin, direction)
    assert hit, "the cap must cover the sample with a real solid"
    return point.z


@pytest.mark.parametrize("frame", (0, 1), ids=("medium", "heavy"))
@pytest.mark.parametrize("sign", (-1, 1), ids=("right", "left"))
@pytest.mark.parametrize("thickness", (0.016, 0.045, 0.065))
def test_shoulder_caps_are_closed_crowned_and_thick(material, frame, sign, thickness):
    profile, depth = PROFILES[frame], (0.24, 0.27)[frame]
    cap = gear_parts.shoulder_cap("Cap", profile, depth, material, sign, thickness)
    assert_solid(cap)
    points = [vertex.co for vertex in cap.data.vertices]
    assert min(point.x * sign for point in points) == pytest.approx(profile[0][0])
    assert max(point.x * sign for point in points) == pytest.approx(profile[-1][0])
    x = sign * profile[2][0]
    crown = vertical_hit(cap, x, 0, True)
    edge = vertical_hit(cap, x, depth * 0.42, True)
    assert crown > edge + 0.01, "the broad face must arch over the shoulder rather than form a flat box"
    for y in (0, depth * 0.42, -depth * 0.42):
        actual = vertical_hit(cap, x, y, True) - vertical_hit(cap, x, y, False)
        assert actual == pytest.approx(thickness, abs=1e-6)
    shares = gear_paint.zone_shares(cap)
    assert shares[gear_paint.ZONE_MAIN] > 0.5
    assert 0.1 < shares[gear_paint.ZONE_TRIM] < 0.5
    assert shares[gear_paint.ZONE_GLOW] == 0
    color = cap.data.color_attributes["Color"]
    for face in cap.data.polygons:
        if gear_paint._face_zone(cap.data, color, face) == gear_paint.ZONE_TRIM:
            assert all(abs(cap.data.vertices[index].co.y) > depth * 0.25 for index in face.vertices)


@pytest.mark.parametrize("frame,width", (("light", 0.273), ("medium", 0.3042), ("heavy", 0.3276)))
def test_rear_bands_keep_the_rarity_face_visible_and_a_separate_sewn_edge(material, frame, width):
    band = gear_parts.rear_band(width, {"webbing": material}, light=frame == "light")
    assert_solid(band)
    bpy.context.view_layer.update()
    low, high = check_models.bounds([band])
    color = band.data.color_attributes["Color"]
    trim = {
        index
        for face in band.data.polygons
        if gear_paint._face_zone(band.data, color, face) == gear_paint.ZONE_TRIM
        for index in face.vertices
    }
    trim_x = [(band.matrix_world @ band.data.vertices[index].co).x for index in trim]
    assert max(trim_x) - min(trim_x) == pytest.approx(width, abs=1e-5)
    assert width <= high.x - low.x <= width + 0.002, "sewn border stays within a millimetre of each end"
    assert high.y - low.y >= 0.0039, "the band is a solid, not a coplanar decal"
    inverse = band.matrix_world.inverted()
    direction = inverse.to_3x3() @ Vector((0, -1, 0))
    z = 1.22 if frame == "light" else 1.36
    for x in (-width * 0.4, 0, width * 0.4):
        hit, _point, normal, index = band.ray_cast(inverse @ Vector((x, 1, z)), direction)
        assert hit and (band.matrix_world.to_3x3() @ normal).y > 0.99
        face = band.data.polygons[index]
        assert gear_paint._face_zone(band.data, band.data.color_attributes["Color"], face) == gear_paint.ZONE_TRIM
    shares = gear_paint.zone_shares(band)
    assert shares[gear_paint.ZONE_TRIM] > 0.80
    assert shares[gear_paint.ZONE_ACCENT] > 0
    assert shares[gear_paint.ZONE_GLOW] == 0
