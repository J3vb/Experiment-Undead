"""Build the Talon precision rifle with the shared Blender model primitives."""


def receiver_parts(m, metal, black, grey, parts):
    """Bevelled upper and ventilated handguard around the exposed heavy barrel."""
    parts += [
        m.box("Upper", (.056, .35, .058), (0, 0, .019), metal, bevel=.006),
        m.box("Lower", (.048, .24, .048), (0, -.015, -.029), black, bevel=.006),
        m.box("MagWell", (.049, .091, .035), (0, .065, -.06), metal, bevel=.004),
        m.box("Handguard", (.061, .32, .065), (0, .326, .016), grey, bevel=.011),
        m.box("HandguardNose", (.052, .022, .052), (0, .495, .016), black, bevel=.005),
        m.box("TopRail", (.027, .65, .01), (0, .145, .053), black),
        m.box("EjectionPort", (.003, .088, .024), (.029, .005, .023), black),
        m.box("PortLip", (.005, .095, .005), (.03, .005, .039), metal),
        m.box("GuardBow", (.014, .076, .009), (0, -.058, -.094), black),
        m.box("GuardFront", (.014, .01, .034), (0, -.024, -.078), black),
    ]
    grip = m.box("Grip", (.037, .049, .111), (0, -.122, -.104), black, bevel=.009)
    grip.rotation_euler.x = -.24
    parts.append(grip)
    for index in range(20):
        parts.append(m.box(f"RailTooth{index}", (.031, .012, .005),
                           (0, -.16 + index * .031, .061), metal))
    for side in (-1, 1):
        parts.append(m.box(f"GripPanel{side}", (.003, .031, .053),
                           (side * .018, -.132, -.107), grey))
        for index in range(5):
            parts.append(m.box(f"HandguardVent{side}_{index}", (.002, .037, .015),
                               (side * .0305, .217 + index * .051, .025), black))


def precision_stock(m, receiver, metal, black, grey):
    """Open fixed stock with a cheek riser, adjustment wheel and rubber recoil pad."""
    stock = m.box("Stock", (.044, .245, .034), (0, -.29, .011), grey, bevel=.007)
    brace = m.box("StockBrace", (.034, .228, .026), (0, -.299, -.04), grey, bevel=.006)
    brace.rotation_euler.x = .24
    pieces = [
        brace,
        m.box("StockSocket", (.047, .042, .062), (0, -.185, -.003), metal),
        m.box("RecoilPad", (.052, .025, .124), (0, -.42, -.022), black, bevel=.006),
        m.box("CheekRiser", (.046, .164, .026), (0, -.298, .049), black, bevel=.007),
        m.box("RiserPost", (.025, .025, .024), (0, -.31, .029), metal),
        m.cylinder("RiserWheel", .012, .008, (.028, -.31, .018), metal, axis="x"),
        m.box("SlingSlot", (.003, .032, .009), (.023, -.377, .01), black),
    ]
    m.join_into(stock, pieces)
    m.attach(stock, (0, -.17, 0), receiver)


def scope_parts(m, receiver, metal, black, glass):
    """Three-power optic; rear lens and mount match the existing picture-in-picture disc."""
    optic = m.cylinder("Optic", .015, .31, (0, .055, .09), black)
    pieces = [
        m.box("ScopeMountRear", (.032, .025, .031), (0, -.048, .069), black, bevel=.003),
        m.box("ScopeMountFront", (.032, .025, .031), (0, .158, .069), black, bevel=.003),
        m.cylinder("ScopeRingRear", .0185, .015, (0, -.048, .09), metal),
        m.cylinder("ScopeRingFront", .0185, .015, (0, .158, .09), metal),
        m.cylinder("ObjectiveShoulder", .021, .038, (0, .225, .09), black),
        m.cylinder("ObjectiveBell", .026, .062, (0, .273, .09), black),
        m.cylinder("ObjectiveRim", .0265, .009, (0, .306, .09), metal),
        m.cylinder("Eyepiece", .019, .05, (0, -.095, .09), black),
        m.cylinder("EyeRing", .0195, .008, (0, -.122, .09), metal),
        m.cylinder("EyeLens", .016, .002, (0, -.126, .09), glass),
        m.cylinder("ElevationTurret", .012, .022, (0, .039, .113), metal, axis="z"),
        m.cylinder("WindageTurret", .01, .022, (.022, .039, .09), metal, axis="x"),
    ]
    m.join_into(optic, pieces)
    m.attach(optic, (0, .055, .09), receiver)
    m.cylinder("OpticGlass", .023, .002, (0, .311, .09), glass, parent=receiver)
    m.marker("ScopeLensMount", (0, -.128, .09), parent=receiver)


def barrel_parts(m, receiver, metal, black):
    """Long heavy barrel, ported brake and a folded bipod under the handguard."""
    barrel = m.cylinder("Barrel", .013, .35, (0, .65, .016), metal)
    pieces = [
        m.cylinder("BarrelCollar", .018, .035, (0, .5, .016), black),
        m.cylinder("GasBlock", .018, .028, (0, .591, .016), black),
        m.cylinder("GasTube", .005, .12, (0, .535, .036), metal),
    ]
    m.join_into(barrel, pieces)
    m.attach(barrel, (0, .475, .016), receiver)
    brake = m.box("MuzzleBrake", (.036, .071, .033), (0, .831, .016), metal, bevel=.004)
    ports = [m.cylinder("Bore", .009, .002, (0, .867, .016), black)]
    for side in (-1, 1):
        for index in range(3):
            ports.append(m.box(f"BrakePort{side}_{index}", (.002, .012, .017),
                               (side * .018, .808 + index * .021, .016), black))
    m.join_into(brake, ports)
    m.attach(brake, (0, .831, .016), barrel)
    bipod = m.box("Bipod", (.055, .035, .022), (0, .407, -.026), metal, bevel=.004)
    legs = []
    for side in (-1, 1):
        legs += [
            m.cylinder(f"FoldedLeg{side}", .006, .158, (side * .026, .483, -.041), black),
            m.box(f"BipodFoot{side}", (.019, .023, .015), (side * .026, .564, -.041),
                  black),
        ]
    m.join_into(bipod, legs)
    m.attach(bipod, (0, .407, -.026), receiver)
    m.marker("Muzzle", (0, .868, .016), parent=receiver)


def moving_parts(m, receiver, metal, black, grey):
    """Magazine pivots at its feed lips; the charging handle travels with the bolt."""
    magazine = m.box("Magazine", (.039, .082, .106), (0, .065, -.119), black, bevel=.005)
    pieces = [m.box("MagBase", (.045, .088, .012), (0, .065, -.175), metal, bevel=.003)]
    for side in (-1, 1):
        for index in range(3):
            pieces.append(m.box(f"MagRib{side}_{index}", (.002, .048, .004),
                                (side * .02, .065, -.102 - index * .023), grey))
    m.join_into(magazine, pieces)
    m.attach(magazine, (0, .065, -.065), receiver)
    magazine.rotation_euler.x = .08
    bolt = m.box("Bolt", (.012, .06, .016), (.031, -.019, .024), metal, bevel=.003)
    m.attach(bolt, (.031, -.019, .024), receiver)
    handle = m.box("ChargingHandle", (.028, .012, .009), (.047, -.035, .025), metal, bevel=.003)
    m.join_into(handle, [m.box("HandleKnob", (.012, .024, .014), (.062, -.035, .025),
                              black, bevel=.004)])
    m.attach(handle, (.036, -.035, .025), bolt)
    trigger = m.box("Trigger", (.006, .008, .028), (0, -.063, -.067), metal, bevel=.002)
    m.attach(trigger, (0, -.063, -.053), receiver)
    trigger.rotation_euler.x = -.15


def build_talon_dmr(m) -> None:
    """Build from shared helpers supplied by build_models, keeping all runtime part names."""
    metal = m.material("GunMetal", m.GUN_METAL, metallic=.8, roughness=.4)
    black = m.material("MatteBlack", m.MATTE_BLACK, roughness=.75)
    grey = m.material("GreyPolymer", m.srgb("#5F6D68"), roughness=.8)
    glass = m.material("OpticGlass", m.LENS, metallic=.3, roughness=.05)
    receiver = m.box("Receiver", (.045, .12, .03), (0, 0, 0), metal, bevel=.004)
    pieces = []
    receiver_parts(m, metal, black, grey, pieces)
    m.join_into(receiver, pieces)
    precision_stock(m, receiver, metal, black, grey)
    scope_parts(m, receiver, metal, black, glass)
    barrel_parts(m, receiver, metal, black)
    moving_parts(m, receiver, metal, black, grey)
