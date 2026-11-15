"""Unit tests for the finishing pass (tools/assets/finish.py). Needs bpy:
python -m pytest tools/assets/tests -q
"""

import math
import os
import sys
import unittest

import bpy

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import build_models as bm
import finish


def corner_normals(obj) -> list:
    return [c.vector.copy() for c in obj.data.corner_normals]


class FinishTest(unittest.TestCase):
    def setUp(self) -> None:
        bm.reset_scene()

    def test_bevels_harden_normals_only_when_polished(self) -> None:
        mat = bm.material("M", (0.5, 0.5, 0.5, 1.0))
        hard = bm.box("A", (0.1, 0.1, 0.1), (0, 0, 0), mat, bevel=0.01)
        bpy.context.scene["unfinished"] = True
        soft = bm.box("B", (0.1, 0.1, 0.1), (1, 0, 0), mat, bevel=0.01)
        self.assertTrue(hard.data.has_custom_normals, "hardened bevel stores custom normals")
        self.assertFalse(soft.data.has_custom_normals, "unpolished mesh stays as before")

    def test_cylinder_caps_stay_crisp_and_sides_smooth(self) -> None:
        cyl = bm.cylinder("C", 0.05, 0.3, (0, 0, 0), bm.material("M", (0.5, 0.5, 0.5, 1.0)), axis="z")
        finish.fix_normals(cyl)
        normals = corner_normals(cyl)
        for poly in cyl.data.polygons:
            for i in poly.loop_indices:
                if abs(poly.normal.z) > 0.99:
                    self.assertGreater(abs(normals[i].z), 0.99, "cap corners point straight out")
                else:
                    self.assertLess(abs(normals[i].z), 0.01, "side corners stay horizontal")
        side = next(p for p in cyl.data.polygons if abs(p.normal.z) < 0.01)
        bent = [normals[i] for i in side.loop_indices if normals[i].dot(side.normal) < 0.999]
        self.assertEqual(len(bent), 4, "side corners bend round the cylinder, not flat facets")

    def test_unwrap_gives_one_uv_layer_inside_the_unit_square(self) -> None:
        obj = bm.box("A", (0.2, 0.4, 0.1), (0, 0, 0), bm.material("M", (0.5, 0.5, 0.5, 1.0)))
        finish.unwrap(obj)
        self.assertEqual(len(obj.data.uv_layers), 1)
        for uv in obj.data.uv_layers[0].data:
            self.assertTrue(-1e-4 <= uv.uv.x <= 1.0001 and -1e-4 <= uv.uv.y <= 1.0001)

    def test_cavity_marks_inner_corners_only(self) -> None:
        bpy.ops.mesh.primitive_plane_add(size=1.0)
        plane = bpy.context.active_object
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.mesh.subdivide(number_cuts=2)
        bpy.ops.object.mode_set(mode="OBJECT")
        mid = [v for v in plane.data.vertices if abs(v.co.x) < 0.2 and abs(v.co.y) < 0.2]
        mid[0].co.z = -0.2
        cav = finish.cavity(plane.data)
        self.assertGreater(cav[mid[0].index], 0.3, "a dent is a crease")
        bpy.ops.mesh.primitive_uv_sphere_add(location=(3, 0, 0))
        self.assertTrue(all(c == 0.0 for c in finish.cavity(bpy.context.active_object.data)), "a ball has no creases")

    def test_finish_bakes_contact_shadow_and_keeps_glow_white(self) -> None:
        grey = bm.material("Grey", (0.5, 0.5, 0.5, 1.0))
        glow = bm.material("Glow", (0.5, 1.0, 0.2, 1.0), glow=2.0)
        bpy.ops.mesh.primitive_grid_add(x_subdivisions=12, y_subdivisions=12, size=1.0)
        floor = bpy.context.active_object
        floor.data.materials.append(grey)
        lamp = bm.box("Lamp", (0.2, 0.2, 0.2), (0, 0, 0.1), glow)
        finish.finish()
        shade = [c.color[0] for c in floor.data.color_attributes[finish.COLOR_NAME].data]
        self.assertLess(min(shade), 0.8, "floor darkens where the lamp sits on it")
        self.assertGreater(max(shade), 0.95, "open floor stays unshaded")
        for c in lamp.data.color_attributes[finish.COLOR_NAME].data:
            self.assertAlmostEqual(c.color[0], 1.0, places=3)
        self.assertTrue(math.isclose(finish.SMOOTH_ANGLE, math.radians(35.0)))

    def test_non_emissive_optic_keeps_clear_shading_and_opaque_alpha(self) -> None:
        glass = bm.material("OpticGlass", bm.LENS, metallic=0.3, roughness=0.05)
        lens = bm.cylinder("OpticGlass", 0.018, 0.001, (0, 0, 0), glass)
        metal = bm.material("GunMetal", bm.GUN_METAL, metallic=0.8)
        bm.box("Housing", (0.05, 0.03, 0.05), (0, 0.02, 0), metal)
        finish.finish()
        self.assertEqual(glass.node_tree.nodes["Principled BSDF"].inputs["Emission Strength"].default_value, 0.0)
        for color in lens.data.color_attributes[finish.COLOR_NAME].data:
            self.assertEqual(tuple(color.color), (1.0, 1.0, 1.0, 1.0))


if __name__ == "__main__":
    unittest.main()
