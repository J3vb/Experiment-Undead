"""Five salvaged luck charms, with two articulated links and a hook-space origin."""

import math

import bpy
import gear_paint as paint
from body_parts import loft, mesh, pad
from gear_parts import engrave, outlined_plate, refine_face, strap
from gun_parts import lathe, rounded


def _materials():
    from build_models import material, srgb

    return {
        "plate": material("GearPlate", srgb("#8A918C"), metallic=0.75, roughness=0.48),
        "polymer": material("GearPolymer", srgb("#5F6D68"), roughness=0.64),
        "rubber": material("GearRubber", srgb("#1C2122"), roughness=0.82),
    }


def _paint(obj, value):
    paint.zone(obj, value)
    return obj


def _pad(name, size, at, mat, value=paint.ZONE_ACCENT):
    return _paint(pad(name, size, at, mat, min(size) * 0.2), value)


def _plate(name, size, at, mat, value=paint.ZONE_MAIN):
    width, depth, height = size
    bevel = min(depth * 0.25, width * 0.02)
    rings = []
    for y, inset in ((-depth / 2, bevel), (-depth / 2 + bevel, 0), (depth / 2 - bevel, 0), (depth / 2, bevel)):
        outline = rounded(
            -width / 2 + inset, -height / 2 + inset, width / 2 - inset, height / 2 - inset, width * 0.18, 2
        )
        rings.append([(x, y, z) for x, z in outline])
    obj = _paint(loft(name, rings, mat), value)
    obj.location = at
    return obj


def _ring(name, centre, radii, mat, value=paint.ZONE_ACCENT, plane="xz"):
    vertices, faces = [], []
    rx, rz, thickness = radii
    segments = 20 if max(rx, rz) > 0.01 else 12
    for i in range(segments):
        angle = math.tau * i / segments
        for j in range(6):
            around = math.tau * j / 6
            x = (rx + thickness * math.cos(around)) * math.cos(angle)
            y = thickness * math.sin(around)
            z = (rz + thickness * math.cos(around)) * math.sin(angle)
            local = {"xz": (x, y, z), "yz": (y, x, z), "xy": (x, z, y)}[plane]
            vertices.append(tuple(a + b for a, b in zip(centre, local, strict=True)))
    for i in range(segments):
        for j in range(6):
            following = (i + 1) % segments
            faces.append((i * 6 + j, i * 6 + (j + 1) % 6, following * 6 + (j + 1) % 6, following * 6 + j))
    return _paint(mesh(name, vertices, faces, mat), value)


def _bead(name, at, radius, mat, value=paint.ZONE_ACCENT):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=6, ring_count=3, radius=radius, location=at)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    return _paint(obj, value)


def _turned(name, profile, at, mat, value=paint.ZONE_MAIN, sides=12):
    return _paint(lathe(name, profile, at, mat, segments=sides, axis="z"), value)


def _finish(parts, mat):
    from build_models import attach, join_into, marker

    body = parts[0]
    join_into(body, parts)
    body.name = "Body"
    hook = marker("Hook", (0, 0, 0))
    first = _ring("Link1", (0, 0, -0.0066), (0.0032, 0.0057, 0.0009), mat)
    second = _ring("Link2", (0, 0, -0.018), (0.0032, 0.0063, 0.0009), mat, plane="yz")
    attach(first, (0, 0, 0), hook)
    attach(second, (0, 0, -0.012), first)
    attach(body, (0, 0, -0.024), second)
    bpy.context.view_layer.update()


def build_charm_dog_tags():
    """A tether-tag pair with recessed serial strokes and open suspension bails."""
    mat = _materials()
    parts = []
    for index, (x, y, z) in enumerate(((-0.004, 0.002, -0.052), (0.005, -0.002, -0.057))):
        tag = _plate(f"Tag{index}", (0.023, 0.0018, 0.038), (x, y, z), mat["plate"])
        engrave(
            tag,
            [
                (-0.005, 0, 0.004, 0.001),
                (0.002, 0, 0.006, 0.001),
                (-0.004, -0.004, 0.005, 0.001),
                (0.003, -0.004, 0.004, 0.001),
            ],
            0.0003,
            mat["rubber"],
        )
        refine_face(tag)
        parts.append(tag)
        parts.append(
            _pad("TetherStripe", (0.020, 0.002, 0.0035), (x, y - 0.001, z + 0.008), mat["polymer"], paint.ZONE_TRIM)
        )
    for x in (-0.0025, 0.0025):
        parts.append(_ring("TagBail", (x, 0, -0.030), (0.0024, 0.0048, 0.0012), mat["plate"]))
    _finish(parts, mat["plate"])


def build_charm_vial():
    """A sealed glass ampoule with a raised meniscus inside a three-rib metal cage."""
    from build_models import material, srgb

    mat = _materials()
    glass = material("GearGlass", srgb("#CDEEE8"), roughness=0.10)
    glass.node_tree.nodes["Principled BSDF"].inputs["Alpha"].default_value = 0.14
    glass.surface_render_method = "DITHERED"
    mat["polymer"].name = "GearLiquid"
    mat["polymer"].node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = srgb("#8DFF3A")
    mat["polymer"].node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.12
    ampoule = _turned(
        "GlassAmpoule",
        [
            (0.0055, -0.064),
            (0.0068, -0.062),
            (0.0068, -0.035),
            (0.0045, -0.031),
            (0.0038, -0.031),
            (0.0058, -0.035),
            (0.0058, -0.061),
            (0.0052, -0.062),
        ],
        (0, 0, 0),
        glass,
        sides=16,
    )
    liquid = _turned(
        "SpecimenLiquid",
        [(0.0049, -0.0617), (0.0056, -0.061), (0.0056, -0.050), (0.0055, -0.0495), (0.0046, -0.050)],
        (0, 0, 0),
        mat["polymer"],
        sides=16,
    )
    liquid_window = [
        face.index for face in liquid.data.polygons if -0.050 < face.center.z < -0.0495 and face.center.y < -0.002
    ]
    paint.zone(liquid, paint.ZONE_GLOW, liquid_window)
    parts = [ampoule, liquid]
    for z in (-0.064, -0.032):
        parts.append(
            _turned(
                "CageCap", [(0.006, -0.003), (0.0085, -0.002), (0.0085, 0.002), (0.006, 0.003)], (0, 0, z), mat["plate"]
            )
        )
    for x, y in ((-0.007, 0), (0.007, 0), (0, 0.007)):
        parts.append(_pad("CageRib", (0.002, 0.002, 0.030), (x, y, -0.048), mat["plate"], paint.ZONE_MAIN))
    parts.append(_ring("SealBand", (0, 0, -0.027), (0.005, 0.002, 0.001), mat["plate"], paint.ZONE_TRIM))
    parts.append(_pad("SampleLabel", (0.0045, 0.001, 0.009), (0.001, -0.007, -0.042), mat["rubber"]))
    _finish(parts, mat["plate"])


def build_charm_keycard():
    """Clipped access credential with stamped code, inset contacts and a spring clip."""
    mat = _materials()
    outline = [(-0.017, -0.0245), (0.017, -0.0245), (0.017, 0.0145), (0.007, 0.0245), (-0.017, 0.0245)]
    card = outlined_plate("Credential", outline, 0.0022, (0, 0, -0.055), mat["plate"])
    strokes = [
        (-0.008, 0.002, 0.0015, 0.008),
        (-0.004, 0.006, 0.005, 0.0015),
        (0.003, 0.002, 0.0015, 0.008),
        (0.007, -0.002, 0.005, 0.0015),
        (-0.006, -0.012, 0.008, 0.001),
        (0.005, -0.012, 0.007, 0.001),
        (-0.003, -0.016, 0.015, 0.001),
    ]
    engrave(card, strokes, 0.00035, mat["rubber"])
    refine_face(card)
    parts = [card]
    parts.append(_plate("SpringClip", (0.010, 0.004, 0.015), (0, 0, -0.0315), mat["plate"], paint.ZONE_ACCENT))
    parts.append(_pad("AccessStripe", (0.031, 0.0025, 0.005), (0, -0.0003, -0.042), mat["polymer"], paint.ZONE_TRIM))
    contact = _plate("Contacts", (0.008, 0.0008, 0.005), (0.008, -0.0013, -0.060), mat["polymer"])
    engrave(
        contact, [(-0.002, 0, 0.0005, 0.003), (0, 0, 0.0005, 0.003), (0.002, 0, 0.0005, 0.003)], 0.0002, mat["rubber"]
    )
    parts.append(contact)
    _finish(parts, mat["plate"])


def build_charm_dosimeter():
    """A clipped pen dosimeter with a sealed reading slot and knurled end collar."""
    mat = _materials()
    profile = [(0.0027, -0.087), (0.004, -0.084), (0.004, -0.035), (0.0036, -0.031), (0.0028, -0.030)]
    parts = [_turned("PenBarrel", profile, (0, 0, 0), mat["plate"])]
    cap = _turned(
        "EndCap",
        [(0.003, -0.004), (0.0046, -0.003), (0.0046, 0.002), (0.003, 0.003)],
        (0, 0, -0.031),
        mat["rubber"],
        paint.ZONE_ACCENT,
    )
    for vertex in cap.data.vertices:
        angle = math.atan2(vertex.co.y, vertex.co.x)
        if round(angle / (math.tau / 12)) % 2:
            vertex.co.x *= 0.88
            vertex.co.y *= 0.88
    parts.append(cap)
    for z in (-0.078, -0.041):
        parts.append(
            _ring("ReadingCollar", (0, 0, z), (0.0042, 0.0042, 0.0006), mat["polymer"], paint.ZONE_TRIM, plane="xy")
        )
    parts.append(
        strap(
            "PocketClip",
            [(0, 0.0036, -0.032), (0, 0.005, -0.034), (0, 0.005, -0.056), (0, 0.0036, -0.058)],
            (0.0025, 0.0015),
            mat["plate"],
        )
    )
    meter = _pad("ReadingRecess", (0.0035, 0.001, 0.017), (0, -0.00375, -0.057), mat["rubber"])
    engrave(meter, [(0, -0.005, 0.002, 0.0005), (0, -0.0025, 0.001, 0.0005)], 0.0002, mat["plate"])
    parts.append(meter)
    parts.append(_pad("DoseIndicator", (0.002, 0.0012, 0.003), (0, -0.0038, -0.054), mat["polymer"], paint.ZONE_ACCENT))
    parts.append(
        _turned(
            "Adjustment",
            [(0.002, -0.002), (0.0028, 0), (0.002, 0.002)],
            (0, 0, -0.026),
            mat["plate"],
            paint.ZONE_ACCENT,
            sides=8,
        )
    )
    _finish(parts, mat["plate"])


def build_charm_coin():
    """A worn salvage token held in an open bezel, stamped with rising ledger bars."""
    mat = _materials()
    coin = _paint(
        lathe(
            "SalvageToken",
            [(0.0115, -0.0013), (0.0124, -0.0013), (0.0128, -0.0008), (0.0128, 0.0008), (0.0115, 0.0013)],
            (0, 0, -0.044),
            mat["plate"],
            segments=20,
        ),
        paint.ZONE_MAIN,
    )
    for vertex in coin.data.vertices:
        if vertex.co.x < -0.008 and vertex.co.z > -0.040:
            vertex.co.x *= 0.95
    strokes = []
    for index, height in enumerate((0.006, 0.011, 0.015)):
        strokes.append((-0.006 + index * 0.005, -0.048 + height / 2, 0.002, height))
    strokes.extend(((-0.006, -0.051, 0.001, 0.002), (-0.003, -0.052, 0.001, 0.002), (0.007, -0.049, 0.001, 0.003)))
    engrave(coin, strokes, 0.00035, mat["rubber"])
    refine_face(coin)
    parts = [coin]
    parts.append(_ring("TokenBezel", (0, 0, -0.044), (0.0141, 0.0141, 0.0012), mat["polymer"], paint.ZONE_TRIM))
    for x, z, height in ((-0.013, -0.044, 0.004), (0.013, -0.044, 0.004), (0, -0.028, 0.008)):
        parts.append(_pad("BezelClaw", (0.003, 0.004, height), (x, 0, z), mat["plate"], paint.ZONE_MAIN))
    parts.append(_bead("AssaySeal", (0, -0.0016, -0.052), 0.0012, mat["polymer"], paint.ZONE_ACCENT))
    _finish(parts, mat["plate"])
