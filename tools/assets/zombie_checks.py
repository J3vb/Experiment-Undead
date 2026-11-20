"""Zombie skin, head readability and glow rules on the shared character skeleton."""

import character_checks
import gear_paint

JOINTS = {
    "shambler": {},
    "shambler_guard": {},
    "crawler": {},
    "bloater": {},
    "glower": {},
    "stalker": {},
    "brute": {},
}
TRIANGLES = {
    "shambler": (6_000, 9_000),
    "shambler_guard": (6_000, 9_000),
    "crawler": (6_000, 8_000),
    "bloater": (6_000, 9_000),
    "glower": (6_000, 9_000),
    "stalker": (6_000, 9_000),
    "brute": (6_000, 9_000),
}
FINISHES = ("ZombieSkin", "ZombieCloth", "ZombieShoe", "ZombieGlow")
## Tripo zombies (tripo_intake.py --kind zombie): one baked mesh `Body`, eyes and pale head painted in its texture.
BAKED = "ZombieBaked"


def _is_baked(meshes) -> bool:
    return any(mat and mat.name.startswith(BAKED) for obj in meshes for mat in obj.data.materials)


def _check_baked(objects, meshes) -> list:
    """One `Body` mesh with only the ZombieBaked material. The head-lighter and zone rules are skipped: the head
    tone is in the baked texture and zombies have no dye zones (DECISIONS "Gear looks")."""
    errors = []
    if [obj.name for obj in meshes] != ["Body"]:
        errors.append(f"baked zombies are one mesh named 'Body', found {sorted(obj.name for obj in meshes)}")
    for obj in meshes:
        for material in obj.data.materials:
            if material is None or not material.name.startswith(BAKED):
                errors.append(f"{obj.name}: baked zombies use only the {BAKED} material")
    center = next((obj for obj in objects if obj.name == "HeadCenter"), None)
    if center is None or center.type != "EMPTY" or center.parent_type != "BONE" or center.parent_bone != "head":
        errors.append("baked zombies need a HeadCenter empty on the head bone (ZombieRig hangs the head zone on it)")
    return errors


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
            if obj.name not in {"EyeL", "EyeR"}:
                errors.append(f"{obj.name}: only the eyes may glow on code-built zombies")
        try:
            shares = gear_paint.zone_shares(obj)
            if shares[gear_paint.ZONE_MAIN] < 1.0 - 1e-6:
                errors.append(f"{obj.name}: zombie zones must stay main; no dye or rarity zones")
        except ValueError as error:
            errors.append(f"{obj.name}: every face needs a main zone: {error}")
    return errors


def _check_special_parts(nodes):
    errors = []
    for name in ("Body", "EyeL", "EyeR"):
        if name not in nodes or nodes[name].type != "MESH":
            errors.append(f"missing zombie mesh '{name}'")
    return errors


def check(objects: list, stem: str) -> list:
    """Reuse character bone/weight checks while keeping zombie-only finish and glow rules."""
    nodes = {obj.name: obj for obj in objects}
    meshes = [obj for obj in objects if obj.type == "MESH"]
    armatures = [obj for obj in objects if obj.type == "ARMATURE"]
    errors = character_checks._check_skin(meshes, armatures, "characters")
    errors += character_checks._check_facing(objects, armatures)
    if _is_baked(meshes):
        errors += _check_baked(objects, meshes)
    else:
        errors += _check_materials(meshes) + _check_special_parts(nodes)
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
