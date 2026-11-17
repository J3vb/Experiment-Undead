"""gun_bake.py: a small bake of a real gun, the committed bake still matches its source shapes.

Run from the repo root: python -m pytest tools/assets/tests/test_gun_bake.py
"""

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import bpy

# isort: split
import build_models
import check_models
import gun_bake
import numpy
import pytest

REPO = build_models.REPO
RECORDS = os.path.join(REPO, "assets", "textures", "weapons")


def record(name: str) -> dict:
    with open(os.path.join(RECORDS, f"{name}_bake.json"), encoding="utf-8") as handle:
        return json.load(handle)


def overlapping_texels(parts: list, grid: int = 512) -> int:
    """Texel centres covered by more than one UV triangle across all parts."""
    cover = numpy.zeros((grid, grid), dtype=numpy.int32)
    centres = (numpy.arange(grid) + 0.5) / grid
    for obj in parts:
        mesh = obj.data
        uv = mesh.uv_layers["UVMap"].data
        mesh.calc_loop_triangles()
        for tri in mesh.loop_triangles:
            a, b, c = (numpy.array(uv[i].uv) for i in tri.loops)
            lo = numpy.floor(numpy.minimum(numpy.minimum(a, b), c) * grid).astype(int).clip(0, grid - 1)
            hi = numpy.ceil(numpy.maximum(numpy.maximum(a, b), c) * grid).astype(int).clip(0, grid)
            if hi[0] <= lo[0] or hi[1] <= lo[1]:
                continue
            xs, ys = numpy.meshgrid(centres[lo[0] : hi[0]], centres[lo[1] : hi[1]])
            d = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
            if abs(d) < 1e-12:
                continue
            w1 = ((b[1] - c[1]) * (xs - c[0]) + (c[0] - b[0]) * (ys - c[1])) / d
            w2 = ((c[1] - a[1]) * (xs - c[0]) + (a[0] - c[0]) * (ys - c[1])) / d
            inside = (w1 > 1e-4) & (w2 > 1e-4) & (1.0 - w1 - w2 > 1e-4)
            cover[lo[1] : hi[1], lo[0] : hi[0]] += inside
    return int((cover > 1).sum())


@pytest.fixture(scope="module")
def small_bake(tmp_path_factory):
    out = str(tmp_path_factory.mktemp("bake"))
    tris = gun_bake.bake_gun("rifle_ar", out, out, 64, 1)
    parts = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    return out, tris, parts


def test_every_baked_gun_has_a_record_and_a_model_script() -> None:
    for name, script in build_models.BAKED.items():
        assert os.path.exists(os.path.join(REPO, "tools", "assets", f"{script}.py"))
        assert f"tools/assets/{script}.py" in record(name)["inputs"]


def test_committed_bake_matches_the_gun_shapes_built_today() -> None:
    """gun_parts.py or the gun script changed the shapes: re-run gun_bake.py."""
    for name in build_models.BAKED:
        build_models.reset_scene()
        build_models.MODELS[name][1]()
        assert gun_bake.fingerprint() == record(name)["source"], f"re-bake {name}"


def test_bake_writes_three_maps_and_a_record(small_bake) -> None:
    out, tris, _ = small_bake
    for kind in gun_bake.MAP_KINDS:
        assert os.path.exists(gun_bake.map_path("rifle_ar", kind, out))
    data = json.load(open(os.path.join(out, "rifle_ar_bake.json"), encoding="utf-8"))
    assert data["map_size"] == 64 and data["triangles"] == tris


def test_normal_map_carries_the_soft_edges(small_bake) -> None:
    out, _, _ = small_bake
    image = bpy.data.images.load(gun_bake.map_path("rifle_ar", "normal", out))
    pixels = gun_bake.pixels(image)
    tilted = numpy.abs(pixels[:, :, 0] - 0.5) + numpy.abs(pixels[:, :, 1] - 0.5)
    assert (tilted > 0.08).mean() > 0.01, "bevels and stipple bend the normal somewhere"


def test_baked_gun_has_one_material_and_stays_in_budget(small_bake) -> None:
    out, tris, parts = small_bake
    source = json.load(open(os.path.join(out, "rifle_ar_bake.json"), encoding="utf-8"))["source"]
    assert tris <= check_models.BUDGETS["weapons"][0]
    assert tris > source["triangles"], "the chamfer adds real edge geometry"
    names = {slot.material.name for obj in parts for slot in obj.material_slots}
    assert names == {gun_bake.BAKED, "SightGlass"}


def test_parts_share_one_uv_sheet_without_overlaps(small_bake) -> None:
    _, _, parts = small_bake
    baked = [o for o in parts if o.material_slots[0].material.name == gun_bake.BAKED]
    assert overlapping_texels(baked) == 0, "moving parts would bake onto each other"


def test_material_names_pick_the_finish() -> None:
    assert gun_bake.finish_of("TanKnurledWorn") == (2, gun_bake.WORN_WEAR, gun_bake.WORN_GRIME, True)
    assert gun_bake.finish_of("GunMetal") == (0, 1.0, 0.0, False)
    with pytest.raises(SystemExit):
        gun_bake.finish_of("Chrome")


def test_baked_glb_passes_the_model_rules(small_bake) -> None:
    """Runs last: loading the glb replaces the scene the other tests read."""
    out, _, _ = small_bake
    assert check_models.check_model(os.path.join(out, build_models.MODELS["rifle_ar"][0])) == []
