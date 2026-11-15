"""Five salvaged luck charms, with two articulated links and a hook-space origin."""

import math

import bpy
import gear_paint as paint
from body_parts import loft, mesh, pad
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
        rings.append([(x + at[0], y + at[1], z + at[2]) for x, z in outline])
    return _paint(loft(name, rings, mat), value)


def _ring(name, centre, radii, mat, value=paint.ZONE_ACCENT, plane="xz"):
    vertices, faces = [], []
    rx, rz, thickness = radii
    for i in range(8):
        angle = math.tau * i / 8
        for j in range(4):
            around = math.tau * j / 4
            x = (rx + thickness * math.cos(around)) * math.cos(angle)
            y = thickness * math.sin(around)
            z = (rz + thickness * math.cos(around)) * math.sin(angle)
            local = {"xz": (x, y, z), "yz": (y, x, z), "xy": (x, z, y)}[plane]
            vertices.append(tuple(a + b for a, b in zip(centre, local, strict=True)))
    for i in range(8):
        for j in range(4):
            faces.append((i * 4 + j, i * 4 + (j + 1) % 4, ((i + 1) % 8) * 4 + (j + 1) % 4, ((i + 1) % 8) * 4 + j))
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
    first = _ring("Link1", (0, 0, -0.006), (0.0032, 0.0051, 0.0009), mat)
    second = _ring("Link2", (0, 0, -0.018), (0.0032, 0.0051, 0.0009), mat, plane="yz")
    attach(first, (0, 0, 0), hook)
    attach(second, (0, 0, -0.012), first)
    attach(body, (0, 0, -0.024), second)
    bpy.context.view_layer.update()


def build_charm_dog_tags():
    """A Lantern Post tether-tag pair with coded stamp rows and a bead chain."""
    mat = _materials()
    parts = []
    for index, (x, y, z) in enumerate(((-0.004, 0.002, -0.052), (0.005, -0.002, -0.057))):
        parts.append(_plate(f"Tag{index}", (0.023, 0.0018, 0.038), (x, y, z), mat["plate"]))
        parts.append(
            _pad("TetherStripe", (0.020, 0.002, 0.0035), (x, y - 0.001, z + 0.008), mat["polymer"], paint.ZONE_TRIM)
        )
        for row, width in enumerate((0.013, 0.016)):
            parts.append(
                _pad("StampedCode", (width, 0.0005, 0.001), (x - 0.002, y - 0.0011, z - row * 0.003), mat["rubber"])
            )
    for index, at in enumerate(
        (
            (-0.002, 0, -0.026),
            (-0.004, 0, -0.029),
            (-0.005, 0, -0.032),
            (-0.004, 0, -0.035),
            (0.002, 0, -0.026),
            (0.004, 0, -0.030),
            (0.005, 0, -0.0335),
            (0.005, 0, -0.037),
        )
    ):
        parts.append(_bead(f"ChainBead{index}", at, 0.002, mat["plate"]))
    _finish(parts, mat["plate"])


def build_charm_vial():
    """A sealed Halcyon specimen ampoule protected by a four-rib metal cage."""
    mat = _materials()
    ampoule = _turned(
        "GlassAmpoule",
        [(0.0055, -0.064), (0.0068, -0.062), (0.0068, -0.057), (0.0068, -0.035), (0.0045, -0.031)],
        (0, 0, 0),
        mat["polymer"],
    )
    liquid_window = [
        face.index for face in ampoule.data.polygons if -0.062 < face.center.z < -0.057 and face.center.y < -0.002
    ]
    paint.zone(ampoule, paint.ZONE_GLOW, liquid_window)
    parts = [ampoule]
    for z in (-0.064, -0.032):
        parts.append(
            _turned(
                "CageCap", [(0.006, -0.003), (0.0085, -0.002), (0.0085, 0.002), (0.006, 0.003)], (0, 0, z), mat["plate"]
            )
        )
    for x, y in ((-0.007, 0), (0.007, 0), (0, -0.007), (0, 0.007)):
        parts.append(_pad("CageRib", (0.002, 0.002, 0.030), (x, y, -0.048), mat["plate"], paint.ZONE_MAIN))
    parts.append(_ring("SealBand", (0, 0, -0.027), (0.005, 0.002, 0.001), mat["plate"], paint.ZONE_TRIM))
    parts.append(_pad("SampleLabel", (0.0045, 0.001, 0.009), (0.001, -0.007, -0.042), mat["rubber"]))
    _finish(parts, mat["plate"])


def build_charm_keycard():
    """Original Halcyon lab credential: clipped header, H monogram and serial bars."""
    mat = _materials()
    parts = [_plate("Credential", (0.034, 0.0022, 0.049), (0, 0, -0.055), mat["plate"])]
    parts.append(_plate("SpringClip", (0.010, 0.004, 0.015), (0, 0, -0.0315), mat["plate"], paint.ZONE_ACCENT))
    parts.append(_pad("AccessStripe", (0.031, 0.0025, 0.005), (0, -0.0003, -0.042), mat["polymer"], paint.ZONE_TRIM))
    for x in (-0.005, 0.005):
        parts.append(_pad("HalcyonH", (0.002, 0.0006, 0.012), (x, -0.0013, -0.055), mat["rubber"]))
    parts.append(_pad("HalcyonH", (0.010, 0.0006, 0.002), (0, -0.0013, -0.055), mat["rubber"]))
    for index, width in enumerate((0.019, 0.024, 0.015)):
        parts.append(
            _pad("ClearanceCode", (width, 0.0006, 0.0012), (-0.002, -0.0013, -0.066 - index * 0.003), mat["rubber"])
        )
    parts.append(
        _pad("SealWindow", (0.0035, 0.0007, 0.002), (0.011, -0.0015, -0.054), mat["polymer"], paint.ZONE_ACCENT)
    )
    _finish(parts, mat["plate"])


def build_charm_dosimeter():
    """A clipped pen dosimeter with a sealed reading slot and knurled end collar."""
    mat = _materials()
    parts = [
        _turned(
            "PenBarrel",
            [(0.0027, -0.087), (0.004, -0.084), (0.004, -0.035), (0.0036, -0.031), (0.0028, -0.030)],
            (0, 0, 0),
            mat["plate"],
        )
    ]
    parts.append(
        _turned(
            "EndCap",
            [(0.003, -0.004), (0.0046, -0.003), (0.0046, 0.002), (0.003, 0.003)],
            (0, 0, -0.031),
            mat["rubber"],
            paint.ZONE_ACCENT,
        )
    )
    for z in (-0.078, -0.041):
        parts.append(
            _ring("ReadingCollar", (0, 0, z), (0.0042, 0.0042, 0.0006), mat["polymer"], paint.ZONE_TRIM, plane="xy")
        )
    parts.append(_pad("PocketClip", (0.0025, 0.0015, 0.026), (0, 0.005, -0.045), mat["plate"], paint.ZONE_ACCENT))
    parts.append(_pad("ReadingRecess", (0.0035, 0.001, 0.017), (0, -0.0035, -0.057), mat["rubber"]))
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
            [(0.0115, -0.0013), (0.0128, -0.0008), (0.0128, 0.0008), (0.0115, 0.0013)],
            (0, 0, -0.044),
            mat["plate"],
            segments=20,
        ),
        paint.ZONE_MAIN,
    )
    for vertex in coin.data.vertices:
        if vertex.co.x < -0.008 and vertex.co.z > -0.040:
            vertex.co.x *= 0.95
    parts = [coin]
    parts.append(_ring("TokenBezel", (0, 0, -0.044), (0.0141, 0.0141, 0.0012), mat["polymer"], paint.ZONE_TRIM))
    for index, height in enumerate((0.006, 0.011, 0.015)):
        parts.append(
            _pad(
                "LedgerStamp",
                (0.003, 0.0008, height),
                (-0.006 + index * 0.005, -0.0014, -0.048 + height / 2),
                mat["rubber"],
            )
        )
    for x, z, height in ((-0.013, -0.044, 0.004), (0.013, -0.044, 0.004), (0, -0.028, 0.008)):
        parts.append(_pad("BezelClaw", (0.003, 0.004, height), (x, 0, z), mat["plate"], paint.ZONE_MAIN))
    parts.append(_bead("AssaySeal", (0, -0.0016, -0.052), 0.0012, mat["polymer"], paint.ZONE_ACCENT))
    _finish(parts, mat["plate"])
