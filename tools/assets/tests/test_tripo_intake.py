"""tripo_intake.py: a heavy textured source comes out on budget, placed, with three maps, and rigged when a character.

Run from the repo root: python -m pytest tools/assets/tests/test_tripo_intake.py
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import bpy

# isort: split
import bmesh
import character_checks
import check_models
import numpy
import pytest
import tripo_intake
from player_body.build import build_player


def checker_material(name: str):
    image = bpy.data.images.new(f"{name}_tex", 64, 64)
    y, x = numpy.mgrid[0:64, 0:64]
    data = numpy.ones((64, 64, 4), numpy.float32)
    data[..., 0] = (x // 8 % 2) * 0.7 + 0.1
    data[..., 2] = (y // 8 % 2) * 0.7 + 0.1
    image.pixels.foreach_set(data.ravel())
    image.pack()
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    node = material.node_tree.nodes.new("ShaderNodeTexImage")
    node.image = image
    material.node_tree.links.new(node.outputs[0], material.node_tree.nodes["Principled BSDF"].inputs["Base Color"])
    return material


def export_source(path: str) -> None:
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB")


def prop_source(path: str) -> int:
    """A 49k-triangle bumpy box, off-centre and turned, like an unplaced Tripo export."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(3.0, 2.0, 1.0), rotation=(0.0, 0.0, math.pi / 2))
    obj = bpy.context.active_object
    obj.scale = (0.6, 0.4, 0.45)
    mod = obj.modifiers.new("Subdivide", "SUBSURF")
    mod.levels, mod.subdivision_type = 6, "SIMPLE"
    bpy.ops.object.modifier_apply(modifier=mod.name)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    for vert in bm.verts:
        vert.co += vert.normal * 0.02 * math.sin(vert.co.x * 40) * math.sin(vert.co.z * 40)
    bm.to_mesh(obj.data)
    bm.free()
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.uv.smart_project()
    bpy.ops.object.mode_set(mode="OBJECT")
    obj.data.materials.append(checker_material("TripoProp"))
    export_source(path)
    return len(obj.data.polygons) * 2


def character_source(path: str) -> None:
    """The code-built survivor body as a bare mesh: no skeleton, no weights, like an unrigged Tripo export."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    build_player(clips=False)
    for obj in list(bpy.context.scene.objects):
        if obj.name != "Body":
            bpy.data.objects.remove(obj)
            continue
        world = obj.matrix_world.copy()
        obj.parent = None
        obj.matrix_world = world
        for modifier in list(obj.modifiers):
            obj.modifiers.remove(modifier)
        obj.vertex_groups.clear()
    export_source(path)


@pytest.fixture(scope="module")
def prop(tmp_path_factory):
    folder = tmp_path_factory.mktemp("tripo_prop")
    source = str(folder / "source.glb")
    source_tris = prop_source(source)
    args = tripo_intake.parse([source, "--name", "crate", "--height", "0.9", "--out", str(folder)])
    args.size, args.samples = 256, 2
    summary = tripo_intake.run(args)
    return source_tris, summary


@pytest.fixture(scope="module")
def character(tmp_path_factory):
    folder = tmp_path_factory.mktemp("tripo_character")
    source = str(folder / "source.glb")
    character_source(source)
    args = tripo_intake.parse([source, "--kind", "character", "--name", "keeper", "--out", str(folder)])
    args.size, args.samples = 256, 2
    return tripo_intake.run(args)


def test_prop_is_decimated_to_budget_and_placed(prop):
    source_tris, summary = prop
    assert source_tris > 40_000
    objects = check_models.load_glb(summary["model"])
    assert check_models.check_geometry(objects, "props") == []
    assert check_models.check_origin(objects, "props") == []
    lo, hi = check_models.bounds(objects)
    assert hi.z - lo.z == pytest.approx(0.9, abs=0.01)


def test_prop_has_one_material_and_three_maps(prop):
    _source_tris, summary = prop
    objects = check_models.load_glb(summary["model"])
    names = {m.name for obj in objects if obj.type == "MESH" for m in obj.data.materials}
    assert names == {tripo_intake.BAKED}
    for key in ("albedo", "normal", "orm"):
        assert os.path.getsize(summary[key]) > 0


def test_prop_bake_keeps_the_source_colours(prop):
    _source_tris, summary = prop
    image = bpy.data.images.load(summary["albedo"])
    data = numpy.array(image.pixels[:], numpy.float32).reshape(-1, 4)
    assert data[:, 0].std() > 0.15, "the checker pattern did not transfer"


def test_character_is_on_our_skeleton_with_the_clips(character):
    objects = check_models.load_glb(character["model"])
    assert check_models.check_geometry(objects, "characters") == []
    assert character_checks.check(objects, "characters", "player") == []
    armature = next(obj for obj in objects if obj.type == "ARMATURE")
    assert {bone.name for bone in armature.data.bones} >= {"pelvis", "head", "hand_L", "foot_R"}
    assert len(armature.data.bones) == 22
    assert {"idle", "walk_fwd", "run"} <= {action.name for action in bpy.data.actions}


def test_every_character_vertex_is_weighted(character):
    objects = check_models.load_glb(character["model"])
    body = next(obj for obj in objects if obj.type == "MESH")
    assert all(sum(g.weight for g in v.groups) > 0.5 for v in body.data.vertices)
