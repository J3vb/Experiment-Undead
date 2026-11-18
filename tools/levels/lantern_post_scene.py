"""Writes levels/lantern_post/lantern_post.tscn, the Lantern Post town.

The script is the source of the scene: change it and run it, never edit the .tscn by hand.
    python tools/levels/lantern_post_scene.py
Godot tscn Transform3D values list the basis rows, then the origin.
"""

import math
import random
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCENE = ROOT / "levels/lantern_post/lantern_post.tscn"
MATS = [
    "town_stone",
    "town_plaster",
    "town_planks",
    "town_dark_wood",
    "town_slate",
    "town_cobbles",
    "town_mud",
    "town_snow",
    "rust",
    "bio_leak",
    "sodium_lamp",
    "lit_window",
    "pine",
    "iron",
    "beacon_red",
]
SCENES = ["street_lamp", "wall_lantern", "fence", "signpost"]
MARKET = ["stall_frame", "stall_sign", "missions_board", "trader_goods", "gun_wall", "workbench", "tech_desk"]
LARGE = ["lodge_lantern_post", "lodge_common_room", "cabin_small", "cabin_two_storey", "shed_lean_to", "watchtower"]
LODGE_YAW = math.pi / 2  # model fronts (+Z) face the street (+X)
EAST_YAW = -math.pi / 2  # east-side model fronts face the street (-X)
# Stall sign -> (subtitle, [(dressing model, spot in the stall's own space, extra yaw)]), north to south.
STALLS = {
    "TECHNICIAN": ("Serums / Gear", [("tech_desk", (0, 0, -0.85), 0.0)]),
    "GUNSMITH": ("Upgrades / Mods", [("gun_wall", (0, 0, -1.2), 0.0), ("workbench", (0.5, 0, 0.28), math.pi)]),
    "TRADER": ("Buy / Sell", [("trader_goods", (0, 1.03, 1.0), 0.0)]),
    "MISSIONS": ("", [("missions_board", (0, 0, -0.95), 0.0)]),
}
STALL_X = -6.1
STALL_PITCH = 4.4
STALL_SOUTH_Z = -13.8
# Colliders in a model's own space (front +Z): (centre, size).
STALL_BLOCKS = [((0, 0.5, 1.05), (3.9, 1.0, 0.76)), ((0, 1.3, -1.31), (3.9, 2.6, 0.12))]
CABIN_BLOCKS = {
    "cabin_small": [((0, 2.5, -0.57), (6.34, 5.0, 4.14)), ((0, 0.15, 2.19), (6.3, 0.3, 1.38))],
    "cabin_two_storey": [
        ((-0.104, 3.0, -0.425), (5.54, 6.0, 4.74)),
        ((3.25, 1.5, -0.45), (1.0, 3.0, 3.75)),
        ((-0.904, 0.2, 2.625), (1.6, 0.35, 1.3)),
    ],
}
# East-side cabins north to south: model, (x, z), mirrored, porch lantern spot, stove smoke spot (model space).
CABINS = [
    ("cabin_two_storey", (8.5, -30.0), False, (0.1, 2.2, 2.0), None),
    ("cabin_small", (8.6, -21.5), False, (0.0, 2.2, 1.52), (1.9, 5.5, -1.77)),
    ("cabin_two_storey", (8.5, -12.5), True, (0.1, 2.2, 2.0), None),
    ("cabin_small", (8.6, -3.5), True, (0.0, 2.2, 1.52), (1.9, 5.5, -1.77)),
]
TOWER = (8.0, -35.6)
SHEDS = [(-20.0, -23.0), (-20.0, -11.0), (20.0, -23.0), (20.0, -11.0)]
SODIUM = "1, 0.58, 0.25, 1"
WALL_H = 3.6

nodes: list[str] = []
used: set[tuple[str, str]] = set()
shadow_budget = [6]
counts: dict[str, int] = {}
shapes: dict[str, str] = {}


def fmt(v: float) -> str:
    return f"{v:.4g}"


def _mul(a: list[list[float]], b: list[list[float]]) -> list[list[float]]:
    return [[sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]


def basis_rot(yaw: float = 0.0, roll: float = 0.0, pitch: float = 0.0) -> list[list[float]]:
    """R = Ry(yaw) * Rz(roll) * Rx(pitch)."""
    cy, sy = math.cos(yaw), math.sin(yaw)
    cr, sr = math.cos(roll), math.sin(roll)
    cp, sp = math.cos(pitch), math.sin(pitch)
    ry = [[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]]
    rz = [[cr, -sr, 0], [sr, cr, 0], [0, 0, 1]]
    rx = [[1, 0, 0], [0, cp, -sp], [0, sp, cp]]
    return _mul(_mul(ry, rz), rx)


def xform(pos, rot=None, scale=(1, 1, 1)) -> str:
    m = rot or [[1, 0, 0], [0, 1, 0], [0, 0, 1]]
    rows = [[m[r][c] * scale[c] for c in range(3)] for r in range(3)]
    vals = rows[0] + rows[1] + rows[2] + list(pos)
    return f"Transform3D({', '.join(fmt(v) for v in vals)})"


def block(name, parent, pos, size, mat, rot=None) -> None:
    size_text = f"Vector3({fmt(size[0])}, {fmt(size[1])}, {fmt(size[2])})"
    nodes.append(
        f'[node name="{name}" type="StaticBody3D" parent="{parent}"]\ntransform = {xform(pos, rot)}\n'
        f'script = ExtResource("block")\nsize = {size_text}\nmaterial = ExtResource("{mat}")\n'
    )


def collider(name, parent, pos, size, yaw=0.0) -> None:
    """Invisible box collider for a building model (the model itself has no collision)."""
    key = "shape_" + "x".join(fmt(v) for v in size).replace(".", "p")
    shapes[key] = f"Vector3({fmt(size[0])}, {fmt(size[1])}, {fmt(size[2])})"
    nodes.append(
        f'[node name="{name}" type="StaticBody3D" parent="{parent}"]\ntransform = {xform(pos, basis_rot(yaw))}\n'
    )
    nodes.append(
        f'[node name="Shape" type="CollisionShape3D" parent="{parent}/{name}"]\nshape = SubResource("{key}")\n'
    )


def deco(name, parent, pos, size, mat, rot=None, mesh="box") -> None:
    nodes.append(
        f'[node name="{name}" type="MeshInstance3D" parent="{parent}"]\ntransform = {xform(pos, rot, size)}\n'
        f'mesh = SubResource("{mesh}_{mat}")\n'
    )
    used.add((mesh, mat))


def inst(name, parent, pos, scene, yaw=0.0, scale=(1, 1, 1)) -> None:
    nodes.append(
        f'[node name="{name}" parent="{parent}" instance=ExtResource("{scene}")]\n'
        f"transform = {xform(pos, basis_rot(yaw), scale)}\n"
    )


def label(name, parent, pos, yaw, text, size=48, color="0.95, 0.85, 0.65, 1") -> None:
    nodes.append(
        f'[node name="{name}" type="Label3D" parent="{parent}"]\ntransform = {xform(pos, basis_rot(yaw))}\n'
        f'pixel_size = 0.004\nmodulate = Color({color})\noutline_size = 6\nfont_size = {size}\ntext = "{text}"\n'
    )


def group(name, parent=".") -> None:
    nodes.append(f'[node name="{name}" type="Node3D" parent="{parent}"]\n')


def omni(name, parent, pos, color, energy, rng, shadow=False) -> None:
    s = "\nshadow_enabled = true" if shadow else ""
    nodes.append(
        f'[node name="{name}" type="OmniLight3D" parent="{parent}"]\ntransform = {xform(pos)}\n'
        f"light_color = Color({color})\nlight_energy = {energy}\nomni_range = {rng}\nomni_attenuation = 1.2{s}\n"
    )


def lit(name, parent, pos, energy, rng, color=SODIUM, want_shadow=False) -> None:
    sh = want_shadow and shadow_budget[0] > 0
    if sh:
        shadow_budget[0] -= 1
    omni(name, parent, pos, color, energy, rng, sh)


def body(name, parent, pos, size, mat) -> None:
    nodes.append(
        f'[node name="{name}" type="StaticBody3D" parent="{parent}"]\ntransform = {xform(pos)}\n'
        f'script = ExtResource("block")\nsize = Vector3({size})\nmaterial = ExtResource("{mat}")\n'
    )


def pine(name, parent, x, z, h) -> None:
    """A pine cone mesh scaled by h, its base on the ground."""
    hs = f"{h:.3g}"
    y = 5.0 * float(hs)
    nodes.append(
        f'[node name="{name}" type="MeshInstance3D" parent="{parent}"]\n'
        f"transform = Transform3D({hs}, 0, 0, 0, {hs}, 0, 0, 0, {hs}, {x:.3g}, {y:.3g}, {z:.3g})\n"
        'mesh = SubResource("pine_tree")\n'
    )


def build_ground() -> None:
    group("Ground")
    block("Snow", "Ground", (0, -0.25, -12), (90, 0.5, 100), "town_snow")
    block("Street", "Ground", (0, 0.01, -14), (8, 0.04, 44), "town_mud")
    block("Plaza", "Ground", (0, 0.01, 6), (22, 0.04, 14), "town_mud")
    group("SnowBanks")
    for k in range(18):
        side = -1 if k % 2 == 0 else 1
        z = -33 + k * 2.3 + random.uniform(-0.4, 0.4)
        if z > -1:
            continue
        pos = (side * random.uniform(4.0, 4.4), 0.05, z)
        size = (random.uniform(0.6, 1.0), random.uniform(0.25, 0.45), random.uniform(1.4, 2.4))
        deco(f"Bank{k}", "SnowBanks", pos, size, "town_snow", basis_rot(random.uniform(-0.2, 0.2)))


def build_walls() -> None:
    group("Walls")
    for name, pos, size in [
        ("NorthWest", (-14.5, WALL_H / 2, -38), (23, WALL_H, 0.6)),
        ("NorthEast", (14.5, WALL_H / 2, -38), (23, WALL_H, 0.6)),
        ("South", (0, WALL_H / 2, 16), (52, WALL_H, 0.6)),
        ("West", (-26, WALL_H / 2, -11), (0.6, WALL_H, 54)),
        ("East", (26, WALL_H / 2, -11), (0.6, WALL_H, 54)),
    ]:
        block(name, "Walls", pos, size, "town_planks")
        long_x = size[0] > size[2]
        length = size[0] if long_x else size[2]
        for i in range(int(length / 3) + 1):
            off = -(length / 2) + i * 3
            p = (pos[0] + off, WALL_H / 2 + 0.25, pos[2]) if long_x else (pos[0], WALL_H / 2 + 0.25, pos[2] + off)
            deco(f"{name}Post{i}", "Walls", p, (0.32, WALL_H + 0.5, 0.32), "town_dark_wood")
        deco(f"{name}Cap", "Walls", (pos[0], WALL_H + 0.05, pos[2]), (size[0] + 0.1, 0.1, size[2] + 0.3), "town_snow")


def _on_lodge(centre, local) -> tuple:
    """A point given in a lodge model's own space (front +Z) to world space, lodge turned by LODGE_YAW."""
    return (centre[0] + local[2], local[1], centre[1] - local[0])


def _lantern_post_lodge() -> None:
    """B1 by the plaza: gable sign, hanging lantern, porch light, colliders for the walls and the porch deck."""
    at = (-9.6, -5.0)
    inst("LodgeLanternPost", "Lodges", (at[0], 0, at[1]), "lodge_lantern_post", LODGE_YAW)
    collider("LanternPostWalls", "Lodges", _on_lodge(at, (0, 3.5, -0.925)), (12.34, 7, 6.64), LODGE_YAW)
    collider("LanternPostPorch", "Lodges", _on_lodge(at, (0, 0.15, 3.36)), (12.4, 0.3, 1.93), LODGE_YAW)
    sign = _on_lodge(at, (0.3, 8.05, 2.44))
    label("LanternPostSign", "Lodges", sign, LODGE_YAW, "LANTERN\\nPOST", 190, "0.8, 0.78, 0.72, 1")
    inst("LanternPostLantern", "Lodges", _on_lodge(at, (-2.9, 6.35, 2.2)), "wall_lantern", LODGE_YAW)
    lit("LanternPostLanternLight", "Lodges", _on_lodge(at, (-2.9, 6.8, 3.0)), 2.6, 9.0)
    lit("LanternPostPorchLight", "Lodges", _on_lodge(at, (0, 2.8, 3.4)), 1.6, 8.0)


def _common_room_lodge() -> None:
    """B2 at the north end: COMMON ROOM board on the balcony, stove-pipe smoke, posts and walls collide."""
    at = (-11.8, -29.0)
    inst("LodgeCommonRoom", "Lodges", (at[0], 0, at[1]), "lodge_common_room", LODGE_YAW)
    collider("CommonRoomWalls", "Lodges", _on_lodge(at, (0, 3.5, -1.112)), (14.34, 7, 5.94), LODGE_YAW)
    for k, x in enumerate((-7.0, -3.5, 0.0, 3.5, 7.0)):
        collider(f"CommonRoomPost{k}", "Lodges", _on_lodge(at, (x, 1.6, 3.918)), (0.26, 3.2, 0.26), LODGE_YAW)
    label("CommonRoomSign", "Lodges", _on_lodge(at, (0, 5.76, 4.11)), LODGE_YAW, "COMMON ROOM", 130)
    smoke = xform(_on_lodge(at, (4.4, 9.95, -2.21)))
    nodes.append(
        f'[node name="CommonRoomSmoke" parent="Lodges" instance=ExtResource("chimney_smoke")]\ntransform = {smoke}\n'
    )
    lit("CommonRoomPorchLight", "Lodges", _on_lodge(at, (0, 2.6, 3.0)), 2.4, 9.0)
    lit("CommonRoomBalconyLight", "Lodges", _on_lodge(at, (0, 5.2, 3.2)), 2.4, 9.0)


def build_lodges() -> None:
    """The two hero lodges on the west side of the street (asset list B1, B2; layout map)."""
    group("Lodges")
    _lantern_post_lodge()
    _common_room_lodge()


def build_lamps() -> None:
    group("Lamps")
    k = 0
    for z in range(-31, 13, 7):
        side = -1 if k % 2 == 0 else 1
        x = side * 4.5
        if side < 0 and STALL_SOUTH_Z - len(STALLS) * STALL_PITCH < z < STALL_SOUTH_Z + 2.5:
            k += 1
            continue  # the market stalls stand there and bring their own lights
        block(f"Post{k}", "Lamps", (x, 2.3, z), (0.14, 4.6, 0.14), "iron")
        inst(f"Lamp{k}", "Lamps", (x - 0.3 * side, 0, z), "street_lamp", -side * math.pi / 2)
        lit(f"Light{k}", "Lamps", (x - 0.3 * side - side * 0.4, 3.95, z), 3.2, 13.0, want_shadow=(k % 2 == 0))
        k += 1
    counts["lamps"] = k
    group("StringLights")
    for li, z in enumerate((-26, -18, -10, -3)):
        for b in range(11):
            t = b / 10
            pos = (-4.6 + 9.2 * t, 5.0 - math.sin(math.pi * t) * 0.6, z)
            deco(f"Bulb{li}_{b}", "StringLights", pos, (0.12, 0.12, 0.12), "sodium_lamp")
        deco(f"Wire{li}", "StringLights", (0, 4.55, z), (9.2, 0.02, 0.02), "iron")


def _gate_tower(s) -> None:
    n = "W" if s < 0 else "E"
    tx = s * 4.3
    block(f"Tower{n}", "Gate", (tx, 3.2, -38), (2.4, 6.4, 2.4), "town_planks")
    deco(f"Tower{n}Platform", "Gate", (tx, 6.5, -38), (3.0, 0.2, 3.0), "town_dark_wood")
    deco(f"Tower{n}Roof", "Gate", (tx, 8.2, -38), (3.2, 0.25, 3.2), "town_slate")
    deco(f"Tower{n}RoofSnow", "Gate", (tx, 8.36, -38), (3.0, 0.1, 3.0), "town_snow")
    for c in range(4):
        cx, cz2 = (-1 if c < 2 else 1) * 1.35, (-1 if c % 2 else 1) * 1.35
        deco(f"Tower{n}Pillar{c}", "Gate", (tx + cx, 7.35, -38 + cz2), (0.16, 1.7, 0.16), "town_dark_wood")
    deco(f"Tower{n}Torch", "Gate", (tx - s * 1.3, 3.0, -36.75), (0.25, 0.35, 0.25), "sodium_lamp")
    lit(f"Tower{n}TorchLight", "Gate", (tx - s * 1.3, 3.0, -36.3), 2.5, 8.0)


def build_gate() -> None:
    group("Gate")
    for s in (-1, 1):
        _gate_tower(s)
    block("Lintel", "Gate", (0, 5.6, -38), (6.2, 0.7, 0.9), "town_dark_wood")
    deco("SignBoard", "Gate", (0, 4.85, -37.5), (4.6, 0.8, 0.1), "town_dark_wood")
    deco("SignStrip", "Gate", (0, 4.4, -37.43), (4.2, 0.07, 0.05), "bio_leak")
    nodes.append(
        '[node name="Sign" type="Label3D" parent="Gate"]\ntransform = ' + xform((0, 4.88, -37.43)) + "\n"
        "pixel_size = 0.006\nmodulate = Color(0.553, 1, 0.227, 1)\noutline_size = 0\nfont_size = 80\n"
        'text = "LANTERN POST"\n'
    )
    lit("GateGlow", "Gate", (0, 4.0, -36.3), 3.2, 10.0, color="0.553, 1, 0.227, 1")
    block("GateLeafW", "Gate", (-2.0, 1.7, -38.3), (2.0, 3.4, 0.2), "town_planks")
    block("GateLeafE", "Gate", (2.0, 1.7, -38.3), (2.0, 3.4, 0.2), "town_planks")
    for s in (-1, 1):
        for bh in (0.7, 2.7):
            band = f"GateBand{'W' if s < 0 else 'E'}{int(bh * 10)}"
            deco(band, "Gate", (s * 2.0, bh, -38.18), (1.9, 0.12, 0.05), "iron")
    spot = xform((0, 0, -35.5))
    nodes.append(f'[node name="DeployBoardSpot" type="Marker3D" parent="Gate"]\ntransform = {spot}\n')
    nodes.append(
        '[node name="DeployBoard" parent="Gate/DeployBoardSpot" instance=ExtResource("deploy_board")]\n'
        'place = &"match"\nlabel = "Halcyon Labs"\n'
    )
    nodes.append('[node name="DeployVotePanel" parent="." instance=ExtResource("deploy_vote_panel")]\n')


def _plaza_well() -> None:
    for wk, (dx, dz, sx, sz) in enumerate(
        [(0, -0.8, 1.9, 0.3), (0, 0.8, 1.9, 0.3), (-0.8, 0, 0.3, 1.3), (0.8, 0, 0.3, 1.3)]
    ):
        block(f"Well{wk}", "Props", (6 + dx, 0.45, 9 + dz), (sx, 0.9, sz), "town_stone")
    for s in (-1, 1):
        deco(f"WellPost{s + 1}", "Props", (6 + s * 0.85, 1.4, 9), (0.15, 1.9, 0.15), "town_dark_wood")
    deco("WellRoofA", "Props", (6, 2.45, 8.65), (2.2, 0.1, 0.9), "town_slate", basis_rot(pitch=0.5))
    deco("WellRoofB", "Props", (6, 2.45, 9.35), (2.2, 0.1, 0.9), "town_slate", basis_rot(pitch=-0.5))


def _barrels_and_crates() -> None:
    for bk, (x, z) in enumerate([(-8, 4), (8.5, 4.5), (-2.4, -24), (3.0, -14)]):
        block(f"Barrel{bk}", "Props", (x, 0.45, z), (0.62, 0.9, 0.62), "rust")
        deco(f"BarrelRim{bk}", "Props", (x, 0.88, z), (0.68, 0.06, 0.68), "iron")
        deco(f"Fire{bk}", "Props", (x, 0.98, z), (0.42, 0.14, 0.42), "sodium_lamp")
        lit(f"FireLight{bk}", "Props", (x, 1.5, z), 2.6, 7.0, color="1, 0.5, 0.18, 1", want_shadow=(bk == 0))
    crates = [(-9, 10, 1.0), (-9.6, 11.1, 0.8), (-9.2, 10.4, 0.6), (9.4, 1.5, 1.1), (3.4, -20, 0.9), (-3.4, -8, 1.0)]
    for ck, (x, z, s) in enumerate(crates):
        y = s / 2 if ck != 2 else 1.0 + s / 2
        block(f"Crate{ck}", "Props", (x, y, z), (s, s, s), "town_planks")
        deco(f"CrateSnow{ck}", "Props", (x, y + s / 2 + 0.03, z), (s * 0.9, 0.05, s * 0.9), "town_snow")
    for lk, (x, z) in enumerate([(-12.5, 6.5), (10, 11)]):
        for r in range(3):
            for c in range(5 - r):
                pos = (x, 0.15 + r * 0.27, z - 1.0 + c * 0.5 + r * 0.25)
                deco(f"Log{lk}_{r}_{c}", "Props", pos, (1.8, 0.26, 0.26), "town_dark_wood")
        body(f"LogStackBody{lk}", "Props", (x, 0.4, z), "1.8, 0.8, 2.5", "town_dark_wood")


def build_props() -> None:
    group("Props")
    _plaza_well()
    _barrels_and_crates()
    for bn, (x, z) in enumerate([(-6, 12), (2, 12)]):
        block(f"Bench{bn}", "Props", (x, 0.45, z), (1.8, 0.1, 0.45), "town_planks")
        for s in (-1, 1):
            deco(f"BenchLeg{bn}{s + 1}", "Props", (x + s * 0.75, 0.2, z), (0.1, 0.4, 0.4), "town_dark_wood")
    block("Cart", "Props", (-9.5, 0.75, 5.5), (1.4, 0.5, 2.4), "town_planks")
    for s in (-1, 1):
        deco(f"CartWheel{s + 1}", "Props", (-9.5 + s * 0.78, 0.45, 5.5), (0.08, 0.9, 0.9), "town_dark_wood")


def build_fences_and_signs() -> None:
    group("Fences")
    fk = 0
    for fz in range(-30, -2, 2):
        for sx in (-1, 1):
            if sx < 0 and fz < -21:
                continue  # the Common Room lodge stands there
            inst(f"Fence{fk}", "Fences", (sx * 15.5, 0, fz + 1), "fence", math.pi / 2)
            fk += 1
    for fx in range(-10, 12, 2):
        if -2 <= fx <= 2:
            continue
        inst(f"PlazaFence{fk}", "Fences", (fx + 1, 0, 13.2), "fence", 0.0)
        fk += 1
    group("Signs")
    inst("Signpost", "Signs", (-3.0, 0, -1.0), "signpost", 0.0)
    label("SignGate", "Signs", (-2.58, 2.25, -0.87), 0.0, "DEPLOY GATE", 26)
    label("SignInfirmary", "Signs", (-3.42, 1.85, -0.87), 0.0, "INFIRMARY", 26)


def _sacks() -> None:
    group("Sacks")
    for sk, (x, z) in enumerate([(-9.6, 1.6), (-9.2, 2.2), (9.6, 6.4), (9.9, 7.1), (-3.6, -32.2), (3.7, -33.0)]):
        deco(f"Sack{sk}", "Sacks", (x, 0.25, z), (0.55, 0.5, 0.4), "town_plaster", basis_rot(random.uniform(0, 3)))
        body(f"SackBody{sk}", "Sacks", (x, 0.25, z), "0.5, 0.5, 0.4", "town_plaster")


def _stall(k: int, name: str) -> None:
    """One market stall facing the street: frame, sign board with its name, dressing, light and colliders."""
    subtitle, dressing = STALLS[name]
    at = (STALL_X, STALL_SOUTH_Z - (len(STALLS) - 1 - k) * STALL_PITCH)
    tag = name.capitalize()
    inst(f"{tag}Stall", "Market", (at[0], 0, at[1]), "stall_frame", LODGE_YAW)
    inst(f"{tag}Sign", "Market", _on_lodge(at, (0, 2.45, 1.75)), "stall_sign", LODGE_YAW)
    label(f"{tag}SignName", "Market", _on_lodge(at, (0, 2.98 if subtitle else 2.86, 1.83)), LODGE_YAW, name, 80)
    if subtitle:
        label(f"{tag}SignSub", "Market", _on_lodge(at, (0, 2.66, 1.83)), LODGE_YAW, subtitle, 40)
    for model, spot, yaw in dressing:
        inst(f"{tag}{model.title().replace('_', '')}", "Market", _on_lodge(at, spot), model, LODGE_YAW + yaw)
    for b, (centre, size) in enumerate(STALL_BLOCKS):
        collider(f"{tag}Block{b}", "Market", _on_lodge(at, centre), size, LODGE_YAW)
    lit(f"{tag}Light", "Market", _on_lodge(at, (0, 2.3, 0.2)), 1.8, 6.0)


def build_market() -> None:
    """The market row S1-S7 on the west side between the two lodges (asset list, layout map)."""
    group("Market")
    for k, name in enumerate(STALLS):
        _stall(k, name)
    _sacks()


def _on_east(centre, local, mirror=False) -> tuple:
    """A point in an east-side model's own space (front +Z) to world space, turned by EAST_YAW."""
    lx = -local[0] if mirror else local[0]
    return (centre[0] - local[2], local[1], centre[1] + lx)


def _cabin(k: int, model: str, at: tuple, mirror: bool, lantern: tuple, smoke) -> None:
    scale = (-1, 1, 1) if mirror else (1, 1, 1)
    inst(f"Cabin{k}", "Cabins", (at[0], 0, at[1]), model, EAST_YAW, scale)
    for b, (centre, size) in enumerate(CABIN_BLOCKS[model]):
        collider(f"Cabin{k}Block{b}", "Cabins", _on_east(at, centre, mirror), size, EAST_YAW)
    inst(f"Cabin{k}Lantern", "Cabins", _on_east(at, lantern, mirror), "wall_lantern", EAST_YAW)
    light = (lantern[0], lantern[1] + 0.2, lantern[2] + 0.6)
    lit(f"Cabin{k}LanternLight", "Cabins", _on_east(at, light, mirror), 2.2, 8.0)
    if smoke:
        nodes.append(
            f'[node name="Cabin{k}Smoke" parent="Cabins" instance=ExtResource("chimney_smoke")]\n'
            f"transform = {xform(_on_east(at, smoke, mirror))}\n"
        )


def build_east_side() -> None:
    """Cabins B3/B4 along the east of the street, the watchtower by the gate and the four yard sheds."""
    group("Cabins")
    for k, cabin in enumerate(CABINS):
        _cabin(k, *cabin)
    inst("Watchtower", "Cabins", (TOWER[0], 0, TOWER[1]), "watchtower", EAST_YAW)
    for k, (sx, sz) in enumerate(((-1, -1), (1, -1), (-1, 1), (1, 1))):
        leg = _on_east(TOWER, (sx * 1.55, 4.3, sz * 1.55 - 0.028))
        collider(f"WatchtowerLeg{k}", "Cabins", leg, (0.3, 8.6, 0.3), EAST_YAW)
    lit("WatchtowerFlood", "Cabins", _on_east(TOWER, (1.3, 10.0, 3.2)), 3.0, 14.0)
    group("Yards")
    for k, (x, z) in enumerate(SHEDS):
        yaw = LODGE_YAW if x < 0 else EAST_YAW
        inst(f"Shed{k}", "Yards", (x, 0, z), "shed_lean_to", yaw)
        collider(f"Shed{k}Block", "Yards", (x, 1.3, z), (3.9, 2.6, 2.6), yaw)


def build_yards_and_pines() -> None:
    for k, sx in enumerate((-1, 1)):
        for t in range(5):
            x = sx * random.uniform(16.5 if sx > 0 else 18.5, 24.5)
            z = random.uniform(-34, 12)
            if min(math.dist((x, z), shed) for shed in SHEDS) > 3.5:
                pine(f"YardPine{k}_{t}", "Yards", x, z, random.uniform(0.55, 0.85))
    group("Pines")
    pk = 0
    for _ in range(170):
        x = random.uniform(-46, 46)
        z = random.uniform(-62, 38)
        if -28 < x < 28 and -40 < z < 18:
            continue
        pine(f"Pine{pk}", "Pines", x, z, random.uniform(7, 14) / 10)
        pk += 1
    counts["pines"] = pk


def build_ridge() -> None:
    """Radio mast with red beacons on a snowy knoll north-east of the gate, and the falling snow."""
    group("Ridge")
    mx, mz = 21.0, -55.0
    deco("Knoll", "Ridge", (mx, 0.5, mz), (14, 3, 12), "town_snow", basis_rot(0.4))
    for leg in range(4):
        lx = (-1 if leg < 2 else 1) * 0.9
        lz = (-1 if leg % 2 else 1) * 0.9
        lean = basis_rot(roll=-lx * 0.035, pitch=lz * 0.035)
        deco(f"MastLeg{leg}", "Ridge", (mx + lx * 0.5, 14.0, mz + lz * 0.5), (0.14, 28.0, 0.14), "iron", lean)
    for rung in range(9):
        y = 2.0 + rung * 3.0
        width = 1.8 - y * 0.032
        deco(f"MastRung{rung}", "Ridge", (mx, y, mz), (width, 0.08, width), "iron")
    for bk, y in enumerate((9.5, 19.0, 28.2)):
        deco(f"MastBeacon{bk}", "Ridge", (mx, y, mz), (0.35, 0.35, 0.35), "beacon_red")
    nodes.append(
        '[node name="Snowfall" parent="." instance=ExtResource("snowfall")]\ntransform = ' + xform((0, 18, -12)) + "\n"
    )


def build_spawn_and_moon() -> None:
    nodes.append('[node name="PlayerSpawn" type="Marker3D" parent="."]\ntransform = ' + xform((-5.0, 0.1, 4)) + "\n")
    nodes.append(
        '[node name="Moon" type="DirectionalLight3D" parent="."]\ntransform = '
        + xform((0, 20, 0), basis_rot(yaw=0.6, pitch=-0.9))
        + "\nlight_color = Color(0.6, 0.7, 0.9, 1)\nlight_energy = 0.35\nshadow_enabled = true\n"
    )


def header() -> str:
    ext = [
        '[ext_resource type="Script" path="res://systems/level/level.gd" id="level"]',
        '[ext_resource type="Script" path="res://systems/level/block.gd" id="block"]',
        '[ext_resource type="Environment" path="res://levels/looks/lantern_post_night.tres" id="look"]',
    ]
    ext += [f'[ext_resource type="PackedScene" path="res://assets/models/town/{sc}.glb" id="{sc}"]' for sc in SCENES]
    ext += [f'[ext_resource type="PackedScene" path="res://assets/models/town/{sc}.glb" id="{sc}"]' for sc in MARKET]
    ext += [
        f'[ext_resource type="PackedScene" path="res://assets/models/town_large/{sc}.glb" id="{sc}"]' for sc in LARGE
    ]
    ext += [f'[ext_resource type="Material" path="res://levels/materials/{m}.tres" id="{m}"]' for m in MATS]
    ext.append('[ext_resource type="PackedScene" path="res://systems/hub/deploy_board.tscn" id="deploy_board"]')
    ext.append(
        '[ext_resource type="PackedScene" path="res://systems/hub/deploy_vote_panel.tscn" id="deploy_vote_panel"]'
    )
    for fx in ("snowfall", "chimney_smoke"):
        ext.append(f'[ext_resource type="PackedScene" path="res://levels/lantern_post/{fx}.tscn" id="{fx}"]')
    subs = [
        f'[sub_resource type="BoxMesh" id="{mesh}_{mat}"]\nmaterial = ExtResource("{mat}")\n'
        for mesh, mat in sorted(used)
    ]
    subs += [f'[sub_resource type="BoxShape3D" id="{key}"]\nsize = {size}\n' for key, size in sorted(shapes.items())]
    subs.append(
        '[sub_resource type="CylinderMesh" id="pine_tree"]\nmaterial = ExtResource("pine")\ntop_radius = 0.0\n'
        "bottom_radius = 2.2\nheight = 10.0\nradial_segments = 9\nrings = 3\n"
    )
    return (
        "[gd_scene format=3]\n\n"
        + "\n".join(ext)
        + "\n\n"
        + "\n".join(subs)
        + '\n[node name="LanternPost" type="Node3D" node_paths=PackedStringArray("player_spawn")]\n'
        'script = ExtResource("level")\nplayer_spawn = NodePath("PlayerSpawn")\n\n'
        '[node name="WorldEnvironment" type="WorldEnvironment" parent="."]\n'
        'environment = ExtResource("look")\n\n'
    )


def build() -> str:
    """Returns the whole scene text. Same seed, same scene."""
    nodes.clear()
    used.clear()
    shapes.clear()
    shadow_budget[0] = 6
    random.seed(7)
    build_ground()
    build_walls()
    build_lodges()
    build_market()
    build_east_side()
    build_lamps()
    build_gate()
    build_props()
    build_fences_and_signs()
    build_yards_and_pines()
    build_ridge()
    build_spawn_and_moon()
    return header() + "\n".join(nodes)


def main() -> None:
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else SCENE
    out.write_text(build())
    print(len(nodes), "nodes;", counts, "shadows left", shadow_budget[0])


if __name__ == "__main__":
    main()
