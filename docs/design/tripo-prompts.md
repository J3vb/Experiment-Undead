# Tripo image prompts

Plan: [tripo-models.md](../plans/tripo-models.md). One image per model, made
first, approved by the person, then sent to Tripo (image to 3D). Sizes and
families come from [prop-library.md](../plans/prop-library.md); vendor looks
from [lore.md](lore.md#the-stall-keepers).

## Style line (start of every prompt)

Props: `Single game asset, centred, full object in frame, plain light grey
background, soft even studio light, no shadows on the background, three-quarter
view from slightly above, realistic worn materials, muted colours, no text, no
letters, no logos, clean surfaces, no snow:`

Characters: `Full-body character for a game, standing in an A-pose (arms
45 degrees down, palms forward, fingers relaxed), front view, plain light grey
background, soft even light, feet flat, realistic, no text, no logos:`

Rules for every prompt:

- No text: AI lettering comes out garbled. Signs and stencils are added as our
  own decals.
- No snow or rain unless the row says so: snow is added per map.
- No bright red and no bio-green unless the row says so (look rules 2 and 3).
  Red lamps say "red lamp lens"; green glow only on the last train car.
- One object per image; pairs (jerrycans) stay touching so Tripo makes one mesh.

## Vendors (F-76)

| Model | Prompt after the style line |
|---|---|
| npc_quartermaster | Done in the F-78 trial (Odile Brandt). |
| npc_gunsmith | Teun Maes, man in his 50s, bald, thick grey-brown beard, ear defenders hanging round his neck, tan canvas apron over olive work overalls, sleeves rolled to the elbow, strong forearms, heavy work boots. |
| npc_technician | Dr. Lien Corvelyn, woman in her 30s, short black hair, blue-grey radio headset, dark padded parka under a stained grey lab coat with a patch scratched off the chest, tired eyes, boots. |
| npc_cordon_liaison | Lieutenant Raes, man in his 40s, snow-grey military parka, officer fur hat with a small round metal badge, black armband with a plain white band, holding a rugged tablet at his side, gloves, boots. |

## Family 1: barriers and checkpoint

| Model | Size | Prompt after the style line |
|---|---|---|
| jersey_barrier | 2.0 m long | Concrete jersey barrier with faded yellow and black diagonal stripes, chipped edges. |
| concrete_block | 1.2 m | Square concrete roadblock cube with a rusty lifting loop on top, stained. |
| sandbag_wall | 2.0 m long | Straight wall of stacked canvas sandbags, three rows, olive and tan. |
| sandbag_corner | 1.5 m | L-shaped corner of stacked canvas sandbags, three rows. |
| boom_barrier | 4.0 m long | Checkpoint boom barrier, steel post with counterweight, arm down, white and red stripes faded to pink. |
| chainlink_fence | 3.0 m long | Chain-link fence section between two steel posts, slightly sagging. |
| chainlink_gate | 3.0 m long | Chain-link double gate, closed, with a chain and padlock. |
| razorwire_fence | 3.0 m long | Fence section topped with coiled razor wire, steel posts. |
| hard_case | 0.9 m long | Yellow rugged equipment case, latches closed, scuffed. |
| jerrycan_pair | 0.5 m | Two olive metal jerrycans standing side by side, touching. |
| pallet_stack | 1.2 m | Stack of four wooden pallets, weathered. |

## Family 2: military camp and vehicles

| Model | Size | Prompt after the style line |
|---|---|---|
| army_truck | 7.5 m long, props_large | Six-wheel army cargo truck with an olive canvas top over the bed, mud on the wheels, plain doors. |
| armoured_car | 5.5 m long, props_large | Four-wheel armoured patrol car, dark olive, small turret ring without a gun, hatches closed. |
| field_tent | 5.0 m long | Olive canvas field tent, ridge roof, front flap tied open, guy ropes. |
| field_table | 1.8 m long | Folding field table with a rugged laptop, a field radio with a handset, and paper maps. |
| portable_generator | 0.9 m long | Small portable generator on two wheels with a handle, olive paint, fuel cap. |
| floodlight_tripod | 2.5 m tall | Floodlight on a tall tripod, two square lamp heads, cable coiled at the foot. |
| body_tarp | 1.9 m long | Body-shaped lump under a dark green tarp on the ground, boots showing. |

## Family 3: industrial

| Model | Size | Prompt after the style line |
|---|---|---|
| guard_rail_3 / guard_rail_6 | 3.0 m / 6.0 m long | Yellow steel safety guard rail section, two rails, posts with base plates. |
| pipe_elbow_valve | 1.5 m | Large grey steel pipe elbow with a red-brown valve wheel, flanged joints. |
| electrical_cabinet | 2.0 m tall | Grey steel electrical cabinet, two doors, vents, a hazard sticker shape without text. |
| transformer | 2.5 m tall | Outdoor electrical transformer, grey, cooling fins, insulators on top. |
| cable_reel | 1.2 m | Wooden cable reel with black cable wound on it. |
| wall_ladder | 4.0 m tall | Steel wall ladder with a safety cage, grey paint worn. |
| sodium_street_lamp | 7.0 m tall | Tall cobra-head street lamp on a steel pole, orange sodium lens. |
| control_desk | 2.0 m long | Old industrial control desk with switches, dials and small screens, grey-green paint. |

## Family 4: rail

| Model | Size | Prompt after the style line |
|---|---|---|
| track_section | 6.0 m long | Straight railway track section, two steel rails on wooden sleepers and gravel ballast. |
| buffer_stop | 2.5 m | Railway buffer stop, steel frame with two round buffers, faded paint. |
| signal_post | 4.0 m tall | Railway signal post with two red lamp lenses on a black plate, ladder on the side. |
| container_closed | 6.0 m long | 20 ft shipping container, closed doors, dented, rust patches, dark blue-grey, no logo. |
| container_open | 6.0 m long | 20 ft shipping container with doors open, empty inside, rust patches. |
| flatbed_wagon | 12.0 m long, props_large | Railway flatbed wagon, steel deck, bogies, empty. |
| platform_bench | 2.0 m long | Station platform bench, wooden slats on cast-iron legs. |
| luggage_pile | 1.5 m | Pile of old suitcases and duffel bags. |
| station_sign | 2.0 m long | Station name sign board on two posts, blank panel, enamel edges. |

## Family 5: large pieces

| Model | Size | Prompt after the style line |
|---|---|---|
| hospital_train_car | 20 m long, props_large | Old passenger train carriage converted to a hospital car, side doors open, steps down, windows. |
| last_car_glow | 20 m long, props_large | Old train carriage, doors open, faint green glow from inside the windows. |
| signal_gantry | 12 m wide, props_large | Steel railway signal gantry spanning two tracks, lamps along the top. |
| container_stack | 6 m long, 3 high | Three shipping containers stacked on each other, different dull colours, no logos. |

## Family 6: hospital and sanatorium

| Model | Size | Prompt after the style line |
|---|---|---|
| hospital_bed | 2.0 m long | Old iron hospital bed, white enamel chipped, thin mattress, crumpled sheet. |
| wheelchair | 1.0 m | Old steel wheelchair with leather seat. |
| iv_stand | 1.9 m tall | Steel IV stand on wheels with an empty bag. |
| medical_trolley | 0.9 m long | Steel medical trolley with two shelves, enamel trays. |
| privacy_screen | 1.8 m long | Folding hospital privacy screen, three panels, faded cloth. |
| glass_cabinet | 1.8 m tall | Glass-front medicine cabinet, white enamel, bottles inside. |
| bathtub | 1.7 m long | Clawfoot cast-iron bathtub, stained enamel. |
| reception_desk | 2.5 m long | Old wooden reception desk with a counter top and a bell. |
| chapel_pew | 2.5 m long | Wooden chapel pew, dark varnish worn. |
| wall_radiator | 1.0 m long | Cast-iron wall radiator, painted cream, chipped. |

## Family 7: outdoor and clutter

| Model | Size | Prompt after the style line |
|---|---|---|
| dead_tree | 6.0 m tall | Dead leafless tree, twisted branches. |
| pine_tree | 9.0 m tall | Dark pine tree, dense needles. |
| rock_cluster | 2.0 m | Cluster of grey granite rocks. |
| iron_gate | 4.0 m wide | Wrought-iron double gate between two stone posts with lanterns on top. |
| iron_fence | 3.0 m long | Wrought-iron fence section with spear tops, on a low stone base. |
| park_bench | 1.8 m long | Iron park bench with wooden slats. |
| snow_drift | 2.0 m long | Low snow drift mound (snow allowed for this one). |
| leaf_litter | 1.5 m | Flat patch of dead brown leaves on the ground. |
| trash_bags | 1.0 m | Pile of black trash bags. |
| cardboard_boxes | 1.0 m | Stack of worn cardboard boxes, one open. |

## Family 8: map hero pieces

| Model | Size | Prompt after the style line |
|---|---|---|
| frozen_fountain | 6 m wide | Tiered stone fountain, frozen, icicles hanging from each tier (ice allowed). |
| turbine_housing | 8 m long | Hydro-electric turbine housing, round steel casing, bolted flanges, pipes. |
| dam_control_building | 15 m wide | Concrete dam control building front, radio masts on the roof with red tip lamps, backdrop facade only. |
| sanatorium_front | 30 m wide | Old sanatorium front facade, columns, central balcony, wide stairs, arched windows, backdrop only. |
| sanatorium_cupola | 5 m wide | Roof cupola with a small dome and arched openings. |
