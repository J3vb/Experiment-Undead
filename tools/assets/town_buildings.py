"""Lantern Post buildings (plan F-74, asset list B1-B6): round-log lodges with snowy roofs.

Same rules as prop_models.py: one merged mesh per model, origin at its bottom centre, front facing
Blender -Y (Godot +Z). Materials use the shared town slots (docs/design/lantern-post-assets.md) that
prop_import.gd swaps for levels/materials/town_*.tres. Sign text, lanterns and lights are placed by
tools/levels/lantern_post_scene.py, so the names stay editable and the model stays one mesh.
"""

import math
import random

import bmesh
import bpy
import prop_models as p
from gun_parts import slab

COURSE = 0.32  # log course height; logs overlap a little so walls have no gaps
LOG_R = 0.17
LOG_END = 0.35  # how far crossed log ends stick out past a corner


def _mats() -> dict:
    from build_models import material, srgb

    return {
        "logs": material("Logs", srgb("#4A3526"), roughness=0.85),
        "planks": material("Planks", srgb("#5A4434"), roughness=0.85),
        "dark": material("DarkWood", srgb("#2A1E16"), roughness=0.8),
        "roof": material("RoofSnow", srgb("#3A3F45"), roughness=0.6),
        "snow": material("Snow", srgb("#D6DEE8"), roughness=0.8),
        "glow": material("WindowGlow", srgb("#FFB066"), roughness=0.2, glow=2.5),
        "iron": material("Iron", (0.012, 0.012, 0.014, 1.0), metallic=0.7, roughness=0.5),
    }


def _box(name: str, size: tuple, at: tuple, mat, bevel: float = 0.0, turn: tuple = (0, 0, 0)):
    from build_models import box

    obj = box(name, size, at, mat, bevel=bevel)
    obj.rotation_euler = turn
    return obj


def _log(name: str, length: float, at: tuple, along_x: bool, mat) -> None:
    turn = (0, math.pi / 2, 0) if along_x else (math.pi / 2, 0, 0)
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=LOG_R, depth=length, location=at, rotation=turn)
    bpy.context.active_object.name = name
    bpy.context.active_object.data.materials.append(mat)


def log_walls(name: str, half_x: float, y_front: float, y_back: float, tops: tuple, mat) -> None:
    """Four round-log walls with crossed ends at the corners. tops = (front/back wall top, side wall top).

    Front and back logs sit on full courses, side logs half a course higher, like notched cabin corners.
    """
    long_x = 2 * (half_x + LOG_END)
    long_y = y_back - y_front + 2 * LOG_END
    mid_y = (y_front + y_back) / 2
    for k in range(int((tops[0] - COURSE / 2) / COURSE) + 1):
        z = COURSE / 2 + k * COURSE
        for wall, y in (("Front", y_front), ("Back", y_back)):
            _log(f"{name}{wall}{k}", long_x, (0, y, z), True, mat)
    for k in range(int((tops[1] - COURSE) / COURSE) + 1):
        z = COURSE + k * COURSE
        for wall, x in (("Left", -half_x), ("Right", half_x)):
            _log(f"{name}{wall}{k}", long_y, (x, mid_y, z), False, mat)


def _prism_y(name: str, outline: list, y: float, depth: float, mat):
    """Extrudes a front outline [(x, z), ...] from `y` to `y + depth` (a gable end)."""
    bm = bmesh.new()
    face = bm.faces.new([bm.verts.new((x, y, z)) for x, z in outline])
    geom = bmesh.ops.extrude_face_region(bm, geom=[face])["geom"]
    bmesh.ops.translate(bm, vec=(0, depth, 0), verts=[v for v in geom if isinstance(v, bmesh.types.BMVert)])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.data.materials.append(mat)
    return obj


def window(name: str, at: tuple, size: tuple, m: dict, lit: bool = True, facing: str = "front") -> None:
    """Framed window on a log wall: glowing panes and a cross mullion, or boarded up when not lit.

    `at` is the centre of the pane on the outer wall face; `facing` is front, back, left or right.
    """
    w, h = size
    out = {"front": (0, -1), "back": (0, 1), "left": (-1, 0), "right": (1, 0)}[facing]
    along_x = out[0] == 0

    def part(suffix: str, offset: tuple, dims: tuple, mat, depth_out: float) -> None:
        a, z = offset
        x = at[0] + (a if along_x else out[0] * depth_out)
        y = at[1] + (out[1] * depth_out if along_x else a)
        sx, sz = dims
        _box(f"{name}{suffix}", (sx, 0.1, sz) if along_x else (0.1, sx, sz), (x, y, at[2] + z), mat)

    part("Pane", (0, 0), (w, h), m["glow"] if lit else m["dark"], 0.0)
    for side in (-1, 1):
        part(f"Jamb{side + 1}", (side * (w / 2 + 0.06), 0), (0.14, h + 0.26), m["dark"], 0.06)
    part("Sill", (0, -h / 2 - 0.1), (w + 0.4, 0.12), m["dark"], 0.1)
    part("Head", (0, h / 2 + 0.1), (w + 0.3, 0.16), m["dark"], 0.07)
    if lit:
        part("MullionV", (0, 0), (0.06, h), m["dark"], 0.05)
        part("MullionH", (0, h * 0.12), (w, 0.06), m["dark"], 0.05)
        return
    for b in range(3):
        part(f"Board{b}", (0, (b - 1) * h * 0.32), (w + 0.1, 0.18), m["planks"], 0.08)


def icicles(name: str, start: tuple, end: tuple, count: int, mat, seed: int) -> None:
    """Thin hanging cones spread along an eave line from `start` to `end`."""
    rng = random.Random(seed)
    for i in range(count):
        t = (i + 0.5 + rng.uniform(-0.3, 0.3)) / count
        length = rng.uniform(0.18, 0.55)
        x, y, z = (start[k] + (end[k] - start[k]) * t for k in range(3))
        bpy.ops.mesh.primitive_cone_add(vertices=5, radius1=0.05, radius2=0.0, depth=length)
        cone = bpy.context.active_object
        cone.name = f"{name}{i}"
        cone.location = (x, y, z - length / 2)
        cone.rotation_euler = (math.pi, 0, 0)
        cone.data.materials.append(mat)


def roof_side(name: str, ridge: tuple, eave: tuple, span: tuple, m: dict, thick: float = 0.22) -> None:
    """One roof slope from `ridge` (a, z) down to `eave` (a, z), with a snow layer hanging over the eave.

    span = (axis, from, to): axis "y" means the ridge runs along Y and `a` is x; axis "x" means `a` is y.
    """
    axis, s0, s1 = span
    da, dz = eave[0] - ridge[0], eave[1] - ridge[1]
    run = math.hypot(da, dz)
    sign = 1 if da > 0 else -1
    normal = (-dz * sign / run, abs(da) / run)
    for layer, mat, depth, lift, grow in (("", m["roof"], thick, 0.0, 0.0), ("Snow", m["snow"], 0.2, thick, 0.14)):
        a = (ridge[0] + eave[0]) / 2 + normal[0] * (lift + depth / 2) + da / run * grow / 2
        z = (ridge[1] + eave[1]) / 2 + normal[1] * (lift + depth / 2) + dz / run * grow / 2
        mid, bevel = (s0 + s1) / 2, 0.06 if layer else 0.0
        if axis == "y":
            _box(f"{name}{layer}", (run + grow, s1 - s0, depth), (a, mid, z), mat, bevel, (0, math.atan2(-dz, da), 0))
        else:
            _box(f"{name}{layer}", (s1 - s0, run + grow, depth), (mid, a, z), mat, bevel, (math.atan2(dz, da), 0, 0))


def drifts(name: str, half_x: float, y_front: float, y_back: float, mat) -> None:
    """Low soft snow banks along the foot of each wall, so the building sits in the snow."""
    for k, (size, at) in enumerate(
        (
            ((2 * half_x + 0.6, 0.7, 0.32), (0, y_back + 0.3, 0.16)),
            ((0.7, y_back - y_front, 0.32), (-half_x - 0.3, (y_front + y_back) / 2, 0.16)),
            ((0.7, y_back - y_front, 0.32), (half_x + 0.3, (y_front + y_back) / 2, 0.16)),
        )
    ):
        _box(f"{name}{k}", size, at, mat, bevel=0.12)


def build_lodge_lantern_post() -> None:
    """B1: two-storey log lodge, gable to the street with the LANTERN POST sign, roofed front porch. 12 x 9 x 11."""
    m = _mats()
    half, y_front, y_back, eave = 6.0, -2.3, 4.0, 6.45
    log_walls("Log", half, y_front, y_back, (6.2, 6.6), m["logs"])
    pitch = math.radians(35)
    ridge_z = eave + (half + 0.2) * math.tan(pitch)
    gable = [(-half - 0.2, 6.0), (half + 0.2, 6.0), (0, ridge_z - 0.15)]
    for name, y in (("GableFront", y_front - LOG_R - 0.02), ("GableBack", y_back - 0.15)):
        _prism_y(name, gable, y, 0.32, m["planks"])
    for k, side in enumerate((-1, 1)):
        eave_a = side * (half + 0.75)
        eave_z = ridge_z - (half + 0.75) * math.tan(pitch)
        roof_side(f"Roof{k}", (0, ridge_z), (eave_a, eave_z), ("y", y_front - 0.65, y_back + 0.5), m)
        icicles(
            f"RoofIce{k}",
            (eave_a, y_front - 0.5, eave_z - 0.05),
            (eave_a, y_back + 0.4, eave_z - 0.05),
            14,
            m["snow"],
            k,
        )
    _box("Ridge", (0.3, y_back - y_front + 1.3, 0.3), (0, (y_front + y_back) / 2 - 0.08, ridge_z + 0.3), m["snow"], 0.1)
    _porch(m, half, y_front)
    _lodge_windows(m, half, y_front, y_back)
    drifts("Drift", half, y_front, y_back, m["snow"])


def _porch(m: dict, half: float, y_front: float) -> None:
    """Plank deck, four posts, rails and a snowy lean-to roof across the front."""
    edge = -4.4
    _box("PorchDeck", (2 * half + 0.4, y_front - edge, 0.3), (0, (y_front + edge) / 2, 0.15), m["planks"], 0.03)
    _box("Step", (2.0, 0.4, 0.15), (0, edge - 0.2, 0.075), m["planks"], 0.02)
    for k, x in enumerate((-half + 0.2, -1.4, 1.4, half - 0.2)):
        _box(f"PorchPost{k}", (0.24, 0.24, 2.9), (x, edge + 0.15, 1.75), m["dark"], 0.02)
    _box("PorchBeam", (2 * half + 0.3, 0.26, 0.3), (0, edge + 0.15, 3.2), m["dark"], 0.02)
    for k, side in enumerate((-1, 1)):
        mid = side * (half / 2 + 0.6)
        _box(f"Rail{k}", (half - 1.6, 0.1, 0.12), (mid, edge + 0.15, 1.25), m["dark"])
        _box(f"RailLow{k}", (half - 1.6, 0.08, 0.08), (mid, edge + 0.15, 0.6), m["dark"])
        _box(f"RailSnow{k}", (half - 1.7, 0.16, 0.08), (mid, edge + 0.15, 1.35), m["snow"], 0.03)
    wall_face = y_front - LOG_R
    roof_side("PorchRoof", (wall_face, 4.05), (edge - 0.1, 3.4), ("x", -half - 0.3, half + 0.3), m, thick=0.16)
    icicles("PorchIce", (-half, edge - 0.15, 3.3), (half, edge - 0.15, 3.3), 18, m["snow"], 7)
    _box("Door", (1.3, 0.08, 2.3), (0, wall_face - 0.04, 1.45), m["planks"], 0.02)
    _box("DoorFrame", (1.6, 0.06, 2.5), (0, wall_face + 0.01, 1.5), m["dark"])


def _lodge_windows(m: dict, half: float, y_front: float, y_back: float) -> None:
    front, back = y_front - LOG_R - 0.02, y_back + LOG_R + 0.02
    for k, x in enumerate((-3.6, 3.6)):
        window(f"FrontLow{k}", (x, front, 1.75), (1.2, 1.3), m)
        window(f"FrontHigh{k}", (x * 0.85, front, 4.75), (1.1, 1.2), m)
        window(f"BackLow{k}", (x, back, 1.75), (1.1, 1.2), m, lit=k == 0, facing="back")
        window(f"BackHigh{k}", (x, back, 4.75), (1.0, 1.1), m, lit=False, facing="back")
    for k, (side, facing) in enumerate(((-1, "left"), (1, "right"))):
        x = side * (half + LOG_R + 0.02)
        for j, y in enumerate((-0.6, 2.4)):
            window(f"Side{k}Low{j}", (x, y, 1.75), (1.1, 1.2), m, lit=(j + k) % 3 != 2, facing=facing)
            window(f"Side{k}High{j}", (x, y, 4.75), (1.0, 1.1), m, lit=j == k, facing=facing)


def build_lodge_common_room() -> None:
    """B2: log lodge with a long first-floor balcony under the front roof, string lights, dish and stove pipe.

    14 x 9 x 10. The ridge runs along the street; the front roof slope reaches out over the balcony.
    """
    m = _mats()
    m["planks"] = m["logs"]  # six materials: boarded windows use log wood here
    half, y_front, y_back = 7.0, -1.6, 4.0
    ridge_y, ridge_z = 1.2, 8.4
    front_slope, back_slope = math.tan(math.radians(20)), math.tan(math.radians(35))
    log_walls("Log", half, y_front, y_back, (7.15, 6.3), m["logs"])
    under = [
        (y_front - LOG_R, 6.2),
        (y_back + LOG_R, 6.2),
        (ridge_y, ridge_z - 0.1),
        (y_front - LOG_R, ridge_z - 0.1 - (ridge_y - y_front + LOG_R) * front_slope),
    ]
    for k, x in enumerate((-half, half)):
        slab(f"Gable{k}", under, 0.34, m["dark"], x=x)
    eave_front, eave_back = -4.5, 4.6
    roof_front = (eave_front, ridge_z - (ridge_y - eave_front) * front_slope)
    roof_side("RoofFront", (ridge_y, ridge_z), roof_front, ("x", -half - 0.6, half + 0.6), m)
    roof_back = (eave_back, ridge_z - (eave_back - ridge_y) * back_slope)
    roof_side("RoofBack", (ridge_y, ridge_z), roof_back, ("x", -half - 0.6, half + 0.6), m)
    _box("Ridge", (2 * half + 1.3, 0.3, 0.3), (0, ridge_y, ridge_z + 0.3), m["snow"], 0.1)
    icicles(
        "FrontIce",
        (-half, eave_front, roof_front[1] - 0.12),
        (half, eave_front, roof_front[1] - 0.12),
        22,
        m["snow"],
        3,
    )
    icicles("BackIce", (-half, eave_back, roof_back[1] - 0.1), (half, eave_back, roof_back[1] - 0.1), 16, m["snow"], 4)
    _balcony(m, half, y_front, roof_front)
    _common_room_windows(m, half, y_front, y_back)
    _dish_and_pipe(m, ridge_y, ridge_z, front_slope, back_slope)
    drifts("Drift", half, y_front, y_back, m["snow"])


def _balcony(m: dict, half: float, y_front: float, roof_front: tuple) -> None:
    """First-floor balcony on posts, rail with balusters, sign board and string lights under the eave."""
    edge, floor_z = -3.95, 3.3
    deck_y = (y_front - LOG_R + edge) / 2
    _box("BalconyDeck", (2 * half + 0.3, y_front - LOG_R - edge, 0.26), (0, deck_y, floor_z), m["dark"], 0.03)
    post_y = edge + 0.12
    beam_z = roof_front[1] + (post_y - roof_front[0]) * math.tan(math.radians(20)) - 0.2
    posts = (-half, -half / 2, 0.0, half / 2, half)
    for k, x in enumerate(posts):
        _box(f"Post{k}", (0.26, 0.26, beam_z), (x, post_y, beam_z / 2), m["dark"], 0.02)
    _box("Beam", (2 * half + 0.4, 0.28, 0.32), (0, post_y, beam_z), m["dark"], 0.02)
    rail_z = floor_z + 1.05
    _box("RailTop", (2 * half, 0.12, 0.12), (0, post_y, rail_z), m["dark"])
    _box("RailSnow", (2 * half - 0.2, 0.18, 0.08), (0, post_y, rail_z + 0.09), m["snow"], 0.03)
    _box("RailLow", (2 * half, 0.08, 0.1), (0, post_y, floor_z + 0.25), m["dark"])
    for k in range(int(2 * half / 0.42)):
        x = -half + 0.21 + k * 0.42
        if min(abs(x - px) for px in posts) > 0.2:
            _box(f"Baluster{k}", (0.06, 0.06, 0.8), (x, post_y, floor_z + 0.62), m["dark"])
    for k, x in enumerate((-half, half)):
        _box(f"SideRail{k}", (0.12, y_front - edge - 0.3, 0.12), (x, deck_y, rail_z), m["dark"])
    _box("SignBoard", (4.2, 0.1, 0.75), (0, post_y - 0.12, beam_z - 0.62), m["dark"], 0.02)
    for k, side in enumerate((-1, 1)):
        _box(f"SignChain{k}", (0.04, 0.04, 0.3), (side * 1.8, post_y - 0.12, beam_z - 0.15), m["iron"])
    _string_lights(m, posts, post_y - 0.18, beam_z - 0.18)


def _string_lights(m: dict, posts: tuple, y: float, z: float) -> None:
    """A wire sagging between the balcony posts with a warm bulb every half metre."""
    for span in range(len(posts) - 1):
        x0, x1 = posts[span], posts[span + 1]
        bulbs = int((x1 - x0) / 0.5)
        for k in range(bulbs + 1):
            t = k / bulbs
            x = x0 + (x1 - x0) * t
            sag = math.sin(math.pi * t) * 0.35
            _box(f"Bulb{span}_{k}", (0.09, 0.09, 0.11), (x, y, z - sag - 0.07), m["glow"])
            if k < bulbs:
                t2 = (k + 1) / bulbs
                sag2 = math.sin(math.pi * t2) * 0.35
                length = math.hypot((x1 - x0) / bulbs, sag2 - sag)
                wire = _box(
                    f"Wire{span}_{k}",
                    (length, 0.02, 0.02),
                    (x + (x1 - x0) / bulbs / 2, y, z - (sag + sag2) / 2),
                    m["iron"],
                )
                wire.rotation_euler = (0, math.atan2(sag2 - sag, (x1 - x0) / bulbs), 0)


def _common_room_windows(m: dict, half: float, y_front: float, y_back: float) -> None:
    front, back = y_front - LOG_R - 0.02, y_back + LOG_R + 0.02
    for k, x in enumerate((-4.6, 0.0, 4.6)):
        window(f"Big{k}", (x, front, 4.95), (2.4, 1.7), m)
    for k, x in enumerate((-5.4, -2.7, 2.7, 5.4)):
        window(f"Low{k}", (x, front, 1.65), (1.4, 1.35), m)
        window(f"Back{k}", (x, back, 1.7 if k % 2 else 4.6), (1.1, 1.2), m, lit=k == 1, facing="back")
    _box("Door", (1.3, 0.08, 2.3), (0, front + 0.02, 1.15), m["dark"], 0.02)
    _box("DoorFrame", (1.6, 0.06, 2.5), (0, front + 0.06, 1.25), m["logs"])
    for k, (side, facing) in enumerate(((-1, "left"), (1, "right"))):
        x = side * (half + LOG_R + 0.02)
        for j, y in enumerate((0.0, 2.6)):
            window(f"Side{k}Low{j}", (x, y, 1.7), (1.1, 1.2), m, lit=(j + k) % 2 == 0, facing=facing)
            window(f"Side{k}High{j}", (x, y, 4.6), (1.0, 1.1), m, lit=j == 1, facing=facing)


def _dish_and_pipe(m: dict, ridge_y: float, ridge_z: float, front_slope: float, back_slope: float) -> None:
    """Satellite dish on the front slope and an iron stove pipe on the back slope."""
    dish_y = -0.4
    roof_z = ridge_z - (ridge_y - dish_y) * front_slope + 0.2
    p._cyl("DishPole", 0.05, 1.0, (-4.6, dish_y, roof_z - 0.1), m["iron"], verts=8)
    bpy.ops.mesh.primitive_cone_add(vertices=16, radius1=0.7, radius2=0.12, depth=0.28)
    dish = bpy.context.active_object
    dish.name = "Dish"
    dish.location = (-4.6, dish_y - 0.2, roof_z + 1.05)
    dish.rotation_euler = (math.radians(-60), 0, math.radians(-20))
    dish.data.materials.append(m["iron"])
    _box("DishArm", (0.04, 0.04, 0.7), (-4.6, dish_y - 0.45, roof_z + 1.25), m["iron"], turn=(math.radians(-60), 0, 0))
    pipe_y = 2.3
    pipe_z = ridge_z - (pipe_y - ridge_y) * back_slope - 0.1
    p._cyl("Pipe", 0.16, 2.1, (4.4, pipe_y, pipe_z), m["iron"], verts=12)
    bpy.ops.mesh.primitive_cone_add(
        vertices=12, radius1=0.32, radius2=0.05, depth=0.25, location=(4.4, pipe_y, pipe_z + 2.3)
    )
    cap = bpy.context.active_object
    cap.name = "PipeCap"
    cap.data.materials.append(m["iron"])


def _merged(build, name: str):
    def run() -> None:
        build()
        p._merge(name)

    return run


MODELS = {
    "lodge_lantern_post": ("town_large/lodge_lantern_post.glb", _merged(build_lodge_lantern_post, "LodgeLanternPost")),
    "lodge_common_room": ("town_large/lodge_common_room.glb", _merged(build_lodge_common_room, "LodgeCommonRoom")),
}
