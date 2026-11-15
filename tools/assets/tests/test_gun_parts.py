"""Unit tests for the gun shape tools (tools/assets/gun_parts.py) and the detailed guns. Needs bpy:
python -m pytest tools/assets/tests -q
"""

import math
import os
import sys
import unittest

import bpy

# isort: split
# bpy must load before bmesh.
import bmesh

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import build_models as bm
import check_models
import gun_parts as g

GUNS = (
    "rifle_ar",
    "shotgun_brenner",
    "kestrel_smg",
    "talon_dmr",
    "hollis_44",
    "mako_pdw",
    "atlas_auto",
    "halberd_lmg",
    "corvid_338",
)
DETAIL_FLOOR = 4_000  # the old box-built guns were 1,700-4,800 triangles


def volumes(obj) -> list:
    mesh = bmesh.new()
    mesh.from_mesh(obj.data)
    bmesh.ops.triangulate(mesh, faces=mesh.faces[:])
    out = check_models.shell_volumes(mesh)
    mesh.free()
    return out


def zero_area_faces(obj) -> int:
    mesh = bmesh.new()
    mesh.from_mesh(obj.data)
    bmesh.ops.triangulate(mesh, faces=mesh.faces[:])
    count = sum(1 for f in mesh.faces if f.calc_area() < 1e-10)
    mesh.free()
    return count


class ShapeToolTest(unittest.TestCase):
    def setUp(self) -> None:
        bm.reset_scene()
        self.mat = bm.material("M", (0.5, 0.5, 0.5, 1.0))

    def test_slab_is_a_closed_outward_solid_of_outline_times_width(self) -> None:
        notch = [(0, 0), (0.1, 0), (0.1, 0.05), (0.06, 0.05), (0.06, 0.02), (0.04, 0.02), (0.04, 0.05), (0, 0.05)]
        part = g.slab("Notch", notch, 0.02, self.mat, x=0.01)
        shells = volumes(part)
        self.assertEqual(len(shells), 1)
        self.assertAlmostEqual(shells[0], (0.1 * 0.05 - 0.02 * 0.03) * 0.02, places=7)
        xs = [v.co.x for v in part.data.vertices]
        self.assertAlmostEqual(min(xs), 0.0, places=6)
        self.assertAlmostEqual(max(xs), 0.02, places=6)

    def test_bevelled_slab_stays_closed_without_zero_area_faces(self) -> None:
        part = g.slab("Grip", [(0, 0), (0.03, 0), (0.06, -0.1), (0.03, -0.1)], 0.03, self.mat, bevel=0.005)
        self.assertEqual(len(volumes(part)), 1)
        self.assertGreater(volumes(part)[0], 0.0)
        self.assertEqual(zero_area_faces(part), 0)

    def test_lathe_turns_a_capped_cylinder_along_each_axis(self) -> None:
        for axis in ("x", "y", "z"):
            part = g.lathe("Tube" + axis, [(0.01, 0.0), (0.01, 0.1)], (0, 0, 0), self.mat, segments=32, axis=axis)
            shells = volumes(part)
            self.assertEqual(len(shells), 1, axis)
            self.assertAlmostEqual(shells[0], math.pi * 0.01**2 * 0.1, delta=0.01 * shells[0])
            size = part.dimensions
            self.assertAlmostEqual(size["xyz".index(axis)], 0.1, places=5)

    def test_rounded_drops_duplicate_points_when_the_slot_is_two_radii_tall(self) -> None:
        points = g.rounded(0.0, 0.0, 0.03, 0.012, 0.006)
        gaps = [math.dist(a, b) for a, b in zip(points, points[1:] + points[:1], strict=True)]
        self.assertGreater(min(gaps), 1e-6)
        self.assertEqual(zero_area_faces(g.slab("Slot", points, 0.002, self.mat)), 0)

    def test_teeth_rail_has_one_tooth_per_pitch_between_base_and_top(self) -> None:
        points = g.teeth(0.0, 0.1, 0.0, 0.008, pitch=0.01)
        tops = [p for p in points if math.isclose(p[1], 0.008)]
        self.assertEqual(len(tops), 20)
        self.assertTrue(all(0.0 <= z <= 0.008 for _, z in points))


class DetailedGunTest(unittest.TestCase):
    def test_every_gun_is_detailed_and_inside_the_weapon_budget(self) -> None:
        budget = check_models.BUDGETS["weapons"][0]
        for name in GUNS:
            bm.reset_scene()
            bm.MODELS[name][1]()
            meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
            triangles = 0
            for obj in meshes:
                obj.data.calc_loop_triangles()
                triangles += len(obj.data.loop_triangles)
                self.assertEqual(zero_area_faces(obj), 0, f"{name}/{obj.name}")
            self.assertGreaterEqual(triangles, DETAIL_FLOOR, f"{name} has real detail, not boxes")
            self.assertLessEqual(triangles, budget, name)


if __name__ == "__main__":
    unittest.main()
