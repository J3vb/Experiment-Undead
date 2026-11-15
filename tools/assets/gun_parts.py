"""Shape tools for detailed guns: side profiles, turned parts and rail teeth.

Guns read as real guns mostly from their side silhouette and their round parts.
`slab` extrudes a side outline (points in Y forward, Z up) across X, `lathe`
turns a radius profile around the Y axis. Both return a plain mesh object with
the material set, like `box` and `cylinder` in build_models.py.
"""

import itertools
import math

import bpy

# isort: split
# bpy must load before bmesh.
import bmesh


def _object(name: str, bm, mat, parent):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.data.materials.append(mat)
    obj.parent = parent
    return obj


def _bevel(obj, width: float) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    mod = obj.modifiers.new("Bevel", "BEVEL")
    mod.width = width
    mod.segments = 2
    mod.limit_method = "ANGLE"
    mod.use_clamp_overlap = True
    mod.harden_normals = not bpy.context.scene.get("unfinished", False)
    bpy.ops.object.modifier_apply(modifier=mod.name)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.dissolve_degenerate(bm, edges=bm.edges[:], dist=1e-5)
    bm.to_mesh(obj.data)
    bm.free()


def slab(name: str, outline: list, width: float, mat, x: float = 0.0, bevel: float = 0.0, parent=None):
    """Extrudes the side `outline` [(y, z), ...] to a part `width` thick, centred on `x`."""
    bm = bmesh.new()
    face = bm.faces.new([bm.verts.new((x - width / 2, y, z)) for y, z in outline])
    geom = bmesh.ops.extrude_face_region(bm, geom=[face])["geom"]
    moved = [v for v in geom if isinstance(v, bmesh.types.BMVert)]
    bmesh.ops.translate(bm, vec=(width, 0.0, 0.0), verts=moved)
    obj = _object(name, bm, mat, parent)
    if bevel > 0.0:
        _bevel(obj, bevel)
    return obj


def lathe(
    name: str, profile: list, at: tuple, mat, segments: int = 24, parent=None, axis: str = "y", turn: float = 0.0
):
    """Turns `profile` [(radius, along), ...] around `axis` through `at`. Ends are capped.
    `turn` rotates the ring start (radians), so an 8-sided part can sit flat side up."""
    bm = bmesh.new()
    rings = []
    for radius, along in profile:
        ring = []
        for i in range(segments):
            a = turn + 2 * math.pi * i / segments
            u, v = radius * math.cos(a), radius * math.sin(a)
            local = {"y": (u, along, v), "x": (along, u, v), "z": (u, v, along)}[axis]
            ring.append(bm.verts.new(tuple(p + q for p, q in zip(local, at, strict=True))))
        rings.append(ring)
    for a, b in itertools.pairwise(rings):
        for i in range(segments):
            j = (i + 1) % segments
            bm.faces.new((a[i], a[j], b[j], b[i]))
    bm.faces.new(rings[0])
    bm.faces.new(rings[-1])
    return _object(name, bm, mat, parent)


def teeth(start: float, end: float, low: float, high: float, pitch: float = 0.01) -> list:
    """Side outline of a toothed accessory rail from `start` to `end` (Y), base `low`, tops `high`."""
    points = [(start, low)]
    y = start
    while y + pitch <= end + 1e-6:
        gap = pitch * 0.45
        points += [(y, high), (y + pitch - gap, high), (y + pitch - gap, low + (high - low) * 0.35)]
        points += [(y + pitch, low + (high - low) * 0.35)]
        y += pitch
    points.append((y, low))
    return points


def rounded(y0: float, z0: float, y1: float, z1: float, r: float, steps: int = 3) -> list:
    """Outline of a rectangle with rounded corners (slots, plates, buttons)."""
    corners = [(y1 - r, z0 + r, -90), (y1 - r, z1 - r, 0), (y0 + r, z1 - r, 90), (y0 + r, z0 + r, 180)]
    points = []
    for cy, cz, start in corners:
        for i in range(steps + 1):
            a = math.radians(start + 90 * i / steps)
            point = (cy + r * math.cos(a), cz + r * math.sin(a))
            if not points or math.dist(point, points[-1]) > 1e-6:
                points.append(point)
    if math.dist(points[0], points[-1]) <= 1e-6:
        points.pop()
    return points


def cut(obj, cutters: list):
    """Subtracts closed world-space cutters, consuming them while keeping the target's pivot and parent."""
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.context.view_layer.update()
    for cutter in cutters:
        modifier = obj.modifiers.new("Machined", "BOOLEAN")
        modifier.operation = "DIFFERENCE"
        modifier.solver = "EXACT"
        modifier.object = cutter
        bpy.ops.object.modifier_apply(modifier=modifier.name)
        bpy.data.objects.remove(cutter, do_unlink=True)
    mesh = bmesh.new()
    mesh.from_mesh(obj.data)
    bmesh.ops.dissolve_degenerate(mesh, edges=mesh.edges[:], dist=1e-5)
    bmesh.ops.recalc_face_normals(mesh, faces=mesh.faces[:])
    bmesh.ops.triangulate(mesh, faces=mesh.faces[:])
    mesh.to_mesh(obj.data)
    mesh.free()
    return obj


def mark_inlay(obj):
    """Marks the last-built strip with alpha zero, initializing this gun's unpainted meshes to alpha one."""
    for part in bpy.context.scene.objects:
        if part.type != "MESH" or part.data.color_attributes.get("Color") is not None:
            continue
        colors = part.data.color_attributes.new("Color", "FLOAT_COLOR", "CORNER")
        for color in colors.data:
            color.color = (1.0, 1.0, 1.0, 1.0)
    for color in obj.data.color_attributes["Color"].data:
        color.color[3] = 0.0
    return obj
