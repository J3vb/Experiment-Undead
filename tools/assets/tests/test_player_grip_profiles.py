"""Every generated weapon grip keeps connected anatomy, cap markers and shared topology."""

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import bpy

# isort: split
import bmesh
import build_models
import character_rig
import finish
import player_arms_model as arms
import player_body_model as body
import player_grip_profiles as profiles
import pytest
from mathutils import Vector
from mathutils.geometry import closest_point_on_tri
from test_player_arm_morphs import accessor, glb


@pytest.mark.parametrize("profile", profiles.PROFILES)
@pytest.mark.parametrize(("side", "sign", "limits"), [("R", -1, (0.025, 0.040)), ("L", 1, (0.040, 0.050))])
def test_profile_curls_keep_attached_roots_closed_surfaces_and_real_tip_markers(profile, side, sign, limits):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    mats = arms._materials()
    skeleton = character_rig.build_armature()
    body._gloves(skeleton, mats)
    parts, metadata = arms._fingers(skeleton, mats, side, sign, profile, markers=False)
    bpy.context.view_layer.update()
    palm = bpy.data.objects["GlovePalm" + side]
    assert limits[0] <= (Vector(metadata["index"]) - Vector(metadata["thumb"])).length <= limits[1]
    for obj in parts:
        mesh = bmesh.new()
        mesh.from_mesh(obj.data)
        assert all(edge.is_manifold for edge in mesh.edges), (profile, obj.name)
        assert all(face.calc_area() > 1e-10 for face in mesh.faces), (profile, obj.name)
        assert mesh.calc_volume(signed=True) > 0, (profile, obj.name)
        mesh.free()
        if obj.name.startswith("FingerPad"):
            continue
        roots = []
        for vertex in list(obj.data.vertices)[:12]:
            point = palm.matrix_world.inverted() @ (obj.matrix_world @ vertex.co)
            hit, nearest, normal, _face = palm.closest_point_on_mesh(point)
            assert hit
            roots.append((point - nearest).dot(normal))
        assert min(roots) < -0.001, (profile, obj.name, "a morph must not detach a finger root")
    for obj, marker in ((parts[0], "index"), (parts[-1], "thumb")):
        centre = sum((obj.matrix_world @ vertex.co for vertex in list(obj.data.vertices)[-12:]), Vector()) / 12
        assert (centre - Vector(metadata[marker])).length < 1e-6


def test_finished_arm_export_has_all_zero_default_morphs_and_matching_metadata(tmp_path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    arms.build_player_arms()
    finish.finish()
    path = tmp_path / "player_arms.glb"
    build_models.export(str(path))
    document, binary = glb(path)
    metadata = json.loads(path.with_name("player_arm_grips.json").read_text())
    assert metadata["version"] == 1 and set(metadata["profiles"]) == set(profiles.PROFILES)
    mesh = document["meshes"][0]
    expected = ["grip_" + profile for profile in profiles.PROFILES if profile != "rifle_ar"]
    assert mesh["extras"]["targetNames"] == expected
    assert mesh["weights"] == [0.0] * len(expected)
    assert len(document["skins"][0]["joints"]) == 22
    assert {material["name"] for material in document["materials"]} == {"BodySuit", "BodyRubber", "BodyKnit"}
    for primitive in mesh["primitives"]:
        assert len(primitive["targets"]) == len(expected)
        base = primitive["attributes"]
        count = document["accessors"][base["POSITION"]]["count"]
        for target in primitive["targets"]:
            assert {"POSITION", "NORMAL"} <= target.keys()
            assert all(document["accessors"][target[field]]["count"] == count for field in ("POSITION", "NORMAL"))
        for weights in accessor(document, binary, base["WEIGHTS_0"]):
            assert sum(weights) == pytest.approx(1.0)
    assert_exported_cap_markers(document, binary, metadata)


def assert_exported_cap_markers(document, binary, metadata):
    mesh = document["meshes"][0]
    names = mesh["extras"]["targetNames"]
    rubber = next(
        primitive
        for primitive in mesh["primitives"]
        if document["materials"][primitive["material"]]["name"] == "BodyRubber"
    )
    base = [Vector(point) for point in accessor(document, binary, rubber["attributes"]["POSITION"])]
    indices = [item[0] for item in accessor(document, binary, rubber["indices"])]
    for name, profile in metadata["profiles"].items():
        points = base
        if profile["morph"]:
            target = rubber["targets"][names.index(profile["morph"])]["POSITION"]
            delta = accessor(document, binary, target)
            points = [point + Vector(change) for point, change in zip(base, delta, strict=True)]
        triangles = [
            tuple(points[index] for index in indices[start : start + 3]) for start in range(0, len(indices), 3)
        ]
        for side in ("R", "L"):
            for marker in ("index", "thumb"):
                x, y, z = profile[side][marker]
                tip = Vector((x, z, -y))
                distance = min((closest_point_on_tri(tip, *triangle) - tip).length for triangle in triangles)
                assert distance < 0.001, (name, side, marker, "exported marker must touch its morphed cap", distance)
