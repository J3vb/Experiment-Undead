"""Five rigid HALCYON implants: fitted forearm saddles and matching neck sockets.

Module attaches at the elbow and runs along Blender -Z (Godot -Y). Its open
inner saddle is 60 mm in radius, clearing the thermal suit's 57-59 mm forearm.
Port has the same zero attach pivot; its side-facing socket reaches the neck.
"""

import math

import body_parts as soft
import bpy
import gear_paint as paint
import gun_parts as hard

INNER_RADIUS = 0.060
MODULE_START = 0.018
MODULE_END = 0.160
PORT_CENTRE = (0.072, -0.035, 0.050)


def _materials():
    from build_models import material, srgb

    return {
        "plate": material("GearPlate", srgb("#5F6D68"), metallic=0.65, roughness=0.48),
        "polymer": material("GearPolymer", srgb("#2F393B"), roughness=0.72),
        "rubber": material("GearRubber", srgb("#1C2122"), roughness=0.86),
    }


def _paint(obj, zone):
    paint.zone(obj, zone)
    return obj


def _pad(name, size, at, mat, zone, bevel=0.001):
    return _paint(soft.pad(name, size, at, mat, min(bevel, min(size) * 0.23)), zone)


def _saddle(name, axial, radii, mat, zone):
    """Closed C section, with bevelled axial lips and a real open inner bore."""
    rings = []
    for along, inner, outer in zip(axial, radii[0], radii[1], strict=True):
        angles = [math.radians(-30 + 240 * i / 12) for i in range(13)]
        section = [(outer * math.cos(a), -outer * math.sin(a), -along) for a in angles]
        section += [(inner * math.cos(a), -inner * math.sin(a), -along) for a in reversed(angles)]
        rings.append(section)
    return _paint(soft.loft(name, rings, mat), zone)


def _ring(name, centre, dimensions, mat, zone, sides=6):
    """Hexagonal open cell, closed at both rims; dimensions are outer/inner/depth."""
    outer, inner, depth = dimensions
    x, y, z = centre
    rings = []
    for along, radius in ((-depth / 2, outer), (depth / 2, outer), (depth / 2, inner), (-depth / 2, inner)):
        rings.append(
            [
                (x + radius * math.cos(a), y + along, z + radius * math.sin(a))
                for a in (2 * math.pi * i / sides for i in range(sides))
            ]
        )
    points = [point for ring in rings for point in ring]
    faces = []
    for ring in range(4):
        for i in range(sides):
            a, b = ring * sides + i, ring * sides + (i + 1) % sides
            faces.append((a, b, ((ring + 1) % 4) * sides + (i + 1) % sides, ((ring + 1) % 4) * sides + i))
    return _paint(soft.mesh(name, points, faces, mat), zone)


def _socket(name, at, mat, zone, radius=0.007):
    obj = hard.lathe(
        name,
        [(radius * 0.8, 0.004), (radius, 0.002), (radius, -0.004), (radius * 0.6, -0.006)],
        at,
        mat,
        segments=8,
    )
    return _paint(obj, zone)


def _module(mats):
    _saddle(
        "CurvedPlate",
        (MODULE_START, 0.022, 0.156, MODULE_END),
        ((0.061,) * 4, (0.065, 0.068, 0.068, 0.065)),
        mats["plate"],
        paint.ZONE_MAIN,
    )
    _saddle(
        "InnerIsolation",
        (0.022, 0.156),
        ((INNER_RADIUS,) * 2, (0.0615,) * 2),
        mats["rubber"],
        paint.ZONE_ACCENT,
    )
    for along in (0.027, 0.144):
        _saddle(
            "RarityBand",
            (along, along + 0.010),
            ((0.067,) * 2, (0.069,) * 2),
            mats["plate"],
            paint.ZONE_TRIM,
        )
    _pad("DorsalHousing", (0.084, 0.020, 0.101), (0, -0.067, -0.091), mats["plate"], paint.ZONE_MAIN, 0.006)
    _pad("ServiceInset", (0.065, 0.004, 0.071), (0, -0.079, -0.087), mats["polymer"], paint.ZONE_ACCENT, 0.003)
    _pad("StatusWindow", (0.033, 0.002, 0.007), (0, -0.082, -0.125), mats["polymer"], paint.ZONE_GLOW)
    for x in (-0.029, 0.029):
        _socket("CablePort", (x, -0.072, -0.149), mats["rubber"], paint.ZONE_ACCENT)
        bolt = hard.lathe(
            "CaptiveScrew", [(0.003, -0.001), (0.003, 0.001)], (x, -0.079, -0.044), mats["plate"], segments=6
        )
        _paint(bolt, paint.ZONE_ACCENT)


def _port(mats):
    """A flanged neck disc, small light ring, and the buried feed-through socket."""
    profile = [
        (0.019, 0.003),
        (0.022, 0),
        (0.022, -0.005),
        (0.019, -0.008),
        (0.017, -0.008),
        (0.0165, -0.0085),
        (0.0158, -0.008),
        (0.005, -0.008),
    ]
    disc = _paint(hard.lathe("NeckDisc", profile, PORT_CENTRE, mats["plate"], segments=12), paint.ZONE_MAIN)
    # The turned front rim carries rarity; only the narrow inset ring emits.
    for face in disc.data.polygons:
        y = sum(disc.data.vertices[index].co.y for index in face.vertices) / len(face.vertices)
        radius = sum(
            math.hypot(disc.data.vertices[i].co.x - PORT_CENTRE[0], disc.data.vertices[i].co.z - PORT_CENTRE[2])
            for i in face.vertices
        ) / len(face.vertices)
        if y < PORT_CENTRE[1] - 0.0075:
            paint.zone(disc, paint.ZONE_TRIM if radius > 0.017 else paint.ZONE_ACCENT, [face])
        if 0.0158 < radius < 0.017 and y < PORT_CENTRE[1] - 0.008:
            paint.zone(disc, paint.ZONE_GLOW, [face])
    feed = soft.tube(
        "BuriedFeed", [(0, 0, 0), (0.040, -0.012, 0.030), PORT_CENTRE], [0.004, 0.004, 0.004], mats["rubber"], 6
    )
    _paint(feed, paint.ZONE_ACCENT)


def _ridges(mats, port):
    scale, x, y, z = (0.25, *PORT_CENTRE) if port else (1.0, 0, -0.084, -0.084)
    for step in (-1, 0, 1):
        ridge = _pad(
            "ReflexRidge",
            (0.055 * scale, 0.005 * scale, 0.006 * scale),
            (x, y - 0.009 * port, z + step * 0.015 * scale),
            mats["plate"],
            paint.ZONE_ACCENT,
        )
        ridge.rotation_euler.y = 0.23


def _hexes(mats, port):
    scale, x, y, z = (0.43, *PORT_CENTRE) if port else (1.0, 0, -0.084, -0.084)
    for dx, dz in ((0, 0.012), (-0.014, -0.012), (0.014, -0.012))[: 1 if port else 3]:
        _ring(
            "LungCell",
            (x + dx * scale, y - 0.009 * port, z + dz * scale),
            (0.013 * scale, 0.010 * scale, 0.003 * scale),
            mats["plate"],
            paint.ZONE_ACCENT,
        )


def _vents(mats, port):
    scale, x, y, z = (0.25, *PORT_CENTRE) if port else (1.0, 0, -0.084, -0.084)
    for step in (-1.5, -0.5, 0.5, 1.5):
        _pad(
            "SpineVent",
            (0.049 * scale, 0.005 * scale, 0.005 * scale),
            (x, y - 0.009 * port, z + step * 0.013 * scale),
            mats["rubber"],
            paint.ZONE_ACCENT,
        )


def _lens(mats, port):
    scale, x, y, z = (0.42, *PORT_CENTRE) if port else (1.0, 0, -0.082, -0.082)
    profile = [
        (0.014 * scale, 0),
        (0.016 * scale, -0.003 * scale),
        (0.013 * scale, -0.007 * scale),
        (0.010 * scale, -0.009 * scale),
    ]
    lens = hard.lathe("OcularLens", profile, (x, y - 0.009 * port, z), mats["polymer"], segments=12)
    _paint(lens, paint.ZONE_ACCENT)
    _ring(
        "OcularBezel",
        (x, y - 0.009 * port, z),
        (0.017 * scale, 0.015 * scale, 0.004 * scale),
        mats["plate"],
        paint.ZONE_TRIM,
        12,
    )


def _antenna(mats, port):
    scale, x, y, z = (0.45, *PORT_CENTRE) if port else (1.0, 0.022, -0.084, -0.062)
    y -= 0.009 * port
    _pad("RelayBase", (0.022 * scale, 0.009 * scale, 0.025 * scale), (x, y, z), mats["polymer"], paint.ZONE_ACCENT)
    mast = soft.tube(
        "RelayAntenna",
        [(x, y, z), (x + 0.009 * scale, y, z + 0.024 * scale), (x + 0.009 * scale, y, z + 0.049 * scale)],
        [0.0035 * scale, 0.003 * scale, 0.0025 * scale],
        mats["rubber"],
        6,
    )
    _paint(mast, paint.ZONE_ACCENT)
    _pad(
        "RelayContact",
        (0.028 * scale, 0.006 * scale, 0.005 * scale),
        (x - 0.020 * scale, y, z - 0.026 * scale),
        mats["plate"],
        paint.ZONE_TRIM,
    )


def _join(name, before):
    from build_models import attach, join_into

    parts = [obj for obj in bpy.context.scene.objects if obj.type == "MESH" and obj not in before]
    join_into(parts[0], parts[1:])
    parts[0].name = name
    return attach(parts[0], (0, 0, 0))


def _build(motif):
    mats = _materials()
    _module(mats)
    motif(mats, False)
    module = _join("Module", set())
    _port(mats)
    motif(mats, True)
    _join("Port", {module})
    bpy.context.view_layer.update()


def build_implant_reflex():
    """Fast reflex hardware uses three slanted reinforcing ridges."""
    _build(_ridges)


def build_implant_lung():
    """Respiration hardware repeats a honeycomb filter cage."""
    _build(_hexes)


def build_implant_spine():
    """Nerve relay hardware repeats deep transverse cooling vents."""
    _build(_vents)


def build_implant_ocular():
    """Optical hardware pairs a raised lens with a turned protective bezel."""
    _build(_lens)


def build_implant_relay():
    """Ability telemetry hardware has a protected bent antenna."""
    _build(_antenna)
