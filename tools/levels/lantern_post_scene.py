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
    "town_mud",
    "town_snow",
    "iron",
]
SCENES = ["street_lamp", "wall_lantern", "signpost"]
MARKET = ["stall_frame", "stall_sign", "missions_board"]
GATE = ["banner", "floodlight"]
CAMP = [
    "bench",
    "supply_crate_large",
    "supply_crate_small",
    "ammo_case",
    "fenlight_crate",
    "lantern_hanging",
    "lantern_table",
    "string_lights",
    "fence_rail",
    "snow_drift_a",
    "snow_drift_b",
    "firewood_stack",
    "pine_tree",
]
LARGE = [
    "lodge_lantern_post",
    "lodge_common_room",
    "cabin_small",
    "cabin_two_storey",
    "shed_lean_to",
    "watchtower",
    "gate_wall",
    "gate_tunnel",
    "radio_mast",
    "stall_technician",
    "stall_gunsmith",
    "stall_trader",
]
LODGE_YAW = math.pi / 2  # model fronts (+Z) face the street (+X)
EAST_YAW = -math.pi / 2  # east-side model fronts face the street (-X)
# Stall sign -> (subtitle, stall model, [(dressing model, spot in the stall's own space, extra yaw)]), north to south.
STALLS = {
    "TECHNICIAN": ("Serums / Gear", "stall_technician", []),
    "GUNSMITH": ("Upgrades / Mods", "stall_gunsmith", []),
    "TRADER": ("Buy / Sell", "stall_trader", []),
    "MISSIONS": ("", "stall_frame", [("missions_board", (0, 0, -0.95), 0.0)]),
}
STALL_X = -6.1
STALL_PITCH = 4.4
STALL_SOUTH_Z = -13.8
# Stall model -> back shift (z, so every back lines up with the frame's), sign board (bottom y, front z),
# hanging lantern spot or None, colliders in the model's own space (front +Z): (centre, size).
STALL_MODELS = {
    "stall_frame": {
        "shift": 0.0,
        "sign": (2.45, 1.75),
        "lantern": (-1.85, 1.95, 1.5),
        "blocks": [((0, 0.5, 1.05), (3.9, 1.0, 0.76)), ((0, 1.3, -1.31), (3.9, 2.6, 0.12))],
    },
    "stall_technician": {
        "shift": 0.66,
        "sign": (2.0, 1.78),
        "lantern": None,
        "blocks": [((0, 1.3, -0.22), (4.1, 2.6, 3.56))],
    },
    "stall_gunsmith": {
        "shift": 0.25,
        "sign": (2.1, 1.62),
        "lantern": None,
        "blocks": [((0, 1.3, -0.09), (4.1, 2.6, 2.8))],
    },
    "stall_trader": {
        "shift": -0.07,
        "sign": (2.0, 1.35),
        "lantern": None,
        "blocks": [((0, 1.3, 0.02), (4.2, 2.6, 1.6))],
    },
}
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
FLOOD = "1, 0.9, 0.75, 1"
GREEN = "0.553, 1, 0.227, 1"
STENCIL = "0.78, 0.78, 0.72, 1"
WALL_H = 3.6
# Deploy gate (asset list G1-G5). The concrete wall's face is at GATE_Z; the tunnel pillars stand a little proud.
GATE_Z = -38.0
GATE_WALL_X = (-17.0, -9.0, 9.0, 17.0)
GATE_WALL_FRONT = 0.925  # wall body face, in the gate_wall model's own space (+Z)
TUNNEL_Z = -37.6  # tunnel pillar faces
TUNNEL_FRONT = 6.62  # pillar face, in the gate_tunnel model's own space (+Z)
TUNNEL_STOP = 3.0  # players can walk this far into the tunnel
BANNER_BACK = 0.1075  # wall plate behind a banner's origin
BANNERS_X = (-17.0, -6.6, 11.4, 17.0)  # east of the tunnel the watchtower stands in front of the wall
SWEEP = (math.pi / 2 - 0.7, math.pi / 2 + 0.7)  # watchtower spotlight yaw range: gate to street
# Camp props (asset list P1-P13). Collider sizes in each model's own space (width, height, depth).
PROP_BLOCKS = {
    "fire_barrel": (0.64, 1.0, 0.64),
    "bench": (1.8, 0.5, 0.45),
    "supply_crate_large": (1.0, 0.8, 0.8),
    "supply_crate_small": (0.6, 0.5, 0.5),
    "ammo_case": (0.72, 0.36, 0.38),
    "firewood_stack": (1.9, 1.0, 0.85),
}
FIRES = [(-8.0, 4.0), (8.5, 4.5), (-2.4, -24.0), (3.0, -14.0)]
BENCHES = [
    (-6.0, 12.0, 0.0),
    (2.0, 12.0, 0.0),
    (3.0, -12.6, 0.0),
    (3.0, -15.4, 0.0),
    (-7.6, 2.7, 0.3),
    (8.0, 3.0, -0.2),
]
TABLE_LANTERNS = [(-5.4, 12.0), (3.5, -12.6)]  # on benches
# (model, x, y, z, yaw): y > 0 stacks on the crate below.
CRATES = [
    ("supply_crate_large", -9.0, 0.0, 10.0, 0.1),
    ("supply_crate_small", -9.7, 0.0, 11.1, 0.4),
    ("supply_crate_small", -9.1, 0.8, 10.0, -0.2),
    ("supply_crate_large", 9.4, 0.0, 1.5, -0.15),
    ("supply_crate_large", 3.4, 0.0, -20.0, 0.25),
    ("supply_crate_large", -3.4, 0.0, -8.0, -0.1),
    ("ammo_case", 4.9, 0.0, -8.6, 0.0),
    ("ammo_case", 4.9, 0.36, -8.6, 0.15),
    ("ammo_case", 4.8, 0.0, -25.5, -0.3),
    ("ammo_case", 8.6, 0.0, 2.8, 0.5),
]
FENLIGHT_CRATES = [(-5.5, -30.2), (-5.5, -31.3)]  # by the Technician stall, on supply crates
FIREWOOD = [(-12.5, 6.5, LODGE_YAW), (10.0, 11.0, EAST_YAW), (-20.0, -17.0, LODGE_YAW), (20.0, -17.0, EAST_YAW)]

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


def spot(name, parent, pos, rot, energy, rng, angle, color=FLOOD, moves=False) -> None:
    """Unshadowed spot light shining along its -Z. A light that moves stays out of the lightmap bake."""
    bake = "light_bake_mode = 0\n" if moves else ""
    nodes.append(
        f'[node name="{name}" type="SpotLight3D" parent="{parent}"]\ntransform = {xform(pos, rot)}\n'
        f"light_color = Color({color})\nlight_energy = {energy}\n{bake}spot_range = {rng}\nspot_angle = {angle}\n"
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
    """A snowy pine_tree model (10 m) scaled by h, its base on the ground, turned at random."""
    inst(name, parent, (x, 0, z), "pine_tree", random.uniform(0, math.tau), (h, h, h))  # cosmetic


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
        pos = (side * random.uniform(4.5, 4.9), -0.04, z)
        drift = "snow_drift_a" if k % 3 else "snow_drift_b"
        inst(f"Bank{k}", "SnowBanks", pos, drift, math.pi / 2 + random.uniform(-0.2, 0.2))


def build_walls() -> None:
    group("Walls")
    for name, pos, size in [
        ("NorthWest", (-23.5, WALL_H / 2, -39), (5, WALL_H, 0.6)),
        ("NorthEast", (23.5, WALL_H / 2, -39), (5, WALL_H, 0.6)),
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
        inst(f"String{li}", "StringLights", (0, 4.25, z), "string_lights")


def _gate_wall() -> None:
    """Four concrete wall sections either side of the tunnel, a box collider each, banners hung on the face."""
    for k, x in enumerate(GATE_WALL_X):
        inst(f"Wall{k}", "Gate", (x, 0, GATE_Z - GATE_WALL_FRONT), "gate_wall")
        collider(f"Wall{k}Block", "Gate", (x, 3.5, GATE_Z - 1.2), (8.0, 7.0, 2.4))
    for k, x in enumerate(BANNERS_X):
        inst(f"Banner{k}", "Gate", (x, 2.1, GATE_Z + BANNER_BACK), "banner")
    for k, x in enumerate((-19.5, 19.5)):
        inst(f"WallFlood{k}", "Gate", (x, 7.3, GATE_Z - 0.3), "floodlight")


def _gate_tunnel() -> None:
    """The DEPLOY tunnel: sign, floodlights on the pillars, green glow, and colliders that close it 3 m in."""
    inst("Tunnel", "Gate", (0, 0, TUNNEL_Z - TUNNEL_FRONT), "gate_tunnel")
    label("DeploySign", "Gate", (-0.9, 7.3, TUNNEL_Z + 0.13), 0.0, "DEPLOY", 300, "0.82, 0.84, 0.82, 1")
    for k, s in enumerate((-1, 1)):
        collider(f"TunnelPillar{k}", "Gate", (s * 4.1, 4.5, TUNNEL_Z - 1.0), (1.8, 9.0, 2.0))
        collider(f"TunnelSide{k}", "Gate", (s * 3.3, 2.5, TUNNEL_Z - 2.7), (0.6, 5.0, 1.4))
        inst(f"TunnelFlood{k}", "Gate", (s * 4.3, 9.1, TUNNEL_Z - 0.6), "floodlight")
        aim = basis_rot(math.pi - s * 0.35, pitch=-0.85)
        spot(f"TunnelFloodLight{k}", "Gate", (s * 4.3, 9.9, TUNNEL_Z - 0.2), aim, 5.0, 22.0, 38.0)
    collider("TunnelStop", "Gate", (0, 2.7, TUNNEL_Z - TUNNEL_STOP - 0.1), (6.0, 5.4, 0.2))
    lit("TunnelGlow", "Gate", (0, 3.5, TUNNEL_Z - 1.5), 2.5, 9.0, color=GREEN)


def build_gate() -> None:
    """The concrete Deploy gate at the north end (asset list G1-G4) with the Deploy board in front."""
    group("Gate")
    _gate_wall()
    _gate_tunnel()
    spot_mark = xform((0, 0, -35.5))
    nodes.append(f'[node name="DeployBoardSpot" type="Marker3D" parent="Gate"]\ntransform = {spot_mark}\n')
    nodes.append(
        '[node name="DeployBoard" parent="Gate/DeployBoardSpot" instance=ExtResource("deploy_board")]\n'
        'place = &"match"\nlabel = "Halcyon Labs"\n'
    )
    nodes.append('[node name="DeployVotePanel" parent="." instance=ExtResource("deploy_vote_panel")]\n')
    block("BannerPole", "Gate", (-5.6, 3.4, -34.6), (0.14, 6.8, 0.14), "iron")
    inst("CommonRoomBanner", "Gate", (-5.53 + BANNER_BACK, 2.1, -34.6), "banner", LODGE_YAW)


def _plaza_well() -> None:
    for wk, (dx, dz, sx, sz) in enumerate(
        [(0, -0.8, 1.9, 0.3), (0, 0.8, 1.9, 0.3), (-0.8, 0, 0.3, 1.3), (0.8, 0, 0.3, 1.3)]
    ):
        block(f"Well{wk}", "Props", (6 + dx, 0.45, 9 + dz), (sx, 0.9, sz), "town_stone")
    for s in (-1, 1):
        deco(f"WellPost{s + 1}", "Props", (6 + s * 0.85, 1.4, 9), (0.15, 1.9, 0.15), "town_dark_wood")
    deco("WellRoofA", "Props", (6, 2.45, 8.65), (2.2, 0.1, 0.9), "town_slate", basis_rot(pitch=0.5))
    deco("WellRoofB", "Props", (6, 2.45, 9.35), (2.2, 0.1, 0.9), "town_slate", basis_rot(pitch=-0.5))


def prop(name: str, parent: str, model: str, pos: tuple, yaw: float = 0.0) -> None:
    """A camp prop model with its box collider (PROP_BLOCKS), standing at `pos`."""
    inst(name, parent, pos, model, yaw)
    size = PROP_BLOCKS[model]
    collider(f"{name}Block", parent, (pos[0], pos[1] + size[1] / 2, pos[2]), size, yaw)


def _fires_and_benches() -> None:
    """Fire barrels (flames, flickering light) with benches round them, table lanterns on two benches."""
    for k, (x, z) in enumerate(FIRES):
        inst(f"FireBarrel{k}", "Props", (x, 0, z), "fire_barrel_scene")
        size = PROP_BLOCKS["fire_barrel"]
        collider(f"FireBarrel{k}Block", "Props", (x, size[1] / 2, z), size)
    for k, (x, z, yaw) in enumerate(BENCHES):
        prop(f"Bench{k}", "Props", "bench", (x, 0, z), yaw)
    for k, (x, z) in enumerate(TABLE_LANTERNS):
        inst(f"TableLantern{k}", "Props", (x, 0.5, z), "lantern_table")


def _crates() -> None:
    """Supply crates and ammo cases, the Fenlight sample crates with their stencil and a soft green glow."""
    for k, (model, x, y, z, yaw) in enumerate(CRATES):
        prop(f"Crate{k}", "Props", model, (x, y, z), yaw)
    for k, (x, z) in enumerate(FENLIGHT_CRATES):
        prop(f"FenlightBase{k}", "Props", "supply_crate_large", (x, 0, z), LODGE_YAW)
        inst(f"FenlightCrate{k}", "Props", (x, 0.8, z), "fenlight_crate", LODGE_YAW)
        label(f"FenlightStencil{k}", "Props", (x + 0.42, 0.4, z), LODGE_YAW, "FENLIGHT\\nSAMPLES", 36, STENCIL)
    mid_z = sum(z for _, z in FENLIGHT_CRATES) / len(FENLIGHT_CRATES)
    lit("FenlightGlow", "Props", (FENLIGHT_CRATES[0][0] + 0.3, 1.6, mid_z), 0.8, 3.5, color=GREEN)
    for k, (x, z, yaw) in enumerate(FIREWOOD):
        prop(f"Firewood{k}", "Props", "firewood_stack", (x, 0, z), yaw)


def build_props() -> None:
    group("Props")
    _plaza_well()
    _fires_and_benches()
    _crates()
    block("Cart", "Props", (-9.5, 0.75, 5.5), (1.4, 0.5, 2.4), "town_planks")
    for s in (-1, 1):
        deco(f"CartWheel{s + 1}", "Props", (-9.5 + s * 0.78, 0.45, 5.5), (0.08, 0.9, 0.9), "town_dark_wood")


def build_fences_and_signs() -> None:
    group("Fences")
    fk = 0
    for fz in range(-30, -2, 3):
        for sx in (-1, 1):
            if sx < 0 and fz < -21:
                continue  # the Common Room lodge stands there
            inst(f"Fence{fk}", "Fences", (sx * 15.5, 0, fz + 1.5), "fence_rail", math.pi / 2)
            fk += 1
    for fx in (-10.5, -7.5, -4.5, 4.5, 7.5, 10.5):
        inst(f"PlazaFence{fk}", "Fences", (fx, 0, 13.2), "fence_rail", 0.0)
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
    """One market stall facing the street: stall model, sign board with its name, dressing, light and colliders."""
    subtitle, model, dressing = STALLS[name]
    spec = STALL_MODELS[model]
    at = (STALL_X + spec["shift"], STALL_SOUTH_Z - (len(STALLS) - 1 - k) * STALL_PITCH)
    tag = name.capitalize()
    sign_y, sign_z = spec["sign"]
    inst(f"{tag}Stall", "Market", (at[0], 0, at[1]), model, LODGE_YAW)
    inst(f"{tag}Sign", "Market", _on_lodge(at, (0, sign_y, sign_z)), "stall_sign", LODGE_YAW)
    name_y = sign_y + (0.53 if subtitle else 0.41)
    label(f"{tag}SignName", "Market", _on_lodge(at, (0, name_y, sign_z + 0.08)), LODGE_YAW, name, 80)
    if subtitle:
        label(f"{tag}SignSub", "Market", _on_lodge(at, (0, sign_y + 0.21, sign_z + 0.08)), LODGE_YAW, subtitle, 40)
    for dress, spot, yaw in dressing:
        inst(f"{tag}{dress.title().replace('_', '')}", "Market", _on_lodge(at, spot), dress, LODGE_YAW + yaw)
    for b, (centre, size) in enumerate(spec["blocks"]):
        collider(f"{tag}Block{b}", "Market", _on_lodge(at, centre), size, LODGE_YAW)
    lit(f"{tag}Light", "Market", _on_lodge(at, (0, 2.3, sign_z + 0.6)), 1.8, 6.0)
    if spec["lantern"]:
        inst(f"{tag}Lantern", "Market", _on_lodge(at, spec["lantern"]), "lantern_hanging", LODGE_YAW)


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


def _watchtower_sweep() -> None:
    """The tower floodlight's beam sweeps between the gate and the street: an AnimationPlayer loop, no script."""
    pivot = xform(_on_east(TOWER, (1.3, 10.1, 2.5)), basis_rot(sum(SWEEP) / 2))
    nodes.append(f'[node name="WatchtowerSweep" type="Node3D" parent="Cabins"]\ntransform = {pivot}\n')
    spot("Beam", "Cabins/WatchtowerSweep", (0, 0, 0), basis_rot(pitch=-0.45), 6.0, 30.0, 14.0, moves=True)
    nodes.append(
        '[node name="Sweep" type="AnimationPlayer" parent="Cabins/WatchtowerSweep"]\n'
        'libraries = {\n&"": SubResource("sweep_library")\n}\nautoplay = &"sweep"\n'
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
    _watchtower_sweep()
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
    """Radio mast (G5) with red beacons on a snowy knoll north-east of the gate, and the falling snow."""
    group("Ridge")
    mx, mz = 21.0, -55.0
    deco("Knoll", "Ridge", (mx, 0.5, mz), (14, 3, 12), "town_snow", basis_rot(0.4))
    inst("RadioMast", "Ridge", (mx, 2.0, mz), "radio_mast", 0.4)
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


def build_lightmap() -> None:
    """Baked light for the static town (Halcyon Labs settings). Pines, fire flames and the sweep beam stay out.
    The bake's ambient is the look's ambient colour (lantern_post_night.tres), not the dark night sky."""
    nodes.append(
        '[node name="LightmapGI" type="LightmapGI" parent="."]\nquality = 2\ntexel_scale = 1.5\n'
        "environment_mode = 3\nenvironment_custom_color = Color(0.26, 0.3, 0.4, 1)\n"
        'environment_custom_energy = 0.75\nlight_data = ExtResource("lightmap")\n'
    )


SWEEP_ANIMATION = (
    '[sub_resource type="Animation" id="sweep"]\nresource_name = "sweep"\nlength = 14.0\nloop_mode = 1\n'
    'tracks/0/type = "value"\ntracks/0/imported = false\ntracks/0/enabled = true\n'
    'tracks/0/path = NodePath(".:rotation")\ntracks/0/interp = 2\ntracks/0/loop_wrap = true\n'
    'tracks/0/keys = {\n"times": PackedFloat32Array(0, 7, 14),\n"transitions": PackedFloat32Array(1, 1, 1),\n'
    f'"update": 0,\n"values": [Vector3(0, {fmt(SWEEP[0])}, 0), Vector3(0, {fmt(SWEEP[1])}, 0), '
    f"Vector3(0, {fmt(SWEEP[0])}, 0)]\n}}\n\n"
    '[sub_resource type="AnimationLibrary" id="sweep_library"]\n_data = {\n&"sweep": SubResource("sweep")\n}\n'
)


def header() -> str:
    ext = [
        '[ext_resource type="Script" path="res://systems/level/level.gd" id="level"]',
        '[ext_resource type="Script" path="res://systems/level/block.gd" id="block"]',
        '[ext_resource type="Environment" path="res://levels/looks/lantern_post_night.tres" id="look"]',
    ]
    ext += [f'[ext_resource type="PackedScene" path="res://assets/models/town/{sc}.glb" id="{sc}"]' for sc in SCENES]
    ext += [
        f'[ext_resource type="PackedScene" path="res://assets/models/town/{sc}.glb" id="{sc}"]'
        for sc in MARKET + GATE + CAMP
    ]
    ext += [
        f'[ext_resource type="PackedScene" path="res://assets/models/town_large/{sc}.glb" id="{sc}"]' for sc in LARGE
    ]
    ext += [f'[ext_resource type="Material" path="res://levels/materials/{m}.tres" id="{m}"]' for m in MATS]
    ext.append('[ext_resource type="PackedScene" path="res://systems/hub/deploy_board.tscn" id="deploy_board"]')
    ext.append(
        '[ext_resource type="PackedScene" path="res://systems/hub/deploy_vote_panel.tscn" id="deploy_vote_panel"]'
    )
    ext.append(
        '[ext_resource type="PackedScene" path="res://levels/lantern_post/fire_barrel.tscn" id="fire_barrel_scene"]'
    )
    for fx in ("snowfall", "chimney_smoke"):
        ext.append(f'[ext_resource type="PackedScene" path="res://levels/lantern_post/{fx}.tscn" id="{fx}"]')
    ext.append(
        '[ext_resource type="LightmapGIData" path="res://levels/lantern_post/lantern_post.lmbake" id="lightmap"]'
    )
    subs = [
        f'[sub_resource type="BoxMesh" id="{mesh}_{mat}"]\nmaterial = ExtResource("{mat}")\nadd_uv2 = true\n'
        for mesh, mat in sorted(used)
    ]
    subs += [f'[sub_resource type="BoxShape3D" id="{key}"]\nsize = {size}\n' for key, size in sorted(shapes.items())]
    subs.append(SWEEP_ANIMATION)
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
    build_lightmap()
    return header() + "\n".join(nodes)


def main() -> None:
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else SCENE
    out.write_text(build())
    print(len(nodes), "nodes;", counts, "shadows left", shadow_budget[0])


if __name__ == "__main__":
    main()
