"""Checks that the model build matches the model list (MODELS in build_models.py).

Run from the repo root:
    python tools/assets/build_models.py --out /tmp/models
    python tools/assets/check_outputs.py --built /tmp/models

Fails when a MODELS entry was not built, or a committed .glb under
assets/models/ is not a MODELS entry or a Tripo manifest row in tools/assets/tripo/ (a stray or renamed file).
"""

import argparse
import glob
import json
import os
import sys

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
TRIPO = os.path.join(REPO, "tools", "assets", "tripo")


def tripo_models(manifest_dir: str, made_only: bool = False) -> list:
    """Paths of the Tripo models (ADR 0017): one manifest row each, made by tripo_make.py, not built.
    `made_only` keeps the rows already made (committed); the others still wait for an image or a run."""
    paths = []
    for manifest in sorted(glob.glob(os.path.join(manifest_dir, "*.json"))):
        with open(manifest, encoding="utf-8") as rows:
            paths += [f"{r['folder']}/{r['name']}.glb" for r in json.load(rows) if r.get("made") or not made_only]
    return paths


def missing_outputs(expected: list, built_dir: str) -> list:
    """MODELS paths with no non-empty file in `built_dir`."""
    missing = []
    for rel_path in sorted(expected):
        path = os.path.join(built_dir, rel_path)
        if not os.path.isfile(path) or os.path.getsize(path) == 0:
            missing.append(rel_path)
    return missing


def stray_models(expected: list, models_dir: str) -> list:
    """Committed .glb files under `models_dir` that no MODELS entry builds."""
    known = {os.path.normpath(p) for p in expected}
    found = glob.glob(os.path.join(models_dir, "**", "*.glb"), recursive=True)
    return sorted(rel for rel in (os.path.relpath(p, models_dir) for p in found) if os.path.normpath(rel) not in known)


def main(argv: list, expected: list | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--built", required=True, help="folder build_models.py --out wrote to")
    parser.add_argument("--committed", default=os.path.join(REPO, "assets", "models"))
    args = parser.parse_args(argv)
    if expected is None:
        import build_models

        expected = [rel_path for rel_path, _build in build_models.MODELS.values()]
    errors = [f"not built: {p} (its build failed or wrote elsewhere)" for p in missing_outputs(expected, args.built)]
    errors += [
        f"not in MODELS: {p} (add it to its family script's MODELS, or delete the file)"
        for p in stray_models(expected + tripo_models(TRIPO), args.committed)
    ]
    for error in errors:
        print(error)
    print(f"{len(expected)} models in MODELS, {len(errors)} problems")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
