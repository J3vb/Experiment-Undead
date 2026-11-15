"""Zombie geometry, glow and character skinning survive source and committed glTF builds."""

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
import zombie_checks
from zombie_model import build_bloater, build_crawler, build_shambler

BUILDERS = {"shambler": build_shambler, "crawler": build_crawler, "bloater": build_bloater}


@pytest.fixture(
    params=((kind, version) for kind in BUILDERS for version in ("source", "committed")),
    ids="-".join,
)
def zombie(request):
    kind, version = request.param
    bpy.ops.wm.read_factory_settings(use_empty=True)
    if version == "source":
        BUILDERS[kind]()
    else:
        check_models.load_glb(os.path.join(check_models.REPO, f"assets/models/zombies/{kind}.glb"))
    bpy.context.view_layer.update()
    return kind, {obj.name: obj for obj in bpy.context.scene.objects}


def meshes(nodes):
    return [obj for obj in nodes.values() if obj.type == "MESH"]


def weights(obj, vertex):
    return {obj.vertex_groups[item.group].name: item.weight for item in vertex.groups if item.weight > 0.0}


def test_triangle_ranges_and_shared_character_bones(zombie):
    kind, nodes = zombie
    count = sum(len(face.vertices) - 2 for obj in meshes(nodes) for face in obj.data.polygons)
    low, high = zombie_checks.TRIANGLES[kind]
    assert low <= count <= high, (kind, count)
    armatures = [obj for obj in nodes.values() if obj.type == "ARMATURE"]
    assert len(armatures) == 1
    armature = armatures[0]
    assert len(armature.data.bones) == 22
    assert set(armature.data.bones.keys()) == character_rig.BONES.keys()
    for name, (parent, _head, _tail) in character_rig.BONES.items():
        bone = armature.data.bones[name]
        assert (bone.parent.name if bone.parent else None) == parent


def test_all_meshes_have_finite_normalized_character_weights(zombie):
    _kind, nodes = zombie
    armature = next(obj for obj in nodes.values() if obj.type == "ARMATURE")
    for obj in meshes(nodes):
        modifiers = [modifier for modifier in obj.modifiers if modifier.type == "ARMATURE"]
        assert len(modifiers) == 1, obj.name
        assert modifiers[0].object == armature
        for vertex in obj.data.vertices:
            assert all(math.isfinite(item.weight) and 0.0 <= item.weight <= 1.0 for item in vertex.groups)
            influences = weights(obj, vertex)
            assert 1 <= len(influences) <= 4, (obj.name, vertex.index)
            assert sum(influences.values()) == pytest.approx(1.0, abs=0.01)
            assert influences.keys() <= character_rig.BONES.keys()
            assert not any(name.startswith("sock_") for name in influences)


def test_body_is_one_closed_connected_smooth_surface(zombie):
    _kind, nodes = zombie
    body = nodes["Body"]
    assert body.type == "MESH"
    area = sum(face.area for face in body.data.polygons)
    smooth_area = sum(face.area for face in body.data.polygons if face.use_smooth)
    # glTF import can mark coplanar triangles flat when their normals coincide.
    assert smooth_area / area >= 0.99
    assert not any(modifier.type in {"SKIN", "SUBSURF"} for modifier in body.modifiers)
    bm = bmesh.new()
    bm.from_mesh(body.data)
    bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=1e-6)
    assert all(edge.is_manifold for edge in bm.edges), "smooth body must not have open joint seams"
    reached, pending = set(), [next(iter(bm.verts))]
    while pending:
        vertex = pending.pop()
        if vertex in reached:
            continue
        reached.add(vertex)
        pending.extend(edge.other_vert(vertex) for edge in vertex.link_edges)
    assert len(reached) == len(bm.verts), "body must remain connected through neck, arms and hips"
    bm.free()


def test_crawler_keeps_bones_but_has_no_mesh_on_leg_bones(zombie):
    kind, nodes = zombie
    if kind != "crawler":
        return
    for obj in meshes(nodes):
        weighted = {name for vertex in obj.data.vertices for name in weights(obj, vertex)}
        assert not any(name.startswith(("thigh_", "shin_", "foot_")) for name in weighted), obj.name


def test_bloater_has_a_separate_glowing_belly_rigid_on_spine_one(zombie):
    kind, nodes = zombie
    if kind != "bloater":
        assert "Belly" not in nodes
        return
    belly = nodes["Belly"]
    assert belly.type == "MESH" and belly != nodes["Body"]
    assert all(weights(belly, vertex) == {"spine_01": 1.0} for vertex in belly.data.vertices)
    assert all(mat.name.startswith("ZombieGlow") for mat in belly.data.materials)


def test_zombie_finishes_use_only_main_zones_and_glow_only_on_experiment_parts(zombie):
    kind, nodes = zombie
    allowed_glow = {"EyeL", "EyeR", "Belly"} if kind == "bloater" else {"EyeL", "EyeR"}
    glowing = set()
    for obj in meshes(nodes):
        shares = gear_paint.zone_shares(obj)
        assert shares[gear_paint.ZONE_MAIN] == pytest.approx(1.0)
        assert all(mat.name.startswith(zombie_checks.FINISHES) for mat in obj.data.materials)
        for mat in obj.data.materials:
            if mat.name.startswith("ZombieGlow"):
                glowing.add(obj.name)
                shader = next(node for node in mat.node_tree.nodes if node.type == "BSDF_PRINCIPLED")
                assert shader.inputs["Emission Strength"].default_value > 0.0
                color = shader.inputs["Emission Color"].default_value
                assert color[1] > color[0] > color[2], "bio-green is the only zombie glow colour"
    assert glowing == allowed_glow


def test_head_is_the_lightest_nonemissive_material(zombie):
    _kind, nodes = zombie
    materials = {mat for obj in meshes(nodes) for mat in obj.data.materials}
    heads = [mat for mat in materials if mat.name.startswith("ZombieSkinHead")]
    assert heads
    head_value = min(zombie_checks._value(mat) for mat in heads)
    for material in materials:
        if not material.name.startswith(("ZombieSkinHead", "ZombieGlow")):
            assert head_value > zombie_checks._value(material), material.name


def test_small_eyes_and_midpoint_marker_follow_the_head(zombie):
    _kind, nodes = zombie
    armature = next(obj for obj in nodes.values() if obj.type == "ARMATURE")
    eyes = nodes["Eyes"]
    assert eyes.type == "EMPTY"
    assert eyes.parent == armature and eyes.parent_type == "BONE" and eyes.parent_bone == "head"
    points = []
    for name in ("EyeL", "EyeR"):
        eye = nodes[name]
        low, high = check_models.bounds([eye])
        assert max(high - low) < 0.08, "glowing eyes must remain small targets"
        points.append((low + high) / 2)
        assert all(weights(eye, vertex) == {"head": 1.0} for vertex in eye.data.vertices)
    midpoint = (points[0] + points[1]) / 2
    assert (eyes.matrix_world.translation - midpoint).length < 0.015
    head = armature.matrix_world @ armature.data.bones["head"].head_local
    assert eyes.matrix_world.translation.y < head.y
    before = eyes.matrix_world.translation.copy()
    armature.pose.bones["head"].rotation_mode = "XYZ"
    armature.pose.bones["head"].rotation_euler.z = 0.45
    bpy.context.view_layer.update()
    assert (eyes.matrix_world.translation - before).length > 0.01


def test_character_and_zombie_contract_checks_pass(zombie):
    kind, nodes = zombie
    assert zombie_checks.check(list(nodes.values()), kind) == []
