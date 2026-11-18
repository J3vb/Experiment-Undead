"""stamp_version.sh counts main builds up from the last stable release, ignoring test tags."""

import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parent / "stamp_version.sh"


def _git(repo: Path, *args: str) -> None:
    subprocess.run(["git", *args], cwd=repo, check=True, capture_output=True)


class StampVersionTest(unittest.TestCase):
    def setUp(self) -> None:
        self.repo = Path(tempfile.mkdtemp())
        _git(self.repo, "init", "-q")
        _git(self.repo, "config", "user.email", "ci@example.invalid")
        _git(self.repo, "config", "user.name", "CI")
        shutil.copy(SCRIPT, self.repo / "stamp_version.sh")

    def tearDown(self) -> None:
        shutil.rmtree(self.repo)

    def _commit(self, tag: str = "") -> None:
        _git(self.repo, "commit", "-q", "--allow-empty", "-m", "change")
        if tag:
            _git(self.repo, "tag", tag)

    def _version(self) -> str:
        out = subprocess.run(
            ["bash", "stamp_version.sh"], cwd=self.repo, check=True, capture_output=True, text=True
        ).stdout
        return out.strip().split("version=", 1)[1]

    def test_test_tags_do_not_move_main_builds(self) -> None:
        self._commit("v0.1.0")
        self._commit("v0.2.0-test.1")
        self._commit()
        self.assertTrue(self._version().startswith("0.1.1-dev.2+"))

    def test_tag_build_uses_the_tag(self) -> None:
        self._commit("v0.1.0")
        self._commit("v0.2.0-test.1")
        self.assertEqual(self._version(), "0.2.0-test.1")


if __name__ == "__main__":
    unittest.main()
