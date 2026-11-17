"""Baked guns (ADR 0014) stay in step with their sources: a changed gun script without a
re-bake fails here. CI never bakes; tools/assets/gun_bake.py does, on a machine with bpy."""

import hashlib
import json
import struct
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MAPS = ROOT / "assets" / "textures" / "weapons"
KINDS = ("albedo", "normal", "orm")
MAP_SIZE = 2048
SET_CAP = 16 * 1024 * 1024  # bytes per gun, all three maps (no Git LFS)


def png_size(path: Path) -> tuple:
    with path.open("rb") as handle:
        header = handle.read(24)
    return struct.unpack(">II", header[16:24])


def records() -> dict:
    return {p.name.removesuffix("_bake.json"): json.loads(p.read_text()) for p in MAPS.glob("*_bake.json")}


class GunBakeTest(unittest.TestCase):
    def test_there_is_a_baked_gun(self) -> None:
        self.assertIn("rifle_ar", records())

    def test_bake_inputs_did_not_change_since_the_bake(self) -> None:
        for gun, record in records().items():
            for rel, digest in record["inputs"].items():
                actual = hashlib.sha256((ROOT / rel).read_bytes()).hexdigest()
                self.assertEqual(actual, digest, f"{rel} changed: run python tools/assets/gun_bake.py {gun}")

    def test_record_names_the_gun_script(self) -> None:
        for gun, record in records().items():
            scripts = [rel for rel in record["inputs"] if rel.endswith("_model.py")]
            self.assertEqual(len(scripts), 1, f"{gun} record names its model script")

    def test_maps_are_full_size_and_under_the_repo_cap(self) -> None:
        for gun, record in records().items():
            self.assertEqual(record["map_size"], MAP_SIZE, f"{gun} committed maps are full size")
            total = 0
            for kind in KINDS:
                path = MAPS / f"{gun}_{kind}.png"
                self.assertTrue(path.exists(), f"{path.name} is missing")
                self.assertEqual(png_size(path), (MAP_SIZE, MAP_SIZE), path.name)
                total += path.stat().st_size
            self.assertLessEqual(total, SET_CAP, f"{gun} maps are {total} bytes")

    def test_maps_import_compressed_with_mipmaps(self) -> None:
        for gun in records():
            for kind in KINDS:
                text = (MAPS / f"{gun}_{kind}.png.import").read_text()
                self.assertIn("compress/mode=2", text, f"{gun}_{kind} VRAM compressed")
                self.assertIn("mipmaps/generate=true", text, f"{gun}_{kind} mipmaps")
            normal = (MAPS / f"{gun}_normal.png.import").read_text()
            self.assertIn("compress/normal_map=1", normal, f"{gun} normal map imports as a normal map")


if __name__ == "__main__":
    unittest.main()
