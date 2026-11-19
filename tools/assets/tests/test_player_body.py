"""The survivor body keeps the shared contract (bones, scale, budget, materials) from source to baked glTF."""

import json
import math
import os
import struct
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import bpy

# isort: split
import character_checks
import character_rig
import check_models
import numpy as np
import pytest
from mathutils import Vector
from player_body import surface
from player_body.build import build_player

GLB = os.path.join(check_models.REPO, "assets/models/characters/player.glb")
MATERIALS = {"BodySkin", "BodyHair", "BodyCloth", "BodyRubber"}


@pytest.fixture(scope="module", params=("source", "committed"))
def player(request):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    if request.param == "source":
        build_player()
    else:
        check_models.load_glb(GLB)
    bpy.context.view_layer.update()
    return list(bpy.context.scene.objects)


def meshes(objects):
    return [obj for obj in objects if obj.type == "MESH"]


def weights(obj, vertex):
    return {obj.vertex_groups[group.group].name: group.weight for group in vertex.groups if group.weight > 0.0}


def test_player_passes_the_character_rules(player):
    assert character_checks.check(player, "characters", "player") == []
    assert check_models.check_geometry(player, "characters") == []


def test_player_scale_budget_and_materials(player):
    parts = meshes(player)
    low, high = check_models.bounds(parts)
    assert 1.75 <= high.z - low.z <= 1.85
    assert low.z == pytest.approx(0.0, abs=0.01)
    triangles = sum(len(face.vertices) - 2 for obj in parts for face in obj.data.polygons)
    assert 8_000 <= triangles <= 16_000
    assert {mat.name for obj in parts for mat in obj.data.materials} == MATERIALS


def test_player_has_the_shared_bones_and_valid_skin_weights(player):
    armatures = [obj for obj in player if obj.type == "ARMATURE"]
    assert len(armatures) == 1
    armature = armatures[0]
    assert set(armature.data.bones.keys()) == character_rig.BONES.keys()
    for name, (parent, _head, _tail) in character_rig.BONES.items():
        bone = armature.data.bones[name]
        assert (bone.parent.name if bone.parent else None) == parent
    for obj in meshes(player):
        for vertex in obj.data.vertices:
            influences = weights(obj, vertex)
            assert 1 <= len(influences) <= 4, (obj.name, vertex.index)
            assert all(math.isfinite(weight) and 0 < weight <= 1 for weight in influences.values())
            assert sum(influences.values()) == pytest.approx(1.0, abs=0.01)
            assert influences.keys() <= character_rig.BONES.keys()


def test_eyes_follow_the_head_and_face_forward(player):
    armature = next(obj for obj in player if obj.type == "ARMATURE")
    eyes = next(obj for obj in player if obj.name == "Eyes")
    assert eyes.type == "EMPTY"
    assert (eyes.parent, eyes.parent_type, eyes.parent_bone) == (armature, "BONE", "head")
    head = armature.matrix_world @ armature.data.bones["head"].head_local
    position = eyes.matrix_world.translation
    assert position.y < head.y - 0.04, "Blender -Y becomes Godot +Z"
    assert 1.65 <= position.z <= 1.77
    assert abs(position.x) < 0.015


def test_sleeve_follows_an_arm_pose(player):
    armature = next(obj for obj in player if obj.type == "ARMATURE")
    body = next(obj for obj in meshes(player) if obj.name == "Body")
    candidates = [vertex for vertex in body.data.vertices if weights(body, vertex).get("forearm_L", 0.0) > 0.9]
    assert candidates, "the sleeve must be weighted to the forearm"
    vertex = max(candidates, key=lambda item: item.co.x)
    before = body.matrix_world @ vertex.co
    pose = armature.pose.bones["forearm_L"]
    pose.rotation_mode = "XYZ"
    pose.rotation_euler.x = 0.4
    bpy.context.view_layer.update()
    evaluated = body.evaluated_get(bpy.context.evaluated_depsgraph_get())
    after = evaluated.matrix_world @ evaluated.data.vertices[vertex.index].co
    pose.rotation_euler.x = 0.0
    bpy.context.view_layer.update()
    assert (after - before).length > 0.01
    assert all(math.isfinite(component) for component in Vector(after))


def test_committed_glb_carries_one_set_of_baked_maps():
    with open(GLB, "rb") as glb:
        glb.seek(12)
        length, _kind = struct.unpack("<II", glb.read(8))
        document = json.loads(glb.read(length))
    assert {material["name"] for material in document["materials"]} == MATERIALS
    assert len(document["images"]) == 3, "colour, normal and roughness maps, shared by the four materials"
    assert all(image["mimeType"] == "image/jpeg" for image in document["images"])
    for material in document["materials"]:
        assert "baseColorTexture" in material["pbrMetallicRoughness"], material["name"]
        assert "normalTexture" in material, material["name"]


def test_spline_passes_through_its_keys():
    values = surface.spline([0.0, 1.0, 3.0], [[0.0], [2.0], [1.0]], np.asarray([0.0, 1.0, 3.0]))
    assert values[:, 0] == pytest.approx([0.0, 2.0, 1.0])


def test_tube_front_and_side_follow_the_angle():
    tube = surface.Tube((0, 0, 0), (0, 0, 1), (1, 0, 0), [(0, 0, 0, 0.2, 0.1, 0.3, 2.0), (1, 0, 0, 0.2, 0.1, 0.3, 2.0)])
    front, side, back = tube.surface(np.asarray([0.0, 0.25, 0.5]), np.full(3, 0.5))
    assert front == pytest.approx([0, -0.1, 0.5], abs=1e-6)
    assert side == pytest.approx([0.2, 0, 0.5], abs=1e-6)
    assert back == pytest.approx([0, 0.3, 0.5], abs=1e-6)


# Taken from the player build before player_body learned to take a look (F-76 step 1): the default
# look must build the same body, so the NPC refactor cannot change the player by accident.
PLAYER_BUILD = {
    "triangles": 14_998,
    "vertices": 8_341,
    "coordinate_sum": (-6.4591, -201.9211, 9202.2354),
    "looks": {
        0: 2034,
        1: 52,
        2: 1172,
        3: 1552,
        4: 522,
        5: 308,
        6: 626,
        7: 216,
        8: 280,
        9: 540,
        10: 744,
        11: 110,
        12: 112,
        13: 21,
    },
    "head_weight": 2629.96,
    "pelvis_weight": 617.7,
}


def test_default_look_builds_the_same_player_as_before_the_npc_refactor():
    from collections import Counter

    bpy.ops.wm.read_factory_settings(use_empty=True)
    build_player(clips=False)
    body = bpy.data.objects["Body"]
    points = np.asarray([vertex.co[:] for vertex in body.data.vertices])
    assert sum(len(face.vertices) - 2 for face in body.data.polygons) == PLAYER_BUILD["triangles"]
    assert len(points) == PLAYER_BUILD["vertices"]
    assert points.sum(axis=0) == pytest.approx(PLAYER_BUILD["coordinate_sum"], abs=1e-2)
    looks = Counter(item.value for item in body.data.attributes["look"].data)
    assert {look: looks[look] for look in PLAYER_BUILD["looks"]} == PLAYER_BUILD["looks"]
    totals = Counter()
    for vertex in body.data.vertices:
        for group in vertex.groups:
            totals[body.vertex_groups[group.group].name] += group.weight
    assert totals["head"] == pytest.approx(PLAYER_BUILD["head_weight"], abs=0.05)
    assert totals["pelvis"] == pytest.approx(PLAYER_BUILD["pelvis_weight"], abs=0.05)
