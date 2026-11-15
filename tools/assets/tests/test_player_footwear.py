"""Boot laces and toe reinforcement stay visible and seated on the actual last."""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import bpy

# isort: split
import bmesh
import character_rig
import player_body_model as body
import pytest
from mathutils.bvhtree import BVHTree


@pytest.fixture(params=[("L", 1), ("R", -1)])
def footwear(request, monkeypatch):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    mats = {key: bpy.data.materials.new(name) for key, name in (("rubber", "BodyRubber"), ("knit", "BodyKnit"))}
    original = body._boot_details
    captured = []

    def capture(boot, materials, sign):
        details = original(boot, materials, sign)
        bpy.context.view_layer.update()
        boot.data.calc_loop_triangles()
        surface = BVHTree.FromPolygons(
            [boot.matrix_world @ vertex.co for vertex in boot.data.vertices],
            [triangle.vertices[:] for triangle in boot.data.loop_triangles],
            all_triangles=True,
        )
        for detail in details:
            if not detail.name.startswith(("BootLace", "ToeGuard")):
                continue
            distances = []
            for vertex in detail.data.vertices:
                point = detail.matrix_world @ vertex.co
                nearest, normal, _face, _distance = surface.find_nearest(point)
                distances.append((point - nearest).dot(normal))
            captured.append((detail.name, detail.data.copy(), distances))
        return details

    monkeypatch.setattr(body, "_boot_details", capture)
    side, sign = request.param
    body._boot(character_rig.build_armature(), mats, side, sign)
    return captured


def test_every_lace_crosses_the_boot_surface_without_floating_or_burial(footwear):
    laces = [distances for name, _mesh, distances in footwear if name.startswith("BootLace")]
    assert laces, "the boot must retain its visible lacing"
    for distances in laces:
        assert min(distances) < 0.0, "the underside must seat into the boot"
        assert max(distances) > 0.001, "a buried lace has no visible raised profile"
        assert max(abs(distance) for distance in distances) < 0.006, "lacing must follow the sloped vamp"


def test_toe_guard_sits_above_and_close_to_the_boot_surface(footwear):
    guards = [distances for name, _mesh, distances in footwear if name.startswith("ToeGuard")]
    assert guards, "the toe reinforcement must survive assembly"
    for distances in guards:
        assert min(distances) >= -0.0001, "the guard must not disappear into the toe"
        assert min(distances) < 0.002, "the guard needs contact with the upper"
        assert 0.002 < max(distances) < 0.008, "the raised guard stays shallow enough to read as reinforcement"


def test_footwear_details_remain_closed_outward_shells_after_projection(footwear):
    for name, mesh, _distances in footwear:
        surface = bmesh.new()
        try:
            surface.from_mesh(mesh)
            bmesh.ops.triangulate(surface, faces=surface.faces[:])
            assert all(edge.is_manifold and edge.is_contiguous for edge in surface.edges), name
            assert all(face.calc_area() > 1e-10 for face in surface.faces), name
            assert surface.calc_volume(signed=True) > 0, name
        finally:
            surface.free()
