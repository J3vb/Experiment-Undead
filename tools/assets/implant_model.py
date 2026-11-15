"""Five rigid implants with a 60 mm forearm bore and matching neck sockets.
Module runs down Blender -Z (Godot -Y) from the elbow; both attachment origins stay zero.
"""

import math

import body_parts as soft
import bpy
import gear_paint as paint
import gear_parts as gear
import gun_parts as hard

INNER_RADIUS = 0.060
MODULE_START = 0.018
MODULE_END = 0.160
PORT_CENTRE = (0.072, -0.065, 0.050)


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


def _turned(name, profile, at, mat, zone=paint.ZONE_MAIN):
    return _paint(hard.lathe(name, profile, at, mat, segments=12), zone)


def _saddle(name, axial, radii, mat, zone, arc=(-30, 210)):
    """Closed C section, with bevelled axial lips and a real open inner bore."""
    rings = []
    start, end = arc
    angles = [math.radians(start + (end - start) * i / 12) for i in range(13)]
    for along, inner, outer in zip(axial, radii[0], radii[1], strict=True):
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


def _paired(outlines):
    return [[(side * x, z) for x, z in outline] for side in (-1, 1) for outline in outlines]


def _cutaways(shell, outlines, mat):
    """Cut side contours out of a constant-angle shell without crossing its bore."""
    for outline in outlines:
        cutter = gear.outlined_plate("ShellCut", outline, 0.3, (0, 0, 0), mat, bevel=0)
        soft.select(shell)
        modifier = shell.modifiers.new("Side relief", "BOOLEAN")
        modifier.operation = "DIFFERENCE"
        modifier.solver = "EXACT"
        modifier.object = cutter
        bpy.ops.object.modifier_apply(modifier=modifier.name)
        bpy.data.objects.remove(cutter, do_unlink=True)
    paint.zone(shell, paint.ZONE_MAIN)


def _module(mats, notches):
    shell = _saddle(
        "CurvedPlate",
        (MODULE_START, 0.022, 0.156, MODULE_END),
        ((0.061,) * 4, (0.065, 0.068, 0.068, 0.065)),
        mats["plate"],
        paint.ZONE_MAIN,
    )
    _cutaways(shell, notches, mats["plate"])
    _saddle(
        "InnerIsolation",
        (0.022, 0.156),
        ((INNER_RADIUS,) * 2, (0.0615,) * 2),
        mats["rubber"],
        paint.ZONE_ACCENT,
        (45, 135),
    )
    for along in (0.027, 0.144):
        _saddle(
            "RarityBand",
            (along, along + 0.010),
            ((0.067,) * 2, (0.069,) * 2),
            mats["plate"],
            paint.ZONE_TRIM,
        )
    _pad("StatusWindow", (0.033, 0.002, 0.007), (0, -0.070, -0.149), mats["polymer"], paint.ZONE_GLOW)
    for x in (-0.029, 0.029):
        _ring("CablePort", (x, -0.069, -0.144), (0.0065, 0.0035, 0.006), mats["rubber"], paint.ZONE_ACCENT, 8)
        bolt = hard.lathe("CaptiveScrew", [(0.003, -0.001), (0.003, 0.001)], (0, 0, 0), mats["plate"], segments=6)
        bolt.location = (x, -0.063, -0.032)
        _paint(bolt, paint.ZONE_ACCENT)
        gear.engrave(bolt, [(0, 0, 0.004, 0.0009)], 0.0007, mats["rubber"])


def _port(mats, code):
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
    disc = _turned("NeckDisc", profile, PORT_CENTRE, mats["plate"])
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
    if "glass" in mats:
        _turned(
            "NeckOpticalWell", [(0.011, 0), (0.011, -0.001)], (0.072, -0.0735, 0.050), mats["rubber"], paint.ZONE_ACCENT
        )
        _turned(
            "NeckOptic",
            [(0.012, 0), (0.010, -0.003), (0.004, -0.004)],
            (0.072, -0.0745, 0.050),
            mats["glass"],
            paint.ZONE_ACCENT,
        )
    else:
        strokes = [
            (PORT_CENTRE[0] - 0.006 + i * 0.004, PORT_CENTRE[2], 0.0015, height) for i, height in enumerate(code)
        ]
        gear.engrave(disc, strokes, 0.0015, mats["rubber"])


def _ridges(mats):
    outline = [(-0.038, -0.042), (0.016, -0.050), (0.041, 0.031), (0.021, 0.049), (-0.038, 0.016)]
    gear.outlined_plate("SweptHousing", outline, 0.016, (0, -0.069, -0.087), mats["plate"], 0.002)
    insert = gear.outlined_plate(
        "ReflexInsert", [(x * 0.79, z * 0.79) for x, z in outline], 0.003, (0, -0.078, -0.087), mats["polymer"], 0.0005
    )
    _paint(insert, paint.ZONE_ACCENT)
    gear.engrave(insert, [(0, z, 0.038, 0.0028) for z in (-0.021, -0.007, 0.007)], 0.001, mats["rubber"])
    for step in (-1, 0, 1):
        ridge = _pad(
            "ReflexRidge", (0.049, 0.004, 0.005), (0.002, -0.082, -0.088 + step * 0.014), mats["plate"], paint.ZONE_MAIN
        )
        ridge.rotation_euler.y = -0.23


def _hexes(mats):
    outline = [
        (-0.036, -0.039),
        (-0.044, -0.025),
        (-0.044, 0.028),
        (-0.027, 0.042),
        (-0.010, 0.039),
        (0, 0.025),
        (0.010, 0.039),
        (0.027, 0.042),
        (0.044, 0.028),
        (0.044, -0.025),
        (0.036, -0.039),
    ]
    gear.outlined_plate("TwinFilterHousing", outline, 0.019, (0, -0.0705, -0.086), mats["plate"], 0.002)
    for x in (-0.022, 0.022):
        _ring("FilterCage", (x, -0.081, -0.084), (0.020, 0.016, 0.008), mats["plate"], paint.ZONE_MAIN, 6)
        backing = _pad(
            "FilterMembrane", (0.029, 0.002, 0.032), (x, -0.0805, -0.084), mats["polymer"], paint.ZONE_ACCENT
        )
        gear.engrave(backing, [(0, z, 0.023, 0.0015) for z in (-0.008, 0, 0.008)], 0.0006, mats["rubber"])


def _vents(mats):
    _pad("SpinalKeel", (0.025, 0.014, 0.100), (0, -0.070, -0.089), mats["rubber"], paint.ZONE_ACCENT, 0.003)
    for index, width in enumerate((0.055, 0.067, 0.061, 0.047)):
        outline = [
            (-width / 2, -0.006),
            (-width * 0.30, -0.010),
            (width * 0.30, -0.010),
            (width / 2, -0.006),
            (width / 2, 0.007),
            (0, 0.011),
            (-width / 2, 0.007),
        ]
        vertebra = gear.outlined_plate(
            "SpineVertebra", outline, 0.022, (0, -0.074, -0.054 - index * 0.023), mats["plate"], 0.0015
        )
        gear.engrave(vertebra, [(0, 0, width * 0.62, 0.003)], 0.0012, mats["rubber"])


def _lens(mats):
    from build_models import material, srgb

    mats["glass"] = material("GearGlass", srgb("#CDEEE8"), roughness=0.1)
    mats["glass"].node_tree.nodes["Principled BSDF"].inputs["Alpha"].default_value = 0.14
    _turned(
        "OcularDrum",
        [(0.025, 0.010), (0.037, 0.009), (0.037, -0.005), (0.032, -0.009)],
        (0, -0.071, -0.084),
        mats["plate"],
    )
    _turned("OpticalWell", [(0.027, 0), (0.027, -0.001)], (0, -0.0805, -0.084), mats["rubber"], paint.ZONE_ACCENT)
    _ring("OpticalIris", (0, -0.082, -0.084), (0.014, 0.009, 0.001), mats["plate"], paint.ZONE_MAIN, 12)
    profile = [(0.028, 0), (0.026, -0.003), (0.021, -0.007), (0.009, -0.009)]
    _turned("OcularLens", profile, (0, -0.082, -0.084), mats["glass"], paint.ZONE_ACCENT)
    _ring("OcularBezel", (0, -0.082, -0.084), (0.033, 0.0285, 0.004), mats["plate"], paint.ZONE_TRIM, 12)
    for x in (-0.039, 0.039):
        _pad("LensGuard", (0.008, 0.014, 0.032), (x, -0.076, -0.084), mats["rubber"], paint.ZONE_ACCENT)


def _antenna(mats):
    outline = [
        (-0.037, -0.047),
        (0.033, -0.047),
        (0.042, -0.030),
        (0.042, 0.018),
        (0.017, 0.018),
        (0.017, 0.048),
        (-0.026, 0.048),
        (-0.037, 0.032),
    ]
    gear.outlined_plate("RelayHousing", outline, 0.016, (0, -0.070, -0.088), mats["plate"], 0.002)
    plate = gear.outlined_plate(
        "RelayService",
        [(-0.015, -0.036), (0.012, -0.036), (0.012, 0.036), (-0.015, 0.036)],
        0.003,
        (-0.011, -0.079, -0.088),
        mats["polymer"],
        0.0005,
    )
    _paint(plate, paint.ZONE_ACCENT)
    gear.engrave(
        plate,
        [(0, z, width, 0.002) for z, width in ((0.020, 0.017), (0.014, 0.010), (0.008, 0.014))],
        0.001,
        mats["rubber"],
    )
    x, y, z = 0.030, -0.081, -0.062
    _pad("RelayBase", (0.018, 0.009, 0.023), (x, y, z), mats["rubber"], paint.ZONE_ACCENT)
    mast = soft.tube(
        "RelayAntenna",
        [(x, y, z), (x + 0.006, y, z + 0.024), (x + 0.006, y, z + 0.049)],
        [0.0035, 0.003, 0.0025],
        mats["rubber"],
        6,
    )
    _paint(mast, paint.ZONE_ACCENT)
    _pad("RelayContact", (0.023, 0.003, 0.005), (-0.010, -0.082, -0.112), mats["plate"], paint.ZONE_TRIM)


def _join(name, before):
    from build_models import attach, join_into

    parts = [obj for obj in bpy.context.scene.objects if obj.type == "MESH" and obj not in before]
    join_into(parts[0], parts[1:])
    parts[0].name = name
    return attach(parts[0], (0, 0, 0))


def _build(motif, notches, code):
    mats = _materials()
    _module(mats, notches)
    motif(mats)
    module = _join("Module", set())
    _port(mats, code)
    _join("Port", {module})
    bpy.context.view_layer.update()


def build_implant_reflex():
    """Swept reflex hardware tapers toward the wrist with slanted reinforcing ridges."""
    cuts = [[(0.067, -0.043), (0.090, -0.043), (0.090, -0.137), (0.045, -0.137)]]
    _build(_ridges, _paired(cuts), (0.004, 0.007, 0.010))


def build_implant_lung():
    """Respiration hardware has paired filter lobes and a pinched waist."""
    cuts = [[(0.043, -0.086), (0.062, -0.061), (0.090, -0.061), (0.090, -0.111), (0.062, -0.111)]]
    _build(_hexes, _paired(cuts), (0.008, 0.004, 0.008))


def build_implant_spine():
    """Nerve hardware has separate vertebrae and three side relief notches."""
    cuts = [[(0.048, z), (0.090, z - 0.012), (0.090, z + 0.012)] for z in (-0.056, -0.091, -0.126)]
    cuts[1] = [(0.048, -0.095), (0.048, -0.087), (0.090, -0.077), (0.090, -0.105)]
    _build(_vents, _paired(cuts), (0.010, 0.007, 0.004))


def build_implant_ocular():
    """Optical hardware pairs a clear raised lens with a protective iris drum."""
    cuts = [[(0.044, z - 0.008), (0.044, z + 0.008), (0.090, z + 0.020), (0.090, z - 0.020)] for z in (-0.052, -0.123)]
    _build(_lens, _paired(cuts), (0.004, 0.010, 0.004))


def build_implant_relay():
    """Ability telemetry hardware has an asymmetric shoulder and bent antenna."""
    cuts = [
        [(0.045, -0.043), (0.090, -0.043), (0.090, -0.098), (0.045, -0.080)],
        [(-0.052, -0.105), (-0.090, -0.100), (-0.090, -0.138), (-0.052, -0.138)],
    ]
    _build(_antenna, cuts, (0.010, 0.004, 0.010))
