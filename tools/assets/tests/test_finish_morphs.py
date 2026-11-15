"""Weighted normal finishing keeps authored hand morphs and their geometry intact."""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import bpy
import build_models
import finish
import pytest
from mathutils import Vector


@pytest.fixture
def cylinder():
    build_models.reset_scene()
    material = build_models.material("BodyRubber", (0.1, 0.1, 0.1, 1.0))
    return build_models.cylinder("Palm", 0.05, 0.2, (0, 0, 0), material, axis="z")


def add_morphs(obj):
    basis = obj.shape_key_add(name="Basis")
    curl = obj.shape_key_add(name="Grip")
    for point in curl.data:
        point.co.x += max(0, point.co.z) * 0.4
    curl.value, curl.slider_min, curl.slider_max = 0.35, -0.2, 1.4
    folded = obj.shape_key_add(name="Fold")
    folded.relative_key, folded.mute = curl, True
    for point in folded.data:
        point.co.y += max(0, point.co.z) * 0.2
    return basis, curl, folded


def test_morph_mesh_receives_the_same_weighted_corner_normals_as_its_unkeyed_basis(cylinder):
    reference = cylinder.copy()
    reference.data = cylinder.data.copy()
    bpy.context.collection.objects.link(reference)
    finish.fix_normals(reference)
    expected = [tuple(corner.vector) for corner in reference.data.corner_normals]
    add_morphs(cylinder)
    finish.fix_normals(cylinder)
    assert cylinder.data.has_custom_normals
    assert len(cylinder.data.corner_normals) == len(expected)
    for corner, normal in zip(cylinder.data.corner_normals, expected, strict=True):
        assert tuple(corner.vector) == pytest.approx(normal, abs=1e-6)


def test_finish_preserves_shape_identity_coordinates_values_and_relative_keys(cylinder):
    keys = add_morphs(cylinder)
    saved = [[tuple(point.co) for point in key.data] for key in keys]
    topology = [tuple(face.vertices) for face in cylinder.data.polygons]
    original = cylinder.data.shape_keys
    finish.fix_normals(cylinder)
    assert cylinder.data.shape_keys == original
    assert list(original.key_blocks) == list(keys)
    for key, coordinates in zip(keys, saved, strict=True):
        assert [tuple(point.co) for point in key.data] == coordinates
    assert keys[1].value == pytest.approx(0.35)
    assert keys[1].slider_min == pytest.approx(-0.2)
    assert keys[1].slider_max == pytest.approx(1.4)
    assert keys[2].relative_key == keys[1]
    assert keys[2].mute
    assert [tuple(face.vertices) for face in cylinder.data.polygons] == topology


def test_finish_discards_the_temporary_object_and_mesh(cylinder):
    add_morphs(cylinder)
    before = (len(bpy.data.objects), len(bpy.data.meshes), len(bpy.data.shape_keys))
    finish.fix_normals(cylinder)
    assert (len(bpy.data.objects), len(bpy.data.meshes), len(bpy.data.shape_keys)) == before
    assert bpy.context.view_layer.objects.active == cylinder
    assert len(cylinder.modifiers) == 0


def test_a_crease_present_only_in_a_morph_gets_outward_split_normals():
    build_models.reset_scene()
    mesh = bpy.data.meshes.new("Fold")
    mesh.from_pydata(
        [(-1, -1, 0), (0, -1, 0), (1, -1, 0), (-1, 1, 0), (0, 1, 0), (1, 1, 0)],
        [],
        [(0, 1, 4, 3), (1, 2, 5, 4)],
    )
    obj = bpy.data.objects.new("Fold", mesh)
    bpy.context.collection.objects.link(obj)
    obj.shape_key_add(name="Basis")
    targets = []
    for angle in (math.radians(100), math.radians(-110)):
        key = obj.shape_key_add(name="Bent")
        key.value = 0.0
        for index in (2, 5):
            key.data[index].co.x = math.cos(angle)
            key.data[index].co.z = math.sin(angle)
        targets.append((key, angle))
    finish.fix_normals(obj)
    shared = next(edge for edge in mesh.edges if set(edge.vertices) == {1, 4})
    assert shared.use_edge_sharp
    for key, angle in targets:
        normals = key.normals_split_get()
        for face, expected in zip(mesh.polygons, ((0, 0, 1), (-math.sin(angle), 0, math.cos(angle))), strict=True):
            for loop in face.loop_indices:
                normal = Vector(normals[loop * 3 : loop * 3 + 3])
                assert normal.dot(Vector(expected)) > 0.99999
    assert len(mesh.vertices) == 6
    assert len(mesh.polygons) == 2
    assert all(key.value == 0 for key, _angle in targets)
