"""Surface looks for the player body: each part gets a detailed material, baked to three texture maps.

Colour, normal and roughness are baked from procedural materials (weave, wrinkles, strands, wear,
stitching, dirt), so the game model keeps its triangle count and gains the fine detail.
"""

import math

import bpy
import numpy as np
from surface import bump, step

SIZE = 2048
MUD = "#4A3D2C"
THREAD = "#5E5C4C"
# look: (final material, colour, roughness, (mottle strength, scale), (grain scale, height),
#        (wrinkle scale, height), edge wear, part names)
LOOKS = {
    "skin": ("BodySkin", "#8F6A50", 0.55, (0.08, 40), (260, 0.0004), (60, 0.0005), 0.0, ("Head", "Ear", "Neck")),
    "eye": ("BodySkin", "#CFC8BD", 0.15, (0.0, 1), (1, 0.0), (1, 0.0), 0.0, ("Eyeball",)),
    "hair": ("BodyHair", "#1E1915", 0.70, (0.45, 1), (1, 0.0030), (30, 0.0010), 0.0, ("Hair", "Beard", "Brow")),
    "jacket": (
        "BodyCloth",
        "#3A423C",
        0.90,
        (0.24, 14),
        (240, 0.0010),
        (38, 0.0035),
        0.25,
        ("Jacket", "JacketHem", "Placket", "BackYoke", "Sleeve", "CuffBand", "HoodRoll", "HoodPouch"),
    ),
    "pocket": (
        "BodyCloth",
        "#343B34",
        0.90,
        (0.24, 14),
        (240, 0.0010),
        (38, 0.0022),
        0.30,
        ("ChestPocket", "PocketFlap", "HipPocket", "ArmPocket", "ElbowPatch", "CargoPocket", "CargoFlap"),
    ),
    "scarf": ("BodyCloth", "#56503F", 0.95, (0.20, 20), (200, 0.0016), (45, 0.0040), 0.15, ("ScarfLow", "ScarfHigh")),
    "trousers": ("BodyCloth", "#25272A", 0.90, (0.26, 12), (240, 0.0010), (34, 0.0038), 0.25, ("Pelvis", "Leg")),
    "pad": ("BodyRubber", "#1C2122", 0.60, (0.10, 30), (220, 0.0005), (25, 0.0004), 0.5, ("KneePad", "KnuckleGuard")),
    "strap": (
        "BodyRubber",
        "#4A4534",
        0.85,
        (0.10, 30),
        (260, 0.0006),
        (40, 0.0003),
        0.3,
        ("KneeStrap", "GloveStrap", "GloveCuff"),
    ),
    "glove": (
        "BodyRubber",
        "#17191A",
        0.70,
        (0.12, 40),
        (240, 0.0005),
        (50, 0.0006),
        0.4,
        ("GlovePalm", "GloveFinger", "GloveThumb", "GloveThumbPad"),
    ),
    "boot": (
        "BodyRubber",
        "#221E1A",
        0.60,
        (0.22, 25),
        (220, 0.0008),
        (30, 0.0018),
        0.6,
        ("Boot", "ToeCap", "HeelCounter", "BootCollar"),
    ),
    "sole": ("BodyRubber", "#0E1010", 0.85, (0.10, 30), (200, 0.0005), (30, 0.0003), 0.2, ()),
    "lace": ("BodyRubber", "#3A382F", 0.90, (0.10, 30), (300, 0.0004), (60, 0.0), 0.0, ("BootLace",)),
    "snap": ("BodyRubber", "#6A6D6E", 0.35, (0.05, 30), (300, 0.0), (30, 0.0), 0.6, ("Snap",)),
}
NAMES = list(LOOKS)
DIRTY = ("jacket", "pocket", "trousers", "pad", "strap", "boot", "lace")
SOLE_TOP = 0.034


def tag(obj) -> None:
    """Store the look of every face, so it survives joining the parts into one mesh."""
    part = obj.name.split(".")[0]
    look = next(name for name, spec in LOOKS.items() if part in spec[7])
    values = obj.data.attributes.new("look", "INT", "FACE")
    for face, item in zip(obj.data.polygons, values.data, strict=True):
        sole = look == "boot" and part == "Boot" and face.center.z < SOLE_TOP
        item.value = NAMES.index("sole" if sole else look)


def _linear(hex_code: str) -> np.ndarray:
    from build_models import srgb

    return np.asarray(srgb(hex_code)[:3])


def _mix(colours, target, amount):
    return colours + (target - colours) * amount[:, None]


def _skin_tint(colours, points, mask):
    """Lips, shadowed eye sockets and a flush on the nose and cheeks."""
    ax, y, z = np.abs(points[:, 0]), points[:, 1], points[:, 2]
    face = step(-y, 0.06, 0.02) * mask
    lips = bump(z, 1.6170, 0.0040) * bump(ax, 0, 0.022) + bump(z, 1.6075, 0.0045) * bump(ax, 0, 0.018)
    colours = _mix(colours, _linear("#6E4038"), np.clip(lips, 0, 1) * 0.8 * face)
    flush = bump(ax, 0, 0.015) * bump(z, 1.644, 0.012) + bump(ax, 0.05, 0.02) * bump(z, 1.655, 0.015)
    colours = _mix(colours, _linear("#9A5F4E"), np.clip(flush, 0, 1) * 0.35 * face)
    return colours * (1 - 0.3 * bump(ax, 0.030, 0.02) * bump(z, 1.684, 0.012) * face)[:, None]


def paint_tint(obj) -> None:
    """Per-vertex base colour: the look's colour, mud towards the ground, skin tones on the face."""
    mesh = obj.data
    looks = np.zeros(len(mesh.vertices), dtype=int)
    for face, item in zip(mesh.polygons, mesh.attributes["look"].data, strict=True):
        looks[list(face.vertices)] = item.value
    points = np.asarray([vertex.co[:] for vertex in mesh.vertices])
    colours = np.asarray([_linear(LOOKS[name][1]) for name in NAMES])[looks]
    dirty = np.isin(looks, [NAMES.index(name) for name in DIRTY])
    mud = np.clip((0.75 - points[:, 2]) / 0.75, 0, 1) * 0.8
    colours = _mix(colours, _linear(MUD), mud * dirty)
    colours = _skin_tint(colours, points, looks == NAMES.index("skin"))
    tint = mesh.color_attributes.new("Tint", "FLOAT_COLOR", "POINT")
    tint.data.foreach_set("color", np.concatenate([colours, np.ones((len(colours), 1))], axis=1).ravel())
    mesh.color_attributes.active_color = mesh.color_attributes["Color"]
    mesh.color_attributes.render_color_index = mesh.color_attributes.find("Color")


class _Graph:
    """Small helper to wire shader nodes without repeating the lookups."""

    def __init__(self, material):
        material.use_nodes = True
        self.tree = material.node_tree
        self.tree.nodes.clear()

    def node(self, kind, **settings):
        node = self.tree.nodes.new(kind)
        for key, value in settings.items():
            setattr(node, key, value)
        return node

    def link(self, source, target) -> None:
        self.tree.links.new(source, target)

    def math(self, operation, first, second):
        node = self.node("ShaderNodeMath", operation=operation)
        for slot, value in zip(node.inputs, (first, second), strict=False):
            if isinstance(value, int | float):
                slot.default_value = value
            else:
                self.link(value, slot)
        return node.outputs[0]

    def noise(self, vector, scale, detail=4.0):
        node = self.node("ShaderNodeTexNoise")
        node.inputs["Scale"].default_value = scale
        node.inputs["Detail"].default_value = detail
        self.link(vector, node.inputs["Vector"])
        return node.outputs["Fac"]

    def remap(self, value, low, high, to_low, to_high):
        node = self.node("ShaderNodeMapRange")
        for name, number in (("From Min", low), ("From Max", high), ("To Min", to_low), ("To Max", to_high)):
            node.inputs[name].default_value = number
        self.link(value, node.inputs["Value"])
        return node.outputs["Result"]


def _eye_colour(graph: _Graph):
    """White of the eye with a brown iris and a pupil, placed from the head's eye centre."""
    from head import EYE

    position = graph.node("ShaderNodeNewGeometry").outputs["Position"]
    split = graph.node("ShaderNodeSeparateXYZ")
    graph.link(position, split.inputs[0])
    across = graph.math("SUBTRACT", graph.math("ABSOLUTE", split.outputs["X"], 0.0), EYE[0])
    up = graph.math("SUBTRACT", split.outputs["Z"], EYE[1])
    distance = graph.math("SQRT", graph.math("ADD", graph.math("POWER", across, 2.0), graph.math("POWER", up, 2.0)), 0)
    iris = graph.node("ShaderNodeMixRGB")
    iris.inputs[1].default_value = (*_linear("#CFC8BD"), 1)
    iris.inputs[2].default_value = (*_linear("#3B2A1C"), 1)
    graph.link(graph.math("LESS_THAN", distance, 0.0058), iris.inputs[0])
    pupil = graph.node("ShaderNodeMixRGB")
    pupil.inputs[2].default_value = (0.004, 0.004, 0.004, 1)
    graph.link(iris.outputs[0], pupil.inputs[1])
    graph.link(graph.math("LESS_THAN", distance, 0.0024), pupil.inputs[0])
    return pupil.outputs[0]


def _cloth_colour(graph: _Graph, spec, coords, stitch):
    """Tint with blotchy variation, lighter worn edges and pale thread on the seams."""
    tint = graph.node("ShaderNodeAttribute", attribute_name="Tint").outputs["Color"]
    strength, scale = spec[3]
    value = graph.remap(graph.noise(coords, scale), 0.3, 0.7, 1 - strength, 1 + strength)
    worn = graph.remap(graph.node("ShaderNodeNewGeometry").outputs["Pointiness"], 0.5, 0.62, 0.0, spec[6])
    shade = graph.node("ShaderNodeHueSaturation")
    graph.link(tint, shade.inputs["Color"])
    graph.link(graph.math("ADD", value, worn), shade.inputs["Value"])
    seam = graph.node("ShaderNodeMixRGB")
    seam.inputs[2].default_value = (*_linear(THREAD), 1)
    graph.link(shade.outputs[0], seam.inputs[1])
    graph.link(stitch, seam.inputs[0])
    return seam.outputs[0]


def _bake_material(name: str):
    spec = LOOKS[name]
    material = bpy.data.materials.new("Bake" + name)
    graph = _Graph(material)
    surface = graph.node("ShaderNodeBsdfPrincipled")
    graph.link(surface.outputs[0], graph.node("ShaderNodeOutputMaterial").inputs["Surface"])
    coords = graph.node("ShaderNodeTexCoord").outputs["Object"]
    fine = coords
    if name == "hair":
        stretch = graph.node("ShaderNodeMapping")
        stretch.inputs["Scale"].default_value = (230, 230, 14)
        graph.link(coords, stretch.inputs["Vector"])
        fine = stretch.outputs[0]
    seam = graph.math("GREATER_THAN", graph.node("ShaderNodeAttribute", attribute_name="hem").outputs["Fac"], 0.93)
    dashes = graph.math("GREATER_THAN", graph.noise(coords, 180, 0.0), 0.42)
    stitch = graph.math(
        "MULTIPLY", graph.math("MULTIPLY", seam, dashes), 0.0 if name in ("hair", "skin", "eye") else 1.0
    )
    colour = (
        _eye_colour(graph) if name == "eye" else _cloth_colour(graph, spec, fine if name == "hair" else coords, stitch)
    )
    graph.link(colour, surface.inputs["Base Color"])
    grain = graph.noise(fine, spec[4][0])
    height = graph.math("MULTIPLY", graph.math("SUBTRACT", grain, 0.5), spec[4][1])
    wrinkle = graph.math("MULTIPLY", graph.math("SUBTRACT", graph.noise(coords, spec[5][0], 2.0), 0.5), spec[5][1])
    relief = graph.math("ADD", graph.math("ADD", height, wrinkle), graph.math("MULTIPLY", stitch, 0.0015))
    bumps = graph.node("ShaderNodeBump")
    bumps.inputs["Distance"].default_value = 1.0
    graph.link(relief, bumps.inputs["Height"])
    graph.link(bumps.outputs[0], surface.inputs["Normal"])
    graph.link(graph.remap(grain, 0.0, 1.0, spec[2] - 0.12, spec[2] + 0.12), surface.inputs["Roughness"])
    target = graph.node("ShaderNodeTexImage", name="Target")
    graph.tree.nodes.active = target
    return material


def _pixels(image) -> np.ndarray:
    data = np.empty(SIZE * SIZE * 4, dtype=np.float32)
    image.pixels.foreach_get(data)
    return data.reshape(SIZE, SIZE, 4)


def _bake_maps(obj, materials: list) -> dict:
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    images = {}
    for kind, bake_type, samples in (
        ("Color", "DIFFUSE", 4),
        ("Normal", "NORMAL", 4),
        ("Rough", "ROUGHNESS", 4),
        ("Shade", "AO", 32),
    ):
        image = bpy.data.images.new("Body" + kind, SIZE, SIZE, alpha=False, is_data=kind != "Color")
        for material in materials:
            material.node_tree.nodes["Target"].image = image
        scene.cycles.samples = samples
        options = {"pass_filter": {"COLOR"}} if bake_type == "DIFFUSE" else {}
        bpy.ops.object.bake(type=bake_type, margin=4, use_clear=True, **options)
        images[kind] = image
    colour, shade = _pixels(images["Color"]), _pixels(images.pop("Shade"))
    colour[..., :3] *= 0.45 + 0.55 * shade[..., :3]
    images["Color"].pixels.foreach_set(colour.ravel())
    for image in images.values():
        image.pack()
    return images


def _final_material(name: str, images: dict):
    old = bpy.data.materials.get(name)
    if old:
        bpy.data.materials.remove(old)
    material = bpy.data.materials.new(name)
    graph = _Graph(material)
    surface = graph.node("ShaderNodeBsdfPrincipled")
    graph.link(surface.outputs[0], graph.node("ShaderNodeOutputMaterial").inputs["Surface"])
    graph.link(graph.node("ShaderNodeTexImage", image=images["Color"]).outputs["Color"], surface.inputs["Base Color"])
    graph.link(graph.node("ShaderNodeTexImage", image=images["Rough"]).outputs["Color"], surface.inputs["Roughness"])
    normal = graph.node("ShaderNodeNormalMap")
    graph.link(graph.node("ShaderNodeTexImage", image=images["Normal"]).outputs["Color"], normal.inputs["Color"])
    graph.link(normal.outputs[0], surface.inputs["Normal"])
    return material


def _unwrap(obj) -> None:
    """Few large islands packed tight: the default per-model unwrap leaves most of the map empty."""
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(82.0), island_margin=0.0, area_weight=0.0)
    bpy.ops.uv.average_islands_scale()
    bpy.ops.uv.pack_islands(rotate=True, margin=0.0025)
    bpy.ops.object.mode_set(mode="OBJECT")


def bake(obj) -> None:
    """Bake every look into shared colour, normal and roughness maps and leave the four Body materials."""
    mesh = obj.data
    looks = [item.value for item in mesh.attributes["look"].data]
    _unwrap(obj)
    paint_tint(obj)
    bake_materials = [_bake_material(name) for name in NAMES]
    mesh.materials.clear()
    for material in bake_materials:
        mesh.materials.append(material)
    for face, look in zip(mesh.polygons, looks, strict=True):
        face.material_index = look
    images = _bake_maps(obj, bake_materials)
    finals = list(dict.fromkeys(spec[0] for spec in LOOKS.values()))
    mesh.materials.clear()
    for name in finals:
        mesh.materials.append(_final_material(name, images))
    for face, look in zip(mesh.polygons, looks, strict=True):
        face.material_index = finals.index(LOOKS[NAMES[look]][0])
    for material in bake_materials:
        bpy.data.materials.remove(material)
    mesh.color_attributes.remove(mesh.color_attributes["Tint"])
    mesh.attributes.remove(mesh.attributes["look"])
    mesh.attributes.remove(mesh.attributes["hem"])
