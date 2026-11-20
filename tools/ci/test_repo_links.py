"""No tracked file links to the repo's old name; GitHub redirects only until the name is reused."""

import re
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OLD_SLUG = re.compile(r"j3vb/" + "experiment" + r"-undead(?!-server)", re.IGNORECASE)


class RepoLinksTest(unittest.TestCase):
    def test_no_file_names_the_old_repo(self) -> None:
        files = subprocess.run(
            ["git", "ls-files"], cwd=ROOT, capture_output=True, text=True, check=True
        ).stdout.splitlines()
        hits: list[str] = []
        for name in files:
            path = ROOT / name
            if not path.is_file() or path.stat().st_size > 2_000_000:
                continue
            try:
                text = path.read_text(encoding="utf-8")
            except UnicodeDecodeError:
                continue
            for number, line in enumerate(text.splitlines(), 1):
                if OLD_SLUG.search(line):
                    hits.append(f"{name}:{number}")
        self.assertEqual(hits, [], "Point these at J3vb/Fenlight")


if __name__ == "__main__":
    unittest.main()
