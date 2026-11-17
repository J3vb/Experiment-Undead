"""Saved ids are permanent. Run from the repo root:

    python tools/ci/check_saved_ids.py <base-ref> [--fix]

Every id that can end up in a character save must be listed in tools/ci/saved_ids.txt (--fix appends new
ones), and every id listed there or in the base branch's copy must still exist. The save version must never
drop below the one at the newest stable v* tag.
"""

import re
import subprocess
import sys
from pathlib import Path

LIST = "tools/ci/saved_ids.txt"
SAVE_FILE = "systems/save/save_file.gd"
CONTENT_DIRS = (
    "content/weapons",
    "content/loot/gear",
    "content/loot/affixes",
    "content/loot/rarities",
    "content/skills",
)
LEVELS_DIR = "levels"
STABLE_TAG = re.compile(r"^v(\d+)\.(\d+)\.(\d+)$")
SAVE_VERSION = re.compile(r"^const CURRENT_VERSION: int = (\d+)", re.M)
PERMANENT = "Saved ids are permanent. Restore the file, or add a SaveFile migration that renames it."
HEADER = "# Ids that can be in a character save. Grows only: see tools/ci/check_saved_ids.py.\n"


def current_ids(root: Path) -> set[str]:
    """Content files (the file name is the id) and level folders whose map name goes into best_runs."""
    ids = set()
    for folder in CONTENT_DIRS:
        for path in (root / folder).rglob("*.tres"):
            ids.add(f"{folder}/{path.stem}")
    levels = root / LEVELS_DIR
    if levels.is_dir():
        for map_scene in levels.glob("*/map.tscn"):
            ids.add(f"{LEVELS_DIR}/{map_scene.parent.name}")
    return ids


def parse_list(text: str) -> set[str]:
    return {line.strip() for line in text.splitlines() if line.strip() and not line.startswith("#")}


def git(root: Path, *args: str) -> subprocess.CompletedProcess:
    return subprocess.run(["git", *args], cwd=root, check=False, capture_output=True, text=True)


def base_list(root: Path, base: str) -> set[str]:
    result = git(root, "show", f"{base}:{LIST}")
    return parse_list(result.stdout) if result.returncode == 0 else set()


def newest_stable_tag(root: Path) -> str:
    tags = [tag for tag in git(root, "tag", "--list", "v*").stdout.split() if STABLE_TAG.match(tag)]
    if not tags:
        return ""
    return max(tags, key=lambda tag: tuple(int(part) for part in STABLE_TAG.match(tag).groups()))


def save_version(text: str) -> int:
    match = SAVE_VERSION.search(text)
    return int(match.group(1)) if match else -1


def check_save_version(root: Path) -> list[str]:
    tag = newest_stable_tag(root)
    if not tag:
        return []
    released = save_version(git(root, "show", f"{tag}:{SAVE_FILE}").stdout)
    now = save_version((root / SAVE_FILE).read_text(encoding="utf-8"))
    if now < released:
        return [f"{SAVE_FILE}: CURRENT_VERSION is {now}, but {tag} shipped {released}. Save versions never go down."]
    return []


def check_ids(root: Path, base: str, fix: bool) -> list[str]:
    path = root / LIST
    listed = parse_list(path.read_text(encoding="utf-8")) if path.exists() else set()
    ids = current_ids(root)
    problems = [
        f"{LIST}: '{gone}' no longer exists. {PERMANENT}" for gone in sorted((listed | base_list(root, base)) - ids)
    ]
    new = sorted(ids - listed)
    if new and fix:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(HEADER + "".join(f"{line}\n" for line in sorted(listed | ids)), encoding="utf-8")
        print(f"Added {len(new)} id(s) to {LIST}.")
    elif new:
        problems += [f"{LIST}: '{added}' is not listed. Run python tools/ci/check_saved_ids.py --fix" for added in new]
    return problems


def main(argv: list[str], root: Path = Path(".")) -> int:
    args = [arg for arg in argv if not arg.startswith("--")]
    base = args[0] if args else "origin/main"
    problems = check_ids(root, base, "--fix" in argv) + check_save_version(root)
    for problem in problems:
        print(problem)
    print("Saved id checks failed." if problems else "Saved id checks passed.")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
