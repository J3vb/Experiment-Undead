"""Halcyon Labs door models (plan F-63): sliding security bulkheads in hazard-orange paint.

Same rules as prop_models.py: one merged mesh per model, origin at its bottom centre, front facing
Blender -Y (Godot +Z), and it fits inside its door's Blocker box (width x 0.5 x 2.6). Slots map to the
shared Halcyon materials through prop_import.gd (`Hazard` is the buyable-door orange).
"""

from functools import partial

import bmesh
import bpy
import prop_models as p

HEIGHT = 2.6
LEAF_DEPTH = 0.22


def _door_mats() -> dict:
    from build_models import material, srgb

    m = p._mats()
    return {
        "hazard": material("Hazard", srgb("#D96614"), metallic=0.4, roughness=0.6),
        "dark": m["dark"],
        "steel": m["steel"],
        "glass": m["glass"],
    }


def _prism(name: str, outline: list, y0: float, y1: float, mat):
    """Extrudes a flat outline [(x, z), ...] (counter-clockwise seen from -Y) from y0 to y1."""
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    front = [bm.verts.new((x, y0, z)) for x, z in outline]
    back = [bm.verts.new((x, y1, z)) for x, z in outline]
    bm.faces.new(front)
    bm.faces.new(list(reversed(back)))
    count = len(outline)
    for i in range(count):
        j = (i + 1) % count
        bm.faces.new((front[j], front[i], back[i], back[j]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.data.materials.append(mat)
    return obj


def _chevron_band(m, width: float, side: int) -> None:
    """Black kick band near the floor with leaning orange stripes, on one face (side -1 front, 1 back)."""
    from build_models import box

    band_w, band_h, bottom = width - 0.12, 0.38, 0.06
    face = side * LEAF_DEPTH / 2
    box(f"Band{side}", (band_w, 0.02, band_h), (0, face + side * 0.01, bottom + band_h / 2), m["dark"])
    stripe, lean, step = 0.14, 0.22, 0.34
    y0, y1 = sorted((face + side * 0.02, face + side * 0.026))
    x = -band_w / 2 + 0.04
    i = 0
    while x + stripe + lean <= band_w / 2 - 0.04:
        lo, hi = bottom + 0.03, bottom + band_h - 0.03
        outline = [(x, lo), (x + stripe, lo), (x + stripe + lean, hi), (x + lean, hi)]
        _prism(f"Stripe{side}{i}", outline, y0, y1, m["hazard"])
        x += step
        i += 1


def _leaf_face(m, width: float, side: int, windows: list) -> None:
    """Ribs, vision windows, stencil plate and pull bar on one face of the leaf."""
    from build_models import box

    face = side * LEAF_DEPTH / 2
    rib_y = face + side * 0.02
    for k, z in enumerate((0.72, 1.12, 2.28)):
        box(f"Rib{side}{k}", (width - 0.3, 0.04, 0.1), (0, rib_y, z), m["steel"], bevel=0.012)
    for k, x in enumerate((-(width / 2 - 0.16), width / 2 - 0.16)):
        box(f"Post{side}{k}", (0.1, 0.04, 1.96), (x, rib_y, 1.48), m["steel"])
    for k, x in enumerate(windows):
        box(f"WindowFrame{side}{k}", (0.42, 0.03, 0.56), (x, face + side * 0.015, 1.68), m["dark"], bevel=0.01)
        box(f"WindowGlass{side}{k}", (0.3, 0.01, 0.44), (x, face + side * 0.032, 1.68), m["glass"])
    plate_x = windows[0] + 0.5
    box(f"Plate{side}", (0.36, 0.012, 0.16), (plate_x, face + side * 0.006, 1.68), m["steel"])
    pull_x = windows[0] - 0.45
    box(f"Pull{side}", (0.06, 0.05, 0.42), (pull_x, face + side * 0.025, 1.1), m["dark"])
    _chevron_band(m, width, side)


def build_bulkhead(width: float) -> None:
    """Heavy sliding security bulkhead: ribbed hazard-orange leaf, chevron kick band, wired vision
    windows; the wide one is two leaves meeting at a seam. Box width x 0.5 x 2.6."""
    from build_models import box

    m = _door_mats()
    # Leaf, gasket and lip only touch (never overlap): a buried leaf corner would bake black AO
    # across the whole face, since AO is stored per corner.
    box("Leaf", (width - 0.04, LEAF_DEPTH, HEIGHT - 0.12), (0, 0, HEIGHT / 2 - 0.02), m["hazard"], bevel=0.02)
    box("Gasket", (width - 0.04, LEAF_DEPTH + 0.02, 0.04), (0, 0, 0.02), m["dark"])
    box("TopLip", (width - 0.04, LEAF_DEPTH + 0.04, 0.08), (0, 0, HEIGHT - 0.04), m["steel"], bevel=0.01)
    windows = [0.0] if width < 3 else [-width / 4, width / 4]
    if width >= 3:
        box("Seam", (0.04, LEAF_DEPTH + 0.01, HEIGHT - 0.1), (0, 0, HEIGHT / 2), m["dark"])
    for side in (-1, 1):
        _leaf_face(m, width, side, windows)
    p._merge("BulkheadWide" if width >= 3 else "Bulkhead")


MODELS = {
    "bulkhead_door": ("doors/bulkhead_door.glb", partial(build_bulkhead, 2.0)),
    "bulkhead_door_wide": ("doors/bulkhead_door_wide.glb", partial(build_bulkhead, 4.0)),
}
