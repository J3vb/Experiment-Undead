"""Carrier layers share smooth weights, shoulder anchors and the fitted collar."""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import bpy
import character_rig
import pytest
import vest_binding


def weights(obj, vertex):
    return {obj.vertex_groups[item.group].name: item.weight for item in vertex.groups if item.weight > 0}


def sample(points):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    armature = character_rig.build_armature()
    data = bpy.data.meshes.new("CarrierSamples")
    data.from_pydata(points, [], [])
    obj = bpy.data.objects.new("CarrierSamples", data)
    bpy.context.collection.objects.link(obj)
    return obj, armature


def test_inner_fabric_and_outer_hardware_keep_matching_weights_across_joint():
    points = [(0.10, depth, height) for height in (1.1999, 1.2001) for depth in (-0.10, -0.16, -0.23)]
    obj, armature = sample(points)
    vest_binding.bind_torso(obj, armature)
    values = [weights(obj, vertex) for vertex in obj.data.vertices]
    assert values[0] == values[1] == values[2]
    assert values[3] == values[4] == values[5]
    for name in values[0]:
        assert abs(values[0][name] - values[3][name]) < 0.01, "no rigid step across a spine joint"
    assert all(sum(value.values()) == pytest.approx(1) and len(value) == 2 for value in values)


def test_other_upper_panels_and_collar_retain_the_existing_fitted_weights():
    obj, armature = sample([(0.135, -0.065, 1.54), (-0.135, 0.045, 1.54), (0, 0.11, 1.63)])
    character_rig.bind(obj, armature, blend=0.16)
    original = [weights(obj, vertex) for vertex in obj.data.vertices]
    vest_binding.bind_torso(obj, armature)
    assert [weights(obj, vertex) for vertex in obj.data.vertices] == original
    assert any("clavicle_L" in value or "clavicle_R" in value for value in original)


def test_binding_is_idempotent_and_uses_one_armature_modifier():
    obj, armature = sample([(0, -0.14, height) for height in (1.115, 1.225, 1.365, 1.47)])
    vest_binding.bind_torso(obj, armature)
    original = [weights(obj, vertex) for vertex in obj.data.vertices]
    vest_binding.bind_torso(obj, armature)
    assert [weights(obj, vertex) for vertex in obj.data.vertices] == original
    assert [modifier.type for modifier in obj.modifiers] == ["ARMATURE"]
    assert obj.find_armature() == armature
    assert all(sum(value.values()) == pytest.approx(1) for value in original)


def test_upper_shoulder_webbing_follows_its_clavicle_but_lower_straps_bend():
    obj, armature = sample([(0.135, 0, 1.544), (-0.135, 0, 1.544), (0.135, -0.14, 1.424)])
    obj.name = "ShoulderWebbing"
    vest_binding.bind_torso(obj, armature)
    values = [weights(obj, vertex) for vertex in obj.data.vertices]
    assert values[0] == {"clavicle_L": 1.0}
    assert values[1] == {"clavicle_R": 1.0}
    assert values[2] == {"spine_03": 1.0}
