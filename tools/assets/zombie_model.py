"""Continuous infected bodies, torn laboratory clothing and shared character bones."""

import math

import bpy

# isort: split
import bmesh
import body_parts as soft
import character_rig as rig
import gear_paint as paint
import zombie_details
from mathutils import Matrix, Vector


def _materials():
    from build_models import material, srgb

    return {
        "head": material("ZombieSkinHead", srgb("#B9C2B0"), roughness=0.42),
        "skin": material("ZombieSkin", srgb("#8E9887"), roughness=0.4),
        "dark": material("ZombieSkinBloater", srgb("#4A5446"), roughness=0.36),
        "coat": material("ZombieClothCoat", srgb("#8A918C"), roughness=0.94),
        "shirt": material("ZombieClothShirt", srgb("#2F393B"), roughness=0.96),
        "trousers": material("ZombieClothTrousers", srgb("#1C2122"), roughness=0.96),
        "shoe": material("ZombieShoe", srgb("#0E1010"), roughness=0.72),
        "decay": material("ZombieSkinDecay", srgb("#5A0E0C"), roughness=0.72),
        "glow": material("ZombieGlow", srgb("#8DFF3A"), roughness=0.28, glow=0.6),
    }


def _nodes(kind):
    swollen = kind == "bloater"
    nodes = [(None, (0, 0, 0.99), (0.22 if swollen else 0.126, 0.15 if swollen else 0.085))]
    for z, rx, ry in (
        (1.09, 0.34 if swollen else 0.105, 0.28 if swollen else 0.073),
        (1.26, 0.37 if swollen else 0.16, 0.27 if swollen else 0.092),
        (1.43, 0.29 if swollen else 0.18, 0.20 if swollen else 0.082),
        (1.53, 0.065, 0.064),
        (1.61, 0.075, 0.08),
        (1.70, 0.108, 0.103),
        (1.81, 0.078, 0.08),
    ):
        nodes.append((len(nodes) - 1, (0, 0, z), (rx, ry)))
    for sign in (-1, 1):
        parent = 3
        for x, z, radius in (
            (0.23, 1.46, 0.084),
            (0.33, 1.34, 0.060),
            (0.41, 1.25, 0.043),
            (0.49, 1.17, 0.052),
            (0.60, 1.06, 0.031),
            (0.65, 1.01, 0.036),
        ):
            nodes.append((parent, (sign * x, 0, z), (radius * (1.4 if swollen else 1), radius)))
            parent = len(nodes) - 1
        parent = 0
        legs = (
            ((0.90, 0.083), (0.78, 0.076))
            if kind == "crawler"
            else ((0.89, 0.099), (0.72, 0.086), (0.53, 0.058), (0.39, 0.066), (0.20, 0.039), (0.09, 0.038))
        )
        for z, radius in legs:
            nodes.append((parent, (sign * 0.11, 0, z), (radius * (1.35 if swollen else 1), radius)))
            parent = len(nodes) - 1
    return nodes


def _bind(obj, armature, bone=None):
    paint.zone(obj, paint.ZONE_MAIN)
    if bone:
        rig.bind_rigid(obj, armature, bone)
    else:
        rig.bind(obj, armature, blend=0.13)
    return obj


def _body(armature, mats, kind):
    obj = soft.skin_body(_nodes(kind), mats["dark" if kind == "bloater" else "skin"])
    obj.name = "Body"
    if kind == "shambler":
        modifier = obj.modifiers.new("Gaunt surface topology", "DECIMATE")
        modifier.ratio = 0.70
        soft.select(obj)
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    soft.clean(obj)
    for name in ("head", "shirt", "trousers", "decay"):
        obj.data.materials.append(mats[name])
    for face in obj.data.polygons:
        point = sum((obj.data.vertices[i].co for i in face.vertices), Vector()) / len(face.vertices)
        if point.z > 1.57:
            face.material_index = 1
        elif point.z < 0.99:
            face.material_index = 3
        elif abs(point.x) < 0.21 and point.z < 1.47 and kind != "bloater":
            face.material_index = 2
    _decay_faces(obj, kind)
    zombie_details.carve_mouth(obj, mats)
    _bind(obj, armature)
    if kind == "bloater":
        _swollen_weights(obj)
    return obj


def _swollen_weights(obj):
    for vertex in obj.data.vertices:
        if 1.0 < vertex.co.z < 1.46 and abs(vertex.co.x) < 0.38:
            vertex.co.y *= 1.45
            for group in obj.vertex_groups:
                group.remove([vertex.index])
            obj.vertex_groups["spine_01" if vertex.co.z < 1.2 else "spine_02"].add([vertex.index], 1.0, "REPLACE")


def _decay_faces(obj, kind):
    """Broad asymmetric abrasions use existing body faces instead of floating decals."""
    for face in obj.data.polygons:
        point = face.center
        forearm = 0.46 < point.x < 0.59 and point.y < -0.022 and 1.07 < point.z < 1.2
        cheek = -0.075 < point.x < -0.035 and point.y < -0.065 and 1.64 < point.z < 1.68
        stump = kind == "crawler" and point.z < 0.80
        if forearm or cheek or stump:
            face.material_index = 4


def _cloth(name, grid, holes, mat):
    """Sewn shell with actual missing cells, irregular edges and a closed torn thickness."""
    rows, columns = len(grid), len(grid[0])
    vertices = [p for row in grid for p in row]
    vertices += [(x * 0.97, y * 0.97, z + 0.002) for x, y, z in vertices[:]]
    offset, faces, edges = rows * columns, [], {}
    for row in range(rows - 1):
        for col in range(columns - 1):
            if (row, col) in holes:
                continue
            a = row * columns + col
            face = (a, a + 1, a + 1 + columns, a + columns)
            faces += [face, tuple(i + offset for i in reversed(face))]
            for i, j in zip(face, (*face[1:], face[0]), strict=True):
                edge = tuple(sorted((i, j)))
                edges[edge] = edges.get(edge, 0) + 1
    for (i, j), uses in edges.items():
        if uses == 1:
            faces.append((i, j, j + offset, i + offset))
    return soft.mesh(name, vertices, faces, mat)


def _coat_grid(kind):
    swollen = kind == "bloater"
    grid = []
    for row in range(11):
        t = min(row / 9, 1.0)
        z = 0.57 + 0.92 * t
        width = (0.30 - 0.12 * t + 0.06 * t**6) if not swollen else (0.29 + 0.16 * math.sin(t * math.pi))
        depth = (0.17 - 0.045 * t) if not swollen else (0.24 + 0.12 * math.sin(t * math.pi))
        if row == 10:
            z, width, depth = 1.535, 0.078, 0.074
        ring = []
        for col in range(25):
            angle = -math.pi / 2 + 0.44 + (2 * math.pi - 0.88) * col / 24
            hem = (0.025 * math.sin(col * 2.8) + 0.045 * (col % 4 == 0)) * (1 - t) ** 5
            folds = 0.009 * math.sin(col * 2.4 + t * 0.8)
            stagger = 0.013 * math.sin(col * 2.1 + row) if 0 < row < 8 else 0.0
            ring.append(((width + folds) * math.cos(angle), (depth + folds) * math.sin(angle), z + hem + stagger))
        grid.append(ring)
    return grid


def _shoulder_weights(coat):
    """Let the shoulder cloth follow the arm while the hanging coat stays on the spine."""
    groups = {side: coat.vertex_groups.new(name="upperarm_" + side) for side in ("L", "R")}
    for vertex in coat.data.vertices:
        across = max(0.0, min(0.85, (abs(vertex.co.x) - 0.12) / 0.16))
        high = max(0.0, min(1.0, (vertex.co.z - 1.32) / 0.14))
        weight = across * high
        if weight <= 0.0:
            continue
        existing = [(group.group, group.weight) for group in vertex.groups]
        for index, value in existing:
            coat.vertex_groups[index].add([vertex.index], value * (1 - weight), "REPLACE")
        groups["L" if vertex.co.x > 0 else "R"].add([vertex.index], weight, "REPLACE")


def _coat(armature, mats, kind):
    swollen = kind == "bloater"
    grid = _coat_grid(kind)
    holes = {(1, 3), (2, 3), (0, 9), (0, 10), (3, 17), (4, 17), (1, 21)}
    coat = _cloth("CoatSkirt", grid, holes, mats["shirt" if swollen else "coat"])
    deform = {bone: bone.use_deform for bone in armature.data.bones}
    for bone in deform:
        bone.use_deform = bone.name.startswith(("pelvis", "spine_", "neck"))
    _bind(coat, armature)
    _shoulder_weights(coat)
    for bone, enabled in deform.items():
        bone.use_deform = enabled
    for sign in (-1, 1):
        points = [(sign * 0.16, 0, 1.49), (sign * 0.22, 0, 1.46), (sign * 0.29, 0, 1.39), (sign * 0.36, 0, 1.31)]
        sleeve = soft.torn_sleeve("RippedSleeve", points, [0.058, 0.085, 0.074, 0.06], mats["coat"])
        _bind(sleeve, armature)
        lapel = soft.loft(
            "FoldedLapel",
            [
                [(sign * x, y, z) for x, y, z in ((0.055, -0.103, 1.50), (0.13, -0.13, 1.41), (0.16, -0.122, 1.25))],
                [
                    (sign * x, y - 0.008, z)
                    for x, y, z in ((0.055, -0.103, 1.50), (0.13, -0.13, 1.41), (0.16, -0.122, 1.25))
                ],
            ],
            mats["coat"],
        )
        _bind(lapel, armature, "spine_02")
    pocket = soft.pad("SaggingPocket", (0.085, 0.018, 0.10), (0.14, -0.114, 1.31), mats["coat"], 0.006)
    _bind(pocket, armature, "spine_02")


def _aim(armature, name, direction):
    bone = armature.pose.bones[name]
    bpy.context.view_layer.update()
    rotation = (bone.tail - bone.head).rotation_difference(Vector(direction)).to_matrix().to_4x4()
    bone.matrix = Matrix.Translation(bone.head) @ rotation @ Matrix.Translation(-bone.head) @ bone.matrix
    bpy.context.view_layer.update()


def _rest_pose(armature, kind):
    """Bake the reaching/prone rest shape while keeping all shared names and parents."""
    if kind == "crawler":
        pelvis = armature.pose.bones["pelvis"]
        pivot = pelvis.head.copy()
        pelvis.matrix = (
            Matrix.Translation((0, 0.35, -0.75))
            @ Matrix.Translation(pivot)
            @ Matrix.Rotation(1.2, 4, "X")
            @ Matrix.Translation(-pivot)
            @ pelvis.matrix
        )
        bpy.context.view_layer.update()
        _aim(armature, "head", (0, 0, 1))
    else:
        _aim(armature, "spine_01", (0, -0.12 if kind == "shambler" else -0.04, 1))
    for side, sign in (("L", 1), ("R", -1)):
        if kind == "crawler":
            upper, fore = (sign * 0.7, -0.55, -0.4), (-sign * 0.15, -0.65, -0.30)
        elif kind == "shambler":
            upper, fore = (sign * 0.35, -0.7, -0.5), (sign * 0.15, -0.85, -0.12)
        else:
            upper, fore = (sign * 0.85, -0.15, -0.55), (sign * 0.35, -0.35, -1)
        _aim(armature, "upperarm_" + side, upper)
        _aim(armature, "forearm_" + side, fore)
    markers = {o: o.matrix_world.copy() for o in bpy.context.scene.objects if o.type == "EMPTY"}
    objects = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    for obj in objects:
        soft.select(obj)
        bpy.ops.object.modifier_apply(modifier="Armature")
    soft.select(armature)
    bpy.ops.object.mode_set(mode="POSE")
    bpy.ops.pose.armature_apply(selected=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    for obj in objects:
        obj.modifiers.new("Armature", "ARMATURE").object = armature
    for obj, matrix in markers.items():
        obj.matrix_world = matrix


def _marker(armature, name, at, bone="head"):
    obj = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(obj)
    obj.parent, obj.parent_type, obj.parent_bone = armature, "BONE", bone
    bpy.context.view_layer.update()
    obj.matrix_world = Matrix.Translation(at)


def _finish_meshes(armature, kind):
    from build_models import join_into

    _rest_pose(armature, kind)
    if kind == "crawler":
        coat = bpy.data.objects["CoatSkirt"]
        for vertex in coat.data.vertices:
            if vertex.co.y > 0.32:
                vertex.co.z = max(0.008, vertex.co.z - (vertex.co.y - 0.32) * 0.6)
    for obj in bpy.context.scene.objects:
        if obj.type == "MESH":
            soft.clean(obj)
            if obj.name == "CoatSkirt":
                shell = bmesh.new()
                shell.from_mesh(obj.data)
                if shell.calc_volume(signed=True) < 0:
                    bmesh.ops.reverse_faces(shell, faces=shell.faces[:])
                    shell.to_mesh(obj.data)
                shell.free()
    detail = [
        o
        for o in bpy.context.scene.objects
        if o.type == "MESH"
        and o.name.startswith(("Ear", "Brow", "Nose", "Jaw", "Finger", "Mouth", "Cheek", "Palm", "Thumb"))
    ]
    join_into(detail[0], detail[1:])
    detail[0].name = "AnatomyDetails"
    clothing = [
        o
        for o in bpy.context.scene.objects
        if o.type == "MESH" and o.name.startswith(("RippedSleeve", "FoldedLapel", "SaggingPocket", "Badge"))
    ]
    join_into(bpy.data.objects["CoatSkirt"], clothing)
    bpy.context.view_layer.update()


def _build(kind):
    mats, armature = _materials(), rig.build_armature()
    if kind == "crawler":
        for bone in armature.data.bones:
            if bone.name.startswith(("thigh_", "shin_", "foot_")):
                bone.use_deform = False
        _marker(armature, "Crawler", (0, 0, 0.99), "pelvis")
    _body(armature, mats, kind)
    _coat(armature, mats, kind)
    zombie_details.build(armature, mats, kind, _bind)
    _marker(armature, "Eyes", (0, -0.095, 1.705))
    _marker(armature, "HeadCenter", (0, -0.015, 1.70))
    if kind == "bloater":
        belly = soft.ellipsoid("Belly", (0, -0.245, 1.15), (0.33, 0.235, 0.31), mats["glow"], (24, 16))
        _bind(belly, armature, "spine_01")
    for bone in armature.data.bones:
        bone.use_deform = not bone.name.startswith("sock_")
    _finish_meshes(armature, kind)


def build_shambler():
    """Gaunt worker, hanging torn coat, institutional clothes and one lost shoe."""
    _build("shambler")


def build_crawler():
    """Low dragging worker with a full skeleton and no leg mesh below its stumps."""
    _build("crawler")


def build_bloater():
    """Swollen silhouette with a rigid spine_01 glowing belly and small green eyes."""
    _build("bloater")
