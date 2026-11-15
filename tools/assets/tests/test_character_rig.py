"""In-memory checks for the shared rest skeleton and deterministic skinning."""

import math
import os
import sys

import bpy
import pytest
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import character_rig as rig


@pytest.fixture(autouse=True)
def empty_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def arm_capsule():
    """Small closed capsule with rings along both left arm bones."""
    start = Vector(rig.BONES["upperarm_L"][1])
    end = Vector(rig.BONES["forearm_L"][2])
    direction = (end - start).normalized()
    across = direction.cross(Vector((0.0, 1.0, 0.0)))
    radius, sides = 0.02, 8
    length = (end - start).length
    profile = [(-radius * 0.7, radius * 0.7)]
    profile += [(length * step / 30, radius) for step in range(31)]
    profile += [(length + radius * 0.7, radius * 0.7)]
    points = [start - radius * direction]
    for distance, width in profile:
        for side in range(sides):
            angle = 2 * math.pi * side / sides
            offset = across * math.cos(angle) + Vector((0.0, 1.0, 0.0)) * math.sin(angle)
            points.append(start + direction * distance + width * offset)
    points.append(end + radius * direction)
    faces = [(0, 1 + side, 1 + (side + 1) % sides) for side in range(sides)]
    for ring in range(len(profile) - 1):
        for side in range(sides):
            a, b = 1 + ring * sides + side, 1 + ring * sides + (side + 1) % sides
            faces.append((a, a + sides, b + sides, b))
    last = 1 + (len(profile) - 1) * sides
    faces += [(len(points) - 1, last + (side + 1) % sides, last + side) for side in range(sides)]
    mesh = bpy.data.meshes.new("Capsule")
    mesh.from_pydata(points, [], faces)
    obj = bpy.data.objects.new("Capsule", mesh)
    bpy.context.collection.objects.link(obj)
    return obj


def vertex_weights(obj, vertex):
    return {obj.vertex_groups[group.group].name: group.weight for group in vertex.groups if group.weight > 0.0}


def test_exact_bones_and_parents():
    armature = rig.build_armature()
    expected = {
        "pelvis": None,
        "spine_01": "pelvis",
        "spine_02": "spine_01",
        "spine_03": "spine_02",
        "neck": "spine_03",
        "head": "neck",
        "sock_thigh_R": "thigh_R",
        "sock_back": "spine_03",
    }
    for side in ("L", "R"):
        expected.update(
            {
                f"clavicle_{side}": "spine_03",
                f"upperarm_{side}": f"clavicle_{side}",
                f"forearm_{side}": f"upperarm_{side}",
                f"hand_{side}": f"forearm_{side}",
                f"thigh_{side}": "pelvis",
                f"shin_{side}": f"thigh_{side}",
                f"foot_{side}": f"shin_{side}",
            }
        )
    assert len(armature.data.bones) == 22
    assert set(armature.data.bones.keys()) == expected.keys()
    for name, (parent, head, tail) in rig.BONES.items():
        bone = armature.data.bones[name]
        assert (bone.parent.name if bone.parent else None) == parent == expected[name]
        assert tuple(bone.head_local) == pytest.approx(head)
        assert tuple(bone.tail_local) == pytest.approx(tail)
        assert bone.use_deform == (not name.startswith("sock_"))
    assert rig.BONES["sock_thigh_R"][0] == "thigh_R"
    assert rig.BONES["sock_back"][0] == "spine_03"
    assert rig.BONES["head"][2][2] == 1.8
    for side in ("L", "R"):
        upperarm = armature.data.bones[f"upperarm_{side}"]
        direction = upperarm.tail_local - upperarm.head_local
        assert abs(direction.x) == pytest.approx(-direction.z)
        assert armature.data.bones[f"foot_{side}"].tail_local.z == pytest.approx(0.0)


def test_capsule_weights_are_normalized_and_blend_at_elbow():
    armature = rig.build_armature()
    obj = arm_capsule()
    rig.bind(obj, armature)
    elbow = armature.data.bones["forearm_L"].head_local
    near_elbow = []
    for vertex in obj.data.vertices:
        weights = vertex_weights(obj, vertex)
        assert sum(weights.values()) == pytest.approx(1.0, abs=1e-6)
        assert 1 <= len(weights) <= 4
        assert not any(name.startswith("sock_") for name in weights)
        if (vertex.co - elbow).length < 0.04:
            near_elbow.append(weights)
    assert near_elbow
    assert all({"upperarm_L", "forearm_L"} <= weights.keys() for weights in near_elbow)
    assert len(obj.modifiers) == 1
    assert obj.modifiers[0].type == "ARMATURE"
    assert obj.modifiers[0].object == armature


def test_binding_uses_world_coordinates_without_moving_mesh():
    armature = rig.build_armature()
    obj = arm_capsule()
    rig.bind(obj, armature)
    expected = [vertex_weights(obj, vertex) for vertex in obj.data.vertices]
    world = Matrix.Translation((2.0, -3.0, 0.4)) @ Matrix.Rotation(0.7, 4, "Z")
    armature.matrix_world = world
    obj.matrix_world = world
    bpy.context.view_layer.update()
    local_change = Matrix.Translation((0.2, 0.1, -0.3)) @ Matrix.Diagonal((0.8, 1.3, 0.7, 1.0))
    obj.data.transform(local_change)
    obj.matrix_world = world @ local_change.inverted()
    before = obj.matrix_world.copy()
    rig.bind(obj, armature)
    for vertex, weights in zip(obj.data.vertices, expected, strict=True):
        assert vertex_weights(obj, vertex) == pytest.approx(weights, abs=1e-5)
    assert obj.matrix_world == before
    assert len(obj.modifiers) == 1


def test_no_blend_assigns_only_the_nearest_segment():
    armature = rig.build_armature()
    obj = arm_capsule()
    rig.bind(obj, armature, blend=0.0)
    for vertex in obj.data.vertices:
        weights = vertex_weights(obj, vertex)
        assert len(weights) == 1
        assert next(iter(weights.values())) == pytest.approx(1.0)


def test_rigid_binding_replaces_weights_and_rejects_sockets():
    armature = rig.build_armature()
    obj = arm_capsule()
    rig.bind(obj, armature)
    rig.bind_rigid(obj, armature, "forearm_L")
    for vertex in obj.data.vertices:
        assert vertex_weights(obj, vertex) == {"forearm_L": 1.0}
    assert len(obj.modifiers) == 1
    for bone in ("sock_back", "missing"):
        with pytest.raises(ValueError, match="not a deforming bone"):
            rig.bind_rigid(obj, armature, bone)
