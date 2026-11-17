"""Survivor head: a sculpted face on the continuous body, beard and cropped hair, eyes, brows and ears."""

import math

import body_parts as soft
import bpy
import character_rig as rig
import gear_paint as paint
from mathutils import Matrix, Vector, noise

FACE_CENTRE = (0.0, -0.085, 1.685)
EYE_Z = 1.704
EYE_X = 0.034
MOUTH_Z = 1.651


def _gauss(value, sigma):
    return math.exp(-((value / sigma) ** 2))


def _smooth(edge0, edge1, value):
    t = max(0.0, min(1.0, (value - edge0) / (edge1 - edge0)))
    return t * t * (3 - 2 * t)


def hairline(y):
    """Scalp starts high at the brow and drops behind the ears."""
    return 1.757 + (1.61 - 1.757) * _smooth(-0.05, 0.06, y)


def beard_top(x):
    return 1.666 + 0.026 * _smooth(0.028, 0.078, abs(x))


def is_hair(co):
    return co.z > hairline(co.y) and co.z > 1.62


def is_beard(co):
    x, y, z = co
    if y > 0.035 or z < 1.592 or z > beard_top(x):
        return False
    return not (abs(x) < 0.016 and abs(z - MOUTH_Z) < 0.003)


def _face_offset(x, y, z):
    """Inward (+Y) or outward (-Y) shaping of the front of the head, in metres."""
    if y > -0.02 or z < 1.62 or z > 1.78:
        return 0.0
    bridge = max(0.0, min(1.0, (1.728 - z) / 0.058))
    tip = _smooth(1.660, 1.671, z)
    nose = -(0.003 + 0.016 * bridge**1.4) * _gauss(x, 0.006 + 0.008 * bridge) * tip * (1 if z < 1.73 else 0)
    sockets = sum(0.007 * _gauss(x - s * EYE_X, 0.013) * _gauss(z - EYE_Z, 0.009) for s in (-1, 1))
    brow = -0.005 * _gauss(z - 1.722, 0.006) * _smooth(0.065, 0.045, abs(x))
    cheeks = sum(-0.003 * _gauss(x - s * 0.052, 0.014) * _gauss(z - 1.686, 0.012) for s in (-1, 1))
    lips = 0.003 * _gauss(x, 0.02) * _gauss(z - MOUTH_Z, 0.003)
    return nose + sockets + brow + cheeks + lips


def _beard_offset(co):
    """Full beard: thickest at the chin, which also hangs lower, with clumped strands."""
    edge = _smooth(0.0, 0.012, beard_top(co.x) - co.z) * _smooth(0.0, 0.01, co.z - 1.592)
    chin = _gauss(co.x, 0.04) * _smooth(1.64, 1.60, co.z)
    clump = noise.noise(Vector((co.x * 70, co.y * 70, co.z * 22))) * 0.0028
    return (0.011 + 0.011 * chin + clump) * edge, -0.026 * chin * edge


def sculpt(suit):
    """Refine the face, shape the features, then raise the beard and hair volumes."""
    soft.refine_patch(suit, (0.0, -0.05, 1.64), 0.095)
    soft.refine_patch(suit, (0.0, -0.09, 1.69), 0.055)
    for vertex in suit.data.vertices:
        co = vertex.co
        if co.z < 1.56:
            continue
        jaw = _gauss(co.z - 1.63, 0.03)
        co.x *= 1 - jaw * 0.08
        co.y += _face_offset(co.x, co.y, co.z)
        radial = Vector((co.x, co.y + 0.005, 0.0))
        radial = radial.normalized() if radial.length > 1e-6 else Vector((0, -1, 0))
        if is_beard(co):
            out, down = _beard_offset(co)
            co += radial * out + Vector((0, down * 0.7, down))
        elif is_hair(co):
            co += radial * (0.005 + noise.noise(co * 120) * 0.0015) + Vector((0, 0, 0.004))
    suit.data.update()


def paint_head(suit, skin_index, hair_index):
    """Above the jacket's high collar: hair and beard in the hair material, the rest skin."""
    hair_faces = []
    for face in suit.data.polygons:
        if face.center.z < 1.6:
            continue
        rest = face.center
        if rest.z > hairline(rest.y) - 0.004 or _in_beard(rest):
            face.material_index = hair_index
            hair_faces.append(face)
        else:
            face.material_index = skin_index
    paint.zone(suit, paint.ZONE_ACCENT, hair_faces)


def _in_beard(centre):
    x, y, z = centre
    return y < 0.035 and 1.56 < z < beard_top(x) + 0.004 and not (abs(x) < 0.016 and abs(z - MOUTH_Z) < 0.0045)


def _surface(suit, x, z, inset):
    hit, point, normal, _index = suit.ray_cast(Vector((x, -0.6, z)), Vector((0, 1, 0)))
    if not hit:
        raise ValueError("face detail must sit on the head")
    return point + normal * -inset, normal


def details(armature, mats, suit):
    """Eyes, brows and ears are rigid on the head; the Eyes marker sits between the eyes."""
    parts = []
    for sign in (-1, 1):
        point, _normal = _surface(suit, sign * EYE_X, EYE_Z, 0.004)
        parts.append(soft.ellipsoid("FaceEye", tuple(point), (0.0105, 0.006, 0.0062), mats["rubber"], (10, 6)))
        point, _normal = _surface(suit, sign * 0.036, 1.7205, -0.0015)
        brow = soft.pad("FaceBrow", (0.030, 0.006, 0.0065), tuple(point), mats["hair"], 0.002)
        brow.rotation_euler.y = sign * 0.16
        parts.append(brow)
        ear = soft.ellipsoid("FaceEar", (sign * 0.094, 0.008, 1.700), (0.008, 0.015, 0.024), mats["skin"], (10, 6))
        parts.append(ear)
    for part in parts:
        paint.zone(part, paint.ZONE_ACCENT if part.name.startswith("FaceBrow") else paint.ZONE_MAIN)
        rig.bind_rigid(part, armature, "head")
    eyes = bpy.data.objects.new("Eyes", None)
    bpy.context.collection.objects.link(eyes)
    eyes.parent, eyes.parent_type, eyes.parent_bone = armature, "BONE", "head"
    bpy.context.view_layer.update()
    eyes.matrix_world = Matrix.Translation((0, -0.115, EYE_Z))
    return parts
