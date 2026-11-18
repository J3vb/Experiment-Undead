"""Lantern Post props built in code: street lamp, wall lantern, windows and signpost.

The camp props P1-P13 of the asset list (fire barrel, benches, crates, lanterns, pines, ...) live in
town_camp.py.

Built through build_models.py (MODELS has one line per prop). Blender +Z is up and
fronts face Blender -Y (Godot +Z). Every prop stands on the origin.
"""

import math

import bpy

SODIUM = "#FF9A3C"
IRON = (0.012, 0.012, 0.014, 1.0)
STONE = "#6E6A64"
DARK_WOOD = "#3A2617"
SHUTTER_WOOD = "#6B4528"
DARK_GLASS = "#1A2228"
WINDOW_GLOW = "#FFB066"


def box(*args, **kwargs):
    from build_models import box as build_box

    return build_box(*args, **kwargs)


def material(name: str, color, **kwargs):
    from build_models import material as build_material
    from build_models import srgb

    return build_material(name, srgb(color) if isinstance(color, str) else color, **kwargs)


def _iron():
    return material("Iron", IRON, metallic=0.7, roughness=0.5)


def _glass(lit: bool):
    if lit:
        return material("LampGlass", SODIUM, roughness=0.2, glow=6.0)
    return material("DarkGlass", DARK_GLASS, roughness=0.15)


def _tube(name: str, radius_top: float, radius_bottom: float, length: float, at: tuple, mat, vertices: int = 10):
    bpy.ops.mesh.primitive_cone_add(
        vertices=vertices, radius1=radius_bottom, radius2=radius_top, depth=length, location=at
    )
    obj = bpy.context.active_object
    obj.name = name
    bpy.ops.object.shade_smooth()
    obj.data.materials.append(mat)
    return obj


def _lantern_head(prefix: str, top: float, size: float, iron, glass) -> None:
    """Four glowing panes in an iron cage with a pyramid cap, hung below `top`."""
    half = size / 2
    box(f"{prefix}Glass", (size * 0.86, size * 0.86, size * 1.1), (0, 0, top - size * 0.75), glass)
    for i, (x, y) in enumerate(((-1, -1), (-1, 1), (1, -1), (1, 1))):
        box(f"{prefix}Rail{i}", (0.03, 0.03, size * 1.2), (x * half, y * half, top - size * 0.75), iron)
    box(f"{prefix}Base", (size * 1.05, size * 1.05, 0.04), (0, 0, top - size * 1.35), iron, bevel=0.008)
    box(f"{prefix}Rim", (size * 1.15, size * 1.15, 0.05), (0, 0, top - size * 0.13), iron, bevel=0.01)
    _tube(f"{prefix}Cap", 0.01, size * 0.82, size * 0.45, (0, 0, top + size * 0.1), iron, vertices=4).rotation_euler = (
        0,
        0,
        math.pi / 4,
    )
    _tube(f"{prefix}Finial", 0.012, 0.03, 0.12, (0, 0, top + size * 0.38), iron, vertices=8)


def build_street_lamp() -> None:
    """Iron street lamp, 4.6 m: stone plinth, fluted post, arm reaching -Y with a lantern."""
    iron, stone, glass = _iron(), material("Stone", STONE, roughness=0.9), _glass(True)
    box("Plinth", (0.46, 0.46, 0.4), (0, 0.3, 0.2), stone, bevel=0.03)
    box("PlinthCap", (0.38, 0.38, 0.08), (0, 0.3, 0.44), stone, bevel=0.02)
    _tube("Foot", 0.08, 0.13, 0.5, (0, 0.3, 0.73), iron)
    _tube("Post", 0.055, 0.075, 3.6, (0, 0.3, 2.78), iron)
    for i, z in enumerate((1.05, 2.4, 4.3)):
        _tube(f"Collar{i}", 0.09, 0.09, 0.06, (0, 0.3, z), iron)
    box("Arm", (0.05, 0.75, 0.05), (0, -0.05, 4.45), iron)
    bpy.ops.mesh.primitive_torus_add(
        major_radius=0.18, minor_radius=0.018, major_segments=16, minor_segments=6, location=(0, 0.1, 4.27)
    )
    curl = bpy.context.active_object
    curl.name = "Curl"
    curl.rotation_euler = (0, math.pi / 2, 0)
    curl.data.materials.append(iron)
    box("Hanger", (0.03, 0.03, 0.12), (0, -0.4, 4.39), iron)
    _lantern_head("Head", 4.32, 0.32, iron, glass)


def build_wall_lantern() -> None:
    """Wall lantern: back plate on the wall (+Y side), bracket reaching -Y, small lantern."""
    iron, glass = _iron(), _glass(True)
    box("Plate", (0.16, 0.03, 0.34), (0, 0.22, 0.75), iron, bevel=0.006)
    box("Bracket", (0.035, 0.42, 0.035), (0, 0.02, 0.88), iron)
    box("Brace", (0.025, 0.3, 0.025), (0, 0.08, 0.76), iron).rotation_euler = (math.radians(-38), 0, 0)
    box("Hook", (0.02, 0.02, 0.08), (0, -0.17, 0.83), iron)
    _lantern_head("Head", 0.76, 0.2, iron, glass)
    bpy.context.view_layer.update()
    lowest = min((o.matrix_world @ v.co).z for o in bpy.context.scene.objects for v in o.data.vertices)
    for obj in bpy.context.scene.objects:
        obj.location.z -= lowest


def _window(lit: bool) -> None:
    """Window 1.0 x 1.25 m on a stone sill (bottom at the origin), shutters open, facing -Y."""
    frame = material("WindowFrame", DARK_WOOD, roughness=0.8)
    shutter = material("Shutter", SHUTTER_WOOD, roughness=0.85)
    stone = material("Stone", STONE, roughness=0.9)
    glass = _glass(lit) if not lit else material("WindowGlow", WINDOW_GLOW, roughness=0.2, glow=2.5)
    box("Sill", (1.2, 0.3, 0.08), (0, -0.08, 0.04), stone, bevel=0.012)
    centre = 0.08 + 0.625
    box("Glass", (0.82, 0.03, 1.07), (0, 0.02, centre), glass)
    for i, x in enumerate((-0.455, 0.455)):
        box(f"Jamb{i}", (0.09, 0.12, 1.25), (x, 0.0, centre), frame, bevel=0.01)
    for i, z in enumerate((0.08 + 0.045, 0.08 + 1.25 - 0.045)):
        box(f"Rail{i}", (1.0, 0.12, 0.09), (0, 0.0, z), frame, bevel=0.01)
    box("MullionV", (0.05, 0.06, 1.07), (0, -0.01, centre), frame)
    box("MullionH", (0.82, 0.06, 0.05), (0, -0.01, centre + 0.1), frame)
    box("Lintel", (1.2, 0.16, 0.12), (0, -0.02, 0.08 + 1.31), stone, bevel=0.012)
    for side in (-1, 1):
        x = side * 0.78
        for plank in range(3):
            px = x + (plank - 1) * 0.16
            box(f"Shutter{side + 1}Plank{plank}", (0.15, 0.04, 1.18), (px, -0.06, centre), shutter, bevel=0.006)
        for j, z in enumerate((centre - 0.4, centre + 0.4)):
            box(f"Shutter{side + 1}Batten{j}", (0.46, 0.03, 0.08), (x, -0.095, z), shutter)
        brace = box(f"Shutter{side + 1}Brace", (0.06, 0.03, 0.85), (x, -0.095, centre), shutter)
        brace.rotation_euler = (0, side * math.radians(38), 0)


def build_window_lit() -> None:
    _window(True)


def build_window_dark() -> None:
    _window(False)


def build_signpost() -> None:
    """Signpost, 2.6 m: post with two arrow boards (text is a Label3D in the scene)."""
    wood = material("SignWood", SHUTTER_WOOD, roughness=0.85)
    dark = material("SignPost", DARK_WOOD, roughness=0.85)
    box("Post", (0.14, 0.14, 2.6), (0, 0, 1.3), dark, bevel=0.015)
    _tube("PostTop", 0.0, 0.11, 0.14, (0, 0, 2.67), dark, vertices=4).rotation_euler = (0, 0, math.pi / 4)
    for i, (z, side) in enumerate(((2.25, 1), (1.85, -1))):
        board = box(f"Board{i}", (0.9, 0.05, 0.26), (side * 0.42, -0.1, z), wood, bevel=0.01)
        board.name = f"Board{i}"
        tip = _tube(f"Arrow{i}", 0.0, 0.185, 0.13, (side * 0.93, -0.1, z), wood, vertices=4)
        tip.rotation_euler = (math.pi / 2, math.pi / 4, side * math.pi / 2)


MODELS = {
    "street_lamp": ("town/street_lamp.glb", build_street_lamp),
    "wall_lantern": ("town/wall_lantern.glb", build_wall_lantern),
    "window_lit": ("town/window_lit.glb", build_window_lit),
    "window_dark": ("town/window_dark.glb", build_window_dark),
    "signpost": ("town/signpost.glb", build_signpost),
}
