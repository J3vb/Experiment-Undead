"""Generated grip metadata travels with its GLB, including alternate build directories."""

import json
import os
import re
import sys
from pathlib import Path
from types import SimpleNamespace

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import build_models
import pytest


def exporter(monkeypatch, metadata, callback):
    scene = {} if metadata is None else {"player_arm_grips": metadata}
    fake = SimpleNamespace(
        context=SimpleNamespace(scene=scene), ops=SimpleNamespace(export_scene=SimpleNamespace(gltf=callback))
    )
    monkeypatch.setattr(build_models, "bpy", fake)


def test_metadata_is_written_beside_the_successful_glb_in_the_selected_directory(monkeypatch, tmp_path):
    calls = []
    payload = {"version": 1, "profiles": {"rifle_ar": {"morph": "", "R": {"center": [-0.675, -0.045, 0.985]}}}}
    exporter(monkeypatch, json.dumps(payload), lambda **options: calls.append(options))
    target = tmp_path / "alternate" / "characters" / "player_arms.glb"
    build_models.export(str(target))
    assert calls[0]["filepath"] == str(target)
    companion = target.with_name("player_arm_grips.json")
    assert json.loads(companion.read_text()) == payload
    assert companion.read_text().endswith("\n")


def test_other_model_exports_do_not_write_character_metadata(monkeypatch, tmp_path):
    exporter(monkeypatch, None, lambda **_options: None)
    build_models.export(str(tmp_path / "other.glb"))
    assert not (tmp_path / "player_arm_grips.json").exists()


@pytest.mark.parametrize("metadata", ['{"coordinate": NaN}', '{"coordinate": Infinity}', "invalid"])
def test_invalid_metadata_fails_before_exporting_the_glb(monkeypatch, tmp_path, metadata):
    calls = []
    exporter(monkeypatch, metadata, lambda **options: calls.append(options))
    with pytest.raises(ValueError):
        build_models.export(str(tmp_path / "player_arms.glb"))
    assert calls == []
    assert not (tmp_path / "player_arm_grips.json").exists()


def test_a_failed_glb_export_does_not_replace_its_companion_metadata(monkeypatch, tmp_path):
    companion = tmp_path / "player_arm_grips.json"
    companion.write_text('{"version": 1}\n')

    def fail(**_options):
        raise RuntimeError("export failed")

    exporter(monkeypatch, '{"version": 2}', fail)
    with pytest.raises(RuntimeError, match="export failed"):
        build_models.export(str(tmp_path / "player_arms.glb"))
    assert companion.read_text() == '{"version": 1}\n'


def test_every_game_export_includes_the_raw_grip_metadata():
    text = Path(build_models.REPO, "export_presets.cfg").read_text()
    presets = re.findall(r"(?ms)^\[preset\.\d+\]\n(.*?)(?=^\[|\Z)", text)
    assert presets, "the metadata must ship in real game export presets"
    for preset in presets:
        included = re.search(r'^include_filter="([^"]*)"$', preset, re.MULTILINE)
        assert included is not None
        assert "assets/models/characters/player_arm_grips.json" in included.group(1).split(",")
