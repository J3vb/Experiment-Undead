"""Build the Talon precision rifle with the shared Blender model primitives."""


def receiver_parts(m, metal, black, grey, parts):
    """Bevelled upper and ventilated handguard around the exposed heavy barrel."""
    parts += [
        m.box("Upper", (0.056, 0.35, 0.058), (0, 0, 0.019), metal, bevel=0.006),
        m.box("Lower", (0.048, 0.24, 0.048), (0, -0.015, -0.029), black, bevel=0.006),
        m.box("MagWell", (0.049, 0.091, 0.035), (0, 0.065, -0.06), metal, bevel=0.004),
        m.box("Handguard", (0.061, 0.32, 0.065), (0, 0.326, 0.016), grey, bevel=0.011),
        m.box("HandguardNose", (0.052, 0.022, 0.052), (0, 0.495, 0.016), black, bevel=0.005),
        m.box("TopRail", (0.027, 0.65, 0.01), (0, 0.145, 0.053), black),
        m.box("EjectionPort", (0.003, 0.088, 0.024), (0.029, 0.005, 0.023), black),
        m.box("PortLip", (0.005, 0.095, 0.005), (0.03, 0.005, 0.039), metal),
        m.box("GuardBow", (0.014, 0.076, 0.009), (0, -0.058, -0.094), black),
        m.box("GuardFront", (0.014, 0.01, 0.034), (0, -0.024, -0.078), black),
    ]
    grip = m.box("Grip", (0.037, 0.049, 0.111), (0, -0.122, -0.104), black, bevel=0.009)
    grip.rotation_euler.x = -0.24
    parts.append(grip)
    for index in range(20):
        parts.append(m.box(f"RailTooth{index}", (0.031, 0.012, 0.005), (0, -0.16 + index * 0.031, 0.061), metal))
    for side in (-1, 1):
        parts.append(m.box(f"GripPanel{side}", (0.003, 0.031, 0.053), (side * 0.018, -0.132, -0.107), grey))
        for index in range(5):
            parts.append(
                m.box(
                    f"HandguardVent{side}_{index}",
                    (0.002, 0.037, 0.015),
                    (side * 0.0305, 0.217 + index * 0.051, 0.025),
                    black,
                )
            )


def precision_stock(m, receiver, metal, black, grey):
    """Open fixed stock with a cheek riser, adjustment wheel and rubber recoil pad."""
    stock = m.box("Stock", (0.044, 0.245, 0.034), (0, -0.29, 0.011), grey, bevel=0.007)
    brace = m.box("StockBrace", (0.034, 0.228, 0.026), (0, -0.299, -0.04), grey, bevel=0.006)
    brace.rotation_euler.x = 0.24
    pieces = [
        brace,
        m.box("StockSocket", (0.047, 0.042, 0.062), (0, -0.185, -0.003), metal),
        m.box("RecoilPad", (0.052, 0.025, 0.124), (0, -0.42, -0.022), black, bevel=0.006),
        m.box("CheekRiser", (0.046, 0.164, 0.026), (0, -0.298, 0.049), black, bevel=0.007),
        m.box("RiserPost", (0.025, 0.025, 0.024), (0, -0.31, 0.029), metal),
        m.cylinder("RiserWheel", 0.012, 0.008, (0.028, -0.31, 0.018), metal, axis="x"),
        m.box("SlingSlot", (0.003, 0.032, 0.009), (0.023, -0.377, 0.01), black),
    ]
    m.join_into(stock, pieces)
    m.attach(stock, (0, -0.17, 0), receiver)


def scope_parts(m, receiver, metal, black, glass):
    """Three-power optic; rear lens and mount match the existing picture-in-picture disc."""
    optic = m.cylinder("Optic", 0.015, 0.31, (0, 0.055, 0.09), black)
    pieces = [
        m.box("ScopeMountRear", (0.032, 0.025, 0.031), (0, -0.048, 0.069), black, bevel=0.003),
        m.box("ScopeMountFront", (0.032, 0.025, 0.031), (0, 0.158, 0.069), black, bevel=0.003),
        m.cylinder("ScopeRingRear", 0.0185, 0.015, (0, -0.048, 0.09), metal),
        m.cylinder("ScopeRingFront", 0.0185, 0.015, (0, 0.158, 0.09), metal),
        m.cylinder("ObjectiveShoulder", 0.021, 0.038, (0, 0.225, 0.09), black),
        m.cylinder("ObjectiveBell", 0.026, 0.062, (0, 0.273, 0.09), black),
        m.cylinder("ObjectiveRim", 0.0265, 0.009, (0, 0.306, 0.09), metal),
        m.cylinder("Eyepiece", 0.019, 0.05, (0, -0.095, 0.09), black),
        m.cylinder("EyeRing", 0.0195, 0.008, (0, -0.122, 0.09), metal),
        m.cylinder("EyeLens", 0.016, 0.002, (0, -0.126, 0.09), glass),
        m.cylinder("ElevationTurret", 0.012, 0.022, (0, 0.039, 0.113), metal, axis="z"),
        m.cylinder("WindageTurret", 0.01, 0.022, (0.022, 0.039, 0.09), metal, axis="x"),
    ]
    m.join_into(optic, pieces)
    m.attach(optic, (0, 0.055, 0.09), receiver)
    m.cylinder("OpticGlass", 0.023, 0.002, (0, 0.311, 0.09), glass, parent=receiver)
    m.marker("ScopeLensMount", (0, -0.128, 0.09), parent=receiver)


def barrel_parts(m, receiver, metal, black):
    """Long heavy barrel, ported brake and a folded bipod under the handguard."""
    barrel = m.cylinder("Barrel", 0.013, 0.35, (0, 0.65, 0.016), metal)
    pieces = [
        m.cylinder("BarrelCollar", 0.018, 0.035, (0, 0.5, 0.016), black),
        m.cylinder("GasBlock", 0.018, 0.028, (0, 0.591, 0.016), black),
        m.cylinder("GasTube", 0.005, 0.12, (0, 0.535, 0.036), metal),
    ]
    m.join_into(barrel, pieces)
    m.attach(barrel, (0, 0.475, 0.016), receiver)
    brake = m.box("MuzzleBrake", (0.036, 0.071, 0.033), (0, 0.831, 0.016), metal, bevel=0.004)
    ports = [m.cylinder("Bore", 0.009, 0.002, (0, 0.867, 0.016), black)]
    for side in (-1, 1):
        for index in range(3):
            ports.append(
                m.box(
                    f"BrakePort{side}_{index}",
                    (0.002, 0.012, 0.017),
                    (side * 0.018, 0.808 + index * 0.021, 0.016),
                    black,
                )
            )
    m.join_into(brake, ports)
    m.attach(brake, (0, 0.831, 0.016), barrel)
    bipod = m.box("Bipod", (0.055, 0.035, 0.022), (0, 0.407, -0.026), metal, bevel=0.004)
    legs = []
    for side in (-1, 1):
        legs += [
            m.cylinder(f"FoldedLeg{side}", 0.006, 0.158, (side * 0.026, 0.483, -0.041), black),
            m.box(f"BipodFoot{side}", (0.019, 0.023, 0.015), (side * 0.026, 0.564, -0.041), black),
        ]
    m.join_into(bipod, legs)
    m.attach(bipod, (0, 0.407, -0.026), receiver)
    m.marker("Muzzle", (0, 0.868, 0.016), parent=receiver)


def moving_parts(m, receiver, metal, black, grey):
    """Magazine pivots at its feed lips; the charging handle travels with the bolt."""
    magazine = m.box("Magazine", (0.039, 0.082, 0.106), (0, 0.065, -0.119), black, bevel=0.005)
    pieces = [m.box("MagBase", (0.045, 0.088, 0.012), (0, 0.065, -0.175), metal, bevel=0.003)]
    for side in (-1, 1):
        for index in range(3):
            pieces.append(
                m.box(
                    f"MagRib{side}_{index}", (0.002, 0.048, 0.004), (side * 0.02, 0.065, -0.102 - index * 0.023), grey
                )
            )
    m.join_into(magazine, pieces)
    m.attach(magazine, (0, 0.065, -0.065), receiver)
    magazine.rotation_euler.x = 0.08
    bolt = m.box("Bolt", (0.012, 0.06, 0.016), (0.031, -0.019, 0.024), metal, bevel=0.003)
    m.attach(bolt, (0.031, -0.019, 0.024), receiver)
    handle = m.box("ChargingHandle", (0.028, 0.012, 0.009), (0.047, -0.035, 0.025), metal, bevel=0.003)
    m.join_into(handle, [m.box("HandleKnob", (0.012, 0.024, 0.014), (0.062, -0.035, 0.025), black, bevel=0.004)])
    m.attach(handle, (0.036, -0.035, 0.025), bolt)
    trigger = m.box("Trigger", (0.006, 0.008, 0.028), (0, -0.063, -0.067), metal, bevel=0.002)
    m.attach(trigger, (0, -0.063, -0.053), receiver)
    trigger.rotation_euler.x = -0.15


def build_talon_dmr(m) -> None:
    """Build from shared helpers supplied by build_models, keeping all runtime part names."""
    metal = m.material("GunMetal", m.GUN_METAL, metallic=0.8, roughness=0.4)
    black = m.material("MatteBlack", m.MATTE_BLACK, roughness=0.75)
    grey = m.material("GreyPolymer", m.srgb("#5F6D68"), roughness=0.8)
    glass = m.material("OpticGlass", m.LENS, metallic=0.3, roughness=0.05)
    receiver = m.box("Receiver", (0.045, 0.12, 0.03), (0, 0, 0), metal, bevel=0.004)
    pieces = []
    receiver_parts(m, metal, black, grey, pieces)
    m.join_into(receiver, pieces)
    precision_stock(m, receiver, metal, black, grey)
    scope_parts(m, receiver, metal, black, glass)
    barrel_parts(m, receiver, metal, black)
    moving_parts(m, receiver, metal, black, grey)
