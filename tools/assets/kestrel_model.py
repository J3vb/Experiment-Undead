"""Kestrel SMG: compact receiver, folding skeleton stock and serviceable moving parts."""


def receiver_details(m, metal, black, olive):
    """Bevelled upper and ventilated polymer fore-end with a short accessory rail."""
    receiver = m.box("Receiver", (0.05, 0.28, 0.065), (0, 0, 0), metal, bevel=0.005)
    parts = [
        m.box("Lower", (0.045, 0.19, 0.035), (0, -0.02, -0.044), black, bevel=0.004),
        m.box("Handguard", (0.058, 0.13, 0.061), (0, 0.19, -0.003), olive, bevel=0.008),
        m.box("MagWell", (0.045, 0.064, 0.032), (0, 0.055, -0.057), black, bevel=0.004),
        m.box("TopRail", (0.028, 0.29, 0.009), (0, 0.035, 0.037), black, bevel=0.002),
        m.box("EjectionPort", (0.002, 0.078, 0.023), (0.0255, 0.024, 0.01), black),
        m.box("BoltTrack", (0.002, 0.106, 0.008), (0.026, -0.035, 0.017), black),
        m.box("MagCatch", (0.004, 0.019, 0.012), (0.025, 0.055, -0.044), metal, bevel=0.001),
    ]
    for i in range(8):
        parts.append(m.box(f"RailTooth{i}", (0.031, 0.014, 0.005), (0, -0.09 + i * 0.034, 0.044), metal))
    for side in (-1, 1):
        for i in range(3):
            parts.append(m.box(f"Vent{side}{i}", (0.002, 0.022, 0.012), (side * 0.029, 0.15 + i * 0.033, 0.004), black))
        parts.append(m.cylinder(f"BodyPin{side}", 0.004, 0.003, (side * 0.026, -0.1, -0.012), black, axis="x"))
    m.join_into(receiver, parts)
    return receiver


def stock(m, receiver, metal, black, olive):
    """A real hinge pivot and open skeleton stock keep the compact silhouette readable."""
    hinge_at = (0, -0.145, -0.006)
    folding = m.cylinder("FoldingStock", 0.018, 0.065, hinge_at, metal, axis="z")
    parts = [
        m.box("StockLatch", (0.008, 0.025, 0.018), (0.021, -0.145, -0.008), black, bevel=0.002),
        m.box("CheekRest", (0.042, 0.12, 0.018), (0, -0.258, 0.02), olive, bevel=0.004),
        m.box("ButtFrame", (0.045, 0.024, 0.086), (0, -0.342, -0.022), metal, bevel=0.004),
        m.box("ButtPad", (0.049, 0.012, 0.09), (0, -0.358, -0.022), black, bevel=0.003),
    ]
    for side in (-1, 1):
        parts.append(
            m.box(f"StockStrut{side}", (0.008, 0.19, 0.012), (side * 0.018, -0.246, -0.006), metal, bevel=0.002)
        )
    m.join_into(folding, parts)
    m.attach(folding, hinge_at, receiver)


def controls(m, receiver, metal, black, olive):
    """Grip, trigger and guarded iron sights stay named, with a trigger pin origin."""
    grip = m.box("Grip", (0.036, 0.051, 0.108), (0, -0.1, -0.105), olive, bevel=0.008)
    grip.rotation_euler.x = -0.22
    m.attach(grip, (0, -0.09, -0.055), receiver)
    guard = [
        m.box("TriggerGuard", (0.014, 0.068, 0.007), (0, -0.034, -0.092), black, bevel=0.002),
        m.box("GuardPost", (0.014, 0.008, 0.036), (0, -0.004, -0.075), black, bevel=0.002),
        m.box("Safety", (0.005, 0.023, 0.007), (-0.025, -0.07, -0.028), metal, bevel=0.001),
    ]
    m.join_into(receiver, guard)
    trigger = m.box("Trigger", (0.006, 0.011, 0.025), (0, -0.043, -0.072), metal, bevel=0.002)
    m.attach(trigger, (0, -0.043, -0.059), receiver)
    sights = m.box("IronSights", (0.036, 0.018, 0.009), (0, -0.109, 0.047), black, bevel=0.002)
    parts = [m.box("FrontPost", (0.004, 0.009, 0.018), (0, 0.244, 0.054), metal, bevel=0.001)]
    for side in (-1, 1):
        parts += [
            m.box(f"RearNotch{side}", (0.007, 0.018, 0.02), (side * 0.013, -0.109, 0.06), metal, bevel=0.001),
            m.box(f"FrontGuard{side}", (0.005, 0.018, 0.032), (side * 0.017, 0.244, 0.05), black, bevel=0.001),
        ]
    m.join_into(sights, parts)
    m.attach(sights, (0, -0.109, 0.047), receiver)


def moving_parts(m, receiver, metal, black, olive):
    """Magazine origin at the feed lip, bolt handle parented to its sliding carrier."""
    magazine = m.box("Magazine", (0.032, 0.048, 0.16), (0, 0.055, -0.145), black, bevel=0.004)
    parts = [m.box("MagBase", (0.038, 0.056, 0.01), (0, 0.055, -0.228), olive, bevel=0.002)]
    for side in (-1, 1):
        for i in range(2):
            parts.append(
                m.box(f"MagRib{side}{i}", (0.002, 0.005, 0.115), (side * 0.016, 0.044 + i * 0.022, -0.151), metal)
            )
    m.join_into(magazine, parts)
    m.attach(magazine, (0, 0.055, -0.065), receiver)
    bolt = m.box("Bolt", (0.012, 0.047, 0.015), (0.029, -0.025, 0.016), metal, bevel=0.002)
    m.attach(bolt, (0.029, -0.025, 0.016), receiver)
    handle = m.box("ChargingHandle", (0.023, 0.016, 0.013), (0.041, -0.025, 0.016), black, bevel=0.003)
    m.attach(handle, (0.033, -0.025, 0.016), bolt)


def build_kestrel_smg(m):
    """Build in metres along Blender +Y (Godot -Z), retaining the shared animation nodes."""
    metal = m.material("GunMetal", m.GUN_METAL, metallic=0.8, roughness=0.4)
    black = m.material("MatteBlack", m.MATTE_BLACK, roughness=0.75)
    olive = m.material("OlivePolymer", m.srgb("#5F6D68"), roughness=0.85)
    receiver = receiver_details(m, metal, black, olive)
    stock(m, receiver, metal, black, olive)
    controls(m, receiver, metal, black, olive)
    moving_parts(m, receiver, metal, black, olive)
    barrel = m.cylinder("Barrel", 0.011, 0.1, (0, 0.299, 0.008), metal)
    parts = [
        m.cylinder("MuzzleCap", 0.015, 0.027, (0, 0.349, 0.008), black),
        m.cylinder("MuzzleBore", 0.008, 0.001, (0, 0.363, 0.008), black),
    ]
    m.join_into(barrel, parts)
    m.attach(barrel, (0, 0.249, 0.008), receiver)
    m.marker("Muzzle", (0, 0.364, 0.008), parent=receiver)
