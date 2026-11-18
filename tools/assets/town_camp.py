"""Lantern Post camp props (plan F-74 step 5, asset list P1-P13): fire barrel, bench, crates, ammo case,
Fenlight crate, lanterns, string lights, split-rail fence, snow drifts, firewood and the snowy pine.

Same rules as town_buildings.py: one merged mesh per model, origin at its bottom centre, front facing
Blender -Y (Godot +Z), shared town slots only, at most 4 per model (the `town` budget). Flames, the fire
light and the FENLIGHT SAMPLES stencil are placed by tools/levels/lantern_post_scene.py.
"""

import math
import random

import bpy
import prop_models as p
import town_buildings as tb
from town_buildings import _box

STRING_SPAN = 9.2  # street lamp to street lamp across the road
STRING_SAG = 0.6
PINE_HEIGHT = 10.0


def _mats() -> dict:
    from build_models import material, srgb

    return {
        "planks": material("Planks", srgb("#5A4434"), roughness=0.85),
        "dark": material("DarkWood", srgb("#2A1E16"), roughness=0.8),
        "logs": material("Logs", srgb("#4A3526"), roughness=0.85),
        "snow": material("Snow", srgb("#D6DEE8"), roughness=0.8),
        "iron": material("Iron", (0.012, 0.012, 0.014, 1.0), metallic=0.7, roughness=0.5),
        "olive": material("Olive", srgb("#4A4F33"), roughness=0.7),
        "bulb": material("Bulb", srgb("#FF9A3C"), roughness=0.3, glow=6.0),
        "fluid": material("Fluid", srgb("#8DFF3A"), roughness=0.2, glow=2.0),
        "pine": material("Pine", srgb("#2B4234"), roughness=0.95),
    }


def _cone(name: str, radius: float, depth: float, bottom: tuple, mat, verts: int = 8, top: float = 0.0):
    x, y, z = bottom
    bpy.ops.mesh.primitive_cone_add(
        vertices=verts, radius1=radius, radius2=top, depth=depth, location=(x, y, z + depth / 2)
    )
    obj = bpy.context.active_object
    obj.name = name
    obj.data.materials.append(mat)
    return obj


def _rod(name: str, radius: float, length: float, at: tuple, turn: tuple, mat, verts: int = 8):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=length, location=at, rotation=turn)
    obj = bpy.context.active_object
    obj.name = name
    obj.data.materials.append(mat)
    return obj


def _ring(name: str, radius: float, thick: float, at: tuple, turn: tuple, mat):
    bpy.ops.mesh.primitive_torus_add(
        major_radius=radius, minor_radius=thick, major_segments=12, minor_segments=4, location=at, rotation=turn
    )
    obj = bpy.context.active_object
    obj.name = name
    obj.data.materials.append(mat)
    return obj


def build_fire_barrel() -> None:
    """P1: rusty oil drum with glowing holes, embers and charred logs poking out of the top. 0.64 x 0.64 x 1.1."""
    m = _mats()
    p._cyl("Drum", 0.3, 0.9, (0, 0, 0), m["iron"], verts=16)
    for k, z in enumerate((0.0, 0.3, 0.6, 0.86)):
        p._cyl(f"Hoop{k}", 0.318, 0.05, (0, 0, z), m["iron"], verts=16)
    for k in range(10):
        a = k * math.tau / 10
        z = 0.48 if k % 2 else 0.72
        at = (0.302 * math.cos(a), 0.302 * math.sin(a), z)
        _box(f"Hole{k}", (0.08, 0.02, 0.1), at, m["bulb"], turn=(0, 0, a + math.pi / 2))
    p._cyl("Embers", 0.27, 0.05, (0, 0, 0.82), m["bulb"], verts=12)
    for k in range(4):
        a = k * math.pi / 2 + 0.4
        at = (0.1 * math.cos(a), 0.1 * math.sin(a), 0.98)
        _rod(f"Log{k}", 0.045, 0.5, at, (0.75 * math.sin(a), -0.75 * math.cos(a), 0), m["dark"], verts=6)


def build_bench() -> None:
    """P2: heavy timber trestle bench with splayed legs and a little snow. 1.8 x 0.45 x 0.5."""
    m = _mats()
    _box("Seat", (1.8, 0.36, 0.07), (0, 0, 0.465), m["planks"], 0.015)
    _box("Rail", (1.5, 0.08, 0.1), (0, 0, 0.38), m["dark"])
    for k, x in enumerate((-0.68, 0.68)):
        for j, side in enumerate((-1, 1)):
            _box(f"Leg{k}{j}", (0.08, 0.08, 0.48), (x, side * 0.1, 0.22), m["dark"], turn=(side * 0.35, 0, 0))
        _box(f"Brace{k}", (0.07, 0.3, 0.06), (x, 0, 0.12), m["dark"])
    _box("SeatSnow", (0.7, 0.3, 0.035), (0.45, 0.01, 0.515), m["snow"], 0.015)


def _crate(m: dict, size: tuple, seed: int) -> None:
    """Plank crate with dark battens round each face, a front brace and a snow cap."""
    w, d, h = size
    _box("Body", (w - 0.04, d - 0.04, h - 0.04), (0, 0, h / 2), m["planks"], 0.01)
    for k, y in enumerate((-d / 2 + 0.01, d / 2 - 0.01)):
        for j, z in enumerate((0.04, h - 0.04)):
            _box(f"Rim{k}{j}", (w, 0.04, 0.08), (0, y, z), m["dark"])
        for j, x in enumerate((-w / 2 + 0.04, w / 2 - 0.04)):
            _box(f"Edge{k}{j}", (0.08, 0.04, h), (x, y, h / 2), m["dark"])
    tilt = math.atan2(h - 0.16, w - 0.16)
    brace = (math.hypot(w - 0.16, h - 0.16), 0.03, 0.07)
    _box("Brace", brace, (0, -d / 2 - 0.005, h / 2), m["dark"], turn=(0, tilt, 0))
    rng = random.Random(seed)
    cap = (w * rng.uniform(0.65, 0.85), d * 0.8, 0.05)
    _box("Snow", cap, ((w - cap[0]) / 2 - 0.04, 0, h + 0.02), m["snow"], 0.02)


def build_crate_large() -> None:
    """P3: big plank supply crate with snow on top. 1.0 x 0.8 x 0.75."""
    _crate(_mats(), (1.0, 0.8, 0.75), 3)


def build_crate_small() -> None:
    """P3: small plank crate with snow on top. 0.6 x 0.5 x 0.45."""
    _crate(_mats(), (0.6, 0.5, 0.45), 5)


def build_ammo_case() -> None:
    """P4: olive metal ammo case with a ribbed lid, end handles, front latches and a snow cap. 0.72 x 0.38 x 0.34."""
    m = _mats()
    _box("Body", (0.68, 0.36, 0.26), (0, 0, 0.13), m["olive"], 0.015)
    _box("Lid", (0.72, 0.38, 0.06), (0, 0, 0.29), m["olive"], 0.015)
    for k, x in enumerate((-0.18, 0.0, 0.18)):
        _box(f"Rib{k}", (0.04, 0.34, 0.02), (x, 0, 0.325), m["olive"])
    for k, side in enumerate((-1, 1)):
        _box(f"Handle{k}", (0.03, 0.14, 0.04), (side * 0.36, 0, 0.2), m["iron"])
        _box(f"Latch{k}", (0.06, 0.02, 0.08), (side * 0.2, -0.19, 0.25), m["iron"])
    _box("Snow", (0.4, 0.3, 0.03), (-0.12, 0, 0.345), m["snow"], 0.012)


def build_fenlight_crate() -> None:
    """P5: open plank crate holding six glowing green sample jars with iron lids. 0.9 x 0.6 x 0.5.

    The FENLIGHT SAMPLES stencil is a Label3D on the front, placed by the scene generator.
    """
    m = _mats()
    w, d, h = 0.9, 0.6, 0.2
    _box("Floor", (w, d, 0.04), (0, 0, 0.02), m["planks"])
    for k, y in enumerate((-d / 2 + 0.02, d / 2 - 0.02)):
        _box(f"Side{k}", (w, 0.04, h), (0, y, h / 2), m["planks"])
    for k, x in enumerate((-w / 2 + 0.02, w / 2 - 0.02)):
        _box(f"End{k}", (0.04, d - 0.08, h), (x, 0, h / 2), m["planks"])
    for k, z in enumerate((0.05, h - 0.04)):
        _box(f"Band{k}", (w + 0.02, d + 0.02, 0.05), (0, 0, z), m["dark"])
    for k in range(6):
        x, y = -0.27 + (k % 3) * 0.27, -0.12 + (k // 3) * 0.24
        p._cyl(f"Jar{k}", 0.085, 0.4, (x, y, 0.04), m["fluid"], verts=12)
        p._cyl(f"Lid{k}", 0.09, 0.05, (x, y, 0.44), m["iron"], verts=12)


def build_lantern_hanging() -> None:
    """P6: hanging oil lantern: iron cage round a glowing chimney, cone cap and a hanging ring. 0.2 x 0.2 x 0.48."""
    m = _mats()
    p._cyl("Base", 0.09, 0.05, (0, 0, 0), m["iron"], verts=10)
    p._cyl("Glass", 0.065, 0.2, (0, 0, 0.05), m["bulb"], verts=10)
    for k in range(4):
        a = k * math.pi / 2 + math.pi / 4
        _box(f"Bar{k}", (0.015, 0.015, 0.22), (0.08 * math.cos(a), 0.08 * math.sin(a), 0.15), m["iron"])
    p._cyl("Collar", 0.095, 0.03, (0, 0, 0.25), m["iron"], verts=10)
    _cone("Cap", 0.1, 0.12, (0, 0, 0.28), m["iron"], verts=10, top=0.025)
    _ring("Ring", 0.04, 0.008, (0, 0, 0.44), (math.pi / 2, 0, 0), m["iron"])


def build_lantern_table() -> None:
    """P7: small hurricane lantern for benches and counters, with a wire handle. 0.16 x 0.16 x 0.3."""
    m = _mats()
    p._cyl("Foot", 0.075, 0.04, (0, 0, 0), m["iron"], verts=10)
    p._blob("Globe", 0.06, (0, 0, 0.12), m["bulb"], squash=(1, 1, 1.4))
    for k in range(3):
        a = k * math.tau / 3
        _box(f"Guard{k}", (0.012, 0.012, 0.16), (0.068 * math.cos(a), 0.068 * math.sin(a), 0.12), m["iron"])
    _cone("Cap", 0.075, 0.06, (0, 0, 0.2), m["iron"], verts=10, top=0.02)
    _ring("Handle", 0.07, 0.006, (0, 0, 0.225), (math.pi / 2, 0, 0), m["iron"])


def _sag(t: float) -> float:
    """Height of the string above its lowest point at t in 0..1 across the span."""
    return STRING_SAG * (2 * t - 1) ** 2


def build_string_lights() -> None:
    """P8: a wire sagging across the street with a warm bulb every half metre. 9.2 x 0.1 x 0.75."""
    m = _mats()
    segments = 16
    for k in range(segments):
        t0, t1 = k / segments, (k + 1) / segments
        x0, x1 = (t0 - 0.5) * STRING_SPAN, (t1 - 0.5) * STRING_SPAN
        z0, z1 = _sag(t0) + 0.15, _sag(t1) + 0.15
        tilt = math.atan2(z1 - z0, x1 - x0)
        length = math.hypot(x1 - x0, z1 - z0)
        mid = ((x0 + x1) / 2, 0, (z0 + z1) / 2)
        _box(f"Wire{k}", (length + 0.01, 0.012, 0.012), mid, m["iron"], turn=(0, -tilt, 0))
    bulbs = int(STRING_SPAN / 0.5) - 1
    for k in range(bulbs):
        t = (k + 1) / (bulbs + 1)
        x, z = (t - 0.5) * STRING_SPAN, _sag(t) + 0.15
        _box(f"Socket{k}", (0.03, 0.03, 0.04), (x, 0, z - 0.03), m["iron"])
        p._blob(f"Bulb{k}", 0.04, (x, 0, z - 0.09), m["bulb"], squash=(1, 1, 1.3))


def build_fence_rail() -> None:
    """P10: split-rail timber fence, 3 m along X: three posts, two rough rails, snow on the top rail. 3 x 0.2 x 1.2."""
    m = _mats()
    for k, x in enumerate((-1.42, 0.0, 1.42)):
        _box(f"Post{k}", (0.15, 0.15, 1.2), (x, 0, 0.6), m["dark"], 0.015, turn=(0, (k - 1) * 0.03, 0))
        _box(f"PostSnow{k}", (0.16, 0.16, 0.05), (x, 0, 1.22), m["snow"], 0.02)
    for k, (z, lean) in enumerate(((0.45, 0.02), (0.92, -0.015))):
        _box(f"Rail{k}", (3.0, 0.09, 0.13), (0, -0.07, z), m["planks"], 0.01, turn=(0.15, lean, 0))
    _box("RailSnow", (2.6, 0.09, 0.04), (0.1, -0.07, 1.005), m["snow"], 0.015)


def _drift(size: tuple, seed: int) -> None:
    """A soft snow bank: a grid heightfield with a few bumps, edges down on the ground."""
    from build_models import material, srgb

    w, d, h = size
    rng = random.Random(seed)
    bumps = [(rng.uniform(-0.25, 0.25) * w, rng.uniform(-0.15, 0.15) * d, rng.uniform(0.7, 1.0)) for _ in range(3)]
    cols, rows = 16, 8
    verts, faces = [], []
    for j in range(rows + 1):
        for i in range(cols + 1):
            x, y = (i / cols - 0.5) * w, (j / rows - 0.5) * d
            edge = 1 - (2 * x / w) ** 2 - (2 * y / d) ** 2
            lift = max(
                b[2] * math.exp(-(((x - b[0]) / (0.35 * w)) ** 2) - ((y - b[1]) / (0.4 * d)) ** 2) for b in bumps
            )
            verts.append((x, y, h * max(edge, 0.0) ** 1.3 * lift))
    for j in range(rows):
        for i in range(cols):
            a = j * (cols + 1) + i
            faces.append((a, a + 1, a + cols + 2, a + cols + 1))
    mesh = bpy.data.meshes.new("Drift")
    mesh.from_pydata(verts, [], faces)
    obj = bpy.data.objects.new("Drift", mesh)
    bpy.context.scene.collection.objects.link(obj)
    mesh.materials.append(material("Snow", srgb("#D6DEE8"), roughness=0.8))
    for poly in mesh.polygons:
        poly.use_smooth = True


def build_snow_drift_a() -> None:
    """P11: long low snow drift for wall and stall bases. 2.4 x 1.0 x 0.45."""
    _drift((2.4, 1.0, 0.45), 11)


def build_snow_drift_b() -> None:
    """P11: short round snow drift. 1.4 x 1.2 x 0.6."""
    _drift((1.4, 1.2, 0.6), 17)


def build_firewood_stack() -> None:
    """P12: log pile with the cut ends to the front, two stakes and a snow cap. 1.8 x 0.9 x 1.0."""
    m = _mats()
    radius, pitch = 0.12, 0.25
    for row in range(4):
        count = 7 - row
        z = radius + row * 0.21
        for k in range(count):
            x = (k - (count - 1) / 2) * pitch
            _rod(f"Log{row}_{k}", radius, 0.85, (x, 0, z), (math.pi / 2, 0, 0), m["logs"], verts=8)
    for k, x in enumerate((-0.92, 0.92)):
        _box(f"Stake{k}", (0.07, 0.07, 0.75), (x, 0, 0.375), m["dark"])
    _box("Snow", (0.95, 0.8, 0.07), (0, 0, 0.95), m["snow"], 0.03)


def build_pine_tree() -> None:
    """P13: snowy pine, five tiers of boughs with snow on their upper halves. 4.4 x 4.4 x 10 (scaled in the scene)."""
    m = _mats()
    p._cyl("Trunk", 0.22, 2.0, (0, 0, 0), m["dark"], verts=6)
    tiers = 5
    for k in range(tiers):
        radius = 2.2 - k * 0.38
        depth = 3.4 - k * 0.3
        bottom = 1.1 + k * 1.75
        if k == tiers - 1:
            depth = PINE_HEIGHT - bottom
        tier = _cone(f"Tier{k}", radius, depth, (0, 0, bottom), m["pine"], verts=9)
        tier.rotation_euler = (0, 0, k * 0.6)
        part = 0.6
        snow = _cone(f"Snow{k}", radius * part, depth * part, (0, 0, bottom + depth * (1 - part) + 0.06), m["snow"], 9)
        snow.rotation_euler = (0, 0, k * 0.6)


MODELS = {
    "fire_barrel": ("town/fire_barrel.glb", tb._merged(build_fire_barrel, "FireBarrel")),
    "bench": ("town/bench.glb", tb._merged(build_bench, "Bench")),
    "supply_crate_large": ("town/supply_crate_large.glb", tb._merged(build_crate_large, "CrateLarge")),
    "supply_crate_small": ("town/supply_crate_small.glb", tb._merged(build_crate_small, "CrateSmall")),
    "ammo_case": ("town/ammo_case.glb", tb._merged(build_ammo_case, "AmmoCase")),
    "fenlight_crate": ("town/fenlight_crate.glb", tb._merged(build_fenlight_crate, "FenlightCrate")),
    "lantern_hanging": ("town/lantern_hanging.glb", tb._merged(build_lantern_hanging, "LanternHanging")),
    "lantern_table": ("town/lantern_table.glb", tb._merged(build_lantern_table, "LanternTable")),
    "string_lights": ("town/string_lights.glb", tb._merged(build_string_lights, "StringLights")),
    "fence_rail": ("town/fence_rail.glb", tb._merged(build_fence_rail, "FenceRail")),
    "snow_drift_a": ("town/snow_drift_a.glb", tb._merged(build_snow_drift_a, "SnowDriftA")),
    "snow_drift_b": ("town/snow_drift_b.glb", tb._merged(build_snow_drift_b, "SnowDriftB")),
    "firewood_stack": ("town/firewood_stack.glb", tb._merged(build_firewood_stack, "FirewoodStack")),
    "pine_tree": ("town/pine_tree.glb", tb._merged(build_pine_tree, "PineTree")),
}
