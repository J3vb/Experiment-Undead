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
from mathutils import Vector

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

    def test_cut_makes_a_through_port_with_closed_outward_walls(self) -> None:
        body = g.slab("Body", [(0, 0), (0.1, 0), (0.1, 0.1), (0, 0.1)], 0.05, self.mat)
        cutter = g.slab("Port", [(0.02, 0.02), (0.08, 0.02), (0.08, 0.08), (0.02, 0.08)], 0.07, self.mat)
        self.assertIs(g.cut(body, [cutter]), body)
        self.assertNotIn("Port", bpy.data.objects)
        self.assertAlmostEqual(volumes(body)[0], (0.1**2 - 0.06**2) * 0.05, places=7)
        self.assertFalse(body.ray_cast(Vector((0.1, 0.05, 0.05)), Vector((-1, 0, 0)))[0])
        self.assertTrue(body.ray_cast(Vector((0.1, 0.01, 0.05)), Vector((-1, 0, 0)))[0])
        mesh = bmesh.new()
        mesh.from_mesh(body.data)
        self.assertTrue(all(edge.is_manifold for edge in mesh.edges))
        mesh.free()
        self.assertEqual(zero_area_faces(body), 0)

    def test_cut_keeps_a_blind_port_floor_and_transformed_part_pivot(self) -> None:
        parent = bm.marker("Receiver", (0, 0, 0))
        body = g.slab("Bolt", [(0, 0), (0.1, 0), (0.1, 0.1), (0, 0.1)], 0.05, self.mat)
        bm.attach(body, (0, 0.03, 0.04), parent)
        bpy.context.view_layer.update()
        before = body.matrix_world.copy()
        cutter = g.slab("Pocket", [(0.02, 0.02), (0.08, 0.02), (0.08, 0.08), (0.02, 0.08)], 0.02, self.mat, x=0.025)
        g.cut(body, [cutter])
        self.assertEqual(body.name, "Bolt")
        self.assertEqual(body.parent, parent)
        self.assertEqual(body.matrix_world, before)
        self.assertAlmostEqual(volumes(body)[0], 0.1**2 * 0.05 - 0.06**2 * 0.01, places=7)
        hit, point, _normal, _face = body.ray_cast(Vector((0.1, 0.02, 0.01)), Vector((-1, 0, 0)))
        self.assertTrue(hit)
        self.assertAlmostEqual(point.x, 0.015, places=6)
        self.assertEqual(list(body.data.materials), [self.mat])
        self.assertEqual(zero_area_faces(body), 0)

    def test_cut_bores_a_muzzle_without_leaving_a_cap(self) -> None:
        body = g.lathe("MuzzleBrake", [(0.012, 0.0), (0.012, 0.06)], (0, 0, 0), self.mat, segments=16)
        cutter = g.lathe("Bore", [(0.006, -0.01), (0.006, 0.07)], (0, 0, 0), self.mat, segments=16)
        g.cut(body, [cutter])
        self.assertEqual(len(volumes(body)), 1)
        expected = 8 * math.sin(math.pi / 8) * (0.012**2 - 0.006**2) * 0.06
        self.assertAlmostEqual(volumes(body)[0], expected, places=9)
        self.assertFalse(body.ray_cast(Vector((0, 0.1, 0)), Vector((0, -1, 0)))[0])
        self.assertTrue(body.ray_cast(Vector((0.009, 0.1, 0)), Vector((0, -1, 0)))[0])
        self.assertEqual(zero_area_faces(body), 0)

    def test_cut_locks_valid_export_triangles_at_collinear_port_intersections(self) -> None:
        body = g.lathe(
            "Brake", [(0.016, 0.796), (0.018, 0.8), (0.018, 0.862), (0.016, 0.866)], (0, 0, 0.016), self.mat, 12
        )
        cutters = [g.lathe("Core", [(0.006, 0.79), (0.006, 0.875)], (0, 0, 0.016), self.mat, 12)]
        for i in range(3):
            y = 0.806 + i * 0.019
            cutters.append(g.slab("Port", g.rounded(y, 0.009, y + 0.012, 0.023, 0.003), 0.05, self.mat))
        g.cut(body, cutters)
        bm.attach(body, (0, 0.831, 0.016))
        body.data.calc_loop_triangles()
        self.assertGreater(len(body.data.loop_triangles), 0)
        self.assertTrue(all(triangle.area >= 1e-10 for triangle in body.data.loop_triangles))
        self.assertEqual(len(volumes(body)), 1)
        self.assertGreater(volumes(body)[0], 0)

    def test_inlay_mask_survives_join_without_recolouring_the_body(self) -> None:
        body = g.slab("Receiver", [(0, 0), (0.1, 0), (0.1, 0.1), (0, 0.1)], 0.05, self.mat)
        strip = g.slab("Inlay", [(0.01, 0.01), (0.09, 0.01), (0.09, 0.013), (0.01, 0.013)], 0.001, self.mat, x=0.026)
        body_loops, strip_loops = len(body.data.loops), len(strip.data.loops)
        self.assertIs(g.mark_inlay(strip), strip)
        bm.join_into(body, [strip])
        colors = body.data.color_attributes["Color"].data
        self.assertEqual(sum(color.color[3] == 1.0 for color in colors), body_loops)
        self.assertEqual(sum(color.color[3] == 0.0 for color in colors), strip_loops)
        self.assertTrue(all(tuple(color.color[:3]) == (1.0, 1.0, 1.0) for color in colors))
        self.assertEqual(list(body.data.materials), [self.mat])


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
