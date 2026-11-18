"""Check feature plans in docs/plans/ and the plan links in docs/ROADMAP.md."""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SKIP = {"README.md", "TEMPLATE.md"}
STATUSES = {"Draft", "Review", "Approved", "Building", "Done", "Dropped"}
APPROVED = {"Approved", "Building", "Done"}
NEEDS_LORE_LINE = {"Draft", "Review"}
SECTIONS = (
    "Goal",
    "Scope",
    "Ready to build",
    "Design references",
    "Systems touched",
    "Data",
    "Co-op behaviour",
    "Performance",
    "Steps",
    "Acceptance",
    "Risks",
    "Open decisions",
)
NONE_WORDS = {"", "none", "-", "n.a."}
LINK_RE = re.compile(r"\]\((plans/[^)#\s]+)")


def field(text: str, name: str) -> str | None:
    match = re.search(rf"^{name}:[ \t]*(.*)$", text, re.MULTILINE)
    return match.group(1).strip() if match else None


def section(text: str, name: str) -> str:
    match = re.search(rf"^## {re.escape(name)}\s*$(.*?)(?=^## |\Z)", text, re.MULTILINE | re.DOTALL)
    return match.group(1) if match else ""


def open_decisions(text: str) -> list[str]:
    body = re.sub(r"<!--.*?-->", "", section(text, "Open decisions"), flags=re.DOTALL)
    bullets = [line.strip()[1:].strip() for line in body.splitlines() if line.strip()[:1] in ("-", "*")]
    return [line for line in bullets if line.lower() not in NONE_WORDS and not line.startswith("[x]")]


def check_lore_link(name: str, text: str, status: str | None) -> list[str]:
    if status not in NEEDS_LORE_LINE:
        return []
    lore = field(text, "Lore link")
    if lore is None:
        return [f"{name}: missing 'Lore link:' line (see docs/plans/TEMPLATE.md)"]
    if status == "Review" and (lore.lower() in NONE_WORDS or lore.startswith("<")):
        return [f"{name}: 'Lore link:' must give the story reason, or 'none: <why>' for pure tech work"]
    return []


def check_plan(name: str, text: str) -> list[str]:
    problems: list[str] = []
    if not text.startswith("# Plan: "):
        problems.append(f"{name}: first line must be '# Plan: <feature name>'")
    status = field(text, "Status")
    if status not in STATUSES:
        problems.append(f"{name}: Status must be one of {', '.join(sorted(STATUSES))}, got {status!r}")
    for heading in SECTIONS:
        if not re.search(rf"^## {re.escape(heading)}\s*$", text, re.MULTILINE):
            problems.append(f"{name}: missing section '## {heading}'")
    problems += check_lore_link(name, text, status)
    if not re.search(r"^### Step 1\b", text, re.MULTILINE):
        problems.append(f"{name}: Steps needs at least '### Step 1: ...'")
    if status in APPROVED:
        approved_by = field(text, "Approved by") or ""
        if approved_by.lower() in NONE_WORDS or approved_by.startswith("<"):
            problems.append(f"{name}: Status {status} needs 'Approved by:' filled in")
        for line in open_decisions(text):
            problems.append(f"{name}: open decision left on an approved plan: {line}")
    return problems


def check_roadmap(text: str, plans_dir: Path) -> list[str]:
    missing = [link for link in LINK_RE.findall(text) if not (plans_dir.parent / link).is_file()]
    return [f"ROADMAP.md: plan link points to a missing file: {link}" for link in missing]


def check_all(docs: Path) -> list[str]:
    plans_dir = docs / "plans"
    problems: list[str] = []
    for path in sorted(plans_dir.glob("*.md")):
        if path.name not in SKIP:
            problems += check_plan(path.name, path.read_text(encoding="utf-8"))
    roadmap = docs / "ROADMAP.md"
    if roadmap.is_file():
        problems += check_roadmap(roadmap.read_text(encoding="utf-8"), plans_dir)
    return problems


def main() -> int:
    problems = check_all(ROOT / "docs")
    for problem in problems:
        print(problem)
    print("Plan checks failed. See docs/plans/README.md." if problems else "Plan checks passed.")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
