"""Fenlight growth (plan F-68 step 2): vines that climb walls, wrap tanks and hang from ceilings,
with glowing pods, and the spill mound where a tank broke. Visual-only dressing, same rules as
prop_models.py. Vines use the `Vine` slot, pods the `Fluid` slot (the specimen tank glow).
"""

import math
import random

import bmesh
import bpy
import prop_models as p
from mathutils import Vector

SIDES = 5


def _mats() -> dict:
    from build_models import material, srgb

    return {"vine": material("Vine", srgb("#2A3320"), roughness=0.55), "pod": p._mats()["fluid"]}


def _ring(centre: Vector, tangent: Vector, radius: float) -> list:
    side = tangent.cross(Vector((0.0, 0.0, 1.0)))
    if side.length < 1e-4:
        side = tangent.cross(Vector((1.0, 0.0, 0.0)))
    side.normalize()
    up = side.cross(tangent).normalized()
    out = []
    for i in range(SIDES):
        a = 2.0 * math.pi * i / SIDES
        out.append(centre + (side * math.cos(a) + up * math.sin(a)) * radius)
    return out


def _tube(name: str, points: list, r0: float, r1: float, mat):
    """Closed tube along `points`, tapering from radius r0 to r1."""
    bm = bmesh.new()
    rings = []
    count = len(points)
    for i, point in enumerate(points):
        a = Vector(points[max(i - 1, 0)])
        b = Vector(points[min(i + 1, count - 1)])
        radius = r0 + (r1 - r0) * i / (count - 1)
        rings.append([bm.verts.new(v) for v in _ring(Vector(point), (b - a).normalized(), radius)])
    for i in range(count - 1):
        for j in range(SIDES):
            k = (j + 1) % SIDES
            bm.faces.new((rings[i][j], rings[i][k], rings[i + 1][k], rings[i + 1][j]))
    bm.faces.new(list(reversed(rings[0])))
    bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    for face in bm.faces:
        face.smooth = True
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    return obj


def _pod(name: str, at: tuple, radius: float, mat) -> None:
    bpy.ops.mesh.primitive_uv_sphere_add(segments=8, ring_count=5, radius=radius, location=at)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = (1.0, 1.0, 1.25)
    obj.data.materials.append(mat)


def _leaf(name: str, at: tuple, size: float, mat) -> None:
    """Low-poly clump of leaves (squashed icosphere)."""
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=size, location=at)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = (1.4, 0.55, 1.0)
    obj.data.materials.append(mat)


def _climb(rng: random.Random, x: float, height: float, lean: float) -> list:
    """A stem that wanders up a wall at depth y 0..0.12 (the wall is behind, at +y)."""
    points = []
    steps = max(4, int(height / 0.35))
    for i in range(steps + 1):
        t = i / steps
        wiggle = math.sin(t * 7.0 + x * 3.0) * 0.12 + rng.uniform(-0.05, 0.05)
        points.append((x + lean * t + wiggle, 0.06 + math.sin(t * 5.0 + x) * 0.05, t * height))
    return points


def _wall_vine(seed: int, width: float, height: float, pods: int) -> None:
    rng = random.Random(seed)
    m = _mats()
    trunks = []
    for i, (x, h) in enumerate(((-width * 0.18, height), (width * 0.22, height * 0.8))):
        trunks.append(_climb(rng, x, h, rng.uniform(-0.25, 0.25)))
        _tube(f"Trunk{i}", trunks[-1], 0.09, 0.02, m["vine"])
    tips = []
    for i in range(5):
        trunk = trunks[i % 2]
        x, y, z = trunk[int(len(trunk) * (0.2 + 0.15 * i))]
        side = -1.0 if i % 2 == 0 else 1.0
        reach = rng.uniform(0.35, width * 0.45)
        points = [
            (x + side * reach * t, y + 0.01 * t, z + reach * 0.6 * t + math.sin(t * 3.0) * 0.08)
            for t in (0.0, 0.33, 0.66, 1.0)
        ]
        _tube(f"Branch{i}", points, 0.04, 0.012, m["vine"])
        tips.append(points[-1])
    _tube("Root", [(-width / 2, 0.08, 0.05), (0.0, 0.0, 0.08), (width / 2, 0.08, 0.04)], 0.08, 0.05, m["vine"])
    for i in range(8):
        stem = trunks[i % 2] if i < 6 else [tips[i - 6]]
        x, y, z = stem[int(len(stem) * rng.uniform(0.25, 0.95))]
        _leaf(f"Leaf{i}", (x + rng.uniform(-0.1, 0.1), y - 0.02, z), rng.uniform(0.1, 0.16), m["vine"])
    for i in range(pods):
        x, y, z = tips[i % len(tips)] if i % 2 == 0 else trunks[i % 2][int(len(trunks[i % 2]) * 0.6)]
        _pod(f"Pod{i}", (x, y - 0.08, z), rng.uniform(0.07, 0.11), m["pod"])


def build_vine_wall() -> None:
    """Fenlight vine climbing a wall, about 1.6 x 0.25 x 2.6, back against Godot -Z."""
    _wall_vine(11, 1.6, 2.6, 4)
    p._merge("VineWall")


def build_vine_wall_small() -> None:
    """Small wall vine, about 0.9 x 0.25 x 1.5, back against Godot -Z."""
    _wall_vine(23, 0.9, 1.5, 2)
    p._merge("VineWallSmall")


def build_vine_pillar() -> None:
    """Vine wrapping a 0.6 m radius tank or pipe, 2.4 m tall, with pods."""
    rng = random.Random(37)
    m = _mats()
    for s in range(3):
        start = s * 2.1
        points = []
        for i in range(13):
            t = i / 12
            a = start + t * 4.2
            points.append((0.64 * math.cos(a), 0.64 * math.sin(a), 0.03 + t * 2.4 * rng.uniform(0.8, 1.0)))
        _tube(f"Wrap{s}", points, 0.085, 0.02, m["vine"])
        _leaf(f"Leaf{s}", points[3 + s * 2], 0.14, m["vine"])
        x, y, z = points[6 + s]
        _pod(f"Pod{s}", (x * 1.08, y * 1.08, z), 0.08, m["pod"])
    p._merge("VinePillar")


def build_vine_ceiling() -> None:
    """Strands hanging 1.25 m from a ceiling with pods at the tips. Hang its top at the ceiling."""
    rng = random.Random(41)
    m = _mats()
    top = 1.25
    _tube(
        "Runner",
        [(-1.0, -0.3, top), (-0.2, 0.1, top - 0.03), (0.5, -0.1, top), (1.0, 0.3, top - 0.02)],
        0.05,
        0.04,
        m["vine"],
    )
    for i in range(5):
        x = -0.85 + i * 0.42
        y = rng.uniform(-0.3, 0.3)
        length = rng.uniform(0.6, 1.2) if i != 2 else 1.2
        points = [
            (x + math.sin(t * 2.0) * 0.08, y + math.cos(t * 3.0) * 0.05, top - t * length)
            for t in (0.0, 0.2, 0.4, 0.6, 0.8, 1.0)
        ]
        _tube(f"Strand{i}", points, 0.05, 0.015, m["vine"])
        if i % 2 == 0:
            x, y, z = points[-1]
            _pod(f"Pod{i}", (x, y, max(z, 0.1)), 0.07, m["pod"])
    p._merge("VineCeiling")


def build_fenlight_spill() -> None:
    """Fenlight mound where a tank broke: a low root mat with clustered glowing pods. About 1.6 x 1.2 x 0.4."""
    rng = random.Random(53)
    m = _mats()
    p._blob("Mat", 0.6, (0.0, 0.0, 0.0), m["vine"], squash=(1.3, 0.95, 0.22))
    for i in range(6):
        a = i * math.pi / 3 + rng.uniform(-0.3, 0.3)
        reach = rng.uniform(0.7, 0.95)
        _tube(
            f"Root{i}",
            [(0.3 * math.cos(a), 0.25 * math.sin(a), 0.1), (reach * math.cos(a), 0.75 * reach * math.sin(a), 0.03)],
            0.04,
            0.012,
            m["vine"],
        )
    for i in range(5):
        a = i * 2.4
        _pod(f"Pod{i}", (0.3 * math.cos(a), 0.22 * math.sin(a), 0.14), rng.uniform(0.08, 0.13), m["pod"])
    p._merge("FenlightSpill")


MODELS = {
    "vine_wall": ("dressing/vine_wall.glb", build_vine_wall),
    "vine_wall_small": ("dressing/vine_wall_small.glb", build_vine_wall_small),
    "vine_pillar": ("dressing/vine_pillar.glb", build_vine_pillar),
    "vine_ceiling": ("dressing/vine_ceiling.glb", build_vine_ceiling),
    "fenlight_spill": ("dressing/fenlight_spill.glb", build_fenlight_spill),
}
