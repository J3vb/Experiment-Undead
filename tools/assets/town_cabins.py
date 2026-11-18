"""Lantern Post cabins, shed and watchtower (plan F-74 step 3, asset list B3-B6).

Built like the hero lodges in town_buildings.py and with its helpers: round-log walls, framed windows,
snowy roof slopes, icicles and drifts. One merged mesh per model, origin at its bottom centre, front facing
Blender -Y (Godot +Z), shared town material slots only.
"""

import math

import bpy
import prop_models as p
import town_buildings as tb
from gun_parts import slab
from town_buildings import LOG_R, _box, _mats, drifts, icicles, log_walls, roof_side, window


def _cone(name: str, radius: float, depth: float, at: tuple, mat, verts: int = 4, top: float = 0.0) -> None:
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=radius, radius2=top, depth=depth, location=at)
    obj = bpy.context.active_object
    obj.name = name
    obj.rotation_euler = (0, 0, math.pi / verts)
    obj.data.materials.append(mat)


def _stove_pipe(m: dict, at: tuple, height: float) -> None:
    p._cyl("Pipe", 0.13, height, at, m["dark"], verts=10)
    _cone("PipeCap", 0.26, 0.2, (at[0], at[1], at[2] + height + 0.12), m["dark"], verts=10, top=0.04)


def build_cabin_small() -> None:
    """B3: one-storey log cabin, ridge along the street, the front slope runs on over a porch. 7 x 6 x 6.

    Door left of centre and windows set unevenly, so the generator can mirror it for the second copy.
    """
    m = _mats()
    half, y_front, y_back = 3.0, -1.2, 2.6
    log_walls("Log", half, y_front, y_back, (2.9, 2.9), m["logs"])
    ridge_y, ridge_z = 0.7, 4.9
    front_slope, back_slope = math.tan(math.radians(22)), math.tan(math.radians(35))
    face_front, face_back = y_front - LOG_R, y_back + LOG_R
    gable = [
        (face_front, 2.8),
        (face_back, 2.8),
        (face_back, ridge_z - (face_back - ridge_y) * back_slope - 0.1),
        (ridge_y, ridge_z - 0.1),
        (face_front, ridge_z - (ridge_y - face_front) * front_slope - 0.1),
    ]
    for k, x in enumerate((-half, half)):
        slab(f"Gable{k}", gable, 0.34, m["planks"], x=x)
    eave_front = (-3.0, ridge_z - (ridge_y + 3.0) * front_slope)
    eave_back = (3.2, ridge_z - (3.2 - ridge_y) * back_slope)
    roof_side("RoofFront", (ridge_y, ridge_z), eave_front, ("x", -half - 0.6, half + 0.6), m)
    roof_side("RoofBack", (ridge_y, ridge_z), eave_back, ("x", -half - 0.6, half + 0.6), m)
    _box("Ridge", (2 * half + 1.3, 0.3, 0.3), (0, ridge_y, ridge_z + 0.3), m["snow"], 0.1)
    icicles(
        "FrontIce",
        (-half, eave_front[0], eave_front[1] - 0.12),
        (half, eave_front[0], eave_front[1] - 0.12),
        12,
        m["snow"],
        11,
    )
    icicles(
        "BackIce", (-half, eave_back[0], eave_back[1] - 0.1), (half, eave_back[0], eave_back[1] - 0.1), 9, m["snow"], 12
    )
    _cabin_porch(m, half, face_front, eave_front, front_slope)
    window("FrontBig", (1.6, face_front - 0.02, 1.6), (1.3, 1.2), m)
    window("FrontSmall", (-2.25, face_front - 0.02, 1.7), (0.7, 0.9), m)
    window("Back", (0.8, face_back + 0.02, 1.7), (1.0, 1.0), m, lit=False, facing="back")
    window("Left", (-half - LOG_R - 0.02, 0.7, 1.7), (1.0, 1.1), m, facing="left")
    window("Right", (half + LOG_R + 0.02, 0.7, 1.7), (1.0, 1.1), m, lit=False, facing="right")
    _stove_pipe(m, (1.9, 1.9, ridge_z - (1.9 - ridge_y) * back_slope - 0.1), 1.3)
    drifts("Drift", half, y_front, y_back, m["snow"])


def _cabin_porch(m: dict, half: float, face_front: float, eave_front: tuple, slope: float) -> None:
    """Plank deck, two steps, posts under the front roof slope and a door left of centre."""
    edge = -2.75
    _box("PorchDeck", (2 * half + 0.3, face_front - edge, 0.3), (0, (face_front + edge) / 2, 0.15), m["planks"], 0.03)
    _box("Step", (1.4, 0.4, 0.15), (-0.9, edge - 0.2, 0.075), m["planks"], 0.02)
    post_y = edge + 0.15
    beam_z = eave_front[1] + (post_y - eave_front[0]) * slope - 0.2
    for k, x in enumerate((-half + 0.15, -0.1, half - 0.15)):
        _box(f"PorchPost{k}", (0.22, 0.22, beam_z - 0.3), (x, post_y, 0.3 + (beam_z - 0.3) / 2), m["dark"], 0.02)
    _box("PorchBeam", (2 * half + 0.3, 0.24, 0.26), (0, post_y, beam_z), m["dark"], 0.02)
    _box("Rail", (half - 0.4, 0.1, 0.12), (half / 2 + 0.05, post_y, 1.25), m["dark"])
    _box("RailSnow", (half - 0.5, 0.16, 0.08), (half / 2 + 0.05, post_y, 1.35), m["snow"], 0.03)
    _box("Door", (1.1, 0.08, 2.1), (-0.9, face_front - 0.04, 1.35), m["planks"], 0.02)
    _box("DoorFrame", (1.4, 0.06, 2.3), (-0.9, face_front + 0.01, 1.4), m["dark"])


def build_cabin_two_storey() -> None:
    """B4: narrow two-storey log cabin, gable to the street, outside stair up the right wall. 7 x 7 x 9."""
    m = _mats()
    half, y_front, y_back = 2.6, -2.0, 2.4
    log_walls("Log", half, y_front, y_back, (5.6, 5.9), m["logs"])
    pitch = math.radians(40)
    ridge_z = 5.4 + (half + 0.2) * math.tan(pitch) + 0.3
    gable = [(-half - 0.2, 5.4), (half + 0.2, 5.4), (0, ridge_z - 0.15)]
    for name, y in (("GableFront", y_front - LOG_R - 0.02), ("GableBack", y_back - 0.15)):
        tb._prism_y(name, gable, y, 0.32, m["planks"])
    for k, side in enumerate((-1, 1)):
        eave_a = side * (half + 0.7)
        eave_z = ridge_z - (half + 0.7) * math.tan(pitch)
        roof_side(f"Roof{k}", (0, ridge_z), (eave_a, eave_z), ("y", y_front - 0.6, y_back + 0.5), m)
        icicles(
            f"RoofIce{k}",
            (eave_a, y_front - 0.5, eave_z - 0.05),
            (eave_a, y_back + 0.4, eave_z - 0.05),
            9,
            m["snow"],
            20 + k,
        )
    _box("Ridge", (0.3, y_back - y_front + 1.2, 0.3), (0, (y_front + y_back) / 2 - 0.05, ridge_z + 0.3), m["snow"], 0.1)
    front, back = y_front - LOG_R - 0.02, y_back + LOG_R + 0.02
    _box("Door", (1.1, 0.08, 2.1), (-0.8, front - 0.02, 1.35), m["planks"], 0.02)
    _box("DoorFrame", (1.4, 0.06, 2.3), (-0.8, front + 0.03, 1.4), m["dark"])
    _box("Landing", (1.6, 1.3, 0.25), (-0.8, y_front - 0.85, 0.2), m["planks"], 0.03)
    window("FrontLow", (1.3, front, 1.7), (0.9, 1.1), m)
    for k, x in enumerate((-1.3, 1.3)):
        window(f"FrontHigh{k}", (x, front, 4.3), (0.9, 1.0), m, lit=k == 0)
    window("Gable", (0, front, 6.6), (0.6, 0.6), m)
    window("Left", (-half - LOG_R - 0.02, 0.2, 1.7), (1.0, 1.1), m, lit=False, facing="left")
    window("LeftHigh", (-half - LOG_R - 0.02, 0.2, 4.3), (1.0, 1.0), m, facing="left")
    window("Back", (0, back, 4.3), (0.9, 1.0), m, lit=False, facing="back")
    _side_stair(m, half + LOG_R)
    drifts("Drift", half, y_front, y_back, m["snow"])


def _side_stair(m: dict, wall_x: float) -> None:
    """Open plank stair up the right wall from the back to an upper door and landing near the front."""
    floor_z, steps = 3.0, 10
    x = wall_x + 0.55
    _box("UpperDoor", (0.08, 1.0, 2.0), (wall_x + 0.03, -1.0, floor_z + 1.05), m["planks"], 0.02)
    _box("UpperLanding", (1.0, 1.3, 0.22), (x, -1.0, floor_z), m["planks"], 0.03)
    _box("UpperLandingSnow", (0.9, 1.2, 0.06), (x, -1.0, floor_z + 0.14), m["snow"], 0.02)
    for k in range(steps):
        y = 1.95 - k * 0.24
        _box(f"Tread{k}", (0.95, 0.28, 0.07), (x, y, 0.3 + k * 0.27), m["planks"])
    run = math.hypot(steps * 0.24, steps * 0.27)
    tilt = math.atan2(steps * 0.27, steps * 0.24)
    for k, sx in enumerate((x - 0.5, x + 0.5)):
        _box(f"Stringer{k}", (0.08, run + 0.3, 0.22), (sx, 0.85, 1.55), m["dark"], turn=(tilt, 0, 0))
    _box("Rail", (0.08, run + 0.3, 0.08), (x + 0.5, 0.85, 2.5), m["dark"], turn=(tilt, 0, 0))
    for k, y in enumerate((-1.55, -0.45, 2.05)):
        z_top = floor_z if y < 0 else 0.3
        _box(f"StairPost{k}", (0.16, 0.16, z_top + 1.0), (x + 0.45, y, (z_top + 1.0) / 2), m["dark"])
    _box("LandingRail", (0.08, 1.3, 0.08), (x + 0.45, -1.0, floor_z + 0.95), m["dark"])


def build_shed_lean_to() -> None:
    """B5: plank lean-to shed, open front, roof sloping down to the front, firewood stacked inside. 4 x 3 x 3."""
    m = _mats()
    _box("Back", (3.8, 0.12, 2.6), (0, 1.3, 1.3), m["planks"])
    for k, x in enumerate((-1.85, 1.85)):
        slab(f"Side{k}", [(-1.2, 0), (1.36, 0), (1.36, 2.6), (-1.2, 2.05)], 0.1, m["planks"], x=x)
        _box(f"FrontPost{k}", (0.16, 0.16, 2.05), (x, -1.2, 1.02), m["dark"])
    _box("FrontBeam", (3.9, 0.16, 0.16), (0, -1.2, 2.0), m["dark"])
    roof_side("Roof", (1.45, 2.75), (-1.45, 2.1), ("x", -2.05, 2.05), m, thick=0.12)
    icicles("Ice", (-1.9, -1.5, 2.05), (1.9, -1.5, 2.05), 8, m["snow"], 30)
    for row in range(4):
        for k in range(14 - row):
            x = -1.55 + (k + row * 0.5) * 0.23
            _log_end(f"Wood{row}_{k}", (x, 0.55, 0.11 + row * 0.2), m)
    _box("Drift", (4.2, 0.4, 0.3), (0, 1.58, 0.15), m["snow"], 0.12)
    _box("DriftFront", (1.4, 0.4, 0.22), (1.3, -1.4, 0.11), m["snow"], 0.1)


def _log_end(name: str, at: tuple, m: dict) -> None:
    """A split firewood log lying front to back, so its end shows from the street."""
    bpy.ops.mesh.primitive_cylinder_add(vertices=7, radius=0.1, depth=1.1, location=at, rotation=(math.pi / 2, 0, 0))
    bpy.context.active_object.name = name
    bpy.context.active_object.data.materials.append(m["logs"])


def build_watchtower() -> None:
    """B6: timber tower on four legs, ladder at the front, roofed platform with a rail and a floodlight. 4 x 4 x 13."""
    m = _mats()
    deck, leg = 8.6, 1.55
    for k, (sx, sy) in enumerate(((-1, -1), (1, -1), (-1, 1), (1, 1))):
        _box(f"Leg{k}", (0.3, 0.3, deck), (sx * leg, sy * leg, deck / 2), m["dark"], 0.02)
    _tower_braces(m, leg, deck)
    _box("Deck", (4.0, 4.0, 0.25), (0, 0, deck + 0.12), m["planks"], 0.03)
    for k, (size, at) in enumerate(
        (
            ((4.0, 0.1, 1.1), (0, -1.95, deck + 0.8)),
            ((4.0, 0.1, 1.1), (0, 1.95, deck + 0.8)),
            ((0.1, 4.0, 1.1), (-1.95, 0, deck + 0.8)),
            ((0.1, 3.9, 1.1), (1.95, 0.05, deck + 0.8)),
        )
    ):
        _box(f"Wall{k}", size, at, m["planks"])
        _box(f"WallSnow{k}", (size[0] + 0.04, size[1] + 0.06, 0.08), (at[0], at[1], deck + 1.39), m["snow"], 0.03)
    roof_z = deck + 2.6
    for k, (sx, sy) in enumerate(((-1, -1), (1, -1), (-1, 1), (1, 1))):
        _box(f"RoofPost{k}", (0.18, 0.18, roof_z - deck), (sx * 1.85, sy * 1.85, deck + (roof_z - deck) / 2), m["dark"])
    _cone("Roof", 3.3, 1.4, (0, 0, roof_z + 0.7), m["roof"])
    _cone("RoofSnow", 3.0, 1.25, (0, 0, roof_z + 0.86), m["snow"])
    icicles("Ice", (-2.2, -2.25, roof_z - 0.05), (2.2, -2.25, roof_z - 0.05), 10, m["snow"], 40)
    _ladder(m, deck)
    _floodlight(m, (1.3, -2.05, deck + 1.5))


def _tower_braces(m: dict, leg: float, deck: float) -> None:
    """Cross braces on all four sides, two bays high, plus a ring beam under the deck."""
    span = 2 * leg
    for bay in range(2):
        z0 = 0.6 + bay * (deck - 0.6) / 2
        z1 = z0 + (deck - 0.6) / 2
        length = math.hypot(span, z1 - z0)
        tilt = math.atan2(z1 - z0, span)
        for side in range(4):
            along_x = side < 2
            off = leg * (1 if side % 2 else -1)
            for d, sign in enumerate((1, -1)):
                at = (0, off, (z0 + z1) / 2) if along_x else (off, 0, (z0 + z1) / 2)
                turn = (0, -sign * tilt, 0) if along_x else (sign * tilt, 0, 0)
                size = (length, 0.1, 0.14) if along_x else (0.1, length, 0.14)
                _box(f"Brace{bay}_{side}_{d}", size, at, m["dark"], turn=turn)
    for side, (size, at) in enumerate(
        (
            ((span + 0.3, 0.2, 0.24), (0, -leg, deck - 0.12)),
            ((span + 0.3, 0.2, 0.24), (0, leg, deck - 0.12)),
            ((0.2, span + 0.3, 0.24), (-leg, 0, deck - 0.12)),
            ((0.2, span + 0.3, 0.24), (leg, 0, deck - 0.12)),
        )
    ):
        _box(f"Ring{side}", size, at, m["dark"])


def _ladder(m: dict, deck: float) -> None:
    """Front ladder from the snow up to a hatch gap in the front wall."""
    y = -1.85
    for k, x in enumerate((-0.3, 0.3)):
        _box(f"LadderRail{k}", (0.08, 0.08, deck + 1.0), (x, y, (deck + 1.0) / 2), m["dark"])
    for k in range(int(deck / 0.35)):
        _box(f"Rung{k}", (0.56, 0.05, 0.05), (0, y, 0.35 + k * 0.35), m["dark"])


def _floodlight(m: dict, at: tuple) -> None:
    """Box floodlight on a short iron bracket at the front rail, lens facing the street."""
    x, y, z = at
    _box("FloodArm", (0.08, 0.08, 0.6), (x, y + 0.05, z - 0.1), m["iron"])
    _box("FloodBody", (0.6, 0.35, 0.45), (x, y - 0.12, z + 0.35), m["iron"], 0.03, turn=(math.radians(-15), 0, 0))
    _box("FloodLens", (0.5, 0.04, 0.36), (x, y - 0.31, z + 0.3), m["glow"], turn=(math.radians(-15), 0, 0))


MODELS = {
    "cabin_small": ("town_large/cabin_small.glb", tb._merged(build_cabin_small, "CabinSmall")),
    "cabin_two_storey": ("town_large/cabin_two_storey.glb", tb._merged(build_cabin_two_storey, "CabinTwoStorey")),
    "shed_lean_to": ("town_large/shed_lean_to.glb", tb._merged(build_shed_lean_to, "ShedLeanTo")),
    "watchtower": ("town_large/watchtower.glb", tb._merged(build_watchtower, "Watchtower")),
}
