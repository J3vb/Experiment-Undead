"""Rigid gear keeps its close inspection detail, paint zones and attachment geometry after export."""

import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import bpy
import character_checks
import character_models
import character_rig
import check_models
import gear_paint as paint
import pytest
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from player_body.build import build_player

NAMES = character_checks.CHARMS + character_checks.IMPLANTS


@pytest.fixture(
    params=[(name, version) for name in NAMES for version in ("source", "committed")],
    ids=[f"{name}-{version}" for name in NAMES for version in ("source", "committed")],
)
def gear(request):
    name, version = request.param
    bpy.ops.wm.read_factory_settings(use_empty=True)
    path, build = character_models.MODELS[name]
    if version == "source":
        build()
    else:
        check_models.load_glb(str(Path(check_models.REPO) / "assets/models" / path))
    bpy.context.view_layer.update()
    return name, list(bpy.context.scene.objects)


def _meshes(objects):
    return [obj for obj in objects if obj.type == "MESH"]


def _zone_shares(objects):
    areas = dict.fromkeys(paint.ZONES, 0.0)
    for obj in _meshes(objects):
        shares = paint.zone_shares(obj)
        mesh = check_models.world_mesh(obj)
        area = sum(face.calc_area() for face in mesh.faces)
        mesh.free()
        for zone in areas:
            areas[zone] += shares[zone] * area
    total = sum(areas.values())
    return {zone: area / total for zone, area in areas.items()}


def _zone_points(obj, value):
    attribute = obj.data.color_attributes["Color"]
    return [
        obj.matrix_world @ obj.data.vertices[index].co
        for face in obj.data.polygons
        if paint._face_zone(obj.data, attribute, face) == value
        for index in face.vertices
    ]


def test_gear_detail_rigid_nodes_materials_and_closed_shells(gear):
    name, objects = gear
    triangles = sum(len(face.vertices) - 2 for obj in _meshes(objects) for face in obj.data.polygons)
    low, high = (600, 1_000) if name in character_checks.CHARMS else (1_000, 1_500)
    high = {
        "charm_vial": 1_200,
        "charm_dog_tags": 1_300,
        "charm_coin": 1_200,
        "implant_spine": 1_600,
        "implant_ocular": 1_800,
    }.get(name, high)
    assert low <= triangles <= high, (name, triangles)
    nodes = {obj.name: obj for obj in objects}
    assert character_checks.JOINTS[name].keys() <= nodes.keys()
    expected = {"Link1", "Link2", "Body"} if name in character_checks.CHARMS else {"Module", "Port"}
    assert {obj.name for obj in _meshes(objects)} == expected
    assert not any(obj.type == "ARMATURE" or obj.modifiers for obj in objects)
    materials = {material.name for obj in _meshes(objects) for material in obj.data.materials}
    assert "GearPlate" in materials
    expected_materials = {"GearPlate", "GearPolymer", "GearRubber"}
    if name in {"charm_vial", "implant_ocular"}:
        expected_materials.add("GearGlass")
        assert "GearGlass" in materials, "specimen and optical hardware need the glass finish"
    if name == "charm_vial":
        expected_materials.remove("GearPolymer")
        expected_materials.add("GearLiquid")
        assert "GearLiquid" in materials, "the liquid needs a polished finish beneath the glass"
    assert materials <= expected_materials
    assert len(materials) <= 4
    assert check_models.check_geometry(objects, "gear") == []
    assert character_checks.check(objects, "gear", name) == []
    assert check_models.check_joints(nodes, name) == []


def test_zones_keep_a_broad_trim_band_and_small_experiment_glow(gear):
    name, objects = gear
    shares = _zone_shares(objects)
    assert shares[paint.ZONE_MAIN] > 0.35
    assert shares[paint.ZONE_ACCENT] > 0.0
    assert shares[paint.ZONE_TRIM] >= 0.02
    assert 0.0 <= shares[paint.ZONE_GLOW] <= 0.05 + 1e-6
    if name == "charm_vial" or name in character_checks.IMPLANTS:
        assert shares[paint.ZONE_GLOW] > 0.0
    part = next(obj for obj in objects if obj.name == ("Body" if name in character_checks.CHARMS else "Module"))
    points = _zone_points(part, paint.ZONE_TRIM)
    assert points, "the main rigid piece needs a trim band, not only painted chain links"
    low, high = check_models.bounds([part])
    assert max(point.x for point in points) - min(point.x for point in points) >= (high.x - low.x) * 0.5


def test_charm_chain_pivots_hang_below_the_origin(gear):
    name, objects = gear
    if name not in character_checks.CHARMS:
        return
    nodes = {obj.name: obj for obj in objects}
    hook = nodes["Hook"]
    assert hook.type == "EMPTY"
    assert hook.matrix_world.translation.length < 1e-5
    for name, parent in (("Link1", "Hook"), ("Link2", "Link1"), ("Body", "Link2")):
        obj = nodes[name]
        assert obj.parent == nodes[parent]
        low, high = check_models.bounds([obj])
        pivot = obj.matrix_world.translation
        assert abs(pivot.z - high.z) <= 0.003
        assert high.z <= 0.003
        assert low.z < high.z
    assert nodes["Body"].matrix_world.translation.z < nodes["Link2"].matrix_world.translation.z < 0.0


def _forearm_radius():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    build_player()
    bpy.context.view_layer.update()
    suit = bpy.data.objects["Body"]
    head, tail = map(Vector, character_rig.BONES["forearm_L"][1:])
    axis = (tail - head).normalized()
    center = head + axis * 0.09
    across = axis.cross(Vector((0, 1, 0))).normalized()
    radii = []
    for index in range(16):
        angle = index * math.tau / 16
        direction = across * math.cos(angle) + Vector((0, 1, 0)) * math.sin(angle)
        hit, point, _normal, _face = suit.ray_cast(center + direction * 0.2, -direction)
        assert hit, "the fit check must intersect the actual thermal sleeve"
        radii.append((point - center).length)
    return max(radii)


def _inner_radius(module):
    radii = []
    for face in module.data.polygons:
        points = [module.data.vertices[index].co for index in face.vertices]
        if max(point.z for point in points) - min(point.z for point in points) < 0.08:
            continue
        center = sum(points, Vector()) / len(points)
        radial = Vector((center.x, center.y, 0)).normalized()
        face_radii = [math.hypot(point.x, point.y) for point in points]
        if face.normal.dot(radial) < -0.7 and max(face_radii) - min(face_radii) < 0.0005:
            radii.append(sum(face_radii) / len(face_radii))
    assert radii, "Module needs a real curved inner shell extending along the forearm"
    return min(radii)


def test_implant_inner_shell_fits_the_built_forearm():
    radius = _forearm_radius()
    for name in character_checks.IMPLANTS:
        for version in ("source", "committed"):
            bpy.ops.wm.read_factory_settings(use_empty=True)
            path, build = character_models.MODELS[name]
            if version == "source":
                build()
            else:
                check_models.load_glb(str(Path(check_models.REPO) / "assets/models" / path))
            module = bpy.data.objects["Module"]
            inner = _inner_radius(module)
            assert radius - 0.002 <= inner <= radius + 0.01, (name, version, inner, radius)


def test_neck_light_ring_clears_the_actual_undersuit_collar():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    build_player()
    bpy.context.view_layer.update()
    suit = bpy.data.objects["Body"]
    collar = BVHTree.FromObject(suit, bpy.context.evaluated_depsgraph_get())
    neck = Vector(character_rig.BONES["neck"][1])
    for name in character_checks.IMPLANTS:
        path, _build = character_models.MODELS[name]
        check_models.load_glb(str(Path(check_models.REPO) / "assets/models" / path))
        port = bpy.data.objects["Port"]
        ring = _zone_points(port, paint.ZONE_GLOW)
        assert ring, "the neck port needs its own visible glowing ring"
        point = min(ring, key=lambda vertex: (vertex.x, vertex.y)) + neck
        start = Vector((point.x, -0.3, point.z))
        surface, _normal, _index, _distance = collar.ray_cast(start, Vector((0, 1, 0)))
        assert surface is not None, "measure the ring where it overlaps the actual thermal collar"
        assert point.y <= surface.y - 0.004, (name, "neck ring is buried in the thermal collar")


def test_checker_rejects_a_moved_hook_and_flattened_chain():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    character_models.MODELS["charm_coin"][1]()
    bpy.context.view_layer.update()
    nodes = {obj.name: obj for obj in bpy.context.scene.objects}
    nodes["Hook"].location.x = 0.01
    bpy.context.view_layer.update()
    assert "Hook must be at the model origin" in character_checks._check_hanging(nodes)
    nodes["Hook"].location.x = 0.0
    body = nodes["Body"]
    world = body.matrix_world.copy()
    body.parent = nodes["Hook"]
    body.matrix_world = world
    bpy.context.view_layer.update()
    assert "Body must be directly parented to Link2" in character_checks._check_hanging(nodes)
