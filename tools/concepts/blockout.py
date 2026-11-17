"""Shared blockout helpers for the Act I boss Sublevel concept renders.

Each area script next to this file builds a rough scene with these helpers and
calls render_shots(). Colours, light and fog follow docs/design/look-rules.md
(Cold Containment). Units are metres, +Z up; box() and cylinder() take the
centre of their base, so z = 0 stands a part on the floor.
"""

import math
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

OUT = Path(__file__).resolve().parents[2] / "docs/design/concepts/act1"
MAX_BYTES = 500_000

# docs/design/look-rules.md palette
FLUORESCENT = "#CDEEE8"
FOG = "#0A1416"
WALL = "#5F6D68"
SODIUM = "#FF9A42"
BIO_GREEN = "#8DFF3A"
ALARM = "#C3201B"
HEAD = "#B9C2B0"
SKIN = "#8E9887"
DARK_SKIN = "#6C7566"
LAB_COAT = "#8A918C"
SHIRT = "#2F393B"
TROUSERS = "#1C2122"
SHOES = "#0E1010"
BLOATER = "#4A5446"
# levels/materials/*.tres base colours
CONCRETE = "#8C8C87"
WET_FLOOR = "#8C9994"
TILE = "#70807D"
TRIM = "#384040"
PIPE = "#4D5454"
RUST = "#592E1A"
BRICK = "#804533"
WOOD = "#734D2B"

_state = {"scene": None, "materials": {}}


def linear(hex_code):
    """Convert an sRGB hex colour to Blender's linear values."""
    channels = [int(hex_code[i : i + 2], 16) / 255 for i in (1, 3, 5)]
    return tuple(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in channels)


def new_scene(area_id, fog_size, fog_density=0.018):
    """Start a 1920x1080 Cycles scene with the look-rules colour management, bloom and fog."""
    scene = bpy.data.scenes.new(area_id)
    _state["scene"] = scene
    _state["materials"] = {}
    scene.render.engine = "CYCLES"
    use_gpu(scene)
    scene.cycles.samples = 256
    scene.cycles.seed = 7
    scene.cycles.use_denoising = True
    scene.render.resolution_x = 1920
    scene.render.resolution_y = 1080
    scene.render.image_settings.file_format = "JPEG"
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Medium High Contrast"
    scene.view_settings.exposure = math.log2(1.05)
    world = bpy.data.worlds.new(area_id)
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (*linear(FOG), 1)
    scene.world = world
    bloom(scene)
    fog = box("Fog", (0, 0, -2), fog_size, fog_material(fog_density), bevel=0)
    fog.visible_shadow = False
    return scene


def use_gpu(scene):
    """Render on an OptiX GPU when there is one; Cycles stays on the CPU otherwise."""
    prefs = bpy.context.preferences.addons["cycles"].preferences
    try:
        prefs.compute_device_type = "OPTIX"
    except TypeError:
        return
    prefs.refresh_devices()
    for device in prefs.devices:
        device.use = device.type == "OPTIX"
    scene.cycles.device = "GPU"


def bloom(scene):
    """Glow like the game: HDR threshold 1.0, intensity 0.8."""
    tree = bpy.data.node_groups.new("Bloom", "CompositorNodeTree")
    tree.interface.new_socket("Image", in_out="OUTPUT", socket_type="NodeSocketColor")
    layers = tree.nodes.new("CompositorNodeRLayers")
    layers.scene = scene
    glare = tree.nodes.new("CompositorNodeGlare")
    glare.inputs["Type"].default_value = "Bloom"
    glare.inputs["Threshold"].default_value = 1.0
    glare.inputs["Strength"].default_value = 0.8
    output = tree.nodes.new("NodeGroupOutput")
    tree.links.new(layers.outputs["Image"], glare.inputs["Image"])
    tree.links.new(glare.outputs["Image"], output.inputs["Image"])
    scene.compositing_node_group = tree


def fog_material(density):
    """Volumetric fog: light teal-grey, anisotropy 0.45."""
    mat = bpy.data.materials.new("Fog")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    nodes.remove(nodes["Principled BSDF"])
    scatter = nodes.new("ShaderNodeVolumeScatter")
    scatter.inputs["Color"].default_value = (0.6, 0.7, 0.7, 1)
    scatter.inputs["Density"].default_value = density
    scatter.inputs["Anisotropy"].default_value = 0.45
    mat.node_tree.links.new(scatter.outputs["Volume"], nodes["Material Output"].inputs["Volume"])
    return mat


def material(hex_code, rough=0.8, metal=0.0, glow=0.0, wet=False, checker=None):
    """One shared material per look. glow is HDR emission; keep it for lights and bio-green.

    wet adds puddles (noise-driven roughness); checker=(hex, size) adds square tiles.
    """
    key = (hex_code, rough, metal, glow, wet, checker)
    if key in _state["materials"]:
        return _state["materials"][key]
    mat = bpy.data.materials.new(hex_code)
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    bsdf = nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*linear(hex_code), 1)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    bsdf.inputs["Emission Color"].default_value = (*linear(hex_code), 1)
    bsdf.inputs["Emission Strength"].default_value = glow
    if wet:
        puddles(mat, hex_code, rough)
    if checker:
        tiles = nodes.new("ShaderNodeTexChecker")
        tiles.inputs["Color1"].default_value = (*linear(hex_code), 1)
        tiles.inputs["Color2"].default_value = (*linear(checker[0]), 1)
        tiles.inputs["Scale"].default_value = 1 / checker[1]
        offset = nodes.new("ShaderNodeMapping")
        offset.inputs["Location"].default_value = (0.013, 0.017, 0.011)  # keeps faces off a tile boundary
        coords = nodes.new("ShaderNodeTexCoord")
        links.new(coords.outputs["Object"], offset.inputs["Vector"])
        links.new(offset.outputs["Vector"], tiles.inputs["Vector"])
        links.new(tiles.outputs["Color"], bsdf.inputs["Base Color"])
    _state["materials"][key] = mat
    return mat


def puddles(mat, hex_code, rough):
    """Wet floor: noise patches that are darker and mirror-smooth."""
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    bsdf = nodes["Principled BSDF"]
    noise = nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 0.45
    dry = nodes.new("ShaderNodeMapRange")  # 0 in a puddle, 1 on dry floor
    dry.inputs["From Min"].default_value = 0.42
    dry.inputs["From Max"].default_value = 0.58
    roughness = nodes.new("ShaderNodeMath")
    roughness.operation = "MULTIPLY_ADD"
    roughness.inputs[1].default_value = rough
    roughness.inputs[2].default_value = 0.04
    shade = nodes.new("ShaderNodeMix")
    shade.data_type = "RGBA"
    shade.inputs[6].default_value = (*(c * 0.5 for c in linear(hex_code)), 1)
    shade.inputs[7].default_value = (*linear(hex_code), 1)
    links.new(nodes.new("ShaderNodeTexCoord").outputs["Object"], noise.inputs["Vector"])
    links.new(noise.outputs["Fac"], dry.inputs["Value"])
    links.new(dry.outputs["Result"], roughness.inputs[0])
    links.new(dry.outputs["Result"], shade.inputs[0])
    links.new(roughness.outputs[0], bsdf.inputs["Roughness"])
    links.new(shade.outputs[2], bsdf.inputs["Base Color"])


def add(name, bm, mat, at, rot=(0, 0, 0), bevel=0.0, smooth=False):
    """Turn a bmesh into a linked object."""
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    if smooth:
        mesh.polygons.foreach_set("use_smooth", [True] * len(mesh.polygons))
        mesh.set_sharp_from_angle(angle=math.radians(40))
    mesh.materials.append(mat)
    obj = bpy.data.objects.new(name, mesh)
    obj.location = at
    obj.rotation_euler = [math.radians(angle) for angle in rot]
    if bevel:
        mod = obj.modifiers.new("Bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 2
    _state["scene"].collection.objects.link(obj)
    return obj


def box(name, at, size, mat, rot=(0, 0, 0), bevel=0.03):
    """A box standing on `at` (centre of its base). rot is in degrees."""
    bm = bmesh.new()
    lift = Matrix.Translation((0, 0, size[2] / 2))
    bmesh.ops.create_cube(bm, size=1, matrix=lift @ Matrix.Diagonal((*size, 1)))
    return add(name, bm, mat, at, rot, bevel)


def cylinder(name, at, radius, height, mat, rot=(0, 0, 0), top=None, segments=24):
    """An upright cylinder (or cone, with `top` radius) standing on `at`."""
    bm = bmesh.new()
    bmesh.ops.create_cone(
        bm,
        cap_ends=True,
        segments=segments,
        radius1=radius,
        radius2=radius if top is None else top,
        depth=height,
        matrix=Matrix.Translation((0, 0, height / 2)),
    )
    return add(name, bm, mat, at, rot, smooth=True)


def tube(name, start, end, radius, mat):
    """A pipe, limb or cable between two points."""
    start, end = Vector(start), Vector(end)
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=12, radius1=radius, radius2=radius, depth=(end - start).length)
    obj = add(name, bm, mat, (start + end) / 2, smooth=True)
    obj.rotation_euler = (end - start).to_track_quat("Z", "Y").to_euler()
    return obj


def ball(name, at, radius, mat, scale=(1, 1, 1)):
    """A sphere centred on `at`, stretched by `scale`."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=24, v_segments=12, radius=radius, matrix=Matrix.Diagonal((*scale, 1)))
    return add(name, bm, mat, at, smooth=True)


def light(name, kind, at, hex_code, watts, aim=None, size=1.0, cone=70):
    """An AREA, SPOT or POINT light. It points at `aim`, or straight down."""
    data = bpy.data.lights.new(name, kind)
    data.energy = watts
    data.color = linear(hex_code)
    if kind == "AREA":
        data.size = size
    else:
        data.shadow_soft_size = size
    if kind == "SPOT":
        data.spot_size = math.radians(cone)
        data.spot_blend = 0.5
    obj = bpy.data.objects.new(name, data)
    obj.location = at
    target = Vector(aim) if aim else Vector(at) - Vector((0, 0, 1))
    obj.rotation_euler = (target - Vector(at)).to_track_quat("-Z", "Y").to_euler()
    _state["scene"].collection.objects.link(obj)
    return obj


def fixture(at, watts=220, along_y=False, hex_code=FLUORESCENT):
    """A ceiling tube light: a glowing tube and the area light that does the lighting."""
    size = (0.25, 2.4, 0.08) if along_y else (2.4, 0.25, 0.08)
    box("Tube", at, size, material(hex_code, glow=12), bevel=0)
    light("TubeLight", "AREA", (at[0], at[1], at[2] - 0.05), hex_code, watts, size=2.0)


def lit(at, facing=0, clothes=LAB_COAT, hem=0.55, flare=1.0):
    """A 1.8 m Lit host for scale. `hem` is where the garment ends; head is the lightest value."""
    root = bpy.data.objects.new("Lit", None)
    root.location = at
    root.rotation_euler = (0, 0, math.radians(facing))
    _state["scene"].collection.objects.link(root)
    eye = material(BIO_GREEN, glow=6)
    parts = [
        box("LegL", (-0.12, 0, 0), (0.16, 0.18, 0.9), material(TROUSERS)),
        box("LegR", (0.12, 0, 0), (0.16, 0.18, 0.9), material(TROUSERS)),
        box("Clothes", (0, 0, hem), (0.5 * flare, 0.28 * flare, 1.48 - hem), material(clothes)),
        box("ArmL", (-0.31, -0.25, 1.25), (0.11, 0.6, 0.11), material(SKIN), rot=(-15, 0, 0)),
        box("ArmR", (0.31, -0.25, 1.3), (0.11, 0.6, 0.11), material(SKIN), rot=(10, 0, 0)),
        ball("Head", (0, -0.03, 1.64), 0.14, material(HEAD)),
        ball("EyeL", (-0.05, -0.15, 1.66), 0.022, eye),
        ball("EyeR", (0.05, -0.15, 1.66), 0.022, eye),
    ]
    for part in parts:
        part.parent = root
    return root


def camera(name, at, aim, fov):
    """A camera at `at` looking at `aim`. fov is horizontal, in degrees."""
    data = bpy.data.cameras.new(name)
    data.angle = math.radians(fov)
    obj = bpy.data.objects.new(name, data)
    obj.location = at
    obj.rotation_euler = (Vector(aim) - Vector(at)).to_track_quat("-Z", "Y").to_euler()
    _state["scene"].collection.objects.link(obj)
    return obj


def render_shots(shots, cutaway=()):
    """Render {name: (at, aim, fov)} to JPGs under MAX_BYTES.

    `cutaway` objects (ceiling, near walls) still block light but are hidden
    from the camera in the overview shot.
    """
    scene = _state["scene"]
    folder = OUT / scene.name
    folder.mkdir(parents=True, exist_ok=True)
    for name, (at, aim, fov) in shots.items():
        scene.camera = camera(name, at, aim, fov)
        for obj in cutaway:
            obj.visible_camera = name != "overview"
        bpy.ops.render.render(scene=scene.name)
        path = folder / f"{name}.jpg"
        for quality in (92, 85, 75, 60):
            scene.render.image_settings.quality = quality
            bpy.data.images["Render Result"].save_render(str(path), scene=scene)
            if path.stat().st_size <= MAX_BYTES:
                break
        print(f"{path}: {path.stat().st_size // 1000} KB at quality {quality}")
