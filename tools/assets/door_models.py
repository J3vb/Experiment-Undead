"""Halcyon Labs door models (plan F-63): sliding security bulkheads, a debris pile, a roll-up shutter,
vent grates and the cold-room door. Buyable ones carry hazard-orange paint.

Same rules as prop_models.py: one merged mesh per model, origin at its bottom centre, front facing
Blender -Y (Godot +Z), and it fits inside its door's Blocker box (width x 0.5 x 2.6). Slots map to the
shared Halcyon materials through prop_import.gd (`Hazard` is the buyable-door orange).
"""

import math
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
        "paint": m["paint"],
        "concrete": material("Concrete", srgb("#7F7F7A"), roughness=0.95),
        "rust": material("Olive", srgb("#4A5446"), roughness=0.7),
        "wood": material("Wood", (0.16, 0.11, 0.065, 1.0), roughness=0.85),
        "laminate": material("Laminate", srgb("#C9CEC8"), roughness=0.5),
    }


def _turned(obj, degrees: float):
    """Turns a part in the door plane (about Blender Y), so it never grows past the door's depth."""
    obj.rotation_euler = (0, math.radians(degrees), 0)
    return obj


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


SLABS = [  # (width, thickness, height, x, z, turn): broken ceiling panels leaning in the gap
    (1.6, 0.3, 0.9, -1.1, 0.45, 4),
    (1.8, 0.28, 0.8, 0.9, 0.42, -3),
    (2.2, 0.24, 0.5, -0.4, 1.05, 12),
    (1.5, 0.26, 0.55, 1.15, 1.2, -16),
    (1.4, 0.22, 0.45, -1.3, 1.65, -8),
    (1.2, 0.2, 0.4, 0.5, 1.95, 22),
    (1.0, 0.2, 0.35, -0.6, 2.3, -5),
]


def build_debris_pile() -> None:
    """Collapsed ceiling blocking a 4 m gap: concrete slabs, a fallen beam, a crushed cabinet and planks
    with a hazard-orange board nailed across. Box 4.0 x 0.5 x 2.6."""
    from build_models import box

    m = _door_mats()
    box("Fill", (3.9, 0.12, 2.4), (0.0, 0.0, 1.2), m["concrete"])
    for i, (w, t, h, x, z, turn) in enumerate(SLABS):
        _turned(box(f"Slab{i}", (w, t, h), (x, 0.0, z), m["concrete"], bevel=0.03), turn)
    _turned(box("Beam", (4.2, 0.18, 0.22), (0.0, 0.08, 1.45), m["rust"], bevel=0.01), -18)
    _turned(box("BeamFlange", (4.0, 0.3, 0.04), (0.0, 0.08, 1.45), m["rust"]), -18)
    box("Cabinet", (0.7, 0.42, 0.95), (1.55, -0.02, 2.05), m["rust"], bevel=0.02)
    for i, (x, z, turn) in enumerate(((-1.5, 0.95, 70), (0.2, 0.8, -60), (1.6, 1.0, 75))):
        _turned(box(f"Plank{i}", (1.6, 0.05, 0.16), (x, -0.2, z), m["wood"], bevel=0.008), turn)
    for side in (-1, 1):
        y = side * 0.22
        _turned(box(f"HazardBoard{side}", (3.4, 0.04, 0.26), (0.0, y, 1.3), m["hazard"], bevel=0.01), 4 * side)
        for i, x in enumerate((-1.4, 1.4)):
            box(f"BoardBolt{side}{i}", (0.05, 0.03, 0.05), (x, y + side * 0.03, 1.3 - side * x * 0.07), m["rust"])
    p._merge("DebrisPile")


def build_roll_shutter() -> None:
    """Corrugated roll-up shutter: steel slats in side rails under a roller housing, hazard-orange bottom
    bar. Box 3.0 x 0.5 x 2.6."""
    from build_models import box

    m = _door_mats()
    width, top = 3.0, 2.2
    box("Housing", (width, 0.44, 0.4), (0, 0.02, top + 0.2), m["paint"], bevel=0.02)
    box("HousingCap", (width - 0.02, 0.46, 0.04), (0, 0.02, top + 0.02), m["dark"])
    for i, x in enumerate((-(width / 2 - 0.05), width / 2 - 0.05)):
        box(f"Rail{i}", (0.1, 0.16, top), (x, 0, top / 2), m["dark"], bevel=0.01)
    slat = 0.13
    for i in range(int((top - 0.2) / slat)):
        z = 0.2 + slat * (i + 0.5)
        box(f"Slat{i}", (width - 0.16, 0.06, slat - 0.012), (0, 0.01 * (i % 2), z), m["steel"])
    box("BottomBar", (width - 0.16, 0.1, 0.18), (0, 0, 0.11), m["hazard"], bevel=0.01)
    box("Seal", (width - 0.16, 0.12, 0.02), (0, 0, 0.01), m["dark"])
    for i, x in enumerate((-0.6, 0.6)):
        box(f"Lift{i}", (0.16, 0.05, 0.05), (x, -0.07, 0.14), m["dark"])
    p._merge("RollShutter")


def build_vent_grate(width: float) -> None:
    """Rusty louvred vent grate in a bolted frame (opens with its area, nobody buys it).
    Box width x 0.3 x 2.6."""
    from build_models import box

    m = _door_mats()
    for i, x in enumerate((-(width / 2 - 0.06), width / 2 - 0.06)):
        box(f"Side{i}", (0.12, 0.26, HEIGHT), (x, 0, HEIGHT / 2), m["rust"], bevel=0.01)
    for i, z in enumerate((0.06, HEIGHT - 0.06)):
        box(f"Edge{i}", (width - 0.24, 0.26, 0.12), (0, 0, z), m["rust"], bevel=0.01)
    louvre = 0.16
    for i in range(int((HEIGHT - 0.24) / louvre)):
        z = 0.12 + louvre * (i + 0.5)
        blade = box(f"Louvre{i}", (width - 0.24, 0.2, 0.02), (0, 0, z), m["dark"])
        blade.rotation_euler = (math.radians(-35), 0, 0)
    for k, z in enumerate((0.06, HEIGHT - 0.06)):
        for j, x in enumerate((-(width / 2 - 0.06), width / 2 - 0.06)):
            box(f"Bolt{k}{j}", (0.05, 0.28, 0.05), (x, 0, z), m["steel"])
    p._merge("VentGrateWide" if width >= 3 else "VentGrate")


def build_freezer_door() -> None:
    """Insulated sliding cold-room door: thick pale leaf, steel kick plate, long pull handle, rubber seal
    and a frosted view port. Box 2.0 x 0.5 x 2.6."""
    from build_models import box

    m = _door_mats()
    box("Leaf", (1.94, 0.32, HEIGHT - 0.06), (0, 0, HEIGHT / 2 + 0.01), m["laminate"], bevel=0.04)
    box("Seal", (1.96, 0.34, 0.04), (0, 0, 0.02), m["dark"])
    for side in (-1, 1):
        face = side * 0.16
        box(f"Kick{side}", (1.8, 0.012, 0.45), (0, face + side * 0.006, 0.3), m["steel"])
        box(f"Port{side}", (0.36, 0.02, 0.36), (0.45, face + side * 0.01, 1.7), m["dark"])
        box(f"PortGlass{side}", (0.28, 0.01, 0.28), (0.45, face + side * 0.022, 1.7), m["glass"])
        box(f"Handle{side}", (0.05, 0.06, 0.9), (-0.7, face + side * 0.08, 1.15), m["steel"], bevel=0.01)
        for j, z in enumerate((0.75, 1.55)):
            box(f"HandleFoot{side}{j}", (0.05, 0.06, 0.05), (-0.7, face + side * 0.03, z), m["steel"])
    p._merge("FreezerDoor")


MODELS = {
    "bulkhead_door": ("doors/bulkhead_door.glb", partial(build_bulkhead, 2.0)),
    "bulkhead_door_wide": ("doors/bulkhead_door_wide.glb", partial(build_bulkhead, 4.0)),
    "debris_pile": ("doors/debris_pile.glb", build_debris_pile),
    "roll_shutter": ("doors/roll_shutter.glb", build_roll_shutter),
    "vent_grate": ("doors/vent_grate.glb", partial(build_vent_grate, 1.6)),
    "vent_grate_wide": ("doors/vent_grate_wide.glb", partial(build_vent_grate, 3.0)),
    "freezer_door": ("doors/freezer_door.glb", build_freezer_door),
}
