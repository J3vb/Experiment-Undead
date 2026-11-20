"""The committed menu art (FENLIGHT logo, brush stroke) is what tools/assets/menu_art.py draws (F-88)."""

import importlib.util
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "tools" / "assets" / "menu_art.py"
COMMITTED = ROOT / "assets" / "ui"
HAS_IMAGING = importlib.util.find_spec("PIL") is not None and importlib.util.find_spec("numpy") is not None


def load_script():
    spec = importlib.util.spec_from_file_location("menu_art", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


@unittest.skipUnless(HAS_IMAGING, "needs pillow and numpy (pip install -r tools/assets/requirements.txt)")
class MenuArtTest(unittest.TestCase):
    def test_committed_pngs_match_the_script(self) -> None:
        from PIL import Image

        module = load_script()
        with tempfile.TemporaryDirectory() as temp:
            module.OUT = Path(temp)
            module.main()
            for name in ("fenlight_logo.png", "brush_stroke.png"):
                committed = COMMITTED / name
                self.assertTrue(committed.exists(), f"{name} missing: run the script")
                built = Image.open(Path(temp) / name)
                self.assertEqual(Image.open(committed).tobytes(), built.tobytes(), f"{name} is stale: run the script")

    def test_logo_is_wide_and_transparent(self) -> None:
        logo = load_script().draw_logo()
        self.assertEqual(logo.mode, "RGBA")
        self.assertGreater(logo.width, 1000)
        self.assertEqual(logo.getpixel((0, 0))[3], 0)


if __name__ == "__main__":
    unittest.main()
