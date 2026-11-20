"""Turns a rigged Tripo zombie into the Crawler (F-86 step 2): legs cut off at mid-thigh and capped, the thigh
stumps skinned to the pelvis, the leg bones kept but not deforming, and the body laid prone with the arms reaching
forward, the rest pose ZombieRig's crawl poses expect (as the code-built Crawler had it).
"""

import bmesh
import bpy

# isort: split
import tripo_rig
from mathutils import Matrix, Vector

LEGS = ("thigh_", "shin_", "foot_")
ARMS = ("upperarm_", "forearm_", "hand_")
# Where along the thigh (hip 0, knee 1) the legs are cut.
CUT = 0.5
# Prone rest (the old code-built Crawler's numbers): the pelvis tips forward and drops; the arms reach out on the floor.
TIP = 1.2
SHIFT = Vector((0.0, 0.35, 0.0))
UPPER_ARM = Vector((0.7, -0.55, -0.4))
FOREARM = Vector((-0.15, -0.65, -0.30))
# The lowest skinned point rests this high above the floor.
FLOOR_GAP = 0.01


def _dominant(obj, vertex) -> str:
    best = max(vertex.groups, key=lambda item: item.weight, default=None)
    return obj.vertex_groups[best.group].name if best else ""


def _against_rim(face, caps) -> bool:
    """True when a cap winds the same way as the body face it meets, so its normal points into the leg."""
    for loop in face.loops:
        other = next((lp for lp in loop.edge.link_loops if lp.face not in caps), None)
        if other is not None:
            return other.vert == loop.vert
    return False


def _slivers(edge_of_cut: set) -> list:
    """Loose bits the cut left behind: face islands whose every vertex sat next to a deleted one."""
    seen, doomed = set(), []
    for start in edge_of_cut:
        if start in seen:
            continue
        island, todo = {start}, [start]
        while todo:
            vert = todo.pop()
            for other in {o for face in vert.link_faces for o in face.verts}:
                if other not in island:
                    island.add(other)
                    todo.append(other)
        seen |= island
        if island <= edge_of_cut:
            doomed += island
    return doomed


def cut_legs(arm, low) -> float:
    """Deletes the leg below mid-thigh (never the hands), caps the hole; returns the cut height."""
    bones = arm.data.bones
    cut = min(bones[f"thigh_{s}"].head_local.lerp(bones[f"thigh_{s}"].tail_local, CUT).z for s in "LR")
    doomed = {v.index for v in low.data.vertices if v.co.z < cut and not _dominant(low, v).startswith(ARMS)}
    mesh = bmesh.new()
    mesh.from_mesh(low.data)
    mesh.verts.ensure_lookup_table()
    uv = mesh.loops.layers.uv.active
    assert uv is not None, "Tripo meshes carry UVs; the caps copy them from the rim"
    doomed_verts = [mesh.verts[i] for i in doomed]
    edge_of_cut = {o for v in doomed_verts for e in v.link_edges for o in e.verts} - set(doomed_verts)
    bmesh.ops.delete(mesh, geom=doomed_verts, context="VERTS")
    bmesh.ops.delete(mesh, geom=_slivers(edge_of_cut), context="VERTS")
    rim = [e for e in mesh.edges if e.is_valid and e.is_boundary and all(v in edge_of_cut for v in e.verts)]
    caps = bmesh.ops.holes_fill(mesh, edges=rim, sides=0)["faces"]
    bmesh.ops.reverse_faces(mesh, faces=[face for face in caps if _against_rim(face, caps)])
    for face in caps:
        for loop in face.loops:
            other = next((lp for lp in loop.vert.link_loops if lp.face not in caps), None)
            if other is not None:
                loop[uv].uv = other[uv].uv
    mesh.to_mesh(low.data)
    mesh.free()
    return cut


def stumps_on_pelvis(arm, low) -> None:
    """Moves every leg weight onto the pelvis and stops the leg bones deforming."""
    pelvis = low.vertex_groups["pelvis"]
    legs = {g.index: g for g in low.vertex_groups if g.name.startswith(LEGS)}
    for vertex in low.data.vertices:
        moved = sum(item.weight for item in vertex.groups if item.group in legs)
        if moved > 0.0:
            mine = next((item.weight for item in vertex.groups if item.group == pelvis.index), 0.0)
            pelvis.add([vertex.index], mine + moved, "REPLACE")
    for group in legs.values():
        low.vertex_groups.remove(group)
    for bone in arm.data.bones:
        if bone.name.startswith(LEGS):
            bone.use_deform = False


def _lowest(low) -> float:
    evaluated = low.evaluated_get(bpy.context.evaluated_depsgraph_get())
    return min((evaluated.matrix_world @ v.co).z for v in evaluated.data.vertices)


def lay_prone(arm, low) -> None:
    """Poses the body prone, rests its lowest point on the floor, then keeps that pose as the mesh and rest."""
    pelvis = arm.pose.bones["pelvis"]
    pivot = pelvis.head.copy()
    tip = Matrix.Translation(pivot) @ Matrix.Rotation(TIP, 4, "X") @ Matrix.Translation(-pivot)
    pelvis.matrix = Matrix.Translation(SHIFT) @ tip @ pelvis.matrix
    bpy.context.view_layer.update()
    tripo_rig.aim(arm, arm.pose.bones["head"], Vector((0.0, 0.0, 1.0)))
    for side, sign in (("L", 1.0), ("R", -1.0)):
        flip = Vector((sign, 1.0, 1.0))
        tripo_rig.aim(arm, arm.pose.bones[f"upperarm_{side}"], UPPER_ARM * flip)
        tripo_rig.aim(arm, arm.pose.bones[f"forearm_{side}"], FOREARM * flip)
    drop = _lowest(low) - FLOOR_GAP
    pelvis.matrix = Matrix.Translation((0.0, 0.0, -drop)) @ pelvis.matrix
    bpy.context.view_layer.update()
    markers = {o: o.matrix_world.copy() for o in bpy.context.scene.objects if o.type == "EMPTY"}
    bpy.context.view_layer.objects.active = low
    bpy.ops.object.modifier_apply(modifier=next(m.name for m in low.modifiers if m.type == "ARMATURE"))
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="POSE")
    bpy.ops.pose.armature_apply(selected=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    low.modifiers.new("Armature", "ARMATURE").object = arm
    for obj, matrix in markers.items():
        obj.matrix_world = matrix


def make(arm, low) -> object:
    """The whole crawler pass; returns the `Crawler` marker ZombieRig looks for."""
    cut_legs(arm, low)
    stumps_on_pelvis(arm, low)
    marker = bpy.data.objects.new("Crawler", None)
    bpy.context.collection.objects.link(marker)
    marker.parent, marker.parent_type, marker.parent_bone = arm, "BONE", "pelvis"
    bpy.context.view_layer.update()
    marker.matrix_world = Matrix.Translation(arm.data.bones["pelvis"].head_local)
    lay_prone(arm, low)
    return marker
