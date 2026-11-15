"""Zombie skin, head readability and glow rules on the shared character skeleton."""

import character_checks
import gear_paint

JOINTS = {"shambler": {}, "crawler": {}, "bloater": {}}
TRIANGLES = {"shambler": (6_000, 8_000), "crawler": (6_000, 8_000), "bloater": (7_000, 9_000)}
FINISHES = ("ZombieSkin", "ZombieCloth", "ZombieShoe", "ZombieGlow")


def _weights(obj, vertex):
    return {obj.vertex_groups[item.group].name: item.weight for item in vertex.groups if item.weight > 0.0}


def _value(material):
    shader = next((node for node in material.node_tree.nodes if node.type == "BSDF_PRINCIPLED"), None)
    color = shader.inputs["Base Color"].default_value if shader else material.diffuse_color
    if shader and shader.inputs["Base Color"].is_linked:
        node = shader.inputs["Base Color"].links[0].from_node
        if node.type == "MIX":
            color = next(socket.default_value for socket in node.inputs if socket.name == "B" and socket.type == "RGBA")
    return sum(channel * weight for channel, weight in zip(color[:3], (0.2126, 0.7152, 0.0722), strict=True))


def _check_materials(meshes):
    errors = []
    materials = {material for obj in meshes for material in obj.data.materials if material}
    head = next((material for material in materials if material.name.startswith("ZombieSkinHead")), None)
    if head is None:
        errors.append("zombies need the light head material ZombieSkinHead")
    for material in materials:
        if not material.name.startswith(FINISHES):
            errors.append(f"material '{material.name}' must map to a Zombie* finish")
        if (
            head
            and material != head
            and not material.name.startswith("ZombieGlow")
            and _value(material) >= _value(head)
        ):
            errors.append(f"head must be lighter than material '{material.name}'")
    for obj in meshes:
        if any(material.name.startswith("ZombieGlow") for material in obj.data.materials if material):
            if obj.name not in {"EyeL", "EyeR", "Belly"}:
                errors.append(f"{obj.name}: only eyes and the Bloater Belly may glow")
        try:
            shares = gear_paint.zone_shares(obj)
            if shares[gear_paint.ZONE_MAIN] < 1.0 - 1e-6:
                errors.append(f"{obj.name}: zombie zones must stay main; no dye or rarity zones")
        except ValueError as error:
            errors.append(f"{obj.name}: every face needs a main zone: {error}")
    return errors


def _check_special_parts(nodes, stem):
    errors = []
    for name in ("Body", "EyeL", "EyeR"):
        if name not in nodes or nodes[name].type != "MESH":
            errors.append(f"missing zombie mesh '{name}'")
    if stem == "bloater":
        belly = nodes.get("Belly")
        if belly is None or belly.type != "MESH":
            errors.append("Bloater needs a separate glowing Belly mesh")
        else:
            if not any(mat and mat.name.startswith("ZombieGlow") for mat in belly.data.materials):
                errors.append("Belly must use ZombieGlow")
            if any(_weights(belly, vertex) != {"spine_01": 1.0} for vertex in belly.data.vertices):
                errors.append("Belly must be bound rigidly to spine_01")
    return errors


def check(objects: list, stem: str) -> list:
    """Reuse character bone/weight checks while keeping zombie-only finish and glow rules."""
    nodes = {obj.name: obj for obj in objects}
    meshes = [obj for obj in objects if obj.type == "MESH"]
    armatures = [obj for obj in objects if obj.type == "ARMATURE"]
    errors = character_checks._check_skin(meshes, armatures, "characters")
    errors += character_checks._check_facing(objects, armatures)
    errors += _check_materials(meshes) + _check_special_parts(nodes, stem)
    triangles = sum(len(face.vertices) - 2 for obj in meshes for face in obj.data.polygons)
    low, high = TRIANGLES[stem]
    if not low <= triangles <= high:
        errors.append(f"{triangles} triangles, '{stem}' must have {low}-{high}")
    if stem == "crawler":
        for obj in meshes:
            if any(
                name.startswith(("thigh_", "shin_", "foot_")) for v in obj.data.vertices for name in _weights(obj, v)
            ):
                errors.append(f"{obj.name}: Crawler must have no vertices weighted to leg bones")
    return errors
