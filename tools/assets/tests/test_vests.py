"""Vest silhouettes, fit, paint and binding survive source and committed glTF builds."""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import bpy
import character_checks
import character_rig
import check_models
import gear_paint
import pytest
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from vest_model import build_vest_heavy, build_vest_light, build_vest_medium

BUILDERS = {"light": build_vest_light, "medium": build_vest_medium, "heavy": build_vest_heavy}
MATERIALS = {"GearFabric", "GearWebbing", "GearPlate", "GearPolymer"}


def load_vest(frame, version):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    if version == "source":
        BUILDERS[frame]()
    else:
        check_models.load_glb(os.path.join(check_models.REPO, f"assets/models/gear/vest_{frame}.glb"))
    bpy.context.view_layer.update()
    return {obj.name: obj for obj in bpy.context.scene.objects}


@pytest.fixture(
    params=((frame, version) for frame in BUILDERS for version in ("source", "committed")),
    ids="-".join,
)
def vest(request):
    frame, version = request.param
    return frame, load_vest(frame, version)


@pytest.fixture(scope="session")
def player_surfaces():
    parts = check_models.load_glb(os.path.join(check_models.REPO, "assets/models/characters/player.glb"))
    surfaces = []
    for obj in parts:
        if obj.type != "MESH":
            continue
        mesh = obj.data
        mesh.calc_loop_triangles()
        points = [obj.matrix_world @ vertex.co for vertex in mesh.vertices]
        faces = [triangle.vertices[:] for triangle in mesh.loop_triangles]
        surfaces.append((obj.name, BVHTree.FromPolygons(points, faces, all_triangles=True)))
    return surfaces


def meshes(nodes):
    return [obj for obj in nodes.values() if obj.type == "MESH"]


def weights(obj, vertex):
    return {obj.vertex_groups[item.group].name: item.weight for item in vertex.groups if item.weight > 0.0}


def test_triangle_ranges_and_material_contract(vest):
    frame, nodes = vest
    parts = meshes(nodes)
    count = sum(len(face.vertices) - 2 for obj in parts for face in obj.data.polygons)
    low, high = character_checks.VEST_BUDGETS[f"vest_{frame}"]
    assert low <= count <= high, (frame, count)
    assert {mat.name for obj in parts for mat in obj.data.materials} == MATERIALS
    assert len(parts) == 3, "one Shell and the two separate first-person cuffs"


def test_required_nodes_and_first_person_cuff_origins(vest):
    _frame, nodes = vest
    assert {"Shell", "CuffFP_L", "CuffFP_R", "CharmClip"} <= nodes.keys()
    assert nodes["Shell"].type == "MESH"
    assert nodes["CharmClip"].type == "EMPTY"
    clip = nodes["CharmClip"].matrix_world.translation
    assert 1.20 <= clip.z <= 1.52 and clip.y < -0.08, "charm hangs in front of the chest"
    for name in ("CuffFP_L", "CuffFP_R"):
        cuff = nodes[name]
        assert cuff.type == "MESH" and cuff.find_armature() is None
        assert not cuff.vertex_groups and cuff.parent_type != "BONE"
        low, high = check_models.bounds([cuff])
        assert (cuff.matrix_world.translation - (low + high) / 2).length <= 0.01


def test_shell_uses_the_exact_player_rest_rig_and_normalized_weights(vest):
    _frame, nodes = vest
    armatures = [obj for obj in nodes.values() if obj.type == "ARMATURE"]
    assert len(armatures) == 1
    armature = armatures[0]
    assert set(armature.data.bones.keys()) == character_rig.BONES.keys()
    for name, (parent, head, tail) in character_rig.BONES.items():
        bone = armature.data.bones[name]
        assert (bone.parent.name if bone.parent else None) == parent
        assert tuple(armature.matrix_world @ bone.head_local) == pytest.approx(head, abs=1e-4)
        direction = armature.matrix_world.to_3x3() @ (bone.tail_local - bone.head_local).normalized()
        assert direction.dot((Vector(tail) - Vector(head)).normalized()) > 0.99999
    shell = nodes["Shell"]
    assert shell.find_armature() == armature
    assert [modifier.type for modifier in shell.modifiers] == ["ARMATURE"]
    for vertex in shell.data.vertices:
        influences = weights(shell, vertex)
        assert 1 <= len(influences) <= 4
        assert all(math.isfinite(value) and 0 < value <= 1 for value in influences.values())
        assert sum(influences.values()) == pytest.approx(1, abs=0.01)
        assert influences.keys() <= character_rig.BONES.keys()
        assert not any(name.startswith("sock_") for name in influences)


def test_trim_reads_without_glow_and_glow_is_under_five_percent(vest):
    _frame, nodes = vest
    areas = dict.fromkeys(gear_paint.ZONES, 0.0)
    for obj in meshes(nodes):
        shares = gear_paint.zone_shares(obj)
        area = character_checks._surface_area(obj)
        for zone, share in shares.items():
            areas[zone] += area * share
    total = sum(areas.values())
    assert all(area > 0 for area in areas.values()), "all four paint zones are present"
    assert areas[gear_paint.ZONE_TRIM] / total >= 0.05
    assert areas[gear_paint.ZONE_GLOW] / total <= 0.05


def test_front_stencil_trim_is_visible_across_the_curved_carrier(vest):
    frame, nodes = vest
    shell = nodes["Shell"]
    inverse = shell.matrix_world.inverted()
    direction = (inverse.to_3x3() @ Vector((0, 1, 0))).normalized()
    color = shell.data.color_attributes["Color"]
    for x in (-0.10, 0.0, 0.10):
        origin = inverse @ Vector((x, -1, 1.360))
        hit, _point, _normal, index = shell.ray_cast(origin, direction)
        assert hit, (frame, x, "front stencil ray must hit the carrier")
        face = shell.data.polygons[index]
        assert gear_paint._face_zone(shell.data, color, face) == gear_paint.ZONE_TRIM, (frame, x, index)


def test_every_shell_vertex_clears_the_player_body_by_three_mm(player_surfaces, vest):
    frame, nodes = vest
    shell = nodes["Shell"]
    closest = (math.inf, None, None)
    for vertex in shell.data.vertices:
        point = shell.matrix_world @ vertex.co
        for name, surface in player_surfaces:
            nearest, normal, _face, distance = surface.find_nearest(point)
            signed = -distance if (point - nearest).dot(normal) < 0 else distance
            closest = min(closest, (signed, name, vertex.index))
    assert closest[0] >= 0.003 - 1e-6, (frame, "signed clearance / body part / Shell vertex", closest)


def test_world_cuffs_are_rigid_and_shell_deforms_with_the_body(vest):
    _frame, nodes = vest
    shell = nodes["Shell"]
    armature = shell.find_armature()
    for side, sign in (("L", 1), ("R", -1)):
        cuff = [v for v in shell.data.vertices if (shell.matrix_world @ v.co).x * sign > 0.45]
        assert cuff, f"world sleeve cuff on {side} forearm"
        assert all(weights(shell, vertex) == {f"forearm_{side}": 1.0} for vertex in cuff)
        assert any(weights(shell, vertex) == {f"clavicle_{side}": 1.0} for vertex in shell.data.vertices)
    before = [shell.matrix_world @ vertex.co for vertex in shell.data.vertices]
    pose = armature.pose.bones["spine_03"]
    pose.rotation_mode = "XYZ"
    pose.rotation_euler.y = 0.2
    armature.pose.bones["forearm_L"].rotation_mode = "XYZ"
    armature.pose.bones["forearm_L"].rotation_euler.x = 0.4
    bpy.context.view_layer.update()
    evaluated = shell.evaluated_get(bpy.context.evaluated_depsgraph_get())
    after = [evaluated.matrix_world @ vertex.co for vertex in evaluated.data.vertices]
    assert max((a - b).length for a, b in zip(after, before, strict=True)) > 0.015
    assert all(math.isfinite(component) for point in after for component in point)


@pytest.mark.parametrize("version", ("source", "committed"))
def test_collar_and_shoulders_identify_each_frame_at_distance(version):
    widths, collars = {}, {}
    for frame in BUILDERS:
        shell = load_vest(frame, version)["Shell"]
        points = [shell.matrix_world @ vertex.co for vertex in shell.data.vertices]
        shoulders = [point for point in points if 1.35 <= point.z <= 1.65]
        widths[frame] = max(point.x for point in shoulders) - min(point.x for point in shoulders)
        collars[frame] = max(point.z for point in points if abs(point.x) < 0.13)
    assert widths["heavy"] > widths["medium"] + 0.02
    assert widths["medium"] > widths["light"] + 0.02
    assert collars["heavy"] > collars["medium"] + 0.04


def test_vests_pass_the_shared_model_checks(vest):
    frame, nodes = vest
    objects = list(nodes.values())
    assert check_models.check_geometry(objects, "gear") == []
    assert check_models.check_joints(nodes, f"vest_{frame}") == []
    assert character_checks.check(objects, "gear", f"vest_{frame}") == []
