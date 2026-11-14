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
GUN_METAL = (0.13, 0.13, 0.14, 1.0)
POLYMER = (0.06, 0.06, 0.06, 1.0)
TAN = (0.33, 0.28, 0.2, 1.0)
SIGHT_GLOW = (1.0, 0.55, 0.1, 1.0)


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


def cylinder(name: str, radius: float, length: float, at: tuple, mat, parent=None):
    """A cylinder along +Y (the gun's forward axis)."""
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=radius, depth=length, location=at, rotation=(1.5708, 0, 0))
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


def build_rifle_ar() -> None:
    """Assault rifle from parts. Magazine and Bolt stay separate nodes so reloads can move them."""
    metal = material("GunMetal", GUN_METAL, metallic=0.8, roughness=0.45)
    polymer = material("Polymer", POLYMER, roughness=0.75)
    tan = material("Tan", TAN, roughness=0.8)
    glow = material("SightGlow", SIGHT_GLOW, roughness=0.3, glow=2.0)

    receiver = box("Receiver", (0.065, 0.36, 0.09), (0, 0, 0), metal, bevel=0.006)
    box("Handguard", (0.07, 0.26, 0.075), (0, 0.3, 0.005), polymer, bevel=0.008, parent=receiver)
    cylinder("Barrel", 0.011, 0.2, (0, 0.53, 0.01), metal, parent=receiver)
    box("Stock", (0.055, 0.22, 0.08), (0, -0.28, -0.01), tan, bevel=0.01, parent=receiver)
    box("Grip", (0.04, 0.05, 0.11), (0, -0.09, -0.09), polymer, bevel=0.008, parent=receiver)
    box("SightBase", (0.04, 0.08, 0.035), (0, -0.02, 0.062), metal, bevel=0.004, parent=receiver)
    box("SightDot", (0.006, 0.006, 0.006), (0, -0.02, 0.085), glow, parent=receiver)
    box("Magazine", (0.035, 0.07, 0.14), (0, 0.06, -0.11), polymer, bevel=0.006, parent=receiver)
    box("Bolt", (0.012, 0.06, 0.02), (0.035, 0.0, 0.02), metal, parent=receiver)
    marker("Muzzle", (0, 0.63, 0.01), parent=receiver)


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
