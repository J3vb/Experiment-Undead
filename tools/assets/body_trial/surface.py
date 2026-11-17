"""Tube surfaces sampled from key rings: bodies, limbs, conforming patches and offset shells."""

import math

import bpy

# isort: split
# bpy must load before bmesh.
import bmesh
import numpy as np

SUNK = 0.004  # patches and shells start this far under the surface they sit on


def unit(vector) -> np.ndarray:
    vector = np.asarray(vector, dtype=float)
    return vector / np.linalg.norm(vector)


def spline(keys, values, at) -> np.ndarray:
    """Smooth curve through (keys, values) rows, sampled at `at`; ends are clamped."""
    keys, values, at = (np.asarray(item, dtype=float) for item in (keys, values, at))
    slopes = np.gradient(values, keys, axis=0)
    index = np.clip(np.searchsorted(keys, at) - 1, 0, len(keys) - 2)
    step = (keys[index + 1] - keys[index])[..., None]
    t = np.clip((at - keys[index])[..., None] / step, 0.0, 1.0)
    return (
        (2 * t**3 - 3 * t**2 + 1) * values[index]
        + (t**3 - 2 * t**2 + t) * step * slopes[index]
        + (-2 * t**3 + 3 * t**2) * values[index + 1]
        + (t**3 - t**2) * step * slopes[index + 1]
    )


def bump(value, centre, width) -> np.ndarray:
    """Gaussian falloff, 1 at the centre."""
    return np.exp(-(((value - centre) / width) ** 2))


def step(value, edge, soft) -> np.ndarray:
    """Smooth 0 to 1 switch around `edge`, `soft` wide."""
    t = np.clip((value - edge) / soft * 0.5 + 0.5, 0.0, 1.0)
    return t * t * (3 - 2 * t)


class Tube:
    """A straight-axis body part described by key rings.

    Each key row is (distance along the axis, side shift, front shift, half width,
    front depth, back depth, squareness). Squareness 2 is an ellipse, higher is boxier.
    Angle u is in turns: 0 is the front, 0.25 the `side` direction, 0.5 the back.
    """

    def __init__(self, origin, axis, side, keys):
        self.origin = np.asarray(origin, dtype=float)
        self.axis, self.side = unit(axis), unit(side)
        self.front = np.cross(self.side, self.axis)
        self.keys = np.asarray(keys, dtype=float)

    def base(self, u, s) -> np.ndarray:
        ring = spline(self.keys[:, 0], self.keys[:, 1:], s)
        shift_side, shift_front, half, front, back, square = (ring[..., i] for i in range(6))
        power = 2.0 / square
        sin, cos = np.sin(math.tau * u), np.cos(math.tau * u)
        across = np.sign(sin) * np.abs(sin) ** power * half + shift_side
        depth = np.sign(cos) * np.abs(cos) ** power * np.where(cos > 0, front, back) + shift_front
        return self.origin + s[..., None] * self.axis + across[..., None] * self.side + depth[..., None] * self.front

    def normals(self, u, s) -> np.ndarray:
        du, ds = 1e-4, 1e-4
        along = self.base(u, s + ds) - self.base(u, s - ds)
        around = self.base(u + du, s) - self.base(u - du, s)
        normal = np.cross(around, along)
        return normal / np.maximum(np.linalg.norm(normal, axis=-1, keepdims=True), 1e-12)

    def surface(self, u, s, lift=None) -> np.ndarray:
        """Points at (u, s); `lift(points, u, s)` moves them out along the normal, in metres."""
        u, s = np.broadcast_arrays(np.asarray(u, dtype=float), np.asarray(s, dtype=float))
        points = self.base(u, s)
        if lift is None:
            return points
        return points + self.normals(u, s) * np.asarray(lift(points, u, s))[..., None]

    def grid(self, around, along, lift=None) -> np.ndarray:
        """Rows of rings: shape (len(along), len(around), 3)."""
        u, s = np.meshgrid(np.asarray(around, dtype=float), np.asarray(along, dtype=float))
        return self.surface(u, s, lift)


def turns(count: int) -> np.ndarray:
    return np.arange(count) / count


def _object(name, vertices, faces, mat):
    data = bpy.data.meshes.new(name)
    data.from_pydata([tuple(map(float, v)) for v in vertices], [], faces)
    data.materials.append(mat)
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    work = bmesh.new()
    work.from_mesh(data)
    bmesh.ops.remove_doubles(work, verts=work.verts[:], dist=1e-6)
    bmesh.ops.dissolve_degenerate(work, edges=work.edges[:], dist=1e-6)
    bmesh.ops.delete(work, geom=[vertex for vertex in work.verts if not vertex.link_faces], context="VERTS")
    bmesh.ops.recalc_face_normals(work, faces=work.faces[:])
    work.to_mesh(data)
    work.free()
    for face in data.polygons:
        face.use_smooth = True
    return obj


def _grid_faces(rows: int, columns: int, start: int = 0, closed: bool = True) -> list:
    faces = []
    for row in range(rows - 1):
        for column in range(columns if closed else columns - 1):
            a = start + row * columns + column
            b = start + row * columns + (column + 1) % columns
            faces.append((a, b, b + columns, a + columns))
    return faces


def shell(name, rings, mat):
    """Closed shell through rings that go all the way round; flat caps close both ends."""
    rings = np.asarray(rings)
    rows, columns = rings.shape[:2]
    faces = _grid_faces(rows, columns)
    faces.append(tuple(range(columns)))
    faces.append(tuple(range((rows - 1) * columns, rows * columns)))
    return _object(name, rings.reshape(-1, 3), faces, mat)


def slab(name, top, bottom, mat):
    """Pad lid over a sunk outline: the top grid plus walls down to the border of `bottom`.

    It has no floor, because the floor would sit hidden inside the body it is sewn to.
    """
    top, bottom = np.asarray(top), np.asarray(bottom)
    rows, columns = top.shape[:2]
    count = rows * columns
    faces = _grid_faces(rows, columns, 0, False)
    border = (
        [(0, c) for c in range(columns)]
        + [(r, columns - 1) for r in range(1, rows)]
        + [(rows - 1, c) for c in range(columns - 2, -1, -1)]
        + [(r, 0) for r in range(rows - 2, 0, -1)]
    )
    for (r0, c0), (r1, c1) in zip(border, border[1:] + border[:1], strict=True):
        a, b = r0 * columns + c0, r1 * columns + c1
        faces.append((a, b, b + count, a + count))
    return _object(name, np.concatenate([top.reshape(-1, 3), bottom.reshape(-1, 3)]), faces, mat)


def _edge_ramp(samples: np.ndarray, rim: float) -> np.ndarray:
    """0.35 on the border row, 1 inside: a chamfered edge for pads."""
    return np.where((samples <= rim) | (samples >= 1 - rim), 0.35, 1.0)


def patch(name, tube, span, thick, mat, cells=(6, 6), lift=None, dip=None):
    """Sewn-on pad that follows a tube: span is (u0, u1, s0, s1), `dip(0..1)` shapes the s0 edge."""
    u0, u1, s0, s1 = span
    rim = 0.12
    across = np.unique(np.concatenate([[0, rim, 1 - rim, 1], np.linspace(rim, 1 - rim, cells[0])]))
    along = np.unique(np.concatenate([[0, rim, 1 - rim, 1], np.linspace(rim, 1 - rim, cells[1])]))
    un, sn = np.meshgrid(across, along)
    low = s0 + (dip(un) if dip else 0.0)
    u, s = u0 + (u1 - u0) * un, low + (s1 - low) * sn
    height = thick * np.minimum(_edge_ramp(un, rim * 0.5), _edge_ramp(sn, rim * 0.5))

    def raised(points, uu, ss):
        return (lift(points, uu, ss) if lift else 0.0) + height

    def sunk(points, uu, ss):
        return (lift(points, uu, ss) if lift else 0.0) - SUNK

    top = tube.surface(u, s, raised)
    obj = slab(name, top, tube.surface(u, s, sunk), mat)
    inner = (un > 0) & (un < 1) & (sn > 0) & (sn < 1)
    seam = inner & (np.isclose(un, rim) | np.isclose(un, 1 - rim) | np.isclose(sn, rim) | np.isclose(sn, 1 - rim))
    _mark_seam(obj, top[seam] if min(cells) > 1 else top[:0])  # narrow bands are all edge, no stitch row
    return obj


def _mark_seam(obj, points: np.ndarray) -> None:
    """Flag the stitched row just inside a pad's edge in the `hem` attribute, for the texture bake."""

    def key(point) -> tuple:
        return tuple(np.rint(np.asarray(point, dtype=float) * 1e4).astype(int))

    stitched = {key(point) for point in points}
    hem = obj.data.attributes.new("hem", "FLOAT", "POINT")
    for vertex, item in zip(obj.data.vertices, hem.data, strict=True):
        item.value = 1.0 if key(vertex.co) in stitched else 0.0


def sweep(name, path, radii, mat, sides=8, up=(0, 0, 1), closed=False):
    """Tube along a path with (across, up) radii per point: straps, rolls, laces, fingers."""
    path, radii = np.asarray(path, dtype=float), np.asarray(radii, dtype=float)
    if radii.ndim == 1:
        radii = np.stack([radii, radii], axis=1)
    ahead = np.roll(path, -1, axis=0) - np.roll(path, 1, axis=0)
    if not closed:
        ahead[0], ahead[-1] = path[1] - path[0], path[-1] - path[-2]
    rings = []
    for point, heading, (wide, tall) in zip(path, ahead, radii, strict=True):
        tangent = unit(heading)
        across = np.cross(tangent, up)
        across = unit(across if np.linalg.norm(across) > 0.1 else np.cross(tangent, (1, 0, 0)))
        other = np.cross(across, tangent)
        angles = math.tau * turns(sides)
        rings.append(point + np.outer(np.cos(angles), across) * wide + np.outer(np.sin(angles), other) * tall)
    rings = np.asarray(rings)
    if not closed:
        return shell(name, rings, mat)
    faces = _grid_faces(len(rings) + 1, sides)
    faces = [tuple(index % (len(rings) * sides) for index in face) for face in faces]
    return _object(name, rings.reshape(-1, 3), faces, mat)


def ball(name, centre, radii, mat, detail=(12, 8)):
    """Ellipsoid as a closed ring shell, so it needs no operator."""
    rings = []
    for row in range(1, detail[1]):
        polar = math.pi * row / detail[1]
        angles = math.tau * turns(detail[0])
        ring = np.stack(
            [np.cos(angles) * math.sin(polar), np.sin(angles) * math.sin(polar), np.full(detail[0], math.cos(polar))],
            axis=1,
        )
        rings.append(np.asarray(centre) + ring * np.asarray(radii))
    return shell(name, rings, mat)
