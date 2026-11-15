"""Revolver chamber alignment, open machining and preserved animation pivots."""

import math
import sys
from pathlib import Path

import bpy
import pytest

# isort: split
# bpy must load before bmesh.
import bmesh
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import build_models as build
import check_models
import hollis_model as hollis


@pytest.fixture
def materials():
    build.reset_scene()
    return (
        build.material("GunMetal", build.GUN_METAL, metallic=0.8, roughness=0.4),
        build.material("MatteBlack", build.MATTE_BLACK, roughness=0.75),
    )


def assert_closed_outward(obj):
    mesh = bmesh.new()
    mesh.from_mesh(obj.data)
    assert all(edge.is_manifold for edge in mesh.edges)
    bmesh.ops.triangulate(mesh, faces=mesh.faces[:])
    assert all(face.calc_area() >= 1e-10 for face in mesh.faces)
    assert all(volume > 0 for volume in check_models.shell_volumes(mesh))
    mesh.free()
    obj.data.calc_loop_triangles()
    assert all(triangle.area >= 1e-10 for triangle in obj.data.loop_triangles)


def test_six_chambers_are_open_and_the_top_chamber_aligns_with_the_bore(materials):
    cylinder = hollis.cylinder_parts(*materials)[0]
    for index in range(6):
        angle = math.pi / 2 + index * math.pi / 3
        centre = Vector((0.013 * math.cos(angle), 0.1, hollis.CYL_Z + 0.013 * math.sin(angle)))
        assert not cylinder.ray_cast(centre, Vector((0, -1, 0)))[0], f"chamber {index} is open"
    eye = Vector((0, 0.1, hollis.BORE_Z))
    assert not cylinder.ray_cast(eye, Vector((0, -1, 0)))[0], "barrel line passes through the top chamber"
    assert cylinder.ray_cast(Vector((0, 0.1, hollis.CYL_Z)), Vector((0, -1, 0)))[0], "axle retains solid metal"
    assert_closed_outward(cylinder)


def test_crown_and_forcing_cone_are_open_with_a_cylinder_gap(materials):
    cylinder = hollis.cylinder_parts(*materials)[0]
    barrel = hollis.barrel_parts(*materials)[0]
    front = max(vertex.co.y for vertex in cylinder.data.vertices)
    rear = min(vertex.co.y for vertex in barrel.data.vertices)
    assert 0.001 <= rear - front <= 0.004
    assert not barrel.ray_cast(Vector((0, 0.25, hollis.BORE_Z)), Vector((0, -1, 0)))[0]
    assert barrel.ray_cast(Vector((0.007, 0.25, hollis.BORE_Z)), Vector((0, -1, 0)))[0]
    assert_closed_outward(barrel)


def test_frame_and_barrel_leave_the_chamber_line_open_without_moving_animation_pivots(materials):
    hollis.build(build)
    receiver = bpy.data.objects["Receiver"]
    hit, point, _normal, _index = receiver.ray_cast(Vector((0, 0.25, hollis.BORE_Z)), Vector((0, -1, 0)))
    assert hit and point.y < -0.025, "only the recoil shield behind the chamber stops the bore line"
    for name, pivot in {
        "Receiver": (0, 0, 0),
        "Muzzle": (0, 0.204, 0.04),
        "Bolt": (0, -0.05, 0.04),
        "Grip": (0, -0.04, 0),
        "Trigger": (0, -0.004, -0.004),
    }.items():
        assert (bpy.data.objects[name].location - Vector(pivot)).length < 1e-6
    assert "Magazine" not in bpy.data.objects


def test_frame_screws_occupy_both_sides(materials):
    parts = hollis.frame_parts(*materials)
    screws = [part for part in parts if part.name.startswith("Screw")]
    assert len(screws) == 6
    left = [part for part in screws if max(vertex.co.x for vertex in part.data.vertices) < 0]
    right = [part for part in screws if min(vertex.co.x for vertex in part.data.vertices) > 0]
    assert len(left) == len(right) == 3
