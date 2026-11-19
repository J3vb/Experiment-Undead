"""tripo_intake.py: a heavy textured source comes out on budget, placed, with three maps, and rigged when a character.

Run from the repo root: python -m pytest tools/assets/tests/test_tripo_intake.py
"""

import json
import math
import os
import struct
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
from mathutils import Vector
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


def test_mixamo_joints_move_our_bones():
    """Mixamo names map one to one: LeftArm is the upper arm, LeftForeArm the forearm, LeftLeg the shin."""
    import character_rig
    import tripo_rig
    from mathutils import Matrix, Vector

    bpy.ops.wm.read_factory_settings(use_empty=True)
    source = character_rig.build_armature("Source")
    names = {
        f"{ours}_{side}": tripo_rig.MIXAMO[ours].format(s=word)
        for ours in ("upperarm", "forearm", "thigh", "shin")
        for side, word in tripo_rig.SIDES.items()
    }
    names.update(pelvis="Hips", neck="Neck", head="Head")
    for ours, theirs in names.items():
        source.data.bones[ours].name = f"mixamorig:{theirs}"
    joints = tripo_rig.source_joints(source, Matrix.Translation((0.0, 0.0, 0.1)))
    assert set(joints) == set(names)
    rest = character_rig.BONES
    assert joints["forearm_L"] == Vector(rest["forearm_L"][1]) + Vector((0.0, 0.0, 0.1))
    assert joints["shin_R"] == Vector(rest["shin_R"][1]) + Vector((0.0, 0.0, 0.1))
    arm = character_rig.build_armature()
    assert tripo_rig.fit(arm, joints) == len(names)


def mixamo_source(path: str) -> None:
    """The survivor body skinned to a T-posed skeleton with Mixamo names, like Tripo's Humanoid / Mixamo rig."""
    import character_rig
    import tripo_rig

    character_source(path)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=path)
    body = next(obj for obj in bpy.context.scene.objects if obj.type == "MESH")
    arm = character_rig.build_armature("Armature")
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    for side, sign in (("L", 1.0), ("R", -1.0)):
        shoulder = arm.data.edit_bones[f"upperarm_{side}"].head.copy()
        for part, start, end in (("upperarm", 0.0, 0.3), ("forearm", 0.3, 0.58), ("hand", 0.58, 0.72)):
            bone = arm.data.edit_bones[f"{part}_{side}"]
            bone.head = shoulder + Vector((sign * start, 0.0, 0.0))
            bone.tail = shoulder + Vector((sign * end, 0.0, 0.0))
    bpy.ops.object.mode_set(mode="OBJECT")
    character_rig.bind(body, arm, blend=0.08)
    body.parent = arm
    for ours, theirs in tripo_rig._targets().items():
        arm.data.bones[ours].name = f"mixamorig:{theirs}"
    extra = {"spine_01": "Spine", "spine_02": "Spine1", "spine_03": "Spine2"}
    extra.update(clavicle_L="LeftShoulder", clavicle_R="RightShoulder")
    for ours, theirs in extra.items():
        arm.data.bones[ours].name = f"mixamorig:{theirs}"
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB")


def test_rigged_tripo_body_is_swung_to_our_rest_and_keeps_its_skin(tmp_path, capfd):
    import tripo_rig

    source = str(tmp_path / "rigged.glb")
    mixamo_source(source)
    args = tripo_intake.parse([source, "--kind", "character", "--name", "rigged", "--out", str(tmp_path)])
    args.size, args.samples = 128, 1
    summary = tripo_intake.run(args)
    assert "kept the source skin weights" in capfd.readouterr().out
    objects = check_models.load_glb(summary["model"])
    assert character_checks.check(objects, "characters", "player") == []
    armature = next(obj for obj in objects if obj.type == "ARMATURE")
    for side in tripo_rig.SIDES:
        bone = armature.data.bones[f"upperarm_{side}"]
        rest = tripo_rig.character_rig.BONES[f"upperarm_{side}"]
        want = (Vector(rest[2]) - Vector(rest[1])).normalized()
        assert (bone.tail_local - bone.head_local).normalized().dot(want) > 0.98
    body = next(obj for obj in objects if obj.type == "MESH")
    assert all(sum(g.weight for g in v.groups) > 0.5 for v in body.data.vertices)


def test_embedded_jpegs_have_no_icc_profile(prop):
    """Godot's JPEG loader rejects ICC (APP2) segments, which left the albedo blank in the game."""
    _source_tris, summary = prop
    with open(summary["model"], "rb") as glb:
        data = glb.read()
    length = struct.unpack("<I", data[12:16])[0]
    document = json.loads(data[20 : 20 + length])
    binary = data[28 + length :]
    for image in document["images"]:
        view = document["bufferViews"][image["bufferView"]]
        jpeg = binary[view.get("byteOffset", 0) : view.get("byteOffset", 0) + view["byteLength"]]
        assert b"ICC_PROFILE" not in jpeg


def test_forearm_twist_turns_the_thumb_like_our_player_rest_hand():
    """Tripo's T-pose palms face down; after the swing the thumb must point where our rest hand's does
    (up and out, a little forward), or every clip turns her hands the wrong way."""
    import tripo_rig

    bpy.ops.wm.read_factory_settings(use_empty=True)
    arm = bpy.data.objects.new("Armature", bpy.data.armatures.new("Armature"))
    bpy.context.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    rest = tripo_rig.character_rig.BONES["upperarm_L"]
    direction = (Vector(rest[2]) - Vector(rest[1])).normalized()
    parts = {}
    for name, head, tail in (
        ("LeftForeArm", (0.0, 0.0, 0.0), direction * 0.25),
        ("LeftHand", direction * 0.25, direction * 0.35),
        ("LeftHandThumb2", direction * 0.27 + Vector((0.0, -0.04, 0.0)), direction * 0.27 + Vector((0.0, -0.08, 0.0))),
    ):
        bone = arm.data.edit_bones.new(f"mixamorig:{name}")
        bone.head, bone.tail = head, tail
        parts[name] = bone
    parts["LeftHand"].parent = parts["LeftForeArm"]
    parts["LeftHandThumb2"].parent = parts["LeftHand"]
    bpy.ops.object.mode_set(mode="POSE")
    bones = {tripo_rig._plain(b.name): b for b in arm.pose.bones}
    tripo_rig._turn_thumb_up(arm, bones, "left", direction)
    thumb = (bones["lefthandthumb2"].head - bones["lefthand"].head).normalized()
    up = Vector((0.0, 0.0, 1.0))
    want = (up - direction * up.dot(direction)).normalized() * 0.86 + Vector((0.0, -0.51, 0.0))
    assert (thumb - direction * thumb.dot(direction)).normalized().dot(want.normalized()) > 0.99
    bpy.ops.object.mode_set(mode="OBJECT")


def test_large_kind_fits_the_building_budget():
    tris, size, height = tripo_intake.KINDS["large"]
    assert tris <= check_models.BUDGETS["town_large"][0]
    assert tris <= check_models.BUDGETS["props_large"][0]
    assert (size, height) == (2048, None)


def test_length_scales_the_longest_side_and_folder_writes_into_assets(tmp_path, monkeypatch):
    """Snapping pieces (track, guard rail, fence) are sized by length, and --folder skips the copy step."""
    source = str(tmp_path / "source.glb")
    prop_source(source)
    monkeypatch.setattr(tripo_intake, "MODELS", str(tmp_path / "models"))
    argv = [source, "--name", "rail", "--length", "3.0", "--folder", "props", "--out", str(tmp_path / "maps")]
    args = tripo_intake.parse(argv)
    args.size, args.samples = 128, 1
    summary = tripo_intake.run(args)
    assert summary["model"] == str(tmp_path / "models" / "props" / "rail.glb")
    lo, hi = check_models.bounds(check_models.load_glb(summary["model"]))
    assert max(hi - lo) == pytest.approx(3.0, abs=0.02)
    assert lo.z == pytest.approx(0.0, abs=0.01)
    assert os.path.isfile(str(tmp_path / "maps" / "rail" / "rail_albedo.png"))


def test_make_low_stays_on_budget_and_keeps_the_bottom_on_the_floor():
    """Hundreds of small islands: the collapse moves the lowest point, so the copy is put back on the floor."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bm = bmesh.new()
    for i in range(300):
        sphere = bmesh.ops.create_icosphere(bm, subdivisions=3, radius=0.02)
        for vert in sphere["verts"]:
            vert.co += Vector(((i % 20) * 0.06, (i // 20) * 0.06, 0.02 + (i % 7) * 0.01))
    mesh = bpy.data.meshes.new("islands")
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new("islands", mesh)
    bpy.context.collection.objects.link(obj)
    low = tripo_intake.make_low(obj, 2_000)
    assert tripo_intake.triangle_count(low) <= 2_000
    assert tripo_intake.world_bounds(low)[0].z == pytest.approx(0.0, abs=1e-6)


def test_make_low_gets_past_edges_shared_by_three_faces():
    """Fins standing on a grid share its edges with two floor faces; the collapse alone stalls far above budget."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bm = bmesh.new()
    size = 40
    grid = [[bm.verts.new((x * 0.05, y * 0.05, 0.0)) for x in range(size + 1)] for y in range(size + 1)]
    for y in range(size):
        for x in range(size):
            bm.faces.new((grid[y][x], grid[y][x + 1], grid[y + 1][x + 1], grid[y + 1][x]))
    up = Vector((0.0, 0.0, 0.05))
    for y in range(1, size):
        for x in range(size):
            a, b = grid[y][x], grid[y][x + 1]
            bm.faces.new((a, b, bm.verts.new(b.co + up), bm.verts.new(a.co + up)))
    mesh = bpy.data.meshes.new("fins")
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new("fins", mesh)
    bpy.context.collection.objects.link(obj)
    assert tripo_intake.triangle_count(tripo_intake.make_low(obj, 600)) <= 600
