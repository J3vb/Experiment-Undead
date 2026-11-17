"""The committed story decal PNGs are exactly what tools/assets/story_decals.py draws."""

import importlib.util
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "tools" / "assets" / "story_decals.py"
COMMITTED = ROOT / "assets" / "textures" / "story"


def load_script():
    spec = importlib.util.spec_from_file_location("story_decals", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class StoryDecalsTest(unittest.TestCase):
    def test_committed_pngs_match_the_script(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            for path in load_script().build(Path(temp)):
                committed = COMMITTED / path.name
                self.assertTrue(committed.exists(), f"{path.name} missing: run the script")
                self.assertEqual(committed.read_bytes(), path.read_bytes(), f"{path.name} is stale: run the script")


if __name__ == "__main__":
    unittest.main()
