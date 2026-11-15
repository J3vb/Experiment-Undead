"""Player geometry, painted zones and skinning survive the source-to-glTF pipeline."""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import bpy

# isort: split
# bpy must load before bmesh.
import bmesh
import character_rig
import check_models
import gear_paint
import pytest
from mathutils import Vector
from player_body_model import build_player


@pytest.fixture(params=("source", "committed"))
def player(request):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    if request.param == "source":
        build_player()
    else:
        check_models.load_glb(os.path.join(check_models.REPO, "assets/models/characters/player.glb"))
    bpy.context.view_layer.update()
    return list(bpy.context.scene.objects)


def meshes(objects):
    return [obj for obj in objects if obj.type == "MESH"]


def weights(obj, vertex):
    return {obj.vertex_groups[group.group].name: group.weight for group in vertex.groups if group.weight > 0.0}


def test_player_triangle_detail_floor_and_budget(player):
    parts = meshes(player)
    triangles = sum(len(face.vertices) - 2 for obj in parts for face in obj.data.polygons)
    assert 8_000 <= triangles <= 16_000


def test_player_adult_scale_and_material_contract(player):
    parts = meshes(player)
    low, high = check_models.bounds(parts)
    assert 1.75 <= high.z - low.z <= 1.85
    assert low.z == pytest.approx(0.0, abs=0.01)
    materials = {mat.name for obj in parts for mat in obj.data.materials}
    assert materials == {"BodySuit", "BodyKnit", "BodyRubber", "BodyLens"}


def test_player_has_the_shared_bones_and_valid_skin_weights(player):
    armatures = [obj for obj in player if obj.type == "ARMATURE"]
    assert len(armatures) == 1
    armature = armatures[0]
    assert len(armature.data.bones) == 22
    assert set(armature.data.bones.keys()) == character_rig.BONES.keys()
    for name, (parent, _head, _tail) in character_rig.BONES.items():
        bone = armature.data.bones[name]
        assert (bone.parent.name if bone.parent else None) == parent
    for obj in meshes(player):
        modifiers = [modifier for modifier in obj.modifiers if modifier.type == "ARMATURE"]
        assert len(modifiers) == 1, obj.name
        assert modifiers[0].object == armature
        for vertex in obj.data.vertices:
            assert all(math.isfinite(group.weight) and 0.0 <= group.weight <= 1.0 for group in vertex.groups)
            influences = weights(obj, vertex)
            assert 1 <= len(influences) <= 4, (obj.name, vertex.index)
            assert all(math.isfinite(weight) and 0 < weight <= 1 for weight in influences.values())
            assert sum(influences.values()) == pytest.approx(1.0, abs=0.01)
            assert influences.keys() <= character_rig.BONES.keys()
            assert not any(name.startswith("sock_") for name in influences)


def test_undersuit_is_one_closed_connected_surface(player):
    suit = next(obj for obj in meshes(player) if obj.name == "Undersuit")
    bm = bmesh.new()
    bm.from_mesh(suit.data)
    bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=1e-6)
    assert all(edge.is_manifold for edge in bm.edges), "joint seams must not leave open borders"
    reached, pending = set(), [next(iter(bm.verts))]
    while pending:
        vertex = pending.pop()
        if vertex in reached:
            continue
        reached.add(vertex)
        pending.extend(edge.other_vert(vertex) for edge in vertex.link_edges)
    assert len(reached) == len(bm.verts), "thermal body must be connected through every joint"
    bm.free()
    assert not any(modifier.type in {"SKIN", "SUBSURF"} for modifier in suit.modifiers)


def test_zones_use_surface_area_and_keep_the_lenses_small(player):
    areas = dict.fromkeys(gear_paint.ZONES, 0.0)
    for obj in meshes(player):
        shares = gear_paint.zone_shares(obj)
        bm = check_models.world_mesh(obj)
        area = sum(face.calc_area() for face in bm.faces)
        bm.free()
        for value in areas:
            areas[value] += shares[value] * area
        lens_faces = [face for face in obj.data.polygons if obj.data.materials[face.material_index].name == "BodyLens"]
        if lens_faces:
            attr = obj.data.color_attributes["Color"]
            assert all(gear_paint._face_zone(obj.data, attr, face) == gear_paint.ZONE_GLOW for face in lens_faces)
    total = sum(areas.values())
    assert all(area > 0.0 for area in areas.values()), "all four paint zones must be present"
    assert areas[gear_paint.ZONE_MAIN] / total > 0.5
    assert 0.0 < areas[gear_paint.ZONE_GLOW] / total < 0.05


def test_eyes_follow_the_head_and_face_forward(player):
    armature = next(obj for obj in player if obj.type == "ARMATURE")
    eyes = next(obj for obj in player if obj.name == "Eyes")
    assert eyes.type == "EMPTY"
    assert eyes.parent == armature
    assert eyes.parent_type == "BONE"
    assert eyes.parent_bone == "head"
    head = armature.matrix_world @ armature.data.bones["head"].head_local
    position = eyes.matrix_world.translation
    assert position.y < head.y - 0.04, "Blender -Y becomes Godot +Z"
    assert 1.65 <= position.z <= 1.77
    assert abs(position.x) < 0.015


def test_boots_goggles_and_buckles_are_rigidly_bound(player):
    parts = [obj for obj in meshes(player) if obj.name.startswith(("Boot", "Goggle", "Buckle"))]
    assert any(obj.name.startswith("Boot") for obj in parts)
    assert any(obj.name.startswith("Goggle") for obj in parts)
    assert any(obj.name.startswith("Buckle") for obj in parts)
    for obj in parts:
        assigned = [weights(obj, vertex) for vertex in obj.data.vertices]
        assert all(len(influences) == 1 for influences in assigned), obj.name
        bones = {next(iter(influences)) for influences in assigned}
        assert len(bones) == 1, obj.name
        if obj.name.startswith("Boot"):
            assert bones <= {"foot_L", "foot_R"}
        elif obj.name.startswith("Goggle"):
            assert bones == {"head"}


def test_undersuit_follows_an_arm_pose(player):
    armature = next(obj for obj in player if obj.type == "ARMATURE")
    suit = next(obj for obj in meshes(player) if obj.name == "Undersuit")
    candidates = [vertex for vertex in suit.data.vertices if weights(suit, vertex).get("forearm_L", 0.0) > 0.9]
    assert candidates, "the continuous sleeve must be weighted to the forearm"
    vertex = max(candidates, key=lambda item: item.co.x)
    before = suit.matrix_world @ vertex.co
    pose = armature.pose.bones["forearm_L"]
    pose.rotation_mode = "XYZ"
    pose.rotation_euler.x = 0.4
    bpy.context.view_layer.update()
    evaluated = suit.evaluated_get(bpy.context.evaluated_depsgraph_get())
    after = evaluated.matrix_world @ evaluated.data.vertices[vertex.index].co
    assert (after - before).length > 0.01
    assert all(math.isfinite(component) for component in Vector(after))
