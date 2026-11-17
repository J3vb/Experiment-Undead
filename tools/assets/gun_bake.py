"""Bakes a code-built gun to texture maps (docs/plans/baked-gun-textures.md, ADR 0014).

Run from the repo root (needs bpy):
    python tools/assets/gun_bake.py rifle_ar              # 2048 px maps + glb into assets/
    python tools/assets/gun_bake.py rifle_ar --size 512   # quick look, into --out

The gun is built from its script as usual. The game mesh gets a small chamfer on hard
edges and one shared UV sheet. A detail material then stands in for the high-detail copy:
Cycles' Bevel shader rounds every edge, bump nodes add stipple, engraved marks and dents,
and the paint chips on edges and gathers grime in creases, following the gun finish
shader's rules. Baking it gives three maps: albedo (sRGB), normal (tangent space) and
ORM (R ambient occlusion, G roughness, B metal). The glb gets one `Baked` material;
`gun_finish_import.gd` loads the maps by the glb's name.
"""

import argparse
import hashlib
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy

# isort: split
import build_models
import check_models
import finish
import mathutils
import numpy

REPO = build_models.REPO
GLASS = ("SightGlass", "OpticGlass")
BAKED = "Baked"
MAP_SIZE = 2048
SAMPLES = 16
MAP_KINDS = ("albedo", "normal", "orm")
CHAMFER = 0.0006  # m, real geometry on hard edges so the silhouette is not razor sharp
CHAMFER_ANGLE = math.radians(30.0)
EDGE_RADIUS = 0.0009  # m, Bevel shader radius: the soft edge every face gets in the normal map
WEAR_RADIUS = 0.004  # m, how far from an edge paint can chip
UV_MARGIN = 0.003

FINISHES = {"GunMetal": 0, "MatteBlack": 1, "Tan": 2, "OlivePolymer": 2, "GreyPolymer": 2, "Wood": 3, "Markings": 2}
BARE_METAL = (0.258, 0.283, 0.266)  # #8A918C in linear
GRIME = (0.106, 0.064, 0.030)  # #5A4630 in linear
WORN_WEAR = 1.6
WORN_GRIME = 1.0
BRASS = (0.48, 0.32, 0.10)  # linear; worn-through primer and brass under the paint (concept sheet)
RUST = (0.20, 0.08, 0.03)
TAN_SHADE = (0.8, 0.7, 0.56)  # concept tan is darker and browner than the shader-finish tan
SCRATCH_STRETCH = (450.0, 12.0, 450.0)  # long scratches along the barrel (Blender +Y)
MARKINGS_MAP = os.path.join(REPO, "assets", "textures", "gun_markings.png")
# Files whose change means a re-bake (tools/ci/test_gun_bakes.py). Shared helpers such as
# gun_parts.py are covered by the source fingerprint instead (tools/assets/tests/test_gun_bake.py).
INPUTS = ("tools/assets/gun_bake.py", "assets/textures/gun_markings.png")


def map_path(name: str, kind: str, folder: str) -> str:
    return os.path.join(folder, f"{name}_{kind}.png")


def bake_parts() -> list:
    """Every mesh that gets the baked material: all but the see-through glass."""
    parts = []
    for obj in bpy.context.scene.objects:
        if obj.type != "MESH":
            continue
        if all(slot.material and slot.material.name in GLASS for slot in obj.material_slots):
            continue
        parts.append(obj)
    return parts


def chamfer(obj) -> None:
    mod = obj.modifiers.new("Chamfer", "BEVEL")
    mod.width = CHAMFER
    mod.segments = 1
    mod.limit_method = "ANGLE"
    mod.angle_limit = CHAMFER_ANGLE
    mod.use_clamp_overlap = True
    finish._select_only(obj)
    bpy.ops.object.modifier_apply(modifier=mod.name)
    build_models.drop_degenerate_faces(obj)
    finish.fix_normals(obj)
    tri = obj.modifiers.new("Triangulate", "TRIANGULATE")
    tri.keep_custom_normals = True
    bpy.ops.object.modifier_apply(modifier=tri.name)


def shared_unwrap(parts: list) -> None:
    """One UV sheet for the whole gun, islands scaled by real size, no overlaps."""
    for obj in parts:
        layers = obj.data.uv_layers
        if layers.get("UVMap") is None:
            layers.new(name="UVMap")
            if len(layers) > 1:
                layers.active_index = len(layers) - 1
        layers.active = layers["UVMap"]
    bpy.ops.object.select_all(action="DESELECT")
    for obj in parts:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(66.0), island_margin=UV_MARGIN, scale_to_bounds=False)
    bpy.ops.uv.pack_islands(margin=UV_MARGIN, rotate=True)
    bpy.ops.object.mode_set(mode="OBJECT")


class Nodes:
    """Small helper to wire one detail material."""

    def __init__(self, mat) -> None:
        self.tree = mat.node_tree
        self.n = self.tree.nodes
        self.link = self.tree.links.new

    def node(self, kind: str, samples: int = 0, **inputs):
        node = self.n.new(kind)
        if samples:
            node.samples = samples
        for key, value in inputs.items():
            if isinstance(value, bpy.types.NodeSocket):
                self.link(value, node.inputs[key])
            else:
                node.inputs[key].default_value = value
        return node

    def math(self, op: str, a, b=0.0):
        node = self.n.new("ShaderNodeMath")
        node.operation = op
        for i, v in enumerate((a, b)):
            if isinstance(v, bpy.types.NodeSocket):
                self.link(v, node.inputs[i])
            else:
                node.inputs[i].default_value = v
        return node.outputs[0]

    def smooth(self, value, lo: float, hi: float):
        node = self.n.new("ShaderNodeMapRange")
        node.interpolation_type = "SMOOTHSTEP"
        self.link(value, node.inputs["Value"])
        node.inputs["From Min"].default_value = lo
        node.inputs["From Max"].default_value = hi
        return node.outputs["Result"]

    def noise(self, coords, scale: float, offset: float = 0.0):
        tex = self.n.new("ShaderNodeTexNoise")
        tex.noise_dimensions = "4D"
        tex.inputs["Scale"].default_value = scale
        tex.inputs["Detail"].default_value = 3.0
        tex.inputs["W"].default_value = offset
        self.link(coords, tex.inputs["Vector"])
        return tex.outputs["Fac"]

    def mix(self, a, b, fac, kind: str = "RGBA"):
        node = self.n.new("ShaderNodeMix")
        node.data_type = kind
        node.clamp_factor = True
        sockets = {"RGBA": (6, 7, 0), "FLOAT": (2, 3, 0)}[kind]
        for socket, value in zip(sockets, (a, b, fac), strict=True):
            if isinstance(value, bpy.types.NodeSocket):
                self.link(value, node.inputs[socket])
            else:
                node.inputs[socket].default_value = value
        return node.outputs[2 if kind == "RGBA" else 0]


def finish_of(name: str) -> tuple:
    """(finish, wear, grime, knurled) from a Blender material name, like gun_finish_import.gd."""
    worn = name.endswith("Worn")
    base = name.removesuffix("Worn")
    knurled = base.endswith("Knurled")
    base = base.removesuffix("Knurled")
    if base not in FINISHES:
        raise SystemExit(f"gun material '{name}' has no finish")
    marked = base == "Markings"
    wear, grime = (WORN_WEAR, WORN_GRIME) if worn or marked else (1.0, 0.0)
    return FINISHES[base], wear, grime, knurled


def detail_material(source):
    """A material with one output node per baked channel, wired by `use_channel`."""
    bsdf = source.node_tree.nodes["Principled BSDF"]
    base = tuple(bsdf.inputs["Base Color"].default_value)
    metal = bsdf.inputs["Metallic"].default_value
    rough = bsdf.inputs["Roughness"].default_value
    kind, wear, grime, knurled = finish_of(source.name)
    mat = bpy.data.materials.new(source.name + "_Detail")
    mat.use_nodes = True
    mat.node_tree.nodes.clear()
    g = Nodes(mat)
    p = g.n.new("ShaderNodeTexCoord").outputs["Object"]
    geo = g.n.new("ShaderNodeNewGeometry").outputs["Normal"]
    ao = g.node("ShaderNodeAmbientOcclusion", samples=16, Distance=0.012).outputs["AO"]
    wide = g.node("ShaderNodeBevel", samples=8, Radius=WEAR_RADIUS).outputs["Normal"]
    dot = g.n.new("ShaderNodeVectorMath")
    dot.operation = "DOT_PRODUCT"
    g.link(wide, dot.inputs[0])
    g.link(geo, dot.inputs[1])
    bend = g.math("SUBTRACT", 1.0, dot.outputs["Value"])
    edge = g.math("MULTIPLY", g.smooth(bend, 0.004, 0.06), wear)
    blotch = g.noise(p, 28.0)
    chips = g.noise(p, 140.0, 3.0)
    heavy = max(wear - 1.0, 0.0)
    worn = g.math("MULTIPLY", g.smooth(edge, 0.4, 0.9), g.smooth(chips, 0.3 - heavy * 0.15, 0.6 - heavy * 0.15))
    flat_chips = g.math("MULTIPLY", g.smooth(g.noise(p, 90.0, 7.0), 0.64, 0.69), heavy)
    worn = g.math("MAXIMUM", worn, flat_chips)
    color = _base_color(g, source, base)
    color, metal_out, rough_out, height = _finish(g, kind, color, metal, rough, worn, blotch, p)
    if heavy > 0.0:
        scratch = _scratches(g, p, heavy)
        lines = (*BARE_METAL, 1.0) if kind < 2 else (0.32, 0.26, 0.18, 1.0)
        color = g.mix(color, lines, g.math("MULTIPLY", scratch, 0.8))
        rough_out = g.mix(rough_out, 0.35, scratch, "FLOAT")
        height = g.math("SUBTRACT", height, g.math("MULTIPLY", scratch, 0.00002))
    if knurled:
        stipple = g.node("ShaderNodeTexVoronoi", Scale=900.0, Vector=p).outputs["Distance"]
        height = g.math("ADD", height, g.math("MULTIPLY", stipple, 0.00025))
        rough_out = g.math("SUBTRACT", rough_out, g.math("MULTIPLY", stipple, 0.1))
    dirt = g.math(
        "MULTIPLY",
        g.math(
            "ADD",
            g.math("MULTIPLY", g.math("SUBTRACT", 1.0, ao), 2.0),
            g.math("MULTIPLY", g.smooth(blotch, 0.55, 0.8), 0.5),
        ),
        grime,
    )
    dirt = g.math("MINIMUM", dirt, 1.0)
    color = g.mix(color, (*tuple(c * 0.5 for c in GRIME), 1.0), g.math("MULTIPLY", dirt, 0.75))
    rough_out = g.math("ADD", rough_out, g.math("MULTIPLY", dirt, 0.15))
    if source.name.startswith("Markings"):
        height = g.math("SUBTRACT", height, g.math("MULTIPLY", _markings(g, "luma"), 0.00008))
    soft = g.node("ShaderNodeBevel", samples=8, Radius=EDGE_RADIUS).outputs["Normal"]
    bump = g.node("ShaderNodeBump", Strength=1.0, Distance=1.0, Height=height, Normal=soft)
    _outputs(g, color, rough_out, metal_out, bump.outputs["Normal"])
    return mat


def _base_color(g: Nodes, source, base: tuple):
    if source.name.startswith("Markings"):
        return _markings(g, "color")
    if finish_of(source.name)[0] == 2:
        base = (*(c * k for c, k in zip(base[:3], TAN_SHADE, strict=True)), 1.0)
    return g.mix(base, base, 0.0)


def _markings(g: Nodes, out: str):
    uv = g.n.new("ShaderNodeUVMap")
    uv.uv_map = "Markings"
    tex = g.n.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(MARKINGS_MAP, check_existing=True)
    tex.extension = "CLIP"
    g.link(uv.outputs["UV"], tex.inputs["Vector"])
    if out == "color":
        return tex.outputs["Color"]
    gray = g.n.new("ShaderNodeRGBToBW")
    g.link(tex.outputs["Color"], gray.inputs[0])
    return gray.outputs[0]


def _under(g: Nodes, p) -> tuple:
    """What shows through chipped paint: bare metal, patches of brass, spots of rust."""
    brass = g.smooth(g.noise(p, 35.0, 11.0), 0.5, 0.62)
    rust = g.smooth(g.noise(p, 60.0, 17.0), 0.55, 0.68)
    color = g.mix(g.mix((*BARE_METAL, 1.0), (*BRASS, 1.0), brass), (*RUST, 1.0), rust)
    metal = g.mix(0.9, 0.0, rust, "FLOAT")
    rough = g.mix(g.mix(0.3, 0.38, brass, "FLOAT"), 0.9, rust, "FLOAT")
    return color, metal, rough


def _scratches(g: Nodes, p, heavy: float):
    stretched = g.n.new("ShaderNodeVectorMath")
    stretched.operation = "MULTIPLY"
    g.link(p, stretched.inputs[0])
    stretched.inputs[1].default_value = SCRATCH_STRETCH
    lines = g.smooth(g.noise(stretched.outputs[0], 1.0, 23.0), 0.66, 0.68)
    clusters = g.smooth(g.noise(p, 9.0, 29.0), 0.5, 0.62)
    return g.math("MULTIPLY", g.math("MULTIPLY", lines, clusters), heavy)


def _finish(g: Nodes, kind: int, color, metal: float, rough: float, worn, blotch, p) -> tuple:
    """Paint, metal, roughness and height for one finish, as in gun_finish.gdshader."""
    color = g.mix(g.mix((0, 0, 0, 1), color, 0.96), g.mix((0, 0, 0, 1), color, 1.04), blotch)
    rough_out = g.math("ADD", rough, g.math("MULTIPLY", g.math("SUBTRACT", blotch, 0.5), 0.1))
    metal_out = g.math("ADD", metal, 0.0)
    height = g.math("ADD", 0.0, 0.0)
    if kind == 0:
        under, _, _ = _under(g, p)
        color = g.mix(color, under, g.math("MULTIPLY", worn, 0.7))
        rough_out = g.mix(rough_out, 0.28, worn, "FLOAT")
    elif kind == 1:
        under, under_metal, under_rough = _under(g, p)
        color = g.mix(color, under, worn)
        metal_out = g.mix(metal_out, under_metal, worn, "FLOAT")
        rough_out = g.mix(rough_out, under_rough, worn, "FLOAT")
        height = g.math("SUBTRACT", g.math("MULTIPLY", g.noise(p, 2200.0), 0.00004), g.math("MULTIPLY", worn, 0.00005))
    elif kind == 2:
        lighter = g.n.new("ShaderNodeMix")
        lighter.data_type = "RGBA"
        lighter.blend_type = "MULTIPLY"
        lighter.inputs[0].default_value = 1.0
        g.link(color, lighter.inputs[6])
        lighter.inputs[7].default_value = (1.45, 1.45, 1.45, 1.0)
        color = g.mix(color, lighter.outputs[2], g.math("MULTIPLY", worn, 0.7))
        rough_out = g.math("ADD", rough_out, g.math("MULTIPLY", worn, 0.08))
        height = g.math("MULTIPLY", g.noise(p, 1600.0), 0.00008)
    else:
        rough_out = g.mix(rough_out, 0.85, worn, "FLOAT")
    return color, metal_out, rough_out, height


def _outputs(g: Nodes, color, rough, metal, normal) -> None:
    """Emission nodes per channel; `use_channel` picks which one reaches the output."""
    out = g.n.new("ShaderNodeOutputMaterial")
    out.name = "Output"
    for key, value in (("albedo", color), ("roughness", rough), ("metal", metal)):
        emit = g.n.new("ShaderNodeEmission")
        emit.name = key
        g.link(value, emit.inputs["Color"])
    bsdf = g.n.new("ShaderNodeBsdfPrincipled")
    bsdf.name = "normal"
    g.link(normal, bsdf.inputs["Normal"])
    target = g.n.new("ShaderNodeTexImage")
    target.name = "Target"
    g.n.active = target


def use_channel(materials: list, channel: str, image) -> None:
    for mat in materials:
        nodes = mat.node_tree.nodes
        source = nodes[channel].outputs[0]
        mat.node_tree.links.new(source, nodes["Output"].inputs["Surface"])
        nodes["Target"].image = image
        nodes.active = nodes["Target"]


def swap_in_detail(parts: list) -> list:
    made = {}
    for obj in parts:
        for slot in obj.material_slots:
            if slot.material.name not in made:
                made[slot.material.name] = detail_material(slot.material)
            slot.material = made[slot.material.name]
    return list(made.values())


def new_image(name: str, size: int, color: bool, float_buffer: bool = False):
    """8-bit maps are saved; float buffers only hold channels before they are packed."""
    image = bpy.data.images.new(name, size, size, alpha=False, float_buffer=float_buffer)
    image.colorspace_settings.name = "sRGB" if color else "Non-Color"
    return image


def bake(parts: list, kind: str, samples: int) -> None:
    scene = bpy.context.scene
    scene.cycles.samples = samples
    bpy.ops.object.select_all(action="DESELECT")
    for obj in parts:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    settings = scene.render.bake
    settings.margin = 8
    settings.margin_type = "EXTEND"
    settings.use_clear = True
    settings.use_selected_to_active = False
    if kind == "EMIT":
        bpy.ops.object.bake(type="EMIT")
    elif kind == "NORMAL":
        settings.normal_space = "TANGENT"
        bpy.ops.object.bake(type="NORMAL")
    else:
        bpy.ops.object.bake(type="AO")


def pixels(image) -> numpy.ndarray:
    data = numpy.empty(len(image.pixels), dtype=numpy.float32)
    image.pixels.foreach_get(data)
    return data.reshape(image.size[1], image.size[0], 4)


def save(image, path: str, data: numpy.ndarray | None = None) -> None:
    if data is not None:
        image.pixels.foreach_set(data.ravel())
    image.filepath_raw = path
    image.file_format = "PNG"
    image.save()


def bake_maps(parts: list, materials: list, name: str, folder: str, size: int, samples: int) -> None:
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.seed = 0
    if scene.world is None:
        scene.world = bpy.data.worlds.new("BakeWorld")
    scene.world.light_settings.distance = 0.012
    os.makedirs(folder, exist_ok=True)
    albedo = new_image(f"{name}_albedo", size, True)
    use_channel(materials, "albedo", albedo)
    bake(parts, "EMIT", samples)
    save(albedo, map_path(name, "albedo", folder))
    normal = new_image(f"{name}_normal", size, False)
    use_channel(materials, "normal", normal)
    bake(parts, "NORMAL", samples)
    save(normal, map_path(name, "normal", folder))
    orm = numpy.ones((size, size, 4), dtype=numpy.float32)
    for channel, index in (("roughness", 1), ("metal", 2)):
        image = new_image(f"{name}_{channel}", size, False, True)
        use_channel(materials, channel, image)
        bake(parts, "EMIT", samples)
        orm[:, :, index] = numpy.clip(pixels(image)[:, :, 0], 0.0, 1.0)
    image = new_image(f"{name}_ao", size, False, True)
    use_channel(materials, "albedo", image)
    bake(parts, "AO", samples * 2)
    orm[:, :, 0] = pixels(image)[:, :, 0]
    save(new_image(f"{name}_orm", size, False), map_path(name, "orm", folder), orm)


def use_baked_material(parts: list) -> None:
    """One plain `Baked` material per gun; the import script gives it the maps."""
    baked = bpy.data.materials.new(BAKED)
    baked.use_nodes = True
    for obj in parts:
        obj.data.materials.clear()
        obj.data.materials.append(baked)
        for poly in obj.data.polygons:
            poly.material_index = 0
        markings = obj.data.uv_layers.get("Markings")
        if markings is not None:
            obj.data.uv_layers.remove(markings)


def triangles(objs: list) -> int:
    total = 0
    for obj in objs:
        obj.data.calc_loop_triangles()
        total += len(obj.data.loop_triangles)
    return total


def input_hashes(name: str) -> dict:
    files = list(INPUTS) + gun_scripts(name)
    out = {}
    for rel in files:
        with open(os.path.join(REPO, rel), "rb") as handle:
            out[rel] = hashlib.sha256(handle.read()).hexdigest()
    return out


def gun_scripts(name: str) -> list:
    return [f"tools/assets/{build_models.BAKED[name]}.py"]


def fingerprint() -> dict:
    """Triangles and size of the plain built gun, before the bake changes it."""
    objs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    lo = [math.inf] * 3
    hi = [-math.inf] * 3
    for obj in objs:
        for corner in obj.bound_box:
            world = obj.matrix_world @ mathutils.Vector(corner)
            for i in range(3):
                lo[i] = min(lo[i], world[i])
                hi[i] = max(hi[i], world[i])
    return {"triangles": triangles(objs), "bounds_mm": [round(v * 1000.0, 1) for v in lo + hi]}


def write_record(name: str, folder: str, record: dict) -> None:
    record = {"inputs": input_hashes(name), **record}
    with open(os.path.join(folder, f"{name}_bake.json"), "w", encoding="utf-8") as handle:
        json.dump(record, handle, indent=1, sort_keys=True)
        handle.write("\n")


def bake_gun(name: str, model_out: str, map_out: str, size: int, samples: int) -> int:
    rel_path, build = build_models.MODELS[name]
    build_models.reset_scene()
    build()
    source = fingerprint()
    parts = bake_parts()
    for obj in bpy.context.scene.objects:
        if obj.type == "MESH":
            finish.fix_normals(obj)
    for obj in parts:
        chamfer(obj)
    shared_unwrap(parts)
    for obj in bpy.context.scene.objects:
        if obj.type == "MESH" and obj not in parts:
            finish.unwrap(obj)
    finish.bake_ao([o for o in bpy.context.scene.objects if o.type == "MESH"])
    for obj in bpy.context.scene.objects:
        if obj.type == "MESH":
            finish.apply_mask(obj)
    materials = swap_in_detail(parts)
    bake_maps(parts, materials, name, map_out, size, samples)
    use_baked_material(parts)
    tris = triangles([o for o in bpy.context.scene.objects if o.type == "MESH"])
    budget = check_models.BUDGETS["weapons"][0]
    if tris > budget:
        raise SystemExit(f"{name}: {tris} triangles, budget {budget}")
    path = os.path.join(model_out, rel_path)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        export_yup=True,
        export_apply=True,
        export_vertex_color="ACTIVE",
        export_tangents=True,
    )
    write_record(name, map_out, {"map_size": size, "triangles": tris, "source": source})
    return tris


def main(argv: list) -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("names", nargs="*", default=list(build_models.BAKED))
    parser.add_argument("--size", type=int, default=MAP_SIZE)
    parser.add_argument("--samples", type=int, default=SAMPLES)
    parser.add_argument("--out", default="", help="folder for the glb and maps (default: assets/)")
    args = parser.parse_args(argv)
    model_out = args.out or os.path.join(REPO, "assets", "models")
    map_out = args.out or os.path.join(REPO, "assets", "textures", "weapons")
    for name in args.names:
        tris = bake_gun(name, model_out, map_out, args.size, args.samples)
        print(f"baked {name}: {tris} triangles, {args.size} px maps -> {map_out}")


if __name__ == "__main__":
    main(sys.argv[1:])
