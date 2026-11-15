"""Finishing pass run on every built model just before export.

1. Normals: smooth by angle (35 degrees) plus a weighted-normal modifier, so
   flat faces stay flat, bevels catch light and cylinder caps stay crisp.
2. UVs: smart UV project per mesh, so later textures and bakes have clean,
   non-overlapping islands.
3. Shading mask: ambient occlusion baked with Cycles into a vertex colour,
   multiplied by a cavity (concave curvature) term. Godot multiplies albedo by
   it, so creases and contact spots darken without extra textures or draw calls.
"""

import math

import bpy

# isort: split
# bpy must load before bmesh.
import bmesh
from mathutils import Vector

SMOOTH_ANGLE = math.radians(35.0)
AO_SAMPLES = 64
AO_REACH = 0.08  # AO distance as a share of the model's largest size
AO_STRENGTH = 0.8  # 0 = no darkening, 1 = full baked AO
CAVITY_STRENGTH = 0.5  # how much the deepest crease darkens
COLOR_NAME = "Color"


def meshes() -> list:
    return [o for o in bpy.context.scene.objects if o.type == "MESH"]


def _select_only(obj) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def fix_normals(obj) -> None:
    _select_only(obj)
    bpy.ops.object.shade_smooth_by_angle(angle=SMOOTH_ANGLE, keep_sharp_edges=True)
    mod = obj.modifiers.new("Weighted", "WEIGHTED_NORMAL")
    mod.keep_sharp = True
    mod.weight = 50
    bpy.ops.object.modifier_apply(modifier=mod.name)


def unwrap(obj) -> None:
    _select_only(obj)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(66.0), island_margin=0.02)
    bpy.ops.object.mode_set(mode="OBJECT")


def _model_size(objs: list) -> float:
    lo = [math.inf] * 3
    hi = [-math.inf] * 3
    for obj in objs:
        for corner in obj.bound_box:
            world = obj.matrix_world @ Vector(corner)
            for i in range(3):
                lo[i] = min(lo[i], world[i])
                hi[i] = max(hi[i], world[i])
    return max(h - low for h, low in zip(hi, lo, strict=True))


def bake_ao(objs: list) -> None:
    """Bakes AO from all meshes (they shade each other) into each mesh's colour attribute."""
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = AO_SAMPLES
    scene.cycles.seed = 0
    if scene.world is None:
        scene.world = bpy.data.worlds.new("BakeWorld")
    scene.world.light_settings.distance = _model_size(objs) * AO_REACH
    for obj in objs:
        mesh = obj.data
        attr = mesh.color_attributes.get(COLOR_NAME) or mesh.color_attributes.new(COLOR_NAME, "FLOAT_COLOR", "CORNER")
        mesh.color_attributes.active_color = attr
        mesh.color_attributes.render_color_index = mesh.color_attributes.active_color_index
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objs:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.bake(type="AO", target="VERTEX_COLORS")


def cavity(mesh) -> list:
    """Per vertex 0..1: how deep a crease it sits in (0 = flat or convex edge)."""
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bm.normal_update()
    out = [0.0] * len(bm.verts)
    for v in bm.verts:
        if not v.link_edges:
            continue
        bend = 0.0
        for e in v.link_edges:
            d = (e.other_vert(v).co - v.co).normalized()
            bend += d.dot(v.normal)
        out[v.index] = max(0.0, min(1.0, bend / len(v.link_edges) * 2.0))
    bm.free()
    return out


def _glows(obj) -> bool:
    for mat in obj.data.materials:
        bsdf = mat.node_tree.nodes.get("Principled BSDF") if mat and mat.node_tree else None
        if bsdf is None or bsdf.inputs["Emission Strength"].default_value <= 0.0:
            return False
    return bool(obj.data.materials)


def apply_mask(obj) -> None:
    """Softens the baked AO, multiplies in cavity, and keeps glowing parts unshaded."""
    mesh = obj.data
    attr = mesh.color_attributes[COLOR_NAME]
    glow = _glows(obj)
    cav = cavity(mesh)
    for loop in mesh.loops:
        if glow:
            value = 1.0
        else:
            ao = attr.data[loop.index].color[0]
            value = (1.0 - AO_STRENGTH + AO_STRENGTH * ao) * (1.0 - CAVITY_STRENGTH * cav[loop.vertex_index])
        attr.data[loop.index].color = (value, value, value, 1.0)


def finish() -> None:
    objs = meshes()
    for obj in objs:
        fix_normals(obj)
        unwrap(obj)
    bake_ao(objs)
    for obj in objs:
        apply_mask(obj)
