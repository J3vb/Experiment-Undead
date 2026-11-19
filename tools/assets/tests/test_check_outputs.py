"""check_outputs.py: the build and the committed models match the MODELS list.

Run from the repo root: python -m pytest tools/assets/tests
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import check_outputs

EXPECTED = ["kit/wall_panel.glb", "props/crate_stack.glb"]


def write(root, rel_path: str, data: bytes = b"glTF") -> None:
    path = root / rel_path
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)


def run(tmp_path) -> int:
    built, committed = tmp_path / "built", tmp_path / "committed"
    built.mkdir(exist_ok=True)
    committed.mkdir(exist_ok=True)
    return check_outputs.main(["--built", str(built), "--committed", str(committed)], EXPECTED)


def test_full_build_and_matching_commit_pass(tmp_path):
    for rel_path in EXPECTED:
        write(tmp_path / "built", rel_path)
        write(tmp_path / "committed", rel_path)
    assert run(tmp_path) == 0


def test_missing_build_output_fails(tmp_path):
    write(tmp_path / "built", "kit/wall_panel.glb")
    assert check_outputs.missing_outputs(EXPECTED, str(tmp_path / "built")) == ["props/crate_stack.glb"]
    assert run(tmp_path) == 1


def test_empty_build_output_fails(tmp_path):
    write(tmp_path / "built", "kit/wall_panel.glb")
    write(tmp_path / "built", "props/crate_stack.glb", b"")
    assert check_outputs.missing_outputs(EXPECTED, str(tmp_path / "built")) == ["props/crate_stack.glb"]


def test_stray_committed_glb_fails(tmp_path):
    for rel_path in EXPECTED:
        write(tmp_path / "built", rel_path)
    write(tmp_path / "committed", "props/old_crate.glb")
    write(tmp_path / "committed", "props/old_crate.glb.import", b"")
    assert check_outputs.stray_models(EXPECTED, str(tmp_path / "committed")) == [os.path.join("props", "old_crate.glb")]
    assert run(tmp_path) == 1


def test_real_model_list_matches_committed_models():
    import build_models

    expected = [rel_path for rel_path, _build in build_models.MODELS.values()]
    expected += check_outputs.tripo_models(check_outputs.TRIPO)
    assert check_outputs.stray_models(expected, os.path.join(check_outputs.REPO, "assets", "models")) == []


def test_tripo_manifest_rows_are_not_strays(tmp_path):
    manifests = tmp_path / "tripo"
    manifests.mkdir()
    (manifests / "town.json").write_text('[{"name": "stall_trader", "folder": "town_large"}]', encoding="utf-8")
    write(tmp_path / "committed", "town_large/stall_trader.glb")
    found = check_outputs.tripo_models(str(manifests))
    assert found == ["town_large/stall_trader.glb"]
    assert check_outputs.stray_models(EXPECTED + found, str(tmp_path / "committed")) == []


def test_every_committed_tripo_model_has_a_file():
    for rel_path in check_outputs.tripo_models(check_outputs.TRIPO):
        assert os.path.isfile(os.path.join(check_outputs.REPO, "assets", "models", rel_path)), rel_path
