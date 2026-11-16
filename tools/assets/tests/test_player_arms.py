"""First-person arm detail, body compatibility and grip geometry survive glTF export."""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import bpy

# isort: split
# bpy must load before bmesh.
import bmesh
import character_checks
import character_rig
import check_models
import gear_paint
import pytest
from mathutils import Vector
from player_arms_model import build_player_arms

ARM_BONES = {f"{part}_{side}" for side in ("L", "R") for part in ("clavicle", "upperarm", "forearm", "hand")}


@pytest.fixture(params=("source", "committed"))
def arms(request):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    if request.param == "source":
        build_player_arms()
    else:
        check_models.load_glb(os.path.join(check_models.REPO, "assets/models/characters/player_arms.glb"))
    bpy.context.view_layer.update()
    return list(bpy.context.scene.objects)


def meshes(objects):
    return [obj for obj in objects if obj.type == "MESH"]


def weights(obj, vertex):
    return {obj.vertex_groups[group.group].name: group.weight for group in vertex.groups if group.weight > 0.0}


def test_arms_triangle_detail_floor_and_budget(arms):
    triangles = sum(len(face.vertices) - 2 for obj in meshes(arms) for face in obj.data.polygons)
    assert 5_000 <= triangles <= 10_000


def test_arms_surfaces_are_closed_manifold_shells(arms):
    for obj in meshes(arms):
        surface = bmesh.new()
        try:
            surface.from_mesh(obj.data)
            bmesh.ops.remove_doubles(surface, verts=list(surface.verts), dist=1e-5)
            assert all(edge.is_manifold for edge in surface.edges), obj.name
        finally:
            surface.free()


def test_arms_keep_all_22_bones_and_the_body_rest_pose(arms):
    armatures = [obj for obj in arms if obj.type == "ARMATURE"]
    assert len(armatures) == 1
    skeleton = armatures[0]
    assert len(skeleton.data.bones) == 22
    assert set(skeleton.data.bones.keys()) == character_rig.BONES.keys()
    for name, (parent, head, _tail) in character_rig.BONES.items():
        bone = skeleton.data.bones[name]
        assert (bone.parent.name if bone.parent else None) == parent
        assert tuple(bone.head_local) == pytest.approx(head, abs=1e-5)


def test_only_arm_bones_have_normalized_weights(arms):
    skeleton = next(obj for obj in arms if obj.type == "ARMATURE")
    used = set()
    for obj in meshes(arms):
        modifiers = [modifier for modifier in obj.modifiers if modifier.type == "ARMATURE"]
        assert len(modifiers) == 1
        assert modifiers[0].object == skeleton
        for vertex in obj.data.vertices:
            assert all(math.isfinite(group.weight) and 0.0 <= group.weight <= 1.0 for group in vertex.groups)
            influences = weights(obj, vertex)
            assert 1 <= len(influences) <= 4
            assert influences.keys() <= ARM_BONES
            assert all(math.isfinite(weight) and 0 < weight <= 1 for weight in influences.values())
            assert sum(influences.values()) == pytest.approx(1.0, abs=0.01)
            used.update(influences)
    for side in ("L", "R"):
        assert {f"upperarm_{side}", f"forearm_{side}", f"hand_{side}"} <= used


def test_character_checks_reject_normalized_pelvis_weights_on_arms(arms):
    obj = meshes(arms)[0]
    vertex = obj.data.vertices[0]
    for index in [influence.group for influence in vertex.groups]:
        obj.vertex_groups[index].remove([vertex.index])
    pelvis = obj.vertex_groups.get("pelvis") or obj.vertex_groups.new(name="pelvis")
    pelvis.add([vertex.index], 1.0, "REPLACE")
    errors = character_checks.check(arms, "characters", "player_arms")
    assert any("non-arm bones: pelvis" in error for error in errors)
    assert not any("weights sum" in error for error in errors)


def test_materials_and_zones_match_the_body(arms):
    parts = meshes(arms)
    assert {mat.name for obj in parts for mat in obj.data.materials} == {"BodySuit", "BodyRubber", "BodyKnit"}
    areas = dict.fromkeys(gear_paint.ZONES, 0.0)
    for obj in parts:
        shares = gear_paint.zone_shares(obj)
        surface = check_models.world_mesh(obj)
        area = sum(face.calc_area() for face in surface.faces)
        surface.free()
        for zone in areas:
            areas[zone] += shares[zone] * area
        attribute = obj.data.color_attributes["Color"]
        for face in obj.data.polygons:
            if obj.data.materials[face.material_index].name == "BodySuit":
                assert gear_paint._face_zone(obj.data, attribute, face) == gear_paint.ZONE_MAIN
    assert areas[gear_paint.ZONE_MAIN] > 0
    assert areas[gear_paint.ZONE_ACCENT] > 0
    assert areas[gear_paint.ZONE_TRIM] > 0
    assert areas[gear_paint.ZONE_GLOW] == pytest.approx(0.0)


def glove_surface_point(parts, at):
    """Measure the mesh at a fingertip marker instead of trusting marker spacing alone."""
    candidates = []
    for obj in parts:
        hit, point, _normal, face_index = obj.closest_point_on_mesh(obj.matrix_world.inverted() @ at)
        if not hit:
            continue
        world_point = obj.matrix_world @ point
        material = obj.data.materials[obj.data.polygons[face_index].material_index]
        candidates.append(((world_point - at).length, world_point, material.name))
    distance, point, material = min(candidates, key=lambda item: item[0])
    assert distance <= 0.001, "grip markers must be on the actual fingertip caps"
    assert material == "BodyRubber"
    return point


@pytest.mark.parametrize(("side", "minimum", "maximum"), [("R", 0.025, 0.040), ("L", 0.040, 0.050)])
def test_thumb_index_surface_gap_fits_each_grip(arms, side, minimum, maximum):
    parts = meshes(arms)
    tips = []
    for name in (f"GripThumbTip_{side}", f"GripIndexTip_{side}"):
        marker = next(obj for obj in arms if obj.name == name)
        tips.append(glove_surface_point(parts, marker.matrix_world.translation))
    assert minimum <= (tips[0] - tips[1]).length <= maximum


def test_sleeve_moves_with_the_forearm_without_moving_the_other_arm(arms):
    skeleton = next(obj for obj in arms if obj.type == "ARMATURE")
    samples = {}
    for side in ("L", "R"):
        candidates = [
            (obj, vertex)
            for obj in meshes(arms)
            for vertex in obj.data.vertices
            if weights(obj, vertex).get(f"forearm_{side}", 0.0) > 0.9
        ]
        assert candidates
        obj, vertex = max(candidates, key=lambda item: abs((item[0].matrix_world @ item[1].co).x))
        samples[side] = (obj, vertex.index, obj.matrix_world @ vertex.co)
    pose = skeleton.pose.bones["forearm_L"]
    pose.rotation_mode = "XYZ"
    pose.rotation_euler.x = 0.4
    bpy.context.view_layer.update()
    graph = bpy.context.evaluated_depsgraph_get()
    for side, (obj, index, before) in samples.items():
        evaluated = obj.evaluated_get(graph)
        after = evaluated.matrix_world @ evaluated.data.vertices[index].co
        assert all(math.isfinite(component) for component in Vector(after))
        if side == "L":
            assert (after - before).length > 0.01
        else:
            assert (after - before).length < 1e-5
