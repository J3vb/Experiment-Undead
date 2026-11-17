"""The committed sign PNGs are exactly what tools/assets/sign_decals.py draws."""

import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "tools" / "assets" / "sign_decals.py"
COMMITTED = ROOT / "assets" / "textures" / "signs"


def load_script():
    sys.path.insert(0, str(SCRIPT.parent))
    spec = importlib.util.spec_from_file_location("sign_decals", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class SignDecalsTest(unittest.TestCase):
    def test_committed_pngs_match_the_script(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            for path in load_script().build(Path(temp)):
                committed = COMMITTED / path.name
                self.assertTrue(committed.exists(), f"{path.name} missing: run the script")
                self.assertEqual(committed.read_bytes(), path.read_bytes(), f"{path.name} is stale: run the script")

    def test_every_area_gets_a_sign_with_its_code(self) -> None:
        rooms = load_script().ROOMS
        self.assertEqual(len(rooms), 8)
        self.assertEqual(len({code for code, _name, _sector in rooms.values()}), 8, "area codes are unique")


if __name__ == "__main__":
    unittest.main()
