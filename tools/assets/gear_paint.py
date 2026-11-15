"""Paint gear zones into Color alpha while RGB carries baked ambient occlusion."""

import math

ZONE_MAIN = 1.0
ZONE_ACCENT = 0.667
ZONE_TRIM = 0.333
ZONE_GLOW = 0.0
ZONES = (ZONE_MAIN, ZONE_ACCENT, ZONE_TRIM, ZONE_GLOW)


def zone(obj, zone_value: float, faces=None) -> None:
    """Paint all faces, or selected polygon indices, without changing their RGB."""
    if zone_value not in ZONES:
        raise ValueError(f"unknown gear zone {zone_value}")
    mesh = obj.data
    attr = mesh.color_attributes.get("Color")
    if attr is None:
        attr = mesh.color_attributes.new("Color", "FLOAT_COLOR", "CORNER")
        for color in attr.data:
            color.color = (1.0, 1.0, 1.0, ZONE_MAIN)
    if attr.domain != "CORNER":
        raise ValueError("Color must use the CORNER domain to paint individual faces")
    selected = mesh.polygons if faces is None else (mesh.polygons[getattr(f, "index", f)] for f in faces)
    for face in selected:
        for index in face.loop_indices:
            color = attr.data[index].color
            attr.data[index].color = (*color[:3], zone_value)


def _face_zone(mesh, attr, face) -> float:
    values = []
    for index in face.loop_indices:
        color_index = mesh.loops[index].vertex_index if attr.domain == "POINT" else index
        alpha = attr.data[color_index].color[3]
        nearest = min(ZONES, key=lambda value: abs(value - alpha))
        if not math.isfinite(alpha) or abs(nearest - alpha) > 0.005:
            raise ValueError(f"face {face.index} has an unknown zone alpha {alpha:.3f}")
        values.append(nearest)
    if len(set(values)) != 1:
        raise ValueError(f"face {face.index} mixes gear zones")
    return values[0]


def zone_shares(obj) -> dict:
    """Return each zone's fraction of world-space surface area; reject unpainted faces."""
    mesh = obj.data
    attr = mesh.color_attributes.get("Color")
    if attr is None:
        raise ValueError("every face needs a zone in Color alpha")
    if attr.domain not in {"CORNER", "POINT"}:
        raise ValueError("Color must use the CORNER or POINT domain")
    painted = [_face_zone(mesh, attr, face) for face in mesh.polygons]
    mesh.calc_loop_triangles()
    vertices = [obj.matrix_world @ vertex.co for vertex in mesh.vertices]
    areas = dict.fromkeys(ZONES, 0.0)
    for triangle in mesh.loop_triangles:
        a, b, c = (vertices[index] for index in triangle.vertices)
        areas[painted[triangle.polygon_index]] += (b - a).cross(c - a).length / 2.0
    total = sum(areas.values())
    if total <= 0.0:
        raise ValueError("mesh has no surface area")
    return {value: area / total for value, area in areas.items()}
