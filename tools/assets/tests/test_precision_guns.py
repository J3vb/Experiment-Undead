"""Geometry rays verify machined ports, bores and the sniper thumbhole without moving animation pivots."""

import sys
from pathlib import Path

import bpy
import pytest
from mathutils import Vector
from mathutils.bvhtree import BVHTree

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import build_models as models


@pytest.fixture(params=["rifle_ar", "talon_dmr", "corvid_338"])
def gun(request):
    models.reset_scene()
    models.MODELS[request.param][1]()
    bpy.context.view_layer.update()
    return request.param


def hit(name, origin, direction):
    obj = bpy.data.objects[name]
    vertices = [obj.matrix_world @ vertex.co for vertex in obj.data.vertices]
    polygons = [list(face.vertices) for face in obj.data.polygons]
    tree = BVHTree.FromPolygons(vertices, polygons)
    return tree.ray_cast(Vector(origin), Vector(direction))[0]


def test_brake_bore_and_side_ports_are_open(gun):
    bore = 0.018 if gun == "corvid_338" else 0.016
    port = {"rifle_ar": 0.603, "talon_dmr": 0.812, "corvid_338": 0.814}[gun]
    bridge = {"rifle_ar": 0.59, "talon_dmr": 0.822, "corvid_338": 0.826}[gun]
    assert hit("MuzzleBrake", (0, 1.0, bore), (0, -1, 0)) is None
    assert hit("MuzzleBrake", (0.1, port, bore), (-1, 0, 0)) is None
    assert hit("MuzzleBrake", (0.1, bridge, bore), (-1, 0, 0)) is not None


def test_ejection_port_is_recessed_into_the_action(gun):
    point = hit("Receiver", (0.08, 0.0, 0.019), (-1, 0, 0))
    assert point is not None
    assert point.x < {"rifle_ar": 0.021, "talon_dmr": 0.024, "corvid_338": 0.01}[gun]


def test_animation_pivots_and_scope_clearance_stay_fixed(gun):
    bolt = bpy.data.objects["Bolt"]
    expected = {
        "rifle_ar": (0.0275, 0.015, 0.019),
        "talon_dmr": (0.0305, 0.015, 0.022),
        "corvid_338": (0, -0.1, 0.026),
    }[gun]
    assert tuple(bolt.matrix_world.translation) == pytest.approx(expected)
    assert bolt.parent.name == "Receiver"
    assert bpy.data.objects["Magazine"].parent.name == "Receiver"
    scope_vertices = [
        obj.matrix_world @ vertex.co
        for obj in bpy.context.scene.objects
        if obj.type == "MESH"
        for vertex in obj.data.vertices
    ]
    assert all(vertex.y > -0.128 for vertex in scope_vertices if vertex.z > 0.074 and abs(vertex.x) < 0.03)
    if gun != "rifle_ar":
        assert tuple(bpy.data.objects["ScopeLensMount"].matrix_world.translation) == pytest.approx((0, -0.128, 0.09))


@pytest.mark.parametrize("name,vent", [("rifle_ar", 0.23), ("talon_dmr", 0.22)])
def test_handguard_slots_reveal_an_internal_barrel(name, vent):
    models.reset_scene()
    models.MODELS[name][1]()
    bpy.context.view_layer.update()
    interior = hit("Receiver", (0.08, vent, 0.016), (-1, 0, 0))
    bridge = hit("Receiver", (0.08, 0.195, 0.016), (-1, 0, 0))
    assert interior is not None and interior.x < 0.013
    assert bridge is not None and bridge.x > 0.028


def test_corvid_thumbhole_and_flutes_are_carved():
    models.reset_scene()
    models.MODELS["corvid_338"][1]()
    bpy.context.view_layer.update()
    assert hit("Stock", (0.08, -0.12, -0.028), (-1, 0, 0)) is None
    assert hit("Stock", (0.08, -0.12, -0.008), (-1, 0, 0)) is not None
    flute = hit("Barrel", (0.08, 0.5, 0.018), (-1, 0, 0))
    shoulder = hit("Barrel", (0.08, 0.22, 0.018), (-1, 0, 0))
    assert flute is not None and shoulder is not None
    assert flute.x < shoulder.x - 0.001
