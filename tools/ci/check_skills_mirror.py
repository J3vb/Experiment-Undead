"""Checks that .claude/skills is an exact copy of .agents/skills. Run from the repo root:

    python tools/ci/check_skills_mirror.py          # check, exit 1 on a difference
    python tools/ci/check_skills_mirror.py --fix    # copy .agents/skills over .claude/skills

.agents/skills is the source (Codex reads it); .claude/skills is the copy Claude Code reads.
"""

import shutil
import sys
from pathlib import Path

SOURCE = Path(".agents/skills")
COPY = Path(".claude/skills")


def files_in(root: Path) -> dict[str, bytes]:
    return {p.relative_to(root).as_posix(): p.read_bytes() for p in root.rglob("*") if p.is_file()}


def main() -> int:
    if "--fix" in sys.argv:
        shutil.rmtree(COPY, ignore_errors=True)
        shutil.copytree(SOURCE, COPY)
        print(f"copied {SOURCE} -> {COPY}")
        return 0
    source, copy = files_in(SOURCE), files_in(COPY)
    problems = [f"missing in {COPY}: {name}" for name in sorted(source.keys() - copy.keys())]
    problems += [f"extra in {COPY}: {name}" for name in sorted(copy.keys() - source.keys())]
    problems += [f"differs: {name}" for name in sorted(source.keys() & copy.keys()) if source[name] != copy[name]]
    for line in problems:
        print(line)
    if problems:
        print("Edit .agents/skills, then run: python tools/ci/check_skills_mirror.py --fix")
        return 1
    print(f"{len(source)} skill files match")
    return 0


if __name__ == "__main__":
    sys.exit(main())
