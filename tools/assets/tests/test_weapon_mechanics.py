"""Ray probes protect visible cavities and the moving-part contracts of the PDW and LMG."""

import os
import sys
import unittest

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import build_models as bm


def hit_world(obj, origin, direction):
    """Raycast in world coordinates, including meshes with animation pivots."""
    inverse = obj.matrix_world.inverted()
    hit, point, _normal, _face = obj.ray_cast(inverse @ Vector(origin), inverse.to_3x3() @ Vector(direction))
    return obj.matrix_world @ point if hit else None


class VisibleMechanicsTest(unittest.TestCase):
    def build(self, name):
        bm.reset_scene()
        bm.MODELS[name][1]()
        bpy.context.view_layer.update()
        return {obj.name: obj for obj in bpy.context.scene.objects}

    def test_shrouds_have_open_vents_with_an_inner_barrel_and_solid_webs(self):
        for name, part, start, pitch, count, bore in (
            ("mako_pdw", "Receiver", 0.145, 0.03, 3, 0.02),
            ("halberd_lmg", "Handguard", 0.225, 0.034, 7, 0.03),
        ):
            nodes = self.build(name)
            for i in range(count):
                y = start + i * pitch + 0.01
                self.assertIsNone(hit_world(nodes[part], (0.1, y, bore), (-1, 0, 0)), (name, i))
                barrel = hit_world(nodes["Barrel"], (0.1, y, bore), (-1, 0, 0))
                self.assertIsNotNone(barrel, (name, i))
                self.assertLess(barrel.x, 0.015, name)
            self.assertIsNotNone(hit_world(nodes[part], (0.1, start - 0.006, bore), (-1, 0, 0)), name)

    def test_ejection_ports_recess_both_receiver_layers_and_seat_the_bolt(self):
        for name, floor, surface, height in (
            ("mako_pdw", 0.016, 0.023, 0.021),
            ("halberd_lmg", 0.024, 0.032, 0.026),
        ):
            nodes = self.build(name)
            receiver = hit_world(nodes["Receiver"], (0.1, 0.0, height), (-1, 0, 0))
            bolt = hit_world(nodes["Bolt"], (0.1, 0.0, height), (-1, 0, 0))
            self.assertAlmostEqual(receiver.x, floor, places=6, msg=name)
            self.assertGreater(bolt.x, floor, name)
            self.assertLess(bolt.x, surface - 0.002, name)

    def test_muzzle_has_a_deep_bore_and_a_solid_rim(self):
        for name, height, floor, rim in (
            ("mako_pdw", 0.02, 0.275, 0.009),
            ("halberd_lmg", 0.03, 0.73, 0.011),
        ):
            nodes = self.build(name)
            bore = hit_world(nodes["Barrel"], (0, 1, height), (0, -1, 0))
            edge = hit_world(nodes["Barrel"], (0, 1, height + rim), (0, -1, 0))
            self.assertAlmostEqual(bore.y, floor, places=6, msg=name)
            self.assertGreater(edge.y, bore.y + 0.06, name)

    def test_halberd_stock_window_is_open_with_a_load_bearing_top_strut(self):
        stock = self.build("halberd_lmg")["Stock"]
        self.assertIsNone(hit_world(stock, (0.1, -0.31, -0.015), (-1, 0, 0)))
        self.assertIsNotNone(hit_world(stock, (0.1, -0.31, 0.025), (-1, 0, 0)))

    def test_halberd_feed_cover_channel_is_below_the_surrounding_top_face(self):
        receiver = self.build("halberd_lmg")["Receiver"]
        channel = hit_world(receiver, (0, 0.015, 0.2), (0, 0, -1))
        shoulder = hit_world(receiver, (0.02, 0.015, 0.2), (0, 0, -1))
        self.assertAlmostEqual(channel.z, 0.074, places=6)
        self.assertAlmostEqual(shoulder.z, 0.078, places=6)

    def test_moving_parts_and_muzzle_keep_their_original_pivots(self):
        for name, pivots in (
            (
                "mako_pdw",
                {
                    "Bolt": (0.0245, 0, 0.021),
                    "Magazine": (0, 0.05, -0.05),
                    "Stock": (0, -0.13, 0),
                    "Muzzle": (0, 0.35, 0.02),
                },
            ),
            (
                "halberd_lmg",
                {
                    "Bolt": (0.0325, -0.02, 0.026),
                    "Magazine": (0, 0.1, -0.034),
                    "Stock": (0, -0.2, 0),
                    "Muzzle": (0, 0.817, 0.03),
                },
            ),
        ):
            nodes = self.build(name)
            for part, expected in pivots.items():
                self.assertLess((nodes[part].matrix_world.translation - Vector(expected)).length, 1e-6, (name, part))
            self.assertEqual(nodes["ChargingHandle"].parent, nodes["Bolt"])


if __name__ == "__main__":
    unittest.main()
