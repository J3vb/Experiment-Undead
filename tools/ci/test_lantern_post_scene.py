"""The committed Lantern Post scene is exactly what its generator writes (nobody hand-edits it)."""

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "levels"))

import lantern_post_scene


class LanternPostSceneTest(unittest.TestCase):
    def test_generator_reproduces_the_committed_scene(self) -> None:
        committed = lantern_post_scene.SCENE.read_text()
        self.assertEqual(lantern_post_scene.build(), committed, "run python tools/levels/lantern_post_scene.py")


if __name__ == "__main__":
    unittest.main()
