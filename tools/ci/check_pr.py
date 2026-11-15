"""Quality gate for pull requests. Run from the repo root:

    python tools/ci/check_pr.py <base-ref> [--no-tests-label]

Checks only the .gd files the PR changed, so old code is cleaned up as it is touched.
"""

import re
import subprocess
import sys
from pathlib import Path

MAX_FUNCTION_LINES = 50
LINE_LENGTH = "120"
LOGIC_DIRS = ("core/", "systems/")
FUNC_RE = re.compile(r"^(\s*)(static\s+)?func\s+(\w+)")


def changed_files(base: str) -> list[str]:
    out = subprocess.run(
        ["git", "diff", "--name-only", "--diff-filter=ACMR", f"{base}...HEAD"],
        check=True, capture_output=True, text=True,
    ).stdout
    return [line for line in out.splitlines() if line]


def indent_of(line: str) -> int:
    return len(line) - len(line.lstrip("\t "))


def long_functions(path: str) -> list[str]:
    lines = Path(path).read_text(encoding="utf-8").splitlines()
    problems = []
    for i, line in enumerate(lines):
        match = FUNC_RE.match(line)
        if not match:
            continue
        depth = indent_of(line)
        body = 0
        for later in lines[i + 1:]:
            stripped = later.strip()
            if not stripped:
                continue
            if indent_of(later) <= depth and not stripped.startswith("#"):
                break
            body += 1
        if body > MAX_FUNCTION_LINES:
            problems.append(
                f"{path}:{i + 1}: function '{match.group(3)}' has {body} lines (max {MAX_FUNCTION_LINES})"
            )
    return problems


def run(cmd: list[str]) -> bool:
    print("$ " + " ".join(cmd), flush=True)
    return subprocess.run(cmd).returncode == 0


# Third-party code we keep as published: Godot addons and the vendored agent skills.
VENDORED = ("addons/", ".agents/skills/", ".claude/skills/")


def main() -> int:
    base = sys.argv[1]
    skip_tests_rule = "--no-tests-label" in sys.argv
    files = changed_files(base)
    gd_files = [f for f in files if f.endswith(".gd") and not f.startswith(VENDORED)]
    ok = True

    if gd_files:
        ok &= run(["gdlint", *gd_files])
        ok &= run(["gdformat", "--check", "--line-length", LINE_LENGTH, *gd_files])
        long = [p for f in gd_files for p in long_functions(f)]
        for problem in long:
            print(problem)
        ok &= not long
    else:
        print("No GDScript files changed.")

    logic_changed = [f for f in gd_files if f.startswith(LOGIC_DIRS)]
    tests_changed = [f for f in files if f.startswith("tests/")]
    if logic_changed and not tests_changed:
        if skip_tests_rule:
            print("Code changed without tests; allowed by the 'no-tests-needed' label.")
        else:
            print("Code in core/ or systems/ changed but no file in tests/ changed:")
            for f in logic_changed:
                print("  " + f)
            print("Add or update a test, or add the 'no-tests-needed' label if this is visual-only.")
            ok = False

    print("Quality checks passed." if ok else "Quality checks failed. Fix the problems above.")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
