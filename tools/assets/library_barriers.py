"""Prop library family 1, barriers and checkpoint (plan F-77 step 2): jersey barrier, concrete block, sandbag
walls, boom barrier, chain-link fence and gate, razor-wire fence, hard case, jerrycans and a pallet stack.

Same rules as prop_models.py: one merged mesh per model, origin at its bottom centre, long side along x,
front facing Blender -Y (Godot +Z), and only prop_import.gd shared slot names as material names.
"""

import math
import random

import bmesh
import bpy
import prop_models as p

FENCE_LENGTH = 3.0
FENCE_HEIGHT = 2.0
MESH_SPACING = 0.15  # chain-link diamond size, big enough to read at range


def _mats() -> dict:
    from build_models import material, srgb

    return {
        "concrete": material("Concrete", srgb("#7F7F7A"), roughness=0.95),
        "hazard": material("TownHazard", srgb("#D99E14"), roughness=0.7),
        "dark": material("Dark", srgb("#1C2122"), roughness=0.8),
        "steel": material("Steel", srgb("#8A918C"), metallic=0.7, roughness=0.45),
        "paint": material("Paint", srgb("#5F6D68"), roughness=0.65),
        "iron": material("Iron", (0.012, 0.012, 0.014, 1.0), metallic=0.7, roughness=0.5),
        "rust": material("Olive", srgb("#59301A"), roughness=0.7),
        "wood": material("Wood", srgb("#734D2B"), roughness=0.85),
        "burlap": material("Burlap", srgb("#6A604A"), roughness=0.95),
        "beacon": material("Beacon", srgb("#C3201B"), roughness=0.3, glow=4.0),
    }


def _prism(name: str, profile: list, length: float, mat):
    """Extrudes a (y, z) outline along x, centred on x = 0: a closed shell with outward normals."""
    mesh = bpy.data.meshes.new(name)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    bm = bmesh.new()
    left = [bm.verts.new((-length / 2, y, z)) for y, z in profile]
    right = [bm.verts.new((length / 2, y, z)) for y, z in profile]
    bm.faces.new(left)
    bm.faces.new(right)
    count = len(profile)
    for i in range(count):
        j = (i + 1) % count
        bm.faces.new((left[i], left[j], right[j], right[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    mesh.materials.append(mat)
    return obj


def _rod(name: str, start: tuple, end: tuple, size: float, mat):
    """Square bar of `size` from `start` to `end` in the x-z plane (wires, tubes, braces)."""
    from build_models import box

    dx, dz = end[0] - start[0], end[2] - start[2]
    mid = ((start[0] + end[0]) / 2, (start[1] + end[1]) / 2, (start[2] + end[2]) / 2)
    bar = box(name, (math.hypot(dx, dz), size, size), mid, mat)
    bar.rotation_euler = (0, -math.atan2(dz, dx), 0)
    return bar


def _clip(c: float, slope: int, rect: tuple):
    """Part of the line z = slope * x + c inside rect (x0, x1, z0, z1), or None."""
    x0, x1, z0, z1 = rect
    pts = []
    for x in (x0, x1):
        z = slope * x + c
        if z0 <= z <= z1:
            pts.append((x, z))
    for z in (z0, z1):
        x = (z - c) / slope
        if x0 < x < x1:
            pts.append((x, z))
    if len(pts) < 2:
        return None
    a, b = min(pts), max(pts)
    return None if math.dist(a, b) < 0.02 else (a, b)


def _chain_link(prefix: str, rect: tuple, mat) -> None:
    """Diamond wire mesh filling rect (x0, x1, z0, z1) in the y = 0 plane."""
    x0, x1, z0, z1 = rect
    for slope, low, high in ((1, z0 - x1, z1 - x0), (-1, z0 + x0, z1 + x1)):
        steps = int((high - low) / MESH_SPACING)
        for k in range(1, steps + 1):
            seg = _clip(low + k * MESH_SPACING - MESH_SPACING / 2, slope, rect)
            if seg:
                (ax, az), (bx, bz) = seg
                _rod(f"{prefix}{slope}_{k}", (ax, 0, az), (bx, 0, bz), 0.008, mat)


def _bag(name: str, at: tuple, size: tuple, turn: float, mat):
    """One low-poly sandbag: a box with wide chamfered edges, smooth shaded so it reads as a soft bag."""
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=at)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    mod = obj.modifiers.new("Soft", "BEVEL")
    mod.width = size[2] * 0.4
    mod.segments = 1
    bpy.ops.object.modifier_apply(modifier=mod.name)
    obj.rotation_euler = (0, 0, turn)
    bpy.ops.object.shade_smooth()
    obj.data.materials.append(mat)
    return obj


def _bag_row(m: dict, prefix: str, start: tuple, along: tuple, count: int, z: float, rng) -> None:
    """`count` bags laid across the wall, stepping along `along` from `start`."""
    turn = math.atan2(along[1], along[0]) + math.pi / 2
    for k in range(count):
        at = (start[0] + along[0] * k, start[1] + along[1] * k, z)
        size = (0.58 * rng.uniform(0.94, 1.0), 0.34 * rng.uniform(0.95, 1.05), 0.18)
        _bag(f"{prefix}{k}", at, size, turn + rng.uniform(-0.08, 0.08), m["burlap"])


def build_jersey_barrier() -> None:
    """Concrete road barrier painted in yellow and black blocks, forklift slots in the foot. 2.0 x 0.6 x 0.8."""
    from build_models import box

    m = _mats()
    profile = [(-0.3, 0), (0.3, 0), (0.3, 0.08), (0.2, 0.25), (0.1, 0.8), (-0.1, 0.8), (-0.2, 0.25), (-0.3, 0.08)]
    _prism("Body", profile, 2.0, m["concrete"])
    lean = math.atan2(0.1, 0.55)
    for k in range(8):
        x = -0.875 + k * 0.25
        mat = m["hazard"] if k % 2 == 0 else m["dark"]
        for side in (-1, 1):
            band = box(f"Band{k}{side}", (0.25, 0.012, 0.5), (x, side * 0.156, 0.53), mat)
            band.rotation_euler = (side * lean, 0, 0)
        box(f"Top{k}", (0.25, 0.2, 0.012), (x, 0, 0.805), mat)
    for k, x in enumerate((-0.55, 0.55)):
        box(f"Slot{k}", (0.24, 0.62, 0.06), (x, 0, 0.03), m["dark"])
    p._merge("JerseyBarrier")


def build_concrete_block() -> None:
    """Interlocking concrete block with two top studs, a lifting loop and rusty rebar stubs. 1.6 x 0.8 x 0.8."""
    from build_models import box, limb

    m = _mats()
    box("Block", (1.6, 0.8, 0.8), (0, 0, 0.4), m["concrete"], bevel=0.03)
    for k, x in enumerate((-0.4, 0.4)):
        p._cyl(f"Stud{k}", 0.17, 0.1, (x, 0, 0.8), m["concrete"], verts=12)
    limb("LoopA", (-0.1, 0, 0.8), (-0.06, 0, 0.92), 0.012, m["iron"])
    limb("LoopB", (0.1, 0, 0.8), (0.06, 0, 0.92), 0.012, m["iron"])
    limb("LoopTop", (-0.07, 0, 0.92), (0.07, 0, 0.92), 0.012, m["iron"])
    for k, (x, y, lean) in enumerate(((0.82, -0.2, 0.3), (0.82, 0.15, -0.2))):
        limb(f"Rebar{k}", (0.79, y, 0.25 + k * 0.3), (x + 0.12, y + lean * 0.1, 0.28 + k * 0.3), 0.01, m["rust"])
    p._merge("ConcreteBlock")


def build_sandbag_wall() -> None:
    """Straight sandbag wall, five staggered rows of bags laid across it. 2.0 x 0.6 x 0.9."""
    m = _mats()
    rng = random.Random(21)
    for row in range(5):
        shift = 0.17 if row % 2 else 0.0
        count = 5 if row % 2 else 6
        _bag_row(m, f"Row{row}_", (-0.85 + shift, 0, 0), (0.34, 0), count, 0.1 + row * 0.17, rng)
    p._merge("SandbagWall")


def build_sandbag_corner() -> None:
    """L-shaped sandbag corner, two 1.6 m arms meeting at a square end. 1.6 x 1.6 x 0.9."""
    m = _mats()
    rng = random.Random(22)
    for row in range(5):
        z = 0.1 + row * 0.17
        x_first = row % 2 == 0
        _bag_row(m, f"X{row}_", (-0.5 if x_first else -0.16, -0.5, 0), (0.34, 0), 4 if x_first else 3, z, rng)
        _bag_row(m, f"Y{row}_", (-0.5, -0.16 if x_first else -0.5, 0), (0, 0.34), 3 if x_first else 4, z, rng)
    p._merge("SandbagCorner")


def build_boom_barrier() -> None:
    """Checkpoint boom: housing, 4 m yellow-black arm with a red tip lamp, counterweight, rest post. 4.8 x 0.4 x 1.1."""
    from build_models import box

    m = _mats()
    box("Housing", (0.45, 0.4, 0.9), (0, 0, 0.45), m["paint"], bevel=0.02)
    box("Cap", (0.5, 0.45, 0.05), (0, 0, 0.925), m["paint"], bevel=0.01)
    p._cyl("Hub", 0.09, 0.08, (0, -0.24, 0.95), m["dark"], verts=12).rotation_euler = (math.pi / 2, 0, 0)
    for k in range(8):
        mat = m["hazard"] if k % 2 == 0 else m["dark"]
        box(f"Arm{k}", (0.5, 0.08, 0.1), (0.3 + k * 0.5, -0.26, 1.0), mat, bevel=0.008)
    box("Counterweight", (0.35, 0.14, 0.22), (-0.35, -0.26, 1.0), m["dark"], bevel=0.015)
    box("Lamp", (0.06, 0.1, 0.06), (4.08, -0.26, 1.08), m["beacon"])
    box("RestPost", (0.08, 0.08, 0.9), (3.9, -0.26, 0.45), m["paint"])
    for side in (-1, 1):
        box(f"Fork{side}", (0.06, 0.02, 0.14), (3.9, -0.26 + side * 0.06, 0.97), m["paint"])
    box("RestFoot", (0.3, 0.3, 0.04), (3.9, -0.26, 0.02), m["paint"])
    p._merge("BoomBarrier")


def build_chain_link_fence() -> None:
    """3 m chain-link fence section on steel posts, top rail and bottom wire. 3.1 x 0.1 x 2.0."""
    m = _mats()
    half = FENCE_LENGTH / 2
    for k, x in enumerate((-half, half)):
        p._cyl(f"Post{k}", 0.035, FENCE_HEIGHT, (x, 0, 0), m["steel"], verts=8)
        p._cyl(f"PostCap{k}", 0.045, 0.04, (x, 0, FENCE_HEIGHT), m["dark"], verts=8)
    _rod("TopRail", (-half, 0, FENCE_HEIGHT - 0.05), (half, 0, FENCE_HEIGHT - 0.05), 0.04, m["steel"])
    _rod("BottomWire", (-half, 0, 0.06), (half, 0, 0.06), 0.012, m["steel"])
    _chain_link("Wire", (-half + 0.04, half - 0.04, 0.06, FENCE_HEIGHT - 0.07), m["steel"])
    p._merge("ChainLinkFence")


def build_chain_link_gate() -> None:
    """Closed chain-link gate: tube frame with a brace, hinges and a latch between two heavy posts. 2.4 x 0.1 x 2.1."""
    from build_models import box

    m = _mats()
    for k, x in enumerate((-1.1, 1.1)):
        p._cyl(f"Post{k}", 0.05, 2.1, (x, 0, 0), m["steel"], verts=10)
        p._cyl(f"PostCap{k}", 0.06, 0.04, (x, 0, 2.1), m["dark"], verts=10)
    x0, x1, z0, z1 = -1.0, 1.0, 0.08, 1.95
    _rod("FrameTop", (x0, 0, z1), (x1, 0, z1), 0.04, m["steel"])
    _rod("FrameBottom", (x0, 0, z0), (x1, 0, z0), 0.04, m["steel"])
    _rod("FrameL", (x0, 0, z0), (x0, 0, z1), 0.04, m["steel"])
    _rod("FrameR", (x1, 0, z0), (x1, 0, z1), 0.04, m["steel"])
    _rod("Brace", (x0, 0, z0), (x1, 0, z1), 0.03, m["steel"])
    _chain_link("Wire", (x0 + 0.03, x1 - 0.03, z0 + 0.03, z1 - 0.03), m["steel"])
    for k, z in enumerate((0.35, 1.7)):
        box(f"Hinge{k}", (0.12, 0.06, 0.06), (-1.05, 0, z), m["dark"])
    box("Latch", (0.14, 0.05, 0.1), (1.04, 0, 1.0), m["dark"])
    p._merge("ChainLinkGate")


def build_razor_wire_fence() -> None:
    """3 m fence of angle posts, four barbed strands and a razor-wire coil along the top. 3.1 x 0.6 x 2.3."""
    from build_models import box

    m = _mats()
    half = FENCE_LENGTH / 2
    for k, x in enumerate((-half, 0.0, half)):
        box(f"PostA{k}", (0.05, 0.008, 1.8), (x, -0.021, 0.9), m["steel"])
        box(f"PostB{k}", (0.008, 0.05, 1.8), (x - 0.021, 0, 0.9), m["steel"])
    for k in range(4):
        z = 0.3 + k * 0.42
        _rod(f"Strand{k}", (-half, 0, z), (half, 0, z), 0.008, m["steel"])
    count = 20
    for k in range(count):
        x = -half + 0.08 + k * (FENCE_LENGTH - 0.16) / (count - 1)
        tilt = 0.35 if k % 2 else -0.35
        bpy.ops.mesh.primitive_torus_add(
            major_radius=0.27,
            minor_radius=0.007,
            major_segments=10,
            minor_segments=3,
            location=(x, 0, 2.03),
            rotation=(0, math.pi / 2 + tilt, 0),
        )
        ring = bpy.context.active_object
        ring.name = f"Coil{k}"
        ring.data.materials.append(m["steel"])
    p._merge("RazorWireFence")


def build_hard_case() -> None:
    """Yellow hard equipment case with a ribbed lid, black handle and latches. 0.9 x 0.55 x 0.4."""
    from build_models import box

    m = _mats()
    box("Base", (0.9, 0.55, 0.24), (0, 0, 0.13), m["hazard"], bevel=0.03)
    box("Lid", (0.9, 0.55, 0.13), (0, 0, 0.32), m["hazard"], bevel=0.03)
    box("Seam", (0.91, 0.56, 0.02), (0, 0, 0.255), m["dark"])
    for k, x in enumerate((-0.2, 0.0, 0.2)):
        box(f"Rib{k}", (0.08, 0.45, 0.02), (x, 0, 0.395), m["hazard"], bevel=0.008)
    for k, x in enumerate((-0.3, 0.3)):
        box(f"Latch{k}", (0.07, 0.025, 0.08), (x, -0.285, 0.25), m["dark"])
    box("Handle", (0.22, 0.03, 0.035), (0, -0.295, 0.2), m["dark"], bevel=0.008)
    for k, x in enumerate((-0.38, 0.38)):
        box(f"Foot{k}", (0.06, 0.5, 0.02), (x, 0, 0.01), m["dark"])
    p._merge("HardCase")


def _jerrycan(m: dict, name: str, x: float, turn: float) -> None:
    """One 20 l can: pressed X on both faces, three top handles, a dark spout cap."""
    from build_models import box

    parts = [box(f"{name}Body", (0.35, 0.17, 0.44), (0, 0, 0.22), m["paint"], bevel=0.02)]
    for side in (-1, 1):
        for k, lean in enumerate((0.6, -0.6)):
            rib = box(f"{name}X{side}{k}", (0.03, 0.01, 0.42), (0, side * 0.088, 0.2), m["paint"])
            rib.rotation_euler = (0, lean, 0)
            parts.append(rib)
    for k, hx in enumerate((-0.09, 0.0, 0.09)):
        parts.append(box(f"{name}Handle{k}", (0.025, 0.05, 0.05), (hx, 0, 0.465), m["paint"]))
    parts.append(box(f"{name}Grip", (0.22, 0.05, 0.02), (0, 0, 0.495), m["paint"]))
    cap = p._cyl(f"{name}Cap", 0.025, 0.05, (0.14, 0, 0.44), m["dark"], verts=8)
    cap.rotation_euler = (0, 0.5, 0)
    parts.append(cap)
    for part in parts:
        bpy.context.view_layer.update()
        part.matrix_world = _turn_about(turn, x) @ part.matrix_world


def _turn_about(turn: float, x: float):
    from mathutils import Matrix

    return Matrix.Translation((x, 0, 0)) @ Matrix.Rotation(turn, 4, "Z")


def build_jerrycan_pair() -> None:
    """Two grey-green jerrycans side by side, one turned a little (dressing). 0.8 x 0.3 x 0.5."""
    m = _mats()
    _jerrycan(m, "CanA", -0.2, 0.0)
    _jerrycan(m, "CanB", 0.2, 0.25)
    p._merge("JerrycanPair")


def _pallet(m: dict, name: str, z: float, shift: tuple, turn: float) -> None:
    """One 1.2 x 0.8 m pallet: five top boards on nine blocks on three runners."""
    from build_models import box

    parts = []
    for k in range(5):
        y = -0.34 + k * 0.17
        parts.append(box(f"{name}Top{k}", (1.2, 0.12, 0.022), (0, y, z + 0.133), m["wood"]))
    for i, x in enumerate((-0.53, 0.0, 0.53)):
        for j, y in enumerate((-0.34, 0.0, 0.34)):
            parts.append(box(f"{name}Block{i}{j}", (0.14, 0.12, 0.078), (x, y, z + 0.083), m["wood"]))
    for j, y in enumerate((-0.34, 0.0, 0.34)):
        parts.append(box(f"{name}Runner{j}", (1.2, 0.12, 0.022), (0, y, z + 0.033), m["wood"]))
    for part in parts:
        bpy.context.view_layer.update()
        part.matrix_world = _turn_about(turn, shift[0]) @ part.matrix_world
        part.location.y += shift[1]


def build_pallet_stack() -> None:
    """Four wooden pallets stacked a little crooked. 1.3 x 0.9 x 0.6."""
    m = _mats()
    for k, (shift, turn) in enumerate(
        (((0, 0), 0.0), ((0.03, 0.02), 0.04), ((-0.02, 0.03), -0.03), ((0.04, -0.03), 0.06))
    ):
        _pallet(m, f"P{k}", k * 0.144, shift, turn)
    p._merge("PalletStack")


MODELS = {
    "jersey_barrier": ("props/jersey_barrier.glb", build_jersey_barrier),
    "concrete_block": ("props/concrete_block.glb", build_concrete_block),
    "sandbag_wall": ("props/sandbag_wall.glb", build_sandbag_wall),
    "sandbag_corner": ("props/sandbag_corner.glb", build_sandbag_corner),
    "boom_barrier": ("props/boom_barrier.glb", build_boom_barrier),
    "chain_link_fence": ("props/chain_link_fence.glb", build_chain_link_fence),
    "chain_link_gate": ("props/chain_link_gate.glb", build_chain_link_gate),
    "razor_wire_fence": ("props/razor_wire_fence.glb", build_razor_wire_fence),
    "hard_case": ("props/hard_case.glb", build_hard_case),
    "jerrycan_pair": ("dressing/jerrycan_pair.glb", build_jerrycan_pair),
    "pallet_stack": ("props/pallet_stack.glb", build_pallet_stack),
}
