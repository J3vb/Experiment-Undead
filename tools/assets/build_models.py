"""Builds the code-made 3D models (style-guide look, stage A) and exports them as .glb.

Run from the repo root:
    pip install -r tools/assets/requirements.txt
    python tools/assets/build_models.py                 # all models into assets/models/
    python tools/assets/build_models.py --out /tmp/x    # somewhere else
    python tools/assets/build_models.py wall_panel      # one model

Blender axes: +Y is the gun's forward, +Z is up. The glTF exporter turns that
into Godot's -Z forward, +Y up. Units are metres.
"""

import argparse
import os
import sys

import bpy
from mathutils import Vector

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# Cold Containment palette (see the visual style guide).
# Linear values. Wall paint is #5F6D68 from the guide.
WALL_PAINT = (0.114, 0.153, 0.138, 1.0)
WALL_TRIM = (0.04, 0.05, 0.05, 1.0)
GUN_METAL = (0.2, 0.205, 0.21, 1.0)
MATTE_BLACK = (0.025, 0.025, 0.027, 1.0)
TAN = (0.3, 0.24, 0.16, 1.0)
LENS = (0.05, 0.12, 0.13, 1.0)
WOOD = (0.075, 0.042, 0.022, 1.0)


def srgb(hex_code: str) -> tuple:
    """Style-guide hex colour to the linear RGBA Blender and glTF expect."""
    out = []
    for i in (1, 3, 5):
        c = int(hex_code[i : i + 2], 16) / 255.0
        out.append(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4)
    return (*out, 1.0)


# Zombies: heads are always the lightest value in the silhouette; only bio-green glows.
SKIN_HEAD = srgb("#B9C2B0")
SKIN = srgb("#8E9887")
SKIN_DARK = srgb("#6C7566")
LAB_COAT = srgb("#8A918C")
SHIRT = srgb("#2F393B")
TROUSERS = srgb("#1C2122")
SHOES = srgb("#0E1010")
BLOATER_SKIN = srgb("#4A5446")
BIO_GREEN = srgb("#8DFF3A")


def reset_scene() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)


def material(name: str, color: tuple, metallic: float = 0.0, roughness: float = 0.8, glow: float = 0.0):
    mat = bpy.data.materials.get(name)
    if mat:
        return mat
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if glow > 0.0:
        bsdf.inputs["Emission Color"].default_value = color
        bsdf.inputs["Emission Strength"].default_value = glow
    return mat


def box(name: str, size: tuple, at: tuple, mat, bevel: float = 0.0, parent=None):
    """A box of `size` (x, y, z) centred on `at`, with optional bevelled edges."""
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=at)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel > 0.0:
        mod = obj.modifiers.new("Bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        mod.limit_method = "ANGLE"
        bpy.ops.object.modifier_apply(modifier=mod.name)
    obj.data.materials.append(mat)
    obj.parent = parent
    return obj


AXIS_TURN = {"x": (0, 1.5708, 0), "y": (1.5708, 0, 0), "z": (0, 0, 0)}


def cylinder(name: str, radius: float, length: float, at: tuple, mat, parent=None, axis: str = "y"):
    """A cylinder along `axis`; the default +Y is the gun's forward axis."""
    turn = AXIS_TURN[axis]
    bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=radius, depth=length, location=at, rotation=turn)
    obj = bpy.context.active_object
    obj.name = name
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    bpy.ops.object.shade_smooth()
    obj.data.materials.append(mat)
    obj.parent = parent
    return obj


def marker(name: str, at: tuple, parent=None):
    """An empty; exported as a plain Node3D for code to find (muzzle, eject port)."""
    obj = bpy.data.objects.new(name, None)
    obj.location = at
    obj.parent = parent
    bpy.context.scene.collection.objects.link(obj)
    return obj


def build_wall_panel() -> None:
    """Modular wall piece: 2 m wide, 3 m high, 0.2 m thick, origin at bottom centre."""
    paint = material("WallPaint", WALL_PAINT, roughness=0.75)
    trim = material("WallTrim", WALL_TRIM, roughness=0.9)
    box("Panel", (2.0, 0.2, 2.7), (0, 0, 1.65), paint, bevel=0.02)
    box("BaseTrim", (2.0, 0.24, 0.3), (0, 0, 0.15), trim, bevel=0.015)
    box("Stripe", (2.0, 0.22, 0.08), (0, 0, 1.15), trim)
    box("Seam", (0.03, 0.21, 2.7), (0, 0, 1.65), trim)


def rifle_upper(metal, black, tan, parts: list) -> None:
    """Receiver, rail, handguard and barrel; all parts are added to `parts` for joining."""
    parts += [
        box("Upper", (0.05, 0.34, 0.052), (0, 0.0, 0.02), metal, bevel=0.005),
        box("Lower", (0.046, 0.22, 0.048), (0, -0.02, -0.028), black, bevel=0.005),
        box("Rail", (0.024, 0.52, 0.012), (0, 0.09, 0.052), black, bevel=0.002),
        box("PortCover", (0.004, 0.07, 0.024), (0.026, 0.03, 0.02), metal),
        box("Handguard", (0.058, 0.3, 0.06), (0, 0.32, 0.016), tan, bevel=0.01),
        box("GasBlock", (0.03, 0.03, 0.03), (0, 0.5, 0.016), black, bevel=0.003),
        box("MagWell", (0.044, 0.08, 0.03), (0, 0.06, -0.06), black, bevel=0.004),
        box("TriggerGuard", (0.012, 0.08, 0.006), (0, -0.065, -0.088), black),
        box("GuardPost", (0.012, 0.006, 0.04), (0, -0.028, -0.07), black),
        box("Trigger", (0.006, 0.008, 0.028), (0, -0.06, -0.066), metal),
    ]
    for i in range(18):
        parts.append(box(f"RailTooth{i}", (0.027, 0.012, 0.006), (0, -0.15 + i * 0.028, 0.06), black))
    for side in (-1, 1):
        for i in range(4):
            parts.append(box(f"Vent{side}{i}", (0.002, 0.04, 0.012), (side * 0.0295, 0.23 + i * 0.055, 0.02), black))


def rifle_stock(metal, black, tan, parts: list) -> None:
    """Pistol grip, buffer tube and stock."""
    grip = box("Grip", (0.034, 0.045, 0.11), (0, -0.115, -0.095), black, bevel=0.008)
    grip.rotation_euler = (-0.3, 0, 0)
    parts += [
        grip,
        cylinder("BufferTube", 0.016, 0.15, (0, -0.235, 0.015), metal),
        box("Stock", (0.044, 0.15, 0.075), (0, -0.315, 0.0), tan, bevel=0.01),
        box("CheekRest", (0.04, 0.12, 0.02), (0, -0.315, 0.045), black, bevel=0.006),
        box("ButtPad", (0.046, 0.02, 0.11), (0, -0.39, -0.012), black, bevel=0.006),
    ]


def rifle_scope(metal, black, glass, parts: list) -> None:
    """Low-power scope on two rings. The front lens stays its own node (rarity colour later)."""
    parts += [
        box("RingFront", (0.03, 0.022, 0.035), (0, 0.1, 0.07), black, bevel=0.003),
        box("RingBack", (0.03, 0.022, 0.035), (0, -0.04, 0.07), black, bevel=0.003),
        cylinder("ScopeTube", 0.015, 0.2, (0, 0.03, 0.09), black),
        cylinder("ScopeBell", 0.022, 0.06, (0, 0.16, 0.09), black),
        cylinder("ScopeCone", 0.019, 0.02, (0, 0.123, 0.09), black),
        cylinder("Eyepiece", 0.019, 0.05, (0, -0.095, 0.09), black),
        cylinder("EyeRing", 0.0195, 0.008, (0, -0.122, 0.09), metal),
        cylinder("TurretTop", 0.01, 0.02, (0, 0.03, 0.11), metal, axis="z"),
        cylinder("TurretSide", 0.009, 0.018, (0.02, 0.03, 0.09), metal, axis="x"),
        cylinder("EyeLens", 0.016, 0.002, (0, -0.126, 0.09), glass),
    ]


def build_rifle_ar() -> None:
    """Assault rifle from parts. Static parts are joined into Receiver; Magazine, Bolt,
    Barrel and OpticGlass stay separate nodes so code can move or recolour them."""
    metal = material("GunMetal", GUN_METAL, metallic=0.8, roughness=0.4)
    black = material("MatteBlack", MATTE_BLACK, roughness=0.75)
    tan = material("Tan", TAN, roughness=0.8)
    glass = material("OpticGlass", LENS, metallic=0.3, roughness=0.05, glow=0.6)

    receiver = box("Receiver", (0.04, 0.12, 0.03), (0, 0.0, 0.0), metal, bevel=0.004)
    parts: list = []
    rifle_upper(metal, black, tan, parts)
    rifle_stock(metal, black, tan, parts)
    rifle_scope(metal, black, glass, parts)
    join_into(receiver, parts)

    barrel = cylinder("Barrel", 0.011, 0.17, (0, 0.555, 0.016), metal, parent=receiver)
    cylinder("MuzzleBrake", 0.016, 0.04, (0, 0.06, 0), black, parent=barrel)
    mag = box("Magazine", (0.034, 0.075, 0.15), (0, 0.065, -0.135), black, bevel=0.005, parent=receiver)
    mag.rotation_euler = (0.18, 0, 0)
    box("MagBase", (0.04, 0.085, 0.012), (0, 0, -0.08), black, bevel=0.003, parent=mag)
    box("Bolt", (0.014, 0.05, 0.016), (0.034, -0.03, 0.03), metal, bevel=0.003, parent=receiver)
    cylinder("OpticGlass", 0.02, 0.002, (0, 0.191, 0.09), glass, parent=receiver)
    marker("Muzzle", (0, 0.635, 0.016), parent=receiver)


def build_talon_dmr() -> None:
    """Build the detailed DMR using the same primitives as the rifle and shotgun."""
    from talon_model import build_talon_dmr as build

    build(sys.modules[__name__])


def shotgun_body(metal, black, wood, parts: list) -> None:
    """Receiver, barrel with a vented heat shield, magazine tube and wooden stock."""
    stock = box("Stock", (0.044, 0.22, 0.1), (0, -0.27, -0.045), wood, bevel=0.012)
    stock.rotation_euler = (0.08, 0, 0)
    wrist = box("Wrist", (0.036, 0.12, 0.05), (0, -0.12, -0.012), wood, bevel=0.01)
    wrist.rotation_euler = (-0.25, 0, 0)
    parts += [
        stock,
        wrist,
        box("ButtPad", (0.046, 0.02, 0.115), (0, -0.385, -0.05), black, bevel=0.006),
        cylinder("Barrel", 0.013, 0.5, (0, 0.37, 0.03), metal),
        cylinder("MagTube", 0.012, 0.4, (0, 0.32, -0.003), metal),
        cylinder("TubeCap", 0.014, 0.02, (0, 0.53, -0.003), black),
        box("BarrelBand", (0.03, 0.02, 0.05), (0, 0.5, 0.014), black, bevel=0.003),
        box("Bead", (0.004, 0.006, 0.008), (0, 0.615, 0.046), metal),
        box("PortCover", (0.004, 0.07, 0.03), (0.027, 0.03, 0.022), black),
        box("TriggerGuard", (0.012, 0.075, 0.006), (0, -0.035, -0.06), black),
        box("GuardPost", (0.012, 0.006, 0.035), (0, 0.0, -0.045), black),
        box("Trigger", (0.006, 0.008, 0.026), (0, -0.03, -0.04), metal),
        box("Loading", (0.03, 0.08, 0.006), (0, 0.04, -0.023), black),
    ]
    parts.append(box("Shield", (0.036, 0.3, 0.008), (0, 0.33, 0.052), black, bevel=0.002))
    for side in (-1, 1):
        parts.append(box(f"ShieldSide{side}", (0.004, 0.3, 0.024), (side * 0.017, 0.33, 0.04), black))
        for i in range(6):
            parts.append(box(f"Hole{side}{i}", (0.002, 0.026, 0.01), (side * 0.0195, 0.21 + i * 0.048, 0.04), metal))


def build_shotgun_brenner() -> None:
    """Brenner Trench pump shotgun. The wooden pump is the `Bolt` node so the
    viewmodel racks it on every shot; there is no Magazine (shells load one by one)."""
    metal = material("GunMetal", GUN_METAL, metallic=0.8, roughness=0.4)
    black = material("MatteBlack", MATTE_BLACK, roughness=0.75)
    wood = material("Wood", WOOD, roughness=0.7)

    receiver = box("Receiver", (0.05, 0.2, 0.06), (0, 0.02, 0.012), metal, bevel=0.005)
    parts: list = []
    shotgun_body(metal, black, wood, parts)
    join_into(receiver, parts)

    # Children of Receiver are placed relative to it (it sits at y 0.02, z 0.012).
    pump = cylinder("Bolt", 0.022, 0.14, (0, 0.24, -0.015), wood, parent=receiver)
    grooves = [cylinder(f"Groove{i}", 0.0225, 0.006, (0, 0.21 + i * 0.025, -0.003), black) for i in range(5)]
    join_into(pump, grooves)
    marker("Muzzle", (0, 0.605, 0.018), parent=receiver)


def build_kestrel_smg() -> None:
    """Build the detailed SMG using the same primitives as the rifle and shotgun."""
    from kestrel_model import build_kestrel_smg as build

    build(sys.modules[__name__])


def join_into(target, parts: list) -> None:
    """Merges `parts` into `target` so the static body is one mesh (fewer draw calls)."""
    bpy.ops.object.select_all(action="DESELECT")
    for obj in parts:
        obj.select_set(True)
    target.select_set(True)
    bpy.context.view_layer.objects.active = target
    bpy.ops.object.join()


def attach(obj, pivot: tuple, parent=None):
    """Moves the origin to `pivot` (the joint code rotates around) and parents without moving."""
    bpy.context.scene.cursor.location = pivot
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    if parent:
        bpy.context.view_layer.update()
        obj.parent = parent
        obj.matrix_parent_inverse = parent.matrix_world.inverted()
    return obj


def ball(name: str, radius: float, at: tuple, mat, squash: tuple = (1, 1, 1), parent=None):
    """A smooth sphere, scaled by `squash`, with its origin at its centre."""
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=10, radius=radius, location=at)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = squash
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bpy.ops.object.shade_smooth()
    obj.data.materials.append(mat)
    return attach(obj, at, parent)


def limb(name: str, start: tuple, end: tuple, radius: float, mat, parent=None):
    """A rounded cylinder from `start` to `end`, origin at `start` so it swings like a joint."""
    a, b = Vector(start), Vector(end)
    tilt = Vector((0, 0, 1)).rotation_difference(b - a).to_euler()
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=12, radius=radius, depth=(b - a).length, location=(a + b) / 2, rotation=tilt
    )
    obj = bpy.context.active_object
    obj.name = name
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    mod = obj.modifiers.new("Round", "BEVEL")
    mod.width = radius * 0.6
    mod.segments = 3
    mod.limit_method = "ANGLE"
    bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.ops.object.shade_auto_smooth()
    obj.data.materials.append(mat)
    return attach(obj, start, parent)


def tilted_box(name: str, size: tuple, at: tuple, lean: float, mat, pivot: tuple, parent=None):
    """A bevelled box leaned forward by `lean` radians around its pivot (forward is -Y)."""
    obj = box(name, size, at, mat, bevel=min(size) * 0.25)
    attach(obj, pivot, parent)
    obj.rotation_euler = (lean, 0, 0)
    bpy.context.view_layer.update()
    return obj


def head(at: tuple, radius: float, parent, glow: float = 4.0):
    """Light head with two faint green eyes on its front (-Y)."""
    skull = ball("Head", radius, at, material("SkinHead", SKIN_HEAD, roughness=0.7), (0.9, 1.0, 1.12), parent)
    eye = material("Eye", BIO_GREEN, roughness=0.4, glow=glow)
    for side, x in (("EyeL", -0.4), ("EyeR", 0.4)):
        spot = (at[0] + x * radius, at[1] - radius * 0.86, at[2] + radius * 0.1)
        ball(side, radius * 0.16, spot, eye, (1.3, 0.5, 0.7), skull)
    return skull


def build_shambler() -> None:
    """Shambler in a lab coat, leaning in with both arms reaching. Faces -Y (Godot +Z), feet at 0."""
    skin = material("Skin", SKIN, roughness=0.8)
    coat = material("LabCoat", LAB_COAT, roughness=0.9)
    trousers = material("Trousers", TROUSERS, roughness=0.95)
    shoes = material("Shoes", SHOES, roughness=0.7)
    hips = box("Hips", (0.34, 0.22, 0.16), (0, 0, 0.95), trousers, bevel=0.04)
    for side, x, foot_y in (("L", -0.1, 0.06), ("R", 0.1, -0.16)):
        leg = limb("Leg" + side, (x, 0, 0.94), (x * 1.2, foot_y, 0.09), 0.075, trousers, hips)
        foot = (x * 1.2, foot_y - 0.06, 0.04)
        attach(box("Foot" + side, (0.11, 0.24, 0.08), foot, shoes, bevel=0.02), foot, leg)
    torso = tilted_box("Torso", (0.42, 0.25, 0.58), (0, 0, 1.3), 0.22, coat, (0, 0, 1.0), hips)
    tilted_box(
        "Shirt", (0.13, 0.03, 0.42), (0, -0.12, 1.3), 0.22, material("Shirt", SHIRT, roughness=0.9), (0, 0, 1.0), torso
    )
    bpy.ops.mesh.primitive_cone_add(vertices=16, radius1=0.3, radius2=0.23, depth=0.6, location=(0, 0.02, 0.78))
    skirt = bpy.context.active_object
    skirt.name = "CoatSkirt"
    skirt.scale = (1, 0.7, 1)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    skirt.data.materials.append(coat)
    attach(skirt, (0, 0, 1.0), hips)
    head((0.02, -0.2, 1.71), 0.125, torso)
    for side, x, hand in (("L", -0.25, (-0.4, -0.66, 1.4)), ("R", 0.25, (0.44, -0.56, 1.26))):
        arm = limb("Arm" + side, (x, -0.13, 1.5), hand, 0.05, skin, torso)
        limb(
            "Sleeve" + side,
            (x, -0.13, 1.5),
            [(p + q) / 2 for p, q in zip((x, -0.13, 1.5), hand, strict=True)],
            0.07,
            coat,
            arm,
        )


def build_crawler() -> None:
    """Crawler: legs gone, chest low, dragging itself on its arms. Faces -Y, belly at 0."""
    skin = material("SkinDark", SKIN_DARK, roughness=0.85)
    shirt = material("Shirt", SHIRT, roughness=0.9)
    hips = box("Hips", (0.32, 0.24, 0.16), (0, 0.42, 0.16), material("Trousers", TROUSERS, roughness=0.95), bevel=0.04)
    for side, x in (("L", -0.09), ("R", 0.1)):
        limb("Stump" + side, (x, 0.48, 0.14), (x * 1.3, 0.72, 0.1), 0.07, hips.data.materials[0], hips)
    torso = tilted_box("Torso", (0.38, 0.22, 0.55), (0, 0.38, 0.455), 1.2, shirt, (0, 0.38, 0.18), hips)
    head((0, -0.25, 0.5), 0.12, torso)
    for side, x, reach in (("L", -1, 0.72), ("R", 1, 0.45)):
        elbow = (x * 0.4, -0.2, 0.3)
        arm = limb("Arm" + side, (x * 0.2, -0.08, 0.38), elbow, 0.05, skin, torso)
        limb("Forearm" + side, elbow, (x * 0.36, -reach, 0.03), 0.045, skin, arm)


def build_bloater() -> None:
    """Bloater: wide and slow, with a glowing green belly (pulses in code when hurt). Faces -Y."""
    skin = material("BloaterSkin", BLOATER_SKIN, roughness=0.75)
    trousers = material("Trousers", TROUSERS, roughness=0.95)
    hips = box("Hips", (0.5, 0.36, 0.2), (0, 0, 0.8), trousers, bevel=0.05)
    for side, x in (("L", -0.17), ("R", 0.17)):
        leg = limb("Leg" + side, (x, 0, 0.8), (x * 1.15, 0, 0.1), 0.11, trousers, hips)
        foot = (x * 1.15, -0.05, 0.045)
        attach(box("Foot" + side, (0.15, 0.26, 0.09), foot, material("Shoes", SHOES), bevel=0.02), foot, leg)
    torso = ball("Torso", 0.4, (0, 0.04, 1.25), skin, (1.05, 0.85, 1.0), hips)
    ball(
        "Belly", 0.36, (0, -0.16, 1.13), material("Belly", BIO_GREEN, roughness=0.3, glow=1.6), (1.0, 0.85, 0.95), torso
    )
    head((0, -0.06, 1.72), 0.12, torso, glow=3.0)
    for side, x in (("L", -1), ("R", 1)):
        limb("Arm" + side, (x * 0.38, 0, 1.45), (x * 0.56, -0.18, 0.98), 0.085, skin, torso)


MODELS = {
    "wall_panel": ("kit/wall_panel.glb", build_wall_panel),
    "rifle_ar": ("weapons/rifle_ar.glb", build_rifle_ar),
    "kestrel_smg": ("weapons/kestrel_smg.glb", build_kestrel_smg),
    "talon_dmr": ("weapons/talon_dmr.glb", build_talon_dmr),
    "shotgun_brenner": ("weapons/shotgun_brenner.glb", build_shotgun_brenner),
    "shambler": ("zombies/shambler.glb", build_shambler),
    "crawler": ("zombies/crawler.glb", build_crawler),
    "bloater": ("zombies/bloater.glb", build_bloater),
}


def export(path: str) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_yup=True, export_apply=True)


def main(argv: list) -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("names", nargs="*", help="models to build (default: all)")
    parser.add_argument("--out", default=os.path.join(REPO, "assets", "models"))
    args = parser.parse_args(argv)
    for name in args.names or MODELS:
        if name not in MODELS:
            sys.exit(f"unknown model: {name} (known: {', '.join(MODELS)})")
        rel_path, build = MODELS[name]
        reset_scene()
        build()
        export(os.path.join(args.out, rel_path))
        print(f"built {name} -> {rel_path}")


if __name__ == "__main__":
    main(sys.argv[1:])
