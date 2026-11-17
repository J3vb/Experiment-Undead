"""Third-person player clips keyed on the shared skeleton and exported as one NLA track each.

Poses are sampled from functions of the cycle phase, so loops end where they start.
Angles are body-space Euler (x pitch, y roll, z yaw) relative to the parent bone.
Arms are solved with two-bone IK to hand targets in chest space, so the gun hold
stays fixed to the torso while it bobs, leans or kicks.
"""

import math

import bpy
from mathutils import Euler, Matrix, Quaternion, Vector

FPS = 30
LOOPS = (
    "idle",
    "walk_fwd",
    "walk_back",
    "walk_left",
    "walk_right",
    "run",
    "crouch_idle",
    "crouch_walk",
    "downed_idle",
    "downed_crawl",
)
ONE_SHOTS = ("fire", "reload")
CLIPS = LOOPS + ONE_SHOTS
WALK_FRAMES = 18
RUN_FRAMES = 14
WALK_SWING = 0.55
RUN_SWING = 0.8
# Gun hold in rest chest space (Blender metres; the body faces -Y, its right is -X).
GRIP_R = Vector((-0.14, -0.27, 1.19))
# The support hand sits this far along the gun from the grip hand, and this far below its line.
REACH_L = 0.36
UNDER_L = 0.035
GUN_DIR = Vector((0.1, -1.0, -0.1)).normalized()
POLE_R = Vector((-0.45, 0.35, -1.0))
POLE_L = Vector((0.3, 0.1, -1.0))
SPRINT_GRIP_R = Vector((-0.16, -0.2, 1.1))
SPRINT_DIR = Vector((0.6, -0.75, 0.25)).normalized()


def _pose(**bones):
    pose = {"hips": Vector((0.0, 0.0, 0.0)), "grip": (GRIP_R, REACH_L, GUN_DIR, 0.0)}
    pose.update(bones)
    return pose


def _legs(pose, swing, lift, side=0.0):
    """Alternating legs: `swing` + forward for the left leg, `lift` bends the knee in recovery."""
    pose["thigh_L"] = (-swing, side, 0.0)
    pose["thigh_R"] = (swing, -side, 0.0)
    pose["shin_L"] = (max(0.0, -lift), 0.0, 0.0)
    pose["shin_R"] = (max(0.0, lift), 0.0, 0.0)
    pose["foot_L"] = (swing * 0.4, 0.0, 0.0)
    pose["foot_R"] = (-swing * 0.4, 0.0, 0.0)


def idle(p):
    breath = math.sin(p * math.tau)
    pose = _pose(spine_02=(0.03 + 0.015 * breath, 0.0, 0.0), spine_03=(0.0, 0.0, 0.0), head=(0.02 * breath, 0.0, 0.0))
    pose["hips"] = Vector((0.0, 0.0, -0.01 + 0.004 * breath))
    pose["thigh_L"], pose["thigh_R"] = (-0.04, 0.05, 0.0), (0.03, -0.05, 0.0)
    pose["shin_L"], pose["shin_R"] = (0.08, 0.0, 0.0), (0.05, 0.0, 0.0)
    return pose


def _stride(p, swing, lean, bob):
    s = math.sin(p * math.tau)
    c = math.cos(p * math.tau)
    pose = _pose(spine_01=(lean, 0.0, -0.06 * s), spine_02=(0.04, 0.0, 0.0), spine_03=(0.0, 0.0, 0.05 * s))
    pose["pelvis"] = (0.0, 0.05 * s, 0.07 * s)
    pose["head"] = (-lean * 0.6, 0.0, -0.04 * s)
    pose["hips"] = Vector((0.0, 0.0, -bob * abs(c)))
    _legs(pose, swing * s, swing * 1.8 * c)
    return pose


def walk_fwd(p):
    return _stride(p, WALK_SWING, 0.08, 0.035)


def walk_back(p):
    return walk_fwd(1.0 - p)


def _side_step(p, sign):
    s = math.sin(p * math.tau)
    c = math.cos(p * math.tau)
    pose = _pose(spine_02=(0.05, 0.0, 0.0), spine_03=(0.0, 0.0, 0.0))
    pose["hips"] = Vector((0.0, 0.0, -0.03 * abs(c)))
    pose["pelvis"] = (0.0, 0.05 * s * sign, 0.0)
    _legs(pose, 0.08 * s, 0.9 * c, 0.28 * s * sign)
    return pose


def walk_left(p):
    return _side_step(p, 1.0)


def walk_right(p):
    return _side_step(p, -1.0)


def run(p):
    pose = _stride(p, RUN_SWING, 0.22, 0.06)
    pose["grip"] = (SPRINT_GRIP_R, REACH_L, SPRINT_DIR, 0.4)
    return pose


def _crouch(p, swing):
    s = math.sin(p * math.tau)
    c = math.cos(p * math.tau)
    pose = _pose(spine_01=(0.28, 0.0, 0.0), spine_02=(0.08, 0.0, 0.0), head=(-0.3, 0.0, 0.0))
    pose["hips"] = Vector((0.0, -0.06, -0.36 - 0.015 * abs(c) * (swing > 0.0)))
    pose["thigh_L"] = (-1.15 - swing * s, 0.08, 0.0)
    pose["thigh_R"] = (-0.55 + swing * s, -0.08, 0.0)
    pose["shin_L"] = (1.55 + max(0.0, -c) * swing, 0.0, 0.0)
    pose["shin_R"] = (1.65 + max(0.0, c) * swing, 0.0, 0.0)
    pose["foot_L"] = (-0.35, 0.0, 0.0)
    pose["foot_R"] = (-0.95, 0.0, 0.0)
    return pose


def crouch_idle(p):
    pose = _crouch(p, 0.0)
    pose["spine_02"] = (0.08 + 0.012 * math.sin(p * math.tau), 0.0, 0.0)
    return pose


def crouch_walk(p):
    return _crouch(p, 0.3)


def _downed(p, push):
    s = math.sin(p * math.tau)
    pose = _pose(spine_01=(0.45, 0.0, 0.03 * s), spine_02=(0.2, 0.0, 0.0), spine_03=(0.15, 0.0, 0.0))
    pose["pelvis"] = (-1.15, 0.0, 0.0)
    pose["hips"] = Vector((0.0, 0.18, -0.74))
    pose["head"] = (0.3, 0.0, 0.0)
    pose["thigh_L"] = (-0.25 - push * s, 0.1, 0.0)
    pose["thigh_R"] = (-0.05 + push * s, -0.12, 0.0)
    pose["shin_L"] = (0.5 + push * max(0.0, s), 0.0, 0.0)
    pose["shin_R"] = (0.15 + push * max(0.0, -s), 0.0, 0.0)
    pose["foot_L"] = (-0.4, 0.0, 0.0)
    pose["foot_R"] = (-0.3, 0.0, 0.0)
    # Left hand props the body up on the floor; the right holds the sidearm forward.
    pose["grip"] = (Vector((-0.12, -0.42, 1.30)), None, Vector((0.0, -1.0, 0.25)).normalized(), 0.0)
    pose["floor_L"] = Vector((0.32, 0.30 + 0.04 * s * (push > 0.0), 0.02))
    return pose


def downed_idle(p):
    return _downed(p, 0.0)


def downed_crawl(p):
    return _downed(p, 0.45)


def fire(p):
    kick = math.sin(min(p * 3.0, 1.0) * math.pi) if p < 0.34 else 0.0
    settle = max(0.0, 1.0 - p) * 0.15 * kick
    pose = idle(0.0)
    pose["spine_03"] = (-0.07 * kick, 0.0, 0.0)
    pose["clavicle_R"] = (0.0, 0.0, 0.05 * kick + settle)
    back = Vector((0.0, 0.035, 0.012)) * kick
    pose["grip"] = (GRIP_R + back, REACH_L, GUN_DIR, 0.0)
    return pose


def reload(p):
    tilt = math.sin(min(p / 0.85, 1.0) * math.pi)
    pose = idle(0.0)
    pose["head"] = (0.25 * tilt, 0.0, 0.1 * tilt)
    dip = Vector((0.03, 0.06, -0.06)) * tilt
    gun = GUN_DIR.lerp(Vector((0.4, -0.8, 0.3)).normalized(), tilt).normalized()
    guard = GRIP_R + GUN_DIR * REACH_L + Vector((0.0, 0.0, -UNDER_L))
    well = GRIP_R + dip + Vector((0.05, -0.12, -0.1))
    pouch = Vector((0.13, -0.1, 0.97))
    if p < 0.25:
        left = guard.lerp(well, p / 0.25)
    elif p < 0.5:
        left = well.lerp(pouch, (p - 0.25) / 0.25)
    elif p < 0.75:
        left = pouch.lerp(well, (p - 0.5) / 0.25)
    else:
        left = well.lerp(guard, (p - 0.75) / 0.25)
    pose["grip"] = (GRIP_R + dip, left, gun, 0.6 * tilt)
    return pose


CLIP_SPECS = {
    "idle": (idle, 60),
    "walk_fwd": (walk_fwd, WALK_FRAMES),
    "walk_back": (walk_back, WALK_FRAMES),
    "walk_left": (walk_left, WALK_FRAMES),
    "walk_right": (walk_right, WALK_FRAMES),
    "run": (run, RUN_FRAMES),
    "crouch_idle": (crouch_idle, 60),
    "crouch_walk": (crouch_walk, 24),
    "downed_idle": (downed_idle, 60),
    "downed_crawl": (downed_crawl, 36),
    "fire": (fire, 6),
    "reload": (reload, 48),
}


def _world_turn(bone, euler):
    rest = bone.bone.matrix_local.to_quaternion()
    return rest.inverted() @ Euler(euler).to_quaternion() @ rest


def _aim(pbone, head, direction, roll=0.0):
    """Points a pose bone from `head` along `direction` (armature space) with the least twist."""
    rest = pbone.bone.matrix_local.to_quaternion()
    rest_dir = rest @ Vector((0.0, 1.0, 0.0))
    turn = rest_dir.rotation_difference(direction.normalized())
    turn = Quaternion(direction.normalized(), roll) @ turn
    pbone.matrix = Matrix.Translation(head) @ (turn @ rest).to_matrix().to_4x4()


def _hold(pbone, head, direction, up, roll=0.0):
    """Points a hand bone along `direction` with its Z axis toward `up`, so a held gun stays upright."""
    y = direction.normalized()
    z = (up - y * up.dot(y)).normalized()
    z = Quaternion(y, roll) @ z
    x = y.cross(z)
    basis = Matrix((x, y, z)).transposed()
    pbone.matrix = Matrix.Translation(head) @ basis.to_4x4()


def _solve_arm(arm, side, target, pole):
    upper = arm.pose.bones[f"upperarm_{side}"]
    fore = arm.pose.bones[f"forearm_{side}"]
    a = upper.bone.length
    b = fore.bone.length
    shoulder = upper.head.copy()
    to_target = target - shoulder
    d = min(max(to_target.length, 0.05), (a + b) * 0.999)
    axis = to_target.normalized()
    cos_a = (a * a + d * d - b * b) / (2.0 * a * d)
    bend = pole - axis * pole.dot(axis)
    bend = bend.normalized() if bend.length > 1e-6 else Vector((0.0, 0.0, -1.0))
    elbow = shoulder + axis * a * cos_a + bend * a * math.sqrt(max(0.0, 1.0 - cos_a * cos_a))
    _aim(upper, shoulder, elbow - shoulder)
    bpy.context.view_layer.update()
    _aim(fore, fore.head.copy(), shoulder + axis * d - fore.head)
    bpy.context.view_layer.update()


def _chest(arm):
    bone = arm.pose.bones["spine_03"]
    return bone.matrix @ bone.bone.matrix_local.inverted()


def _apply(arm, pose):
    for pbone in arm.pose.bones:
        pbone.rotation_mode = "QUATERNION"
        pbone.rotation_quaternion = Quaternion()
        pbone.location = Vector()
    pelvis = arm.pose.bones["pelvis"]
    pelvis.location = pelvis.bone.matrix_local.to_3x3().inverted() @ pose["hips"]
    for name, euler in pose.items():
        if name in arm.pose.bones:
            arm.pose.bones[name].rotation_quaternion = _world_turn(arm.pose.bones[name], euler)
    bpy.context.view_layer.update()
    chest = _chest(arm)
    grip_r, grip_l, gun_dir, roll = pose["grip"]
    _solve_arm(arm, "R", chest @ grip_r, chest.to_3x3() @ POLE_R)
    gun = (chest.to_3x3() @ gun_dir).normalized()
    up = chest.to_3x3() @ Vector((0.0, 0.0, 1.0))
    _hold(arm.pose.bones["hand_R"], arm.pose.bones["hand_R"].head.copy(), gun, up, roll)
    bpy.context.view_layer.update()
    if grip_l is None:
        left = pose["floor_L"]
    elif isinstance(grip_l, Vector):
        left = chest @ grip_l
    else:
        left = arm.pose.bones["hand_R"].head + gun * grip_l - up * UNDER_L
    _solve_arm(arm, "L", left, chest.to_3x3() @ POLE_L)
    hand_l = arm.pose.bones["hand_L"]
    if grip_l is None:
        _aim(hand_l, hand_l.head.copy(), Vector((0.4, 0.0, -1.0)))
    else:
        _hold(hand_l, hand_l.head.copy(), gun, up)
    bpy.context.view_layer.update()


def _record(arm):
    bones = {pbone.name: pbone.rotation_quaternion.copy() for pbone in arm.pose.bones if pbone.bone.use_deform}
    return bones, arm.pose.bones["pelvis"].location.copy()


def build_clip(arm, name):
    """Poses every frame with no action assigned, so depsgraph updates cannot replay old keys mid-pose."""
    function, frames = CLIP_SPECS[name]
    arm.animation_data.action = None
    samples = []
    for frame in range(frames + 1):
        _apply(arm, function(frame / frames))
        samples.append(_record(arm))
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


def build_clips(arm):
    """Adds every clip to `arm` and leaves it in its rest pose for binding checks and export."""
    bpy.context.scene.render.fps = FPS
    arm.animation_data_create()
    # NLA playback off: finished clips cannot replay into the next one's poses, the source
    # scene stays in rest pose for checks, and the exporter still reads each track.
    arm.animation_data.use_nla = False
    for name in CLIPS:
        build_clip(arm, name)
    for pbone in arm.pose.bones:
        pbone.rotation_quaternion = Quaternion()
        pbone.location = Vector()
    bpy.context.view_layer.update()
