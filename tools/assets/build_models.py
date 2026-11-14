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

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# Cold Containment palette (see the visual style guide).
CONCRETE = (0.42, 0.44, 0.45, 1.0)
CONCRETE_DARK = (0.24, 0.26, 0.27, 1.0)
GUN_METAL = (0.2, 0.205, 0.21, 1.0)
MATTE_BLACK = (0.025, 0.025, 0.027, 1.0)
TAN = (0.3, 0.24, 0.16, 1.0)
LENS = (0.05, 0.12, 0.13, 1.0)


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
    concrete = material("Concrete", CONCRETE, roughness=0.9)
    trim = material("ConcreteDark", CONCRETE_DARK, roughness=0.95)
    box("Panel", (2.0, 0.2, 2.7), (0, 0, 1.65), concrete, bevel=0.02)
    box("BaseTrim", (2.0, 0.24, 0.3), (0, 0, 0.15), trim, bevel=0.015)
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


def join_into(target, parts: list) -> None:
    """Merges `parts` into `target` so the static body is one mesh (fewer draw calls)."""
    bpy.ops.object.select_all(action="DESELECT")
    for obj in parts:
        obj.select_set(True)
    target.select_set(True)
    bpy.context.view_layer.objects.active = target
    bpy.ops.object.join()


MODELS = {
    "wall_panel": ("kit/wall_panel.glb", build_wall_panel),
    "rifle_ar": ("weapons/rifle_ar.glb", build_rifle_ar),
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
