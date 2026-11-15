#!/usr/bin/env python3
"""Check imported hand, sleeve and cuff triangles against actual weapon geometry.

Export first with Godot's focused GUT runner (see character_contact_export.gd),
then run this in the asset Python environment: python tools/check_character_contacts.py /tmp/character-contacts
"""

from __future__ import annotations

import argparse
import collections
import json
from pathlib import Path

import bpy  # noqa: F401 -- initialise Blender before importing its BVH implementation.
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from mathutils.kdtree import KDTree

GROUPS = (
    *(f"{bone}_{side}" for bone in ("clavicle", "upperarm", "forearm", "hand") for side in ("R", "L")),
    "cuffs",
)


def _assemble(meshes, group=None):
    vertices, triangles, labels = [], [], []
    for mesh in meshes:
        offset = len(vertices)
        vertices.extend(mesh["vertices"])
        for index, triangle in enumerate(mesh["triangles"]):
            label = mesh["labels"][index] if "labels" in mesh else mesh["name"]
            if group is None or label == group:
                triangles.append([vertex + offset for vertex in triangle])
                labels.append(label)
    return vertices, triangles, labels


def _blender(point):
    return [point[0], -point[2], point[1]]


def _root(parents, index):
    while parents[index] != index:
        parents[index] = parents[parents[index]]
        index = parents[index]
    return index


def _mesh_edges(vertices, triangles):
    canonical = {}
    welded = []
    for point in vertices:
        key = tuple(round(axis * 1000000) for axis in point)
        welded.append(canonical.setdefault(key, len(canonical)))
    edges = collections.defaultdict(list)
    for index, triangle in enumerate(triangles):
        for side in range(3):
            first, second = triangle[side], triangle[(side + 1) % 3]
            edges[tuple(sorted((welded[first], welded[second])))].append((index, first, second))
    return edges, welded


def _pair_seams(points, edges):
    """Match whole boundary edges across compressed material surfaces, without collapsing small edges."""
    singles = [(key, entries[0]) for key, entries in edges.items() if len(entries) == 1]
    tree = KDTree(len(singles))
    for index, (_key, (_face, first, second)) in enumerate(singles):
        tree.insert((points[first] + points[second]) / 2, index)
    tree.balance()
    matches = {}
    for index, (_key, (_face, first, second)) in enumerate(singles):
        candidates = []
        for _point, other, _distance in tree.find_range((points[first] + points[second]) / 2, 0.00001):
            if other == index:
                continue
            _other_key, (_other_face, left, right) = singles[other]
            error = min(
                max((points[first] - points[left]).length, (points[second] - points[right]).length),
                max((points[first] - points[right]).length, (points[second] - points[left]).length),
            )
            if error < 0.00001:
                candidates.append(other)
        if len(candidates) == 1:
            matches[index] = candidates[0]
    for index, other in matches.items():
        if index < other and matches.get(other) == index:
            edges[singles[index][0]].extend(edges.pop(singles[other][0]))


def _convex_pairs(entries, welded, planes):
    """Separate touching solids at a shared rim using consistent clockwise inward face normals."""
    matches = {}
    for face, first, second in entries:
        candidates = []
        normal, center = planes[face]
        for other, left, right in entries:
            if face == other or welded[first] != welded[right] or welded[second] != welded[left]:
                continue
            other_normal, other_center = planes[other]
            offset = other_center - center
            if normal.dot(offset) > 1e-9 and other_normal.dot(-offset) > 1e-9:
                candidates.append(other)
        if len(candidates) == 1:
            matches[face] = candidates[0]
    return [(face, other) for face, other in matches.items() if matches.get(other) == face]


def _stitched_vertices(points, edges, parents):
    """Build a quantization-seam proxy for containment; exact collision geometry stays unchanged."""
    joints = list(range(len(points)))
    for entries in edges.values():
        pieces = collections.defaultdict(list)
        for face, first, second in entries:
            pieces[_root(parents, face)].append((first, second))
        for pair in pieces.values():
            if len(pair) != 2:
                continue
            (first, second), (left, right) = pair
            direct = (points[first] - points[left]).length + (points[second] - points[right]).length
            reverse = (points[first] - points[right]).length + (points[second] - points[left]).length
            if reverse < direct:
                left, right = right, left
            joints[_root(joints, first)] = _root(joints, left)
            joints[_root(joints, second)] = _root(joints, right)
    sums, counts = collections.defaultdict(Vector), collections.Counter()
    for index, point in enumerate(points):
        joint = _root(joints, index)
        sums[joint] += point
        counts[joint] += 1
    return [sums[_root(joints, index)] / counts[_root(joints, index)] for index in range(len(points))]


def _connected_parts(vertices, triangles):
    points = [Vector(point) for point in vertices]
    edges, welded = _mesh_edges(vertices, triangles)
    _pair_seams(points, edges)
    planes = []
    for first, second, third in triangles:
        normal = (points[second] - points[first]).cross(points[third] - points[first]).normalized()
        planes.append((normal, (points[first] + points[second] + points[third]) / 3))
    parents = list(range(len(triangles)))
    for entries in edges.values():
        if len(entries) == 2:
            parents[_root(parents, entries[0][0])] = _root(parents, entries[1][0])
            continue
        source_edges = collections.defaultdict(list)
        for face, first, second in entries:
            source_edges[tuple(sorted((first, second)))].append(face)
        pairs = [faces for faces in source_edges.values() if len(faces) == 2]
        for first, second in pairs + _convex_pairs(entries, welded, planes):
            parents[_root(parents, first)] = _root(parents, second)
    groups = collections.defaultdict(list)
    for index, triangle in enumerate(triangles):
        groups[_root(parents, index)].append(triangle)
    counts = collections.defaultdict(list)
    for entries in edges.values():
        for group, count in collections.Counter(_root(parents, face) for face, _first, _second in entries).items():
            counts[group].append(count)
    return groups, counts, _stitched_vertices(points, edges, parents)


def _closed_parts(vertices, triangles):
    """Only closed connected pieces enclose volume; every piece still participates in crossings."""
    groups, counts, stitched = _connected_parts(vertices, triangles)
    closed, open_count = [], 0
    for group, faces in groups.items():
        if any(count != 2 for count in counts[group]):
            open_count += 1
            continue
        used = sorted({index for face in faces for index in face})
        if any((Vector(vertices[index]) - stitched[index]).length > 0.00001 for index in used):
            open_count += 1
            continue
        indices = {index: local for local, index in enumerate(used)}
        points = [stitched[index] for index in used]
        local_faces = [[indices[index] for index in face] for face in faces]
        low = tuple(min(point[axis] for point in points) for axis in range(3))
        high = tuple(max(point[axis] for point in points) for axis in range(3))
        closed.append((low, high, BVHTree.FromPolygons(points, local_faces, all_triangles=True)))
    return closed, open_count


def _inside_part(tree, point):
    """Parity is independent of the imported triangle winding; three rays avoid edge ambiguity."""
    votes = 0
    for axis in ((1, 0.371, 0.529), (-0.277, 1, 0.613), (0.419, -0.233, 1)):
        direction, origin, hits = Vector(axis).normalized(), point.copy(), 0
        for _step in range(100):
            hit, _normal, _face, _distance = tree.ray_cast(origin, direction, 5.0)
            if hit is None:
                break
            hits += 1
            origin = hit + direction * 0.000001
        else:
            raise ValueError("Contact containment ray did not leave the weapon mesh")
        votes += hits % 2 == 1
    return votes >= 2


def _enclosed(parts, point):
    return any(
        all(low[axis] <= point[axis] <= high[axis] for axis in range(3)) and _inside_part(tree, point)
        for low, high, tree in parts
    )


def _samples(vertices, triangles):
    used = {index for triangle in triangles for index in triangle}
    points = [vertices[index] for index in used]
    points += [sum((vertices[index] for index in triangle), Vector()) / 3 for triangle in triangles]
    edges = {tuple(sorted((triangle[i], triangle[(i + 1) % 3]))) for triangle in triangles for i in range(3)}
    return points + [(vertices[first] + vertices[second]) / 2 for first, second in edges]


def _clearance(points, tree, labels, parts):
    minimum, closest, enclosed = float("inf"), None, 0
    for point in points:
        _nearest, _normal, face, distance = tree.find_nearest(point)
        # Check each closed solid, preserving hollow trigger wells and overlapping parts.
        if _enclosed(parts, point):
            distance = -distance
            enclosed += 1
        if distance < minimum:
            minimum = distance
            closest = {"point_blender": _blender(point), "gun_part": labels[face]}
    return {"min_sampled_mm": minimum * 1000, "enclosed_samples": enclosed, "closest": closest}


def _inspect_group(meshes, group, weapon):
    vertices, triangles, _labels = _assemble(meshes, None if group == "cuffs" else group)
    if not triangles:
        return None
    points = [Vector(point) for point in vertices]
    tree, labels, parts = weapon
    overlaps = BVHTree.FromPolygons(points, triangles, all_triangles=True).overlap(tree)
    examples = [
        {
            "point_blender": _blender(sum((points[i] for i in triangles[first]), Vector()) / 3),
            "gun_part": labels[second],
        }
        for first, second in overlaps[:30]
    ]
    return {
        "triangles": len(triangles),
        "intersection_pairs": len(overlaps),
        "intersection_parts": dict(collections.Counter(labels[second] for _first, second in overlaps)),
        "intersection_examples": examples,
        "embedded_weapon_samples": 0,
        "embedded_weapon_examples": [],
        **_clearance(_samples(points, triangles), tree, labels, parts),
    }


def _embedded_weapon(snapshot, vertices, triangles, groups):
    """A small trigger or fastener entirely inside a glove need not cross its outer triangles."""
    cuffs = [{**mesh, "labels": ["cuffs"] * len(mesh["triangles"])} for mesh in snapshot["cuffs"]]
    arm_vertices, arm_triangles, labels = _assemble(snapshot["arms"] + cuffs)
    parts, open_count = _closed_parts(arm_vertices, arm_triangles)
    tree = BVHTree.FromPolygons(arm_vertices, arm_triangles, all_triangles=True)
    for point in _samples([Vector(vertex) for vertex in vertices], triangles):
        if not _enclosed(parts, point):
            continue
        _nearest, _normal, face, _distance = tree.find_nearest(point)
        group = groups[labels[face]]
        group["embedded_weapon_samples"] += 1
        if len(group["embedded_weapon_examples"]) < 10:
            group["embedded_weapon_examples"].append(_blender(point))
    return open_count


def inspect_contacts(snapshot):
    """Return finite triangle intersections, containment and measured surface clearances."""
    unexpected = {label for mesh in snapshot["arms"] for label in mesh["labels"]} - set(GROUPS)
    if unexpected:
        raise ValueError(f"Unexpected arm triangle labels: {sorted(unexpected)}")
    vertices, triangles, labels = _assemble(snapshot["weapon_meshes"])
    if not triangles:
        raise ValueError("Contact export contains no weapon triangles")
    # Godot renders clockwise front faces; mathutils expects counter-clockwise outward winding.
    tree = BVHTree.FromPolygons(
        vertices, [(first, third, second) for first, second, third in triangles], all_triangles=True
    )
    parts, open_count = _closed_parts(vertices, triangles)
    groups = {}
    for group in GROUPS:
        meshes = snapshot["cuffs"] if group == "cuffs" else snapshot["arms"]
        result = _inspect_group(meshes, group, (tree, labels, parts))
        if result is not None:
            groups[group] = result
    if not groups:
        raise ValueError("Contact export contains no arm or cuff triangles")
    open_arm_parts = _embedded_weapon(snapshot, vertices, triangles, groups)
    return {
        "weapon": snapshot["weapon"],
        "phase": snapshot["phase"],
        "weapon_triangles": len(triangles),
        "closed_weapon_parts": len(parts),
        "open_weapon_parts": open_count,
        "open_arm_parts": open_arm_parts,
        "morphs": {key: value for key, value in snapshot["morph_weights"].items() if abs(value) > 1e-8},
        "groups": groups,
    }


def _report(result):
    failures = []
    if result["open_weapon_parts"] or result["open_arm_parts"]:
        label = f"{result['weapon']} {result['phase']}: open components make containment inconclusive"
        print(label)
        failures.append(label)
    for group, values in result["groups"].items():
        label = f"{result['weapon']} {result['phase']} {group}"
        print(
            f"{label}: {values['intersection_pairs']} intersections, {values['enclosed_samples']} enclosed samples, "
            f"{values['embedded_weapon_samples']} embedded weapon samples, "
            f"{values['min_sampled_mm']:.3f} mm sampled clearance"
        )
        if values["intersection_pairs"] or values["enclosed_samples"] or values["embedded_weapon_samples"]:
            failures.append(label)
    return failures


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path, help="Directory written by character_contact_export.gd")
    args = parser.parse_args()
    paths = sorted(
        path for phase in ("hip", "ads", "shot_peak", "reload_mid") for path in args.directory.glob(f"*-{phase}.json")
    )
    if not paths:
        parser.error("No exported contact snapshots found")
    results, failures = [], []
    for path in paths:
        result = inspect_contacts(json.loads(path.read_text()))
        results.append(result)
        failures.extend(_report(result))
    (args.directory / "contact-report.json").write_text(json.dumps(results, indent=2) + "\n")
    print(f"Checked {len(results)} weapon poses; {len(failures)} contact or containment failures.")
    return bool(failures)


if __name__ == "__main__":
    raise SystemExit(main())
