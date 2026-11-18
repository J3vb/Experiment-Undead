"""Wrist pressure stays local, preserves closed cloth and never changes the shared rest fit."""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import bpy

# isort: split
import bmesh
import body_parts as soft
import gear_paint as paint
import player_wrist_fit as fit
import pytest
from mathutils import Vector
from player_grip_profiles import PROFILES


@pytest.fixture(autouse=True)
def empty_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def fabric(name="Fabric"):
    rings = [
        [(0.047 * math.cos(i * math.tau / 16), 0.047 * math.sin(i * math.tau / 16), z) for i in range(16)]
        for z in (-0.10, -0.04, -0.015, 0, 0.015, 0.04, 0.10)
    ]
    obj = soft.loft(name, rings, bpy.data.materials.new("BodyKnit"))
    paint.zone(obj, paint.ZONE_ACCENT)
    return obj


def closed_volume(obj, coordinates=None):
    mesh = obj.data.copy()
    if coordinates is not None:
        for vertex, point in zip(mesh.vertices, coordinates, strict=True):
            vertex.co = point
    mesh.calc_loop_triangles()
    for triangle in mesh.loop_triangles:
        original = [obj.data.vertices[index].co for index in triangle.vertices]
        changed = [mesh.vertices[index].co for index in triangle.vertices]
        first = (original[1] - original[0]).cross(original[2] - original[0])
        second = (changed[1] - changed[0]).cross(changed[2] - changed[0])
        assert first.dot(second) > 0, "a pressure fold cannot invert a triangle"
    surface = bmesh.new()
    try:
        surface.from_mesh(mesh)
        bmesh.ops.triangulate(surface, faces=surface.faces[:])
        surface.normal_update()
        assert all(edge.is_manifold and edge.is_contiguous for edge in surface.edges)
        assert all(face.calc_area() > 1e-10 for face in surface.faces)
        volume = surface.calc_volume(signed=True)
        assert volume > 0
        return volume
    finally:
        surface.free()
        bpy.data.meshes.remove(mesh)


def test_press_only_moves_the_contact_side_inside_the_wrist_band():
    obj = fabric()
    before = [vertex.co.copy() for vertex in obj.data.vertices]
    fit.press_fabric(obj, (0, 0, 0), (0, 0, 2), (3, 0, 1), 0.03, 0.08)
    changed = 0
    for original, vertex in zip(before, obj.data.vertices, strict=True):
        assert vertex.co.y == original.y and vertex.co.z == original.z
        assert vertex.co.x <= original.x + 1e-7
        if original.x <= 0.03 or abs(original.z) >= 0.08:
            assert tuple(vertex.co) == tuple(original)
        elif abs(original.z) < 1e-7:
            assert vertex.co.x == pytest.approx(0.03, abs=1e-7)
            changed += 1
    assert changed >= 3


def test_press_preserves_topology_zones_materials_and_outward_volume():
    obj = fabric()
    faces = [tuple(face.vertices) for face in obj.data.polygons]
    colors = [tuple(color.color) for color in obj.data.color_attributes["Color"].data]
    materials = [face.material_index for face in obj.data.polygons]
    original = closed_volume(obj)
    fit.press_fabric(obj, (0, 0, 0), (0, 0, 1), (1, 0, 0), 0.027, 0.08)
    assert [tuple(face.vertices) for face in obj.data.polygons] == faces
    assert [tuple(color.color) for color in obj.data.color_attributes["Color"].data] == colors
    assert [face.material_index for face in obj.data.polygons] == materials
    assert original * 0.65 < closed_volume(obj) < original


@pytest.mark.parametrize(
    "invalid",
    [
        {"axis": (0, 0, 0)},
        {"normal": (0, 0, 0)},
        {"normal": (0, 0, 3)},
        {"limit": 0},
        {"limit": -0.02},
        {"width": 0},
        {"width": -0.08},
    ],
)
def test_invalid_pressure_rejects_without_changing_mesh(invalid):
    obj = fabric()
    before = [tuple(vertex.co) for vertex in obj.data.vertices]
    args = {"centre": (0, 0, 0), "axis": (0, 0, 1), "normal": (1, 0, 0), "limit": 0.03, "width": 0.08}
    with pytest.raises(ValueError):
        fit.press_fabric(obj, **(args | invalid))
    assert [tuple(vertex.co) for vertex in obj.data.vertices] == before


def test_world_space_variants_preserve_basis_key_order_and_unaffected_grips():
    parts = [fabric("GloveCuff" + side) for side in ("L", "R")]
    protected = fabric("GlovePalmL")
    for obj, sign in zip(parts, (1, -1), strict=True):
        obj.rotation_euler = Vector((0, 0, 1)).rotation_difference(Vector((sign, 0, -1)).normalized()).to_euler()
        obj.location = (sign * 0.61, 0, 1.05)
    bpy.context.view_layer.update()
    before = {obj.name: [vertex.co.copy() for vertex in obj.data.vertices] for obj in parts}
    meshes, objects = len(bpy.data.meshes), len(bpy.data.objects)
    fit.add_wrist_variants([*parts, protected])
    assert len(bpy.data.meshes) == meshes and len(bpy.data.objects) == objects
    assert protected.data.shape_keys is None
    for obj in parts:
        keys = obj.data.shape_keys.key_blocks
        assert list(keys.keys()) == ["Basis", *("grip_" + profile for profile in PROFILES[1:])]
        assert [tuple(vertex.co) for vertex in obj.data.vertices] == [tuple(point) for point in before[obj.name]]
        for profile in PROFILES[1:]:
            key = keys["grip_" + profile]
            assert key.value == 0 and key.relative_key == keys["Basis"]
            affected = (obj.name.endswith("L") and profile in ("atlas_auto", "rampart_br")) or (
                obj.name.endswith("R") and profile == "siphon"
            )
            distances = [
                (point.co - original).length for point, original in zip(key.data, before[obj.name], strict=True)
            ]
            if affected:
                assert max(distances) > 0.003
                assert closed_volume(obj, [point.co for point in key.data]) > closed_volume(obj) * 0.65
            else:
                assert max(distances) < 2e-7


def test_actual_fabric_keeps_every_active_profile_closed_and_all_other_shapes_exact():
    import character_rig as rig
    import player_arm_shapes as body
    import player_arms_model as arms

    mats = arms._materials()
    armature = rig.build_armature()
    arms._sleeves(mats)
    body.gloves(armature, mats)
    for side, sign in (("L", 1), ("R", -1)):
        arms._wrist_details(mats, side, sign)
    parts = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    # Production joins and welds these submicron bevel crumbs before export.
    for obj in parts:
        soft.clean(obj)
    fit.add_wrist_variants(parts)
    count = 0
    for obj in parts:
        if obj.data.shape_keys is None:
            continue
        before = [vertex.co.copy() for vertex in obj.data.vertices]
        volume = closed_volume(obj)
        for profile in PROFILES[1:]:
            points = [vertex.co.copy() for vertex in obj.data.shape_keys.key_blocks["grip_" + profile].data]
            affected = (obj.name.endswith("L") and profile in ("atlas_auto", "rampart_br")) or (
                obj.name.endswith("R") and profile == "siphon"
            )
            if affected:
                assert closed_volume(obj, points) > volume * 0.65
                for original, point in zip(before, points, strict=True):
                    world = obj.matrix_world @ original
                    sign = 1 if obj.name.endswith("L") else -1
                    axis = Vector((sign, 0, -1)).normalized()
                    distance = (world - Vector((sign * 0.61, 0, 1.05))).dot(axis)
                    if abs(distance) >= 0.08:
                        assert (point - original).length < 3e-7
                count += 1
            else:
                assert points == before
    assert count == 15
