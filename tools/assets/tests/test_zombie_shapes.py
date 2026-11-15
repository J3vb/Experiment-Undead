"""Cloth thickness, open cuffs and fixed zombie rig contracts survive shape upgrades."""

import hashlib
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import bpy

# isort: split
# bpy must load before bmesh.
import bmesh
import body_parts
import check_models
import pytest
import zombie_details
from mathutils import Vector
from zombie_model import build_bloater, build_crawler, build_shambler

BUILDERS = {"shambler": build_shambler, "crawler": build_crawler, "bloater": build_bloater}
# Captured before the review from 109bb6d, quantized to 1 mm / 0.001 basis units
# to tolerate glTF floating-point round trips while detecting moved joint frames.
REST_DIGESTS = {
    "shambler": "7cc3d394eb7248a75751407711bba29a38d2770459efcd5e8fa9fd3d83e325d6",
    "crawler": "28ec7421d3aee53cf2c604d2df857add957a6ed9e57fd0300f8e7e3ad18885d8",
    "bloater": "e0e844dab39065a2c93a59f8b813a6027ea1fe1694540e162b1c596c68373e70",
}
MARKERS = {
    "shambler": {"Eyes": (0, -0.17117195, 1.68908620), "HeadCenter": (0, -0.09114612, 1.69365335)},
    "crawler": {"Eyes": (0, -0.36946622, 0.52777958), "HeadCenter": (0, -0.28946623, 0.52277958)},
    "bloater": {"Eyes": (0, -0.12070337, 1.70068741), "HeadCenter": (0, -0.04056747, 1.69888878)},
}


@pytest.fixture
def material():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    return bpy.data.materials.new("FabricTest")


def assert_closed_outward(obj):
    bm = bmesh.new()
    try:
        bm.from_mesh(obj.data)
        assert all(edge.is_manifold and edge.is_contiguous for edge in bm.edges)
        assert all(face.calc_area() > 1e-9 for face in bm.faces)
        assert bm.calc_volume(signed=True) > 0.0
    finally:
        bm.free()


@pytest.mark.parametrize("sign", [-1, 1], ids=["left", "right"])
@pytest.mark.parametrize("sides", [8, 10, 12])
def test_torn_sleeves_are_closed_outward_shells_on_mirrored_curved_arms(material, sign, sides):
    points = [(sign * x, y, z) for x, y, z in [(0.16, 0, 1.49), (0.22, -0.02, 1.46), (0.29, -0.06, 1.39)]]
    sleeve = body_parts.torn_sleeve("Sleeve", points, [0.058, 0.085, 0.060], material, sides)
    assert_closed_outward(sleeve)


@pytest.mark.parametrize("direction", [(1, 0, -1), (-1, 0, -1), (0.7, -0.55, -0.4), (0, 1, 0), (0, 0, 1)])
def test_sleeve_has_open_ends_and_four_millimetres_of_fabric(material, direction):
    axis = Vector(direction).normalized()
    points = [axis * distance for distance in (0.0, 0.13, 0.26)]
    sleeve = body_parts.torn_sleeve("Sleeve", points, [0.08] * 3, material)
    assert_closed_outward(sleeve)
    # Look through the bore, then probe both fabric surfaces halfway down the arm.
    assert not sleeve.ray_cast(-axis * 0.1, axis, distance=0.5)[0]
    radial = axis.cross(Vector((0.3, 0.7, 0.2))).normalized()
    center = axis * 0.13
    inside, inner_point, inner_normal, _ = sleeve.ray_cast(center, radial)
    outside, outer_point, outer_normal, _ = sleeve.ray_cast(center + radial * 0.2, -radial)
    assert inside and outside
    assert inner_normal.dot(radial) < -0.9
    assert outer_normal.dot(radial) > 0.9
    assert 0.0034 < (outer_point - inner_point).length < 0.0042


def test_cuff_tears_change_the_outline_asymmetrically(material):
    sleeve = body_parts.torn_sleeve("Sleeve", [(0, 0, 0), (0, 0, 0.13), (0, 0, 0.26)], [0.08] * 3, material)
    cuff = [vertex.co for vertex in sleeve.data.vertices if vertex.co.z > 0.23 and vertex.co.xy.length > 0.078]
    assert max(point.z for point in cuff) - min(point.z for point in cuff) > 0.012
    differences = []
    for point in cuff:
        opposite = min(cuff, key=lambda candidate: (candidate.xy + point.xy).length)
        differences.append(abs(point.z - opposite.z))
    assert max(differences) > 0.012, "opposite cuff edges must have different tears, not a regular scallop"


@pytest.mark.parametrize("resolution,triangles", [((8, 6), 80), ((12, 8), 168), ((24, 16), 720)])
def test_ellipsoid_resolution_preserves_requested_bounds(material, resolution, triangles):
    center, radius = Vector((0.3, -0.1, 1.5)), Vector((0.08, 0.10, 0.20))
    obj = body_parts.ellipsoid("Detail", center, radius, material, resolution)
    bpy.context.view_layer.update()
    low, high = check_models.bounds([obj])
    assert tuple(low) == pytest.approx(tuple(center - radius), abs=1e-6)
    assert tuple(high) == pytest.approx(tuple(center + radius), abs=1e-6)
    assert sum(len(face.vertices) - 2 for face in obj.data.polygons) == triangles
    assert_closed_outward(obj)


def test_carved_mouth_is_a_recessed_closed_cavity_with_decay_inside(material):
    head = body_parts.ellipsoid("HeadTest", (0, 0, 1.68), (0.095, 0.10, 0.12), material, (24, 16))
    body_parts.select(head)
    bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)
    decay = bpy.data.materials.new("DecayTest")
    for _slot in range(3):
        head.data.materials.append(material)
    head.data.materials.append(decay)
    direction = Vector((0, 1, 0))
    center = Vector((0.003, -0.3, 1.655))
    hit, original, _normal, _index = head.ray_cast(center, direction)
    assert hit and original.y < -0.08
    zombie_details.carve_mouth(head, {"decay": decay})
    hit, recessed, _normal, face_index = head.ray_cast(center, direction)
    assert hit and recessed.y > -0.06, "the mouth must remove volume, not add a lip-shaped bump"
    assert head.data.polygons[face_index].material_index == 4
    hit, lip, _normal, _index = head.ray_cast(Vector((0.003, -0.3, 1.685)), direction)
    assert hit and lip.y < -0.08, "carving must leave the surrounding face intact"
    assert_closed_outward(head)
    assert not any(obj.name.startswith("MouthCutter") for obj in bpy.context.scene.objects)


@pytest.mark.parametrize("kind", BUILDERS)
@pytest.mark.parametrize("version", ["source", "committed"])
def test_joint_rest_frames_and_head_hit_markers_match_the_review_baseline(kind, version):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    if version == "source":
        BUILDERS[kind]()
    else:
        check_models.load_glb(os.path.join(check_models.REPO, f"assets/models/zombies/{kind}.glb"))
    bpy.context.view_layer.update()
    skeleton = next(obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE")
    frames = {
        bone.name: [[round(value * 1000) for value in row] for row in bone.matrix_local] for bone in skeleton.data.bones
    }
    digest = hashlib.sha256(json.dumps(frames, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
    assert digest == REST_DIGESTS[kind], "joint frames changed; preserve runtime animation and socket pivots"
    for name, location in MARKERS[kind].items():
        marker = bpy.data.objects[name]
        assert marker.parent == skeleton and marker.parent_type == "BONE" and marker.parent_bone == "head"
        assert tuple(marker.matrix_world.translation) == pytest.approx(location, abs=2e-6)
