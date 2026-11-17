"""Survivor body geometry, painted zones and skinning survive the source-to-glTF pipeline."""

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
    assert materials == {"BodySuit", "BodyHair", "BodyRubber", "BodySkin"}


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


def test_zones_use_surface_area_and_the_body_never_glows(player):
    areas = dict.fromkeys(gear_paint.ZONES, 0.0)
    for obj in meshes(player):
        shares = gear_paint.zone_shares(obj)
        bm = check_models.world_mesh(obj)
        area = sum(face.calc_area() for face in bm.faces)
        bm.free()
        for value in areas:
            areas[value] += shares[value] * area
    total = sum(areas.values())
    painted = (gear_paint.ZONE_MAIN, gear_paint.ZONE_ACCENT, gear_paint.ZONE_TRIM)
    assert all(areas[zone] > 0.0 for zone in painted), "main, accent and trim zones must be present"
    assert areas[gear_paint.ZONE_MAIN] / total > 0.5
    assert areas[gear_paint.ZONE_GLOW] == 0.0, "glow belongs to gear such as the implant, not the body"


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


def test_boots_face_details_and_buckles_are_rigidly_bound(player):
    parts = [obj for obj in meshes(player) if obj.name.startswith(("Boot", "Face", "Buckle"))]
    assert any(obj.name.startswith("Boot") for obj in parts)
    assert any(obj.name.startswith("Face") for obj in parts)
    assert any(obj.name.startswith("Buckle") for obj in parts)
    for obj in parts:
        assigned = [weights(obj, vertex) for vertex in obj.data.vertices]
        assert all(len(influences) == 1 for influences in assigned), obj.name
        bones = {next(iter(influences)) for influences in assigned}
        assert len(bones) == 1, obj.name
        if obj.name.startswith("Boot"):
            assert bones <= {"foot_L", "foot_R"}
        elif obj.name.startswith("Face"):
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


def _head_faces(player, material):
    suit = next(obj for obj in meshes(player) if obj.name == "Undersuit")
    return [
        face
        for face in suit.data.polygons
        if suit.data.materials[face.material_index].name == material and face.center.z > 1.55
    ]


def test_head_shows_a_bare_face_framed_by_beard_and_hair(player):
    skin = _head_faces(player, "BodySkin")
    hair = _head_faces(player, "BodyHair")
    assert skin and hair
    eye_level = [face for face in skin if abs(face.center.z - 1.704) < 0.01 and face.center.y < -0.05]
    assert eye_level, "the eyes look out of skin, not a mask"
    chin = [face for face in hair if face.center.z < 1.64 and face.center.y < -0.05 and abs(face.center.x) < 0.03]
    assert chin, "a beard covers the chin"
    crown = [face for face in hair if face.center.z > 1.78]
    assert crown, "cropped hair covers the crown"


def test_beard_and_nose_stand_out_from_the_face(player):
    suit = next(obj for obj in meshes(player) if obj.name == "Undersuit")
    points = [vertex.co for vertex in suit.data.vertices if abs(vertex.co.x) < 0.012 and vertex.co.y < 0]

    def front(low, high):
        return min(point.y for point in points if low <= point.z <= high)

    assert front(1.67, 1.69) < front(1.70, 1.71) - 0.008, "the nose tip stands in front of the eye line"
    assert front(1.60, 1.64) < -0.09, "the beard fills out the chin"
