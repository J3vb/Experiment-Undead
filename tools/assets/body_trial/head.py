"""Survivor head: a CC0 base head (MakeHuman) cut down to budget, with hair, beard and brows grown on it."""

import os

import bpy
import numpy as np
import surface as surf
from surface import bump, step

BASE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "base_head.obj")
SCALE = 0.098  # base mesh decimetres to our metres, sized so the crown sits at 1.80 m
BASE_EYE = (0.31, 7.285, 1.245)  # eye centre in the base mesh (x right, y up, z front)
BASE_EAR_Z = 0.477  # base depth that lands on our y = 0
EYE = (BASE_EYE[0] * SCALE, 1.682)
EYE_Y = -(BASE_EYE[2] - BASE_EAR_Z) * SCALE
EYE_RADIUS = 0.0134
SKIN_TRIANGLES = 3600
NECK_KEYS = (
    (1.46, 0, -0.016, 0.060, 0.058, 0.060, 2.0),
    (1.53, 0, -0.008, 0.055, 0.054, 0.056, 2.0),
    (1.60, 0, 0.004, 0.054, 0.056, 0.056, 2.0),
)
HAIRLINE_Y = (-0.11, -0.085, -0.06, -0.045, -0.03, -0.018, -0.008, 0.022, 0.035, 0.06, 0.11)
HAIRLINE_Z = (1.772, 1.770, 1.752, 1.712, 1.662, 1.662, 1.700, 1.702, 1.660, 1.600, 1.600)
CHEEK_X = (0.0, 0.018, 0.030, 0.042, 0.055, 0.066, 0.080)
CHEEK_Z = (1.637, 1.635, 1.625, 1.627, 1.645, 1.665, 1.673)
JAW_BACK_Z = (1.545, 1.57, 1.60, 1.63, 1.68)
JAW_BACK_Y = (0.040, 0.038, 0.022, 0.004, -0.006)


def _load_base() -> tuple:
    """Base head vertices in our space (metres, facing -Y) and its faces."""
    vertices, faces = [], []
    with open(BASE, encoding="utf-8") as lines:
        for line in lines:
            kind, *values = line.split() or ["#"]
            if kind == "v":
                vertices.append([float(value) for value in values])
            elif kind == "f":
                faces.append([int(value) - 1 for value in values])
    base = np.asarray(vertices)
    points = np.stack(
        [base[:, 0] * SCALE, -(base[:, 2] - BASE_EAR_Z) * SCALE, EYE[1] + (base[:, 1] - BASE_EYE[1]) * SCALE], axis=1
    )
    return points, faces


def _rugged(points: np.ndarray) -> np.ndarray:
    """The base head is a neutral average: give it a heavier brow and a wider jaw."""
    ax, y, z = np.abs(points[:, 0]), points[:, 1], points[:, 2]
    front = step(-y, 0.0, 0.05)
    points = points.copy()
    points[:, 0] *= 1 + 0.07 * front * bump(z, 1.60, 0.035)
    points[:, 1] -= 0.0035 * front * bump(z, 1.703, 0.008) * step(0.055 - ax, 0, 0.015)
    points[:, 1] -= 0.004 * front * bump(z, 1.578, 0.016) * bump(ax, 0, 0.03)
    return points


def _decimate(obj, triangles: int) -> None:
    """Collapse to a triangle count, mirrored left to right."""
    now = sum(len(face.vertices) - 2 for face in obj.data.polygons)
    modifier = obj.modifiers.new("Decimate", "DECIMATE")
    modifier.ratio, modifier.use_symmetry, modifier.symmetry_axis = triangles / now, True, "X"
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=modifier.name)


def neck_cover(points: np.ndarray) -> np.ndarray:
    """Above one half where the head is kept; the neck tube takes over below."""
    return step(points[:, 2] - 1.572 - 0.040 * step(points[:, 1], 0.0, 0.05), 0.0, 0.004)


def hair_cover(points: np.ndarray) -> np.ndarray:
    """0 to 1: how much short cropped hair grows at each point."""
    ax, y, z = np.abs(points[:, 0]), points[:, 1], points[:, 2]
    line = surf.spline(HAIRLINE_Y, np.asarray(HAIRLINE_Z)[:, None], y)[..., 0]
    return step(z - line, 0.0, 0.010) * step(0.079 - ax, 0, 0.004)


def beard_cover(points: np.ndarray) -> np.ndarray:
    """0 to 1: full beard and moustache with a gap for the lips."""
    ax, y, z = np.abs(points[:, 0]), points[:, 1], points[:, 2]
    cover = step(surf.spline(CHEEK_X, np.asarray(CHEEK_Z)[:, None], ax)[..., 0] - z, 0.0, 0.008)
    cover *= 1 - step(0.020 - ax, 0, 0.006) * step(z - 1.603, 0, 0.003) * step(1.6165 - z, 0, 0.002)
    cover *= step(surf.spline(JAW_BACK_Z, np.asarray(JAW_BACK_Y)[:, None], z)[..., 0] - y, 0.0, 0.012)
    return cover * step(z, 1.555, 0.006) * step(0.071 - ax, 0, 0.003)


def brow_cover(points: np.ndarray) -> np.ndarray:
    ax, y, z = np.abs(points[:, 0]), points[:, 1], points[:, 2]
    arch = 1.7035 - 0.004 * (ax - 0.012) / 0.04 + 0.003 * bump(ax, 0.03, 0.012)
    return bump(z, arch, 0.0034) * step(ax, 0.009, 0.004) * step(0.054 - ax, 0, 0.005) * step(-y, 0.03, 0.02)


def _hair_thick(points: np.ndarray) -> np.ndarray:
    y, z = points[:, 1], points[:, 2]
    return 0.010 + 0.005 * bump(y, -0.055, 0.04) * step(z, 1.745, 0.02)


def _beard_thick(points: np.ndarray) -> np.ndarray:
    ax, z = np.abs(points[:, 0]), points[:, 2]
    return 0.006 + 0.006 * step(1.60 - z, 0, 0.03) + 0.006 * bump(ax, 0, 0.03) * step(1.585 - z, 0, 0.02)


def _cut(mesh, cover: np.ndarray) -> tuple:
    """The part of a mesh where cover is above one half: points, normals, cover and faces."""
    points = [np.asarray(vertex.co[:]) for vertex in mesh.vertices]
    normals = [np.asarray(vertex.normal[:]) for vertex in mesh.vertices]
    covers = list(cover)
    cuts: dict = {}

    def cross(inside: int, outside: int) -> int:
        key = (inside, outside)
        if key not in cuts:
            at = (cover[inside] - 0.5) / (cover[inside] - cover[outside])
            points.append(points[inside] + (points[outside] - points[inside]) * at)
            normals.append(surf.unit(normals[inside] + (normals[outside] - normals[inside]) * at))
            covers.append(0.5)
            cuts[key] = len(points) - 1
        return cuts[key]

    faces = []
    for face in mesh.polygons:
        ring = []
        for here, after in zip(face.vertices, [*face.vertices[1:], face.vertices[0]], strict=True):
            if cover[here] > 0.5:
                ring.append(here)
            if (cover[here] > 0.5) != (cover[after] > 0.5):
                ring.append(cross(here, after) if cover[here] > 0.5 else cross(after, here))
        if len(ring) >= 3:
            faces.append(ring)
    return np.asarray(points), np.asarray(normals), np.asarray(covers), faces


def _grow(name, skin, cover: np.ndarray, thick, mat):
    """A shell of hair lifted off the skin, thinning out to a clean edge."""
    points, normals, covers, faces = _cut(skin.data, cover)
    lift = 0.0008 + np.resize(thick, len(points)) * np.clip(covers * 2 - 1, 0, 1)
    return surf._object(name, points + normals * lift[:, None], faces, mat)


def _points_of(obj) -> np.ndarray:
    return np.asarray([vertex.co[:] for vertex in obj.data.vertices])


def _bare(skin, covers: list) -> None:
    """Drop the skin triangles that sit fully under hair."""
    import bmesh

    hidden = np.max(covers, axis=0) > 0.75
    mesh = bmesh.new()
    mesh.from_mesh(skin.data)
    doomed = [face for face in mesh.faces if all(hidden[vertex.index] for vertex in face.verts)]
    bmesh.ops.delete(mesh, geom=doomed, context="FACES")
    mesh.to_mesh(skin.data)
    mesh.free()


def build_head(mats: dict) -> dict:
    """Returns {"skin": [...], "hair": [...], "eyes": [...]}: every part rides the head bone."""
    points, faces = _load_base()
    skin = surf._object("Head", _rugged(points), faces, mats["skin"])
    _decimate(skin, SKIN_TRIANGLES)
    points, _normals, _covers, faces = _cut(skin.data, neck_cover(_points_of(skin)))
    bpy.data.objects.remove(skin)
    skin = surf._object("Head", points, faces, mats["skin"])
    points = _points_of(skin)
    hair, beard, brow = hair_cover(points), beard_cover(points), brow_cover(points)
    hairs = [
        _grow("Hair", skin, hair, _hair_thick(points), mats["hair"]),
        _grow("Beard", skin, beard, _beard_thick(points), mats["hair"]),
        _grow("Brow", skin, brow, 0.0022, mats["hair"]),
    ]
    _bare(skin, [hair, beard])
    eyes = [
        surf.ball("Eyeball", (sign * EYE[0], EYE_Y, EYE[1]), (EYE_RADIUS,) * 3, mats["rubber"], (8, 5))
        for sign in (1, -1)
    ]
    return {"skin": [skin], "hair": hairs, "eyes": eyes}


def build_neck(mats: dict):
    tube = surf.Tube((0, 0, 0), (0, 0, 1), (1, 0, 0), NECK_KEYS)
    return surf.shell("Neck", tube.grid(surf.turns(14), (1.46, 1.50, 1.54, 1.575, 1.60)), mats["skin"])
