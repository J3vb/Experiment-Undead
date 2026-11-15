"""Worn vest surfaces must clear the unchanged body in rest and the booth's bent pose."""

import math
import os
import sys
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import bpy
import pytest
from mathutils import Quaternion, Vector
from mathutils.bvhtree import BVHTree
from vest_model import build_vest_heavy, build_vest_light, build_vest_medium

ROOT = Path(__file__).resolve().parents[3]
BUILDERS = {"light": build_vest_light, "medium": build_vest_medium, "heavy": build_vest_heavy}
BEND = {"spine_01": 12, "spine_02": 12, "spine_03": 8, "neck": -12, "forearm_L": 35, "forearm_R": 35}
RAYS = tuple(Vector(axis).normalized() for axis in ((1, 0.371, 0.217), (-0.253, 1, 0.419), (0.173, -0.289, 1)))


@pytest.fixture(params=((frame, version) for frame in BUILDERS for version in ("source", "committed")), ids="-".join)
def worn_vest(request):
    frame, version = request.param
    bpy.ops.wm.read_factory_settings(use_empty=True)
    if version == "source":
        BUILDERS[frame]()
    else:
        bpy.ops.import_scene.gltf(filepath=str(ROOT / f"assets/models/gear/vest_{frame}.glb"), disable_bone_shape=True)
    shell = bpy.data.objects["Shell"]
    vest_objects = set(bpy.context.scene.objects)
    bpy.ops.import_scene.gltf(filepath=str(ROOT / "assets/models/characters/player.glb"), disable_bone_shape=True)
    body = [obj for obj in bpy.context.scene.objects if obj not in vest_objects and obj.type == "MESH"]
    armatures = [obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE"]
    bpy.context.view_layer.update()
    return frame, version, shell, body, armatures


def pose(armatures, bent):
    for armature in armatures:
        for name, degrees in BEND.items():
            bone = armature.pose.bones[name]
            axis = bone.bone.matrix_local.to_3x3().inverted() @ Vector((1, 0, 0))
            bone.rotation_mode = "QUATERNION"
            bone.rotation_quaternion = Quaternion(axis, math.radians(degrees) if bent else 0.0)
    bpy.context.view_layer.update()


def surface(obj):
    evaluated = obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
    mesh = evaluated.data
    mesh.calc_loop_triangles()
    points = [evaluated.matrix_world @ vertex.co for vertex in mesh.vertices]
    faces = [tuple(triangle.vertices) for triangle in mesh.loop_triangles]
    return points, faces, BVHTree.FromPolygons(points, faces, all_triangles=True)


def inside(tree, point):
    """Majority parity avoids treating concave folds or disconnected details as inside."""
    votes = 0
    for direction in RAYS:
        origin, count = point.copy(), 0
        while True:
            hit, _normal, _face, _distance = tree.ray_cast(origin, direction)
            if hit is None:
                break
            count += 1
            origin = hit + direction * 1e-6
        votes += count % 2
    return votes >= 2


@pytest.mark.parametrize("bent", (False, True), ids=("rest", "bent"))
def test_shell_faces_and_vertices_clear_body(worn_vest, bent):
    frame, version, shell, body, armatures = worn_vest
    pose(armatures, bent)
    points, faces, shell_tree = surface(shell)
    for obj in body:
        _body_points, _body_faces, body_tree = surface(obj)
        overlaps = shell_tree.overlap(body_tree)
        if overlaps:
            triangle = overlaps[0][0]
            centre = sum((points[index] for index in faces[triangle]), Vector()) / 3
            pytest.fail(f"{frame}/{version} {obj.name}: {len(overlaps)} intersecting pairs near {tuple(centre)}")
        for index, point in enumerate(points):
            nearest, normal, _face, distance = body_tree.find_nearest(point)
            if distance > 1e-6 and (point - nearest).dot(normal) < 0 and inside(body_tree, point):
                pytest.fail(f"{frame}/{version} vertex {index} is inside {obj.name} at {tuple(point)}")
