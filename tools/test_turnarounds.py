"""Run with python -m unittest tools/test_turnarounds.py (needs numpy and Pillow, not Blender)."""

import sys
import tempfile
import unittest
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import turnarounds


def solid(color, size=(64, 32)):
    return Image.new("RGB", size, color)


class FindModelsTests(unittest.TestCase):
    def test_finds_glbs_by_category_and_ignores_other_files(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name in ("zombies/b.glb", "zombies/a.glb", "weapons/gun.glb", "weapons/gun.glb.import"):
                (root / name).parent.mkdir(parents=True, exist_ok=True)
                (root / name).write_bytes(b"x")
            found = [(category, name) for category, name, _ in turnarounds.find_models(root)]
        self.assertEqual(found, [("weapons", "gun"), ("zombies", "a"), ("zombies", "b")])

    def test_repo_models_are_found(self):
        names = {name for _, name, _ in turnarounds.find_models()}
        self.assertTrue({"shambler", "rifle_ar", "wall_panel"} <= names)


class ReferenceTests(unittest.TestCase):
    def test_every_model_category_has_a_style_guide_reference(self):
        for category, name, _ in turnarounds.find_models():
            self.assertIsNotNone(turnarounds.reference_for(category), f"{category}/{name}: add it to REFERENCES")

    def test_unknown_category_or_missing_image_has_no_reference(self):
        self.assertIsNone(turnarounds.reference_for("vehicles"))
        with tempfile.TemporaryDirectory() as directory:
            self.assertIsNone(turnarounds.reference_for("zombies", Path(directory)))

    def test_every_committed_model_has_an_approved_turnaround(self):
        for category, name, _ in turnarounds.find_models():
            path = turnarounds.approved_path(category, name)
            self.assertTrue(path.is_file(), f"run tools/render_turnarounds.py --approve for {category}/{name}")


class ApprovedFramingTests(unittest.TestCase):
    def test_every_view_is_centred_and_not_clipped(self):
        for category, name, _ in turnarounds.find_models():
            with Image.open(turnarounds.approved_path(category, name)) as image:
                pixels = np.asarray(image.convert("RGB"), dtype=np.int16)
            size = pixels.shape[0]
            for index, (view, _) in enumerate(turnarounds.VIEWS):
                panel = pixels[size // 8 :, index * size : (index + 1) * size]
                content = np.abs(panel - panel[-1, -1]).max(axis=2) > turnarounds.PIXEL_TOLERANCE
                columns = np.flatnonzero(content.any(axis=0))
                label = f"{category}/{name} {view}"
                self.assertGreater(columns.size, 0, label)
                self.assertGreater(columns[0], 0, f"{label} touches the left edge")
                self.assertLess(columns[-1], size - 1, f"{label} touches the right edge")
                self.assertLess(abs((columns[0] + columns[-1]) / 2 - size / 2), size * 0.08, f"{label} is off-centre")


class CompareTests(unittest.TestCase):
    def test_no_approved_render_is_new(self):
        fraction, diff = turnarounds.compare(solid((10, 10, 10)), None)
        self.assertIsNone(fraction)
        self.assertIsNone(diff)
        self.assertEqual(turnarounds.status(fraction), "new")

    def test_render_noise_below_tolerance_is_same(self):
        fraction, _ = turnarounds.compare(solid((100, 100, 100)), solid((100 + turnarounds.PIXEL_TOLERANCE, 90, 100)))
        self.assertEqual(fraction, 0.0)
        self.assertEqual(turnarounds.status(fraction), "same")

    def test_moved_part_is_changed_and_highlighted(self):
        before = solid((0, 0, 0))
        after = before.copy()
        after.paste(solid((200, 200, 200), (8, 4)), (10, 10))
        fraction, diff = turnarounds.compare(after, before)
        self.assertAlmostEqual(fraction, 32 / (64 * 32))
        self.assertEqual(turnarounds.status(fraction), "changed")
        self.assertEqual(diff.getpixel((12, 12)), turnarounds.HIGHLIGHT)
        self.assertEqual(diff.getpixel((0, 0)), (0, 0, 0))

    def test_tiny_change_under_threshold_is_same(self):
        before = solid((0, 0, 0), (1000, 100))
        after = before.copy()
        after.putpixel((5, 5), (255, 255, 255))
        fraction, _ = turnarounds.compare(after, before)
        self.assertEqual(turnarounds.status(fraction), "same")

    def test_different_size_counts_as_fully_changed(self):
        fraction, _ = turnarounds.compare(solid((0, 0, 0)), solid((0, 0, 0), (32, 32)))
        self.assertEqual(fraction, 1.0)


class LayoutTests(unittest.TestCase):
    def test_strip_puts_panels_side_by_side(self):
        strip = turnarounds.make_strip([solid((255, 0, 0), (40, 40)), solid((0, 0, 255), (40, 40))], ["A", "B"])
        self.assertEqual(strip.size, (80, 40))
        self.assertEqual(strip.getpixel((39, 39)), (255, 0, 0))
        self.assertEqual(strip.getpixel((79, 39)), (0, 0, 255))

    def test_sheet_skips_missing_rows_and_adds_reference(self):
        strip = solid((1, 2, 3), (200, 50))
        reference = turnarounds.reference_for("zombies")
        with_ref = turnarounds.make_sheet("T", "S", [("CURRENT", strip), ("APPROVED", None)], reference)
        without = turnarounds.make_sheet("T", "S", [("CURRENT", strip), ("APPROVED", None)], None)
        self.assertEqual(without.size, (200, 56 + 50 + 28))
        self.assertGreater(with_ref.height, without.height)
        self.assertEqual(with_ref.width, 200)

    def test_summary_lists_every_model(self):
        text = turnarounds.summary_table(
            [
                {"model": "zombies/shambler", "status": "same", "fraction": 0.0, "triangles": 2976},
                {"model": "zombies/new_one", "status": "new", "fraction": None, "triangles": 12},
            ]
        )
        self.assertIn("| zombies/shambler | same | 0.000% | 2,976 |", text)
        self.assertIn("| zombies/new_one | new | - | 12 |", text)


if __name__ == "__main__":
    unittest.main()
