"""The markings atlas (tools/assets/gun_markings.py) is generated, never hand-edited:
the committed PNG must match the script, and each region holds its colour.
python -m pytest tools/assets/tests -q
"""

import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import gun_markings as gm


class MarkingsAtlasTest(unittest.TestCase):
    def test_committed_atlas_matches_the_script(self) -> None:
        self.assertEqual(gm.OUT.read_bytes(), gm.png_bytes(gm.draw()), "run python tools/assets/gun_markings.py")

    def test_regions_carry_their_colours(self) -> None:
        img = gm.draw()

        def centre(region: str) -> tuple:
            x0, y0, x1, y1 = gm.REGIONS[region]
            return img[(y0 + y1) // 2][(x0 + x1) // 2]

        tape, shell, brass = centre("tape"), centre("shell"), centre("brass")
        self.assertGreater(tape[0], 150, "tape is yellow")
        self.assertGreater(tape[1], 110, "tape is yellow")
        self.assertGreater(shell[0], shell[1] * 3, "shell hull is red")
        self.assertGreater(brass[0], brass[2] * 2, "brass is warm")
        self.assertEqual(centre("black"), gm.BLACK, "the side faces of every plate read as matte black")
        logo_pixels = {px for row in img[0:48] for px in row[0:128]}
        self.assertIn(gm.PRINT, logo_pixels, "the logo is printed")

    def test_uv_rect_flips_image_rows_to_blender_v(self) -> None:
        u0, v0, u1, v1 = gm.uv_rect("tape")
        self.assertEqual((u0, u1), (0.5, 1.0))
        self.assertEqual((v0, v1), (1.0 - 32 / 256, 1.0))


if __name__ == "__main__":
    unittest.main()
