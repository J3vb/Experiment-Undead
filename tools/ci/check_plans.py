"""Check feature plans in docs/plans/ and the plan links in docs/ROADMAP.md."""

import os
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SKIP = {"README.md", "TEMPLATE.md"}
STATUSES = {"Draft", "Review", "Approved", "Building", "Done", "Dropped"}
APPROVED = {"Approved", "Building", "Done"}
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
PLAN_LINE_RE = re.compile(r"^Plan:[ \t]*(.*)$", re.MULTILINE)
PLAN_PATH_RE = re.compile(r"docs/plans/[\w.-]+\.md")


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


def check_pr_body(body: str, docs: Path) -> list[str]:
    """A PR labelled `new` names its plan step, or says why it needs none."""
    match = PLAN_LINE_RE.search(re.sub(r"<!--.*?-->", "", body, flags=re.DOTALL))
    value = match.group(1).strip() if match else ""
    if value.lower().startswith("none:") and len(value) > len("none:"):
        return []
    path = PLAN_PATH_RE.search(value)
    if not path:
        return ["PR body needs 'Plan: docs/plans/<file>.md, step N' or 'Plan: none: <why>'"]
    if not (docs.parent / path.group(0)).is_file():
        return [f"PR body names a plan that does not exist: {path.group(0)}"]
    return []


def main() -> int:
    problems = check_all(ROOT / "docs")
    if "--pr-body" in sys.argv and "new" in os.environ.get("PR_LABELS", "").split(","):
        problems += check_pr_body(os.environ.get("PR_BODY", ""), ROOT / "docs")
    for problem in problems:
        print(problem)
    print("Plan checks failed. See docs/plans/README.md." if problems else "Plan checks passed.")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
