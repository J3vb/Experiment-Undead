"""Town NPCs keep the survivor body contract (bones, scale, budget, materials) from source to baked glTF."""

import json
import os
import struct
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import bpy

# isort: split
import character_checks
import character_rig
import check_models
import pytest
from town_npcs.build import NPCS, build_npc

MATERIALS = {"BodySkin", "BodyHair", "BodyCloth", "BodyRubber"}
CASES = [(name, version) for name in NPCS for version in ("source", "committed")]


def glb_path(name: str) -> str:
    return os.path.join(check_models.REPO, f"assets/models/characters/npc_{name}.glb")


@pytest.fixture(scope="module", params=CASES, ids=[f"{name}-{version}" for name, version in CASES])
def npc(request):
    name, version = request.param
    bpy.ops.wm.read_factory_settings(use_empty=True)
    if version == "source":
        build_npc(name)
    else:
        check_models.load_glb(glb_path(name))
    bpy.context.view_layer.update()
    return name, list(bpy.context.scene.objects)


def test_npc_passes_the_character_rules(npc):
    name, objects = npc
    assert character_checks.check(objects, "characters", f"npc_{name}") == []
    assert check_models.check_geometry(objects, "characters") == []


def test_npc_scale_budget_materials_and_bones(npc):
    _name, objects = npc
    parts = [obj for obj in objects if obj.type == "MESH"]
    low, high = check_models.bounds(parts)
    assert 1.70 <= high.z - low.z <= 1.85
    assert low.z == pytest.approx(0.0, abs=0.01)
    triangles = sum(len(face.vertices) - 2 for obj in parts for face in obj.data.polygons)
    assert 8_000 <= triangles <= 16_000
    assert {mat.name for obj in parts for mat in obj.data.materials} == MATERIALS
    armature = next(obj for obj in objects if obj.type == "ARMATURE")
    assert set(armature.data.bones.keys()) == character_rig.BONES.keys()


def test_every_npc_part_has_a_texture_look():
    for look, dress in NPCS.values():
        bpy.ops.wm.read_factory_settings(use_empty=True)
        from player_body.build import materials

        clothes = dress(materials(look))
        names = {obj.name.split(".")[0] for obj in clothes["cloth"] + clothes["head"]}
        names |= {obj.name.split(".")[0] for sign in (1, -1) for obj in clothes["arms"][sign]}
        known = {part for spec in look["textures"].values() for part in spec[7]}
        assert names <= known, names - known


@pytest.mark.parametrize("name", list(NPCS))
def test_committed_npc_carries_one_set_of_baked_maps(name):
    with open(glb_path(name), "rb") as glb:
        glb.seek(12)
        length, _kind = struct.unpack("<II", glb.read(8))
        document = json.loads(glb.read(length))
    assert {material["name"] for material in document["materials"]} == MATERIALS
    assert len(document["images"]) == 3, "colour, normal and roughness maps, shared by the four materials"
    assert all(image["mimeType"] == "image/jpeg" for image in document["images"])
    assert not document.get("animations"), "step 1 exports the rest pose only; clips come in F-76 step 3"
