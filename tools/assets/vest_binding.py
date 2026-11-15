"""Keep stacked carrier fabric and hardware together while the wearer bends."""

from itertools import pairwise

import character_rig as rig

SPINE_CENTRES = (("pelvis", 1.00), ("spine_01", 1.13), ("spine_02", 1.275), ("spine_03", 1.42))


def bind_torso(obj, armature):
    """Blend carrier layers by height; anchor harness crests on their shoulders."""
    rig.bind(obj, armature, blend=0.16)
    for vertex in obj.data.vertices:
        point = obj.matrix_world @ vertex.co
        if point.z > 1.47:
            if not obj.name.startswith("ShoulderWebbing"):
                continue
            weights = {"clavicle_L" if point.x > 0 else "clavicle_R": 1.0}
        else:
            weights = {"spine_03": 1.0}
            for (name, lower), (following, upper) in pairwise(SPINE_CENTRES):
                if point.z <= upper:
                    amount = max(0.0, min(1.0, (point.z - lower) / (upper - lower)))
                    weights = {name: 1.0 - amount, following: amount}
                    break
        for influence in list(vertex.groups):
            obj.vertex_groups[influence.group].remove([vertex.index])
        for name, weight in weights.items():
            if weight > 0:
                obj.vertex_groups[name].add([vertex.index], weight, "REPLACE")
