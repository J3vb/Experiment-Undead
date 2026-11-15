"""Cloth folds preserve fitted sleeve envelopes, mesh topology and painted finishes."""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import bpy

# isort: split
# bpy must load before bmesh.
import bmesh
import body_parts as soft
import gear_paint as paint
import pytest
from mathutils import Vector
from mathutils.bvhtree import BVHTree


@pytest.fixture(autouse=True)
def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def sleeve(axis=(0, 0, 1), centre=(0, 0, 0)):
    rotation = Vector((0, 0, 1)).rotation_difference(Vector(axis).normalized())
    centre = Vector(centre)
    rings = [
        [
            centre + rotation @ Vector((0.06 * math.cos(angle), 0.06 * math.sin(angle), z))
            for angle in (2 * math.pi * index / 16 for index in range(16))
        ]
        for z in (-0.10, -0.04, -0.015, 0, 0.015, 0.04, 0.10)
    ]
    return soft.loft("Sleeve", rings, bpy.data.materials.new("BodySuit"))


def assert_closed_outward(obj):
    surface = bmesh.new()
    try:
        surface.from_mesh(obj.data)
        bmesh.ops.triangulate(surface, faces=surface.faces[:])
        surface.normal_update()
        assert all(edge.is_manifold and edge.is_contiguous for edge in surface.edges)
        assert all(face.calc_area() > 1e-10 for face in surface.faces)
        assert surface.calc_volume(signed=True) > 0, "the closed shell must retain outward winding"
        return surface.calc_volume(signed=True)
    finally:
        surface.free()


@pytest.mark.parametrize("axis", [(0, 0, 3), (2, -1, 2)])
def test_fold_compresses_only_radially_and_keeps_the_outer_fit(axis):
    obj = sleeve(axis)
    before = [vertex.co.copy() for vertex in obj.data.vertices]
    direction = Vector(axis).normalized()
    soft.fabric_fold(obj, (0, 0, 0), axis, 0.03, 0.005, 0.07)
    moved = []
    for original, vertex in zip(before, obj.data.vertices, strict=True):
        along = original.dot(direction)
        radial = original - direction * along
        displacement = vertex.co - original
        assert displacement.dot(direction) == pytest.approx(0, abs=1e-7)
        assert displacement.dot(radial) <= 1e-8, "a fold must never expand through fitted gear"
        assert displacement.length <= 0.005 + 1e-7
        if abs(along) > 0.03:
            assert tuple(vertex.co) == tuple(original), "fabric beyond the fold band stays untouched"
        elif abs(along) < 1e-6:
            assert vertex.co.length == pytest.approx(0.055, abs=1e-7)
        moved.append(displacement.length)
    assert max(moved) > 0.0049, "the fold visibly compresses the centre of the sleeve"


@pytest.mark.parametrize("centre", [(0.3, 0, 0), (0, 0, 0.3)])
def test_fold_does_not_move_other_limbs_or_distant_bands(centre):
    obj = sleeve(centre=centre)
    before = [tuple(vertex.co) for vertex in obj.data.vertices]
    soft.fabric_fold(obj, (0, 0, 0), (0, 0, 1), 0.03, 0.005, 0.07)
    assert [tuple(vertex.co) for vertex in obj.data.vertices] == before


def test_fold_keeps_closed_outward_nondegenerate_topology():
    obj = sleeve()
    vertices = len(obj.data.vertices)
    edges = [tuple(edge.vertices) for edge in obj.data.edges]
    faces = [tuple(face.vertices) for face in obj.data.polygons]
    soft.fabric_fold(obj, (0, 0, 0), (0, 0, 1), 0.03, 0.005, 0.07)
    assert len(obj.data.vertices) == vertices
    assert [tuple(edge.vertices) for edge in obj.data.edges] == edges
    assert [tuple(face.vertices) for face in obj.data.polygons] == faces
    assert_closed_outward(obj)


def test_fold_preserves_all_painted_zones_ao_and_material_assignments():
    obj = sleeve()
    obj.data.materials.append(bpy.data.materials.new("BodyKnit"))
    paint.zone(obj, paint.ZONE_MAIN)
    for index, zone in enumerate(paint.ZONES):
        paint.zone(obj, zone, [index])
        obj.data.polygons[index].material_index = index % 2
    attr = obj.data.color_attributes["Color"]
    for index, color in enumerate(attr.data):
        ao = 0.3 + index % 7 * 0.1
        color.color = (ao, ao, ao, color.color[3])
    colors = [tuple(color.color) for color in attr.data]
    materials = [face.material_index for face in obj.data.polygons]
    soft.fabric_fold(obj, (0, 0, 0), (0, 0, 1), 0.03, 0.005, 0.07)
    assert [tuple(color.color) for color in attr.data] == colors
    assert [face.material_index for face in obj.data.polygons] == materials
    assert all(share > 0 for share in paint.zone_shares(obj).values())


@pytest.mark.parametrize(
    "invalid",
    [
        {"axis": (0, 0, 0)},
        {"axis": (0, 0, 1e-8)},
        {"width": 0},
        {"width": -0.03},
        {"depth": -0.005},
        {"reach": 0},
        {"reach": -0.07},
        {"reach": 0.005},
        {"reach": 0.004},
    ],
)
def test_invalid_fold_dimensions_fail_before_touching_the_mesh(invalid):
    obj = sleeve()
    before = [tuple(vertex.co) for vertex in obj.data.vertices]
    dimensions = {"axis": (0, 0, 1), "width": 0.03, "depth": 0.005, "reach": 0.07}
    dimensions.update(invalid)
    with pytest.raises(ValueError, match="fold needs"):
        soft.fabric_fold(obj, (0, 0, 0), **dimensions)
    assert [tuple(vertex.co) for vertex in obj.data.vertices] == before


def test_refining_a_patch_adds_local_support_without_changing_the_fitted_surface():
    obj = sleeve()
    before = {tuple(vertex.co) for vertex in obj.data.vertices}
    original_faces = [tuple(face.vertices) for face in obj.data.polygons]
    original_surface = BVHTree.FromPolygons([vertex.co.copy() for vertex in obj.data.vertices], original_faces)
    centre, radius = Vector((0.06, 0, 0)), 0.04
    untouched_faces = {
        frozenset(tuple(obj.data.vertices[index].co) for index in face.vertices)
        for face in obj.data.polygons
        if all((obj.data.vertices[index].co - centre).length >= radius for index in face.vertices)
    }
    volume = assert_closed_outward(obj)
    soft.refine_patch(obj, centre, radius)
    after = {tuple(vertex.co) for vertex in obj.data.vertices}
    assert before < after, "the existing shape stays put while new support vertices are inserted"
    assert len(obj.data.polygons) > len(original_faces)
    assert all((Vector(point) - centre).length < radius for point in after - before)
    assert untouched_faces <= {
        frozenset(tuple(obj.data.vertices[index].co) for index in face.vertices) for face in obj.data.polygons
    }
    for vertex in obj.data.vertices:
        _point, _normal, _face, distance = original_surface.find_nearest(vertex.co)
        assert distance < 1e-7, "support edges must not smooth or expand the fitted envelope"
    assert assert_closed_outward(obj) == pytest.approx(volume, rel=1e-6)


def test_refinement_carries_face_zones_ao_and_material_boundaries():
    obj = sleeve()
    obj.data.materials.append(bpy.data.materials.new("BodyKnit"))
    paint.zone(obj, paint.ZONE_MAIN)
    for face in obj.data.polygons:
        zone = paint.ZONES[face.index % len(paint.ZONES)]
        paint.zone(obj, zone, [face])
        face.material_index = face.index % 2
        for index in face.loop_indices:
            obj.data.color_attributes["Color"].data[index].color = (0.2 + zone * 0.5,) * 3 + (zone,)
    shares = paint.zone_shares(obj)
    material_areas = [sum(face.area for face in obj.data.polygons if face.material_index == index) for index in (0, 1)]
    soft.refine_patch(obj, (0.06, 0, 0), 0.04)
    assert paint.zone_shares(obj) == pytest.approx(shares, abs=1e-6)
    for color in obj.data.color_attributes["Color"].data:
        assert tuple(color.color[:3]) == pytest.approx((0.2 + color.color[3] * 0.5,) * 3)
    assert [sum(face.area for face in obj.data.polygons if face.material_index == index) for index in (0, 1)] == (
        pytest.approx(material_areas, rel=1e-6)
    )


@pytest.mark.parametrize("radius", [0, -0.04])
def test_refinement_rejects_nonpositive_radius_before_touching_the_mesh(radius):
    obj = sleeve()
    before = [tuple(vertex.co) for vertex in obj.data.vertices]
    faces = [tuple(face.vertices) for face in obj.data.polygons]
    with pytest.raises(ValueError, match="radius must be positive"):
        soft.refine_patch(obj, (0.06, 0, 0), radius)
    assert [tuple(vertex.co) for vertex in obj.data.vertices] == before
    assert [tuple(face.vertices) for face in obj.data.polygons] == faces


def test_ellipsoid_extra_palm_resolution_retains_default_geometry_and_scale():
    mat = bpy.data.materials.new("BodyRubber")
    at, size = (0.649, 0, 1.011), (0.046, 0.027, 0.055)
    default = soft.ellipsoid("DefaultPalm", at, size, mat)
    explicit = soft.ellipsoid("ExplicitPalm", at, size, mat, segments=12, rings=8)
    detailed = soft.ellipsoid("DetailedPalm", at, size, mat, segments=20, rings=12)
    bpy.context.view_layer.update()
    assert [tuple(vertex.co) for vertex in default.data.vertices] == [
        tuple(vertex.co) for vertex in explicit.data.vertices
    ]
    assert [tuple(face.vertices) for face in default.data.polygons] == [
        tuple(face.vertices) for face in explicit.data.polygons
    ]
    assert len(detailed.data.vertices) > len(default.data.vertices)
    for obj in (default, detailed):
        assert tuple(obj.location) == pytest.approx(at)
        assert tuple(obj.scale) == pytest.approx((1, 1, 1))
        assert tuple(obj.dimensions) == pytest.approx(tuple(2 * component for component in size))
        assert list(obj.data.materials) == [mat]
        assert all(face.use_smooth for face in obj.data.polygons)
        assert_closed_outward(obj)
