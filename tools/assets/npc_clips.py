"""Unarmed Lantern Post stall keeper clips on the shared skeleton, exported as one NLA track each (F-76 step 3).

Poses are functions of the cycle phase, so loops end where they start. Body angles work like player_clips
(body-space Euler: x bends forward, z turns). Each hand is solved with two-bone IK to a spot measured from its
own shoulder in chest space and scaled by the arm length, so the same clip fits keepers of every height.
`greet` starts and ends in the first `counter_idle` pose, so it blends in and out cleanly.
"""

import math

import bpy

# isort: split
import player_clips
import tripo_rig
from mathutils import Matrix, Quaternion, Vector

FPS = 30
LOOPS = ("counter_idle", "bench_work", "desk_work", "board_idle")
ONE_SHOTS = ("greet",)
CLIPS = LOOPS + ONE_SHOTS
# Our rest rig's arm length (upper arm + forearm), the length the hand spots are written for.
ARM_LENGTH = 0.59
# Body faces -Y, its left is +X. Finger directions and palm sides are in chest space.
DOWN_FORWARD = Vector((0.0, -1.0, -0.45))
PALM_DOWN = Vector((0.0, 0.0, -1.0))
PALM_IN = Vector((0.0, 1.0, 0.0))
POLE_L = Vector((0.6, 0.4, -1.0))
POLE_R = Vector((-0.6, 0.4, -1.0))
FOLD_POLE_L = Vector((1.0, -0.4, -0.6))
FOLD_POLE_R = Vector((-1.0, -0.4, -0.6))


def _bump(p: float, start: float, length: float) -> float:
    """0 outside [start, start + length], a smooth rise and fall inside; keeps loops closed."""
    t = (p - start) / length
    return math.sin(math.pi * t) ** 2 if 0.0 < t < 1.0 else 0.0


def _hand(spot, direction, palm, pole) -> tuple:
    return (Vector(spot), direction.normalized(), palm.normalized(), pole)


def _palm_down(spot, side: str) -> tuple:
    """A flat hand on a surface: fingers forward and down, palm on the surface."""
    return _hand(spot, DOWN_FORWARD, PALM_DOWN, POLE_L if side == "L" else POLE_R)


def _stand(p: float, sway: float) -> dict:
    """Standing at a counter: a slow breath and a weight shift from foot to foot."""
    breath = math.sin(p * math.tau * 2.0)
    shift = math.sin(p * math.tau)
    pose = {
        "hips": Vector((0.012 * shift * sway, 0.0, -0.01 + 0.003 * breath)),
        "pelvis": (0.0, 0.03 * shift * sway, 0.0),
        "spine_01": (0.06, -0.02 * shift * sway, 0.0),
        "spine_02": (0.05 + 0.012 * breath, 0.0, 0.0),
        "spine_03": (0.03, 0.0, 0.0),
        "head": (0.05, 0.0, 0.0),
    }
    lean = 0.03 * shift * sway
    pose["thigh_L"], pose["thigh_R"] = (-0.03, 0.05 - lean, 0.0), (0.02, -0.05 - lean, 0.0)
    pose["shin_L"] = (0.06 + 0.05 * max(0.0, -shift) * sway, 0.0, 0.0)
    pose["shin_R"] = (0.06 + 0.05 * max(0.0, shift) * sway, 0.0, 0.0)
    return pose


def counter_idle(p: float) -> dict:
    """Both hands resting on the counter, leaning in a little, glancing along the street now and then."""
    pose = _stand(p, 1.0)
    pose["spine_01"] = (0.12, pose["spine_01"][1], 0.0)
    pose["head"] = (0.08, 0.0, 0.35 * _bump(p, 0.15, 0.3) - 0.3 * _bump(p, 0.6, 0.3))
    pose["hand_L"] = _palm_down((-0.06, -0.42, -0.36), "L")
    pose["hand_R"] = _palm_down((0.06, -0.42, -0.36), "R")
    return pose


def bench_work(p: float) -> dict:
    """Filing a part held in a vice: the left hand steadies it, the right pushes the file in four strokes."""
    stroke = math.sin(p * math.tau * 4.0)
    pose = _stand(p, 0.4)
    pose["spine_01"] = (0.2 + 0.02 * stroke, 0.0, -0.05)
    pose["spine_02"] = (0.1, 0.0, 0.0)
    pose["head"] = (0.3, 0.0, 0.05)
    pose["hand_L"] = _palm_down((-0.05, -0.42, -0.36), "L")
    file_spot = (0.04, -0.38 - 0.06 * stroke, -0.34 + 0.015 * stroke)
    pose["hand_R"] = _hand(file_spot, Vector((0.25, -1.0, -0.1)), Vector((1.0, 0.0, 0.0)), POLE_R)
    return pose


def desk_work(p: float) -> dict:
    """Typing at the desk, then looking up at the monitors for a while."""
    look = _bump(p, 0.5, 0.35)
    tap = math.sin(p * math.tau * 12.0) * (1.0 - look)
    pose = _stand(p, 0.3)
    pose["spine_01"] = (0.14, 0.0, 0.0)
    pose["head"] = (0.28 - 0.4 * look, 0.0, 0.25 * look)
    pose["hand_L"] = _palm_down((-0.1, -0.42, -0.34 + 0.012 * tap), "L")
    pose["hand_R"] = _palm_down((0.1, -0.42, -0.34 - 0.012 * tap), "R")
    return pose


def board_idle(p: float) -> dict:
    """Arms crossed, now and then turning to look back at the mission board."""
    turn = _bump(p, 0.35, 0.4)
    pose = _stand(p, 0.8)
    pose["spine_02"] = (0.02, 0.0, 0.15 * turn)
    pose["spine_03"] = (0.0, 0.0, 0.2 * turn)
    pose["head"] = (0.04 - 0.08 * turn, 0.0, 0.7 * turn)
    pose["hand_L"] = _hand((-0.32, -0.2, -0.3), Vector((-1.0, -0.2, 0.15)), PALM_IN, FOLD_POLE_L)
    pose["hand_R"] = _hand((0.32, -0.25, -0.24), Vector((1.0, -0.2, 0.15)), PALM_IN, FOLD_POLE_R)
    return pose


def greet(p: float) -> dict:
    """A nod and a short lift of the right hand, from and back to the counter."""
    lift = _bump(p, 0.0, 1.0)
    nod = _bump(p, 0.15, 0.4)
    pose = counter_idle(0.0)
    pose["spine_01"] = (0.12 - 0.08 * lift, pose["spine_01"][1], 0.0)
    pose["head"] = (0.08 + 0.3 * nod, 0.0, 0.0)
    rest_spot, rest_dir, rest_palm, pole = pose["hand_R"]
    raised = Vector((-0.12, -0.22, 0.02))
    up = Vector((0.0, -0.2, 1.0)).normalized()
    palm = rest_palm.lerp(Vector((0.0, -1.0, 0.0)), lift)
    pose["hand_R"] = (rest_spot.lerp(raised, lift), rest_dir.lerp(up, lift).normalized(), palm, pole)
    return pose


CLIP_SPECS = {
    "counter_idle": (counter_idle, 90),
    "bench_work": (bench_work, 60),
    "desk_work": (desk_work, 120),
    "board_idle": (board_idle, 120),
    "greet": (greet, 36),
}


def _reach(arm) -> float:
    upper = arm.data.bones["upperarm_L"]
    return (upper.length + arm.data.bones["forearm_L"].length) / ARM_LENGTH


def _frame(along: Vector, side: Vector) -> Matrix:
    y = along.normalized()
    x = (side - y * side.dot(y)).normalized()
    return Matrix((x, y, x.cross(y))).transposed()


def rest_palm(bone) -> Vector:
    """The side the palm faces in the rest pose (armature space): forward, because tripo_rig curls the fingers
    forward (`_curl_fingers`). Square to the bone."""
    along = bone.matrix_local.to_3x3() @ Vector((0.0, 1.0, 0.0))
    return (tripo_rig.FORWARD - along * tripo_rig.FORWARD.dot(along)).normalized()


def _point_hand(pbone, direction: Vector, palm: Vector) -> None:
    """Points a hand bone's fingers along `direction` with its palm facing `palm` (armature space)."""
    rest = pbone.bone.matrix_local.to_3x3()
    local = rest.inverted() @ rest_palm(pbone.bone)
    basis = _frame(direction, palm) @ _frame(Vector((0.0, 1.0, 0.0)), local).transposed()
    pbone.matrix = Matrix.Translation(pbone.head.copy()) @ basis.to_4x4()


def _apply(arm, pose: dict) -> None:
    for pbone in arm.pose.bones:
        pbone.rotation_mode = "QUATERNION"
        pbone.rotation_quaternion = Quaternion()
        pbone.location = Vector()
    pelvis = arm.pose.bones["pelvis"]
    pelvis.location = pelvis.bone.matrix_local.to_3x3().inverted() @ pose["hips"]
    for name, euler in pose.items():
        if name in arm.pose.bones and not name.startswith("hand_"):
            arm.pose.bones[name].rotation_quaternion = player_clips._world_turn(arm.pose.bones[name], euler)
    bpy.context.view_layer.update()
    chest = player_clips._chest(arm)
    turn = chest.to_3x3()
    scale = _reach(arm)
    for side in ("L", "R"):
        spot, direction, palm, pole = pose[f"hand_{side}"]
        shoulder = arm.data.bones[f"upperarm_{side}"].head_local
        player_clips._solve_arm(arm, side, chest @ (shoulder + spot * scale), turn @ pole)
        _point_hand(arm.pose.bones[f"hand_{side}"], turn @ direction, turn @ palm)
        bpy.context.view_layer.update()


def build_clip(arm, name: str):
    """Poses every frame with no action assigned, then keys the samples into one NLA track."""
    function, frames = CLIP_SPECS[name]
    arm.animation_data.action = None
    samples = []
    for frame in range(frames + 1):
        _apply(arm, function(frame / frames))
        samples.append(player_clips._record(arm))
    action = bpy.data.actions.new(name)
    action.use_fake_user = True
    arm.animation_data.action = action
    for frame, (rotations, hips) in enumerate(samples):
        for bone, rotation in rotations.items():
            arm.pose.bones[bone].rotation_quaternion = rotation
            arm.pose.bones[bone].keyframe_insert("rotation_quaternion", frame=frame)
        arm.pose.bones["pelvis"].location = hips
        arm.pose.bones["pelvis"].keyframe_insert("location", frame=frame)
    arm.animation_data.action = None
    track = arm.animation_data.nla_tracks.new()
    track.name = name
    track.strips.new(name, 0, action)
    return action


def build_clips(arm) -> None:
    """Adds the five keeper clips to `arm` and leaves it in its rest pose for checks and export."""
    bpy.context.scene.render.fps = FPS
    arm.animation_data_create()
    arm.animation_data.use_nla = False
    for name in CLIPS:
        build_clip(arm, name)
    for pbone in arm.pose.bones:
        pbone.rotation_quaternion = Quaternion()
        pbone.location = Vector()
    bpy.context.view_layer.update()
