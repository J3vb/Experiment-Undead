"""Saved ids only grow and the save version never drops below the newest stable tag; stdlib only."""

import contextlib
import io
import subprocess
import tempfile
import unittest
from pathlib import Path

import check_saved_ids as checker

SAVE = "## Save file\nconst CURRENT_VERSION: int = {}\n"


class SavedIdsTests(unittest.TestCase):
    def setUp(self):
        self._dir = tempfile.TemporaryDirectory()
        self.root = Path(self._dir.name)
        self._git("init", "-q", "-b", "main")
        self._git("config", "user.email", "ci@example.invalid")
        self._git("config", "user.name", "CI")
        self._write("content/weapons/rifle_ar.tres", "[gd_resource]")
        self._write("content/loot/affixes/crit_pct.tres", "[gd_resource]")
        self._write("levels/halcyon_labs/map.tscn", "[gd_scene]")
        self._write(checker.SAVE_FILE, SAVE.format(2))
        self.assertEqual(self._run("--fix"), 0)
        self._commit("base")

    def tearDown(self):
        self._dir.cleanup()

    def _git(self, *args):
        subprocess.run(["git", *args], cwd=self.root, check=True, capture_output=True)

    def _write(self, rel, text):
        path = self.root / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")

    def _commit(self, message):
        self._git("add", "-A")
        self._git("commit", "-q", "-m", message)

    def _run(self, *args):
        with contextlib.redirect_stdout(io.StringIO()):
            return checker.main(["main", *args], self.root)

    def _listed(self):
        return checker.parse_list((self.root / checker.LIST).read_text(encoding="utf-8"))

    def test_fix_lists_content_and_maps(self):
        self.assertEqual(
            self._listed(),
            {"content/weapons/rifle_ar", "content/loot/affixes/crit_pct", "levels/halcyon_labs"},
        )
        self.assertEqual(self._run(), 0)

    def test_removed_listed_id_fails(self):
        (self.root / "content/weapons/rifle_ar.tres").unlink()
        self.assertEqual(self._run(), 1)

    def test_removing_the_id_and_its_line_together_still_fails(self):
        (self.root / "content/weapons/rifle_ar.tres").unlink()
        listed = self._listed() - {"content/weapons/rifle_ar"}
        self._write(checker.LIST, "".join(f"{line}\n" for line in sorted(listed)))
        self.assertEqual(self._run(), 1)

    def test_removed_map_folder_fails(self):
        (self.root / "levels/halcyon_labs/map.tscn").unlink()
        self.assertEqual(self._run(), 1)

    def test_new_unlisted_id_fails_until_fix_adds_it(self):
        self._write("content/skills/carpenter.tres", "[gd_resource]")
        self.assertEqual(self._run(), 1)
        self.assertEqual(self._run("--fix"), 0)
        self.assertIn("content/skills/carpenter", self._listed())
        self.assertEqual(self._run(), 0)

    def test_save_version_below_the_newest_stable_tag_fails(self):
        self._write(checker.SAVE_FILE, SAVE.format(3))
        self._commit("save v3")
        self._git("tag", "v0.1.0")
        self._write(checker.SAVE_FILE, SAVE.format(2))
        self.assertEqual(self._run(), 1)
        self._write(checker.SAVE_FILE, SAVE.format(3))
        self.assertEqual(self._run(), 0)

    def test_newest_stable_tag_orders_numbers_and_skips_pre_releases(self):
        for tag in ("v0.9.0", "v0.10.0", "v0.11.0-test.1"):
            self._git("tag", tag)
        self.assertEqual(checker.newest_stable_tag(self.root), "v0.10.0")

    def test_no_tags_skips_the_save_version_check(self):
        self._write(checker.SAVE_FILE, SAVE.format(1))
        self.assertEqual(checker.check_save_version(self.root), [])


if __name__ == "__main__":
    unittest.main()
