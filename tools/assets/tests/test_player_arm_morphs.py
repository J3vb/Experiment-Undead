"""Grip morphs survive joining, mesh cleanup, skinning and the production glTF export."""

import json
import os
import struct
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import body_parts as soft
import bpy
import build_models
import character_rig as rig
import player_arm_morphs as morphs
import pytest
from mathutils import Vector


@pytest.fixture(autouse=True)
def empty_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def part(name, centre=(0, 0, 0), changed=False):
    vertices = [(x, y, z) for z in (0, 0.04) for x, y in ((-0.02, -0.02), (0.02, -0.02), (0.02, 0.02), (-0.02, 0.02))]
    if changed:
        vertices[-1] = (-0.01, 0.025, 0.035)
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], [(0, 3, 2, 1), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7), (4, 5, 6, 7)])
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.location = centre
    for material in ("BodyRubber", "BodyKnit"):
        mesh.materials.append(bpy.data.materials.get(material) or bpy.data.materials.new(material))
    for face in mesh.polygons:
        face.material_index = face.index % 2
        face.use_smooth = True
    return obj


def world_points(obj, key=None):
    vertices = obj.data.vertices if key is None else obj.data.shape_keys.key_blocks[key].data
    return [obj.matrix_world @ vertex.co for vertex in vertices]


def test_variant_uses_world_coordinates_and_preserves_the_default_rest_mesh():
    base = part("Base", (-0.65, 0, 1.0))
    variant = part("Variant", (-0.64, -0.003, 1.01), changed=True)
    base.rotation_euler.z, variant.rotation_euler.z = 0.2, -0.3
    base.scale, variant.scale = (1.2, 0.8, 1.0), (0.9, 1.1, 1.0)
    bpy.context.view_layer.update()
    rest, desired = world_points(base), world_points(variant)
    transform = base.matrix_world.copy()
    morphs.add_variant([base], [variant], "Pump")
    assert bpy.data.objects.get("Variant") is None
    assert base.matrix_world == transform
    assert base.data.shape_keys.use_relative
    assert list(base.data.shape_keys.key_blocks.keys()) == ["Basis", "Pump"]
    key = base.data.shape_keys.key_blocks["Pump"]
    assert key.value == 0 and key.relative_key.name == "Basis"
    for current, original, target, expected in zip(
        world_points(base), rest, world_points(base, "Pump"), desired, strict=True
    ):
        assert (current - original).length < 1e-7
        assert (target - expected).length < 1e-7


@pytest.mark.parametrize("invalid", ["count", "vertices", "connectivity", "material", "duplicate_name"])
def test_incompatible_variants_fail_before_any_key_or_object_is_changed(invalid):
    bases = [part("BaseA"), part("BaseB", (0.1, 0, 0))]
    variants = [part("VariantA", changed=True), part("VariantB", (0.1, 0, 0), changed=True)]
    if invalid == "count":
        variants = variants[:1]
    elif invalid == "vertices":
        variants[1].data.vertices.add(1)
    elif invalid == "connectivity":
        variants[1].data.polygons[0].flip()
    elif invalid == "material":
        variants[1].data.polygons[0].material_index = 1
    elif invalid == "duplicate_name":
        bases[1].shape_key_add(name="Basis")
        bases[1].shape_key_add(name="Pump")
    names = [variant.name for variant in variants]
    positions = [tuple(vertex.co) for vertex in bases[0].data.vertices]
    with pytest.raises(ValueError, match="arm morph"):
        morphs.add_variant(bases, variants, "Pump")
    assert bases[0].data.shape_keys is None
    assert [tuple(vertex.co) for vertex in bases[0].data.vertices] == positions
    assert all(bpy.data.objects.get(name) is not None for name in names)


def test_adding_another_profile_preserves_the_existing_basis_and_target():
    base = part("Base")
    morphs.add_variant([base], [part("CompactVariant", changed=True)], "CompactGrip")
    before = {key.name: [tuple(vertex.co) for vertex in key.data] for key in base.data.shape_keys.key_blocks}
    morphs.add_variant([base], [part("PumpVariant", (0, 0.003, 0), changed=True)], "PumpGrip")
    keys = base.data.shape_keys.key_blocks
    assert list(keys.keys()) == ["Basis", "CompactGrip", "PumpGrip"]
    for name, vertices in before.items():
        assert [tuple(vertex.co) for vertex in keys[name].data] == vertices
    assert all(key.value == 0 and key.relative_key == keys["Basis"] for key in list(keys)[1:])


def joined_parts():
    bases = [part("First", (-0.66, 0, 1.0)), part("Second", (-0.71, -0.05, 0.95))]
    variants = [part("FirstVariant", (-0.66, 0, 1.0), True), part("SecondVariant", (-0.71, -0.05, 0.95), True)]
    bpy.context.view_layer.update()
    expected = [
        (point.copy(), target.copy())
        for base, variant in zip(bases, variants, strict=True)
        for point, target in zip(world_points(base), world_points(variant), strict=True)
    ]
    morphs.add_variant(bases, variants, "CompactGrip")
    static = part("StaticCuff", (-0.60, 0.06, 1.05))
    bpy.context.view_layer.update()
    expected += [(point.copy(), point.copy()) for point in world_points(static)]
    build_models.join_into(bases[0], [bases[1], static])
    soft.clean(bases[0])
    return bases[0], expected


def test_join_and_cleanup_keep_each_part_morph_and_leave_unkeyed_cuffs_still():
    obj, expected = joined_parts()
    assert len(obj.data.vertices) == len(expected)
    assert len(obj.data.polygons) == 36, "cleanup must triangulate all three parts without losing morph data"
    assert obj.data.shape_keys.key_blocks["CompactGrip"].value == 0
    for point, target in zip(world_points(obj), world_points(obj, "CompactGrip"), strict=True):
        original, moved = min(expected, key=lambda pair: (pair[0] - point).length)
        assert (point - original).length < 1e-7
        assert (target - moved).length < 1e-7
    assert {face.material_index for face in obj.data.polygons} == {0, 1}


def glb(path):
    data = path.read_bytes()
    size, kind = struct.unpack_from("<II", data, 12)
    assert kind == 0x4E4F534A
    return json.loads(data[20 : 20 + size]), data[28 + size :]


def accessor(document, binary, index):
    item = document["accessors"][index]
    components = {"SCALAR": 1, "VEC3": 3, "VEC4": 4}[item["type"]]
    types = {5121: "B", 5123: "H", 5125: "I", 5126: "f"}
    format_ = "<" + types[item["componentType"]] * components

    def read(view_index, offset, fmt, count):
        view = document["bufferViews"][view_index]
        offset += view.get("byteOffset", 0)
        stride = view.get("byteStride", struct.calcsize(fmt))
        return [struct.unpack_from(fmt, binary, offset + row * stride) for row in range(count)]

    result = [(0,) * components] * item["count"]
    if "bufferView" in item:
        result = read(item["bufferView"], item.get("byteOffset", 0), format_, item["count"])
    if "sparse" in item:
        sparse = item["sparse"]
        indices, values = sparse["indices"], sparse["values"]
        rows = read(
            indices["bufferView"], indices.get("byteOffset", 0), "<" + types[indices["componentType"]], sparse["count"]
        )
        changed = read(values["bufferView"], values.get("byteOffset", 0), format_, sparse["count"])
        for row, value in zip(rows, changed, strict=True):
            result[row[0]] = value
    return result


def test_production_export_preserves_named_zero_weight_position_normal_morphs_and_skin(tmp_path):
    obj, _expected = joined_parts()
    skeleton = rig.build_armature()
    rig.bind_rigid(obj, skeleton, "hand_R")
    before = [tuple(vertex.co) for vertex in obj.data.vertices]
    path = tmp_path / "arms.glb"
    build_models.export(str(path))
    document, binary = glb(path)
    mesh = document["meshes"][0]
    assert mesh["extras"]["targetNames"] == ["CompactGrip"]
    assert mesh["weights"] == [0.0]
    assert len(document["skins"]) == 1
    joints = document["skins"][0]["joints"]
    assert {document["nodes"][joint]["name"] for joint in joints} <= set(rig.BONES)
    assert "hand_R" in {document["nodes"][joint]["name"] for joint in joints}
    displacement, changed_normals = [], []
    for primitive in mesh["primitives"]:
        assert len(primitive["targets"]) == 1
        target = primitive["targets"][0]
        assert {"POSITION", "NORMAL"} <= target.keys()
        displacement.extend(accessor(document, binary, target["POSITION"]))
        changed_normals.extend(accessor(document, binary, target["NORMAL"]))
        attributes = primitive["attributes"]
        for weights in accessor(document, binary, attributes["WEIGHTS_0"]):
            assert sum(weights) == pytest.approx(1.0)
        for indices in accessor(document, binary, attributes["JOINTS_0"]):
            assert document["nodes"][joints[indices[0]]]["name"] == "hand_R"
    assert max(Vector(value).length for value in displacement) > 0.005
    assert max(Vector(value).length for value in changed_normals) > 0.01
    assert {material["name"] for material in document["materials"]} == {"BodyRubber", "BodyKnit"}
    assert [tuple(vertex.co) for vertex in obj.data.vertices] == before
