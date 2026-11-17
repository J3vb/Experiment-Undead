# Plan: Halcyon Labs concept pass (after the breakout)

Status: Building
Roadmap: F-68 / issue #297 (look follow-ups)
Phase: P4 (v0.1 Vertical slice)
Size: L
Approved by: the person on decision cards (2026-11-17, plan PR #304): plan approved, Containment lit by tank glow

## Goal

Halcyon Labs looks like the post-breakout concept art: a real Oriel facility
that has been torn apart. Painted signage tells you where you are, Fenlight
vines with glowing pods climb the pillars, the specimen tanks are shattered
and leaking, tables are overturned, small fires burn in the kitchen, broken
light strips hang and spark. The map **stays as dark as it is now** (the
person likes the darkness, 2026-11-17); new light only comes from things in
the concept that glow: Fenlight, fire and red warning lamps. The map plays
exactly the same. Serves the Cold Containment look and "readable rooms you can
navigate under pressure".

## Scope

Reference images (saved in this PR):

- `docs/design/images/halcyon_concept_after.jpg`: **the look target**.
  Post-breakout Mess Hall, Containment and Labs.
- `docs/design/images/halcyon_concept_before.jpg`: the same rooms before the
  breakout. Only a reference for what each room was (kitchen line, benches,
  catwalk office, research room). Not a lighting target.

Gaps, room by room (concept vs the map after F-13, F-15, F-61 to F-64):

| Room | In the concept | In the map now | Gap |
|---|---|---|---|
| Mess Hall | Oriel logo and "HALCYON LABS / SECTOR A / MESS HALL" painted on the wall, "A1" over the exit, yellow band on pillars; kitchen line behind broken serving windows with small fires; overturned bloody tables, benches and chairs; Fenlight vine with glowing pods up a pillar; smashed vending machine with a cracked lit screen; broken light strips hanging with sparks; red wall lamps; papers, cups, debris; low mist | 2 tables, serving counter, barricade, body bag, 2 spills, story decals, flicker/dead lights | No signage, no kitchen line, no fires, no overturned furniture, no vines, no vending machine, no hanging strips, bare walls and ceiling |
| Main Corridor | (concept background) green military cases, wet floor, red lamps, pipes | Pipe runs, hazard sign, stains | Signage (sector arrows, codes), cases, vines |
| Labs | Wall screen pair (one cracked, one Fenlight scan); benches with microscopes, green sample jars, open drawers; knocked stools; glass research room ("HALCYON RESEARCH") with a big glowing Fenlight mass inside; shelves; papers; vines from the ceiling | 4 specimen tanks, 1 bench, 2 jar shelves, filing cabinets, gurney | Screens, more benches and lab gear, research room, vines, signage |
| Containment | Huge shattered tanks C-01 to C-03, green spill pools and low green mist; bent yellow railings; upper catwalk with stairs; toppled console with cracked screen; fallen barrels; floor cables; "ORIEL / CONTAINMENT" wall with a hazard band; vines hanging | Holding cells, barricade, gurney, hazard signs, pipe runs, body bag; about 12/255 average brightness (#297) | Big tanks, spill and mist, railings, catwalk, console, signage, vines; too dark to read zombies |
| All rooms | Heavy ceilings: trusses, ducts, cable trays, hanging cables and vines | Flat ceilings with light fixtures | Ceiling layer |
| Guard Post, Generator Hall, Loading Dock, Coolant Tunnel | Not in the concept | Done in F-13/F-15 | Only signage, a few vines and the ceiling layer, for consistency |

In:

- Painted signage as decals: Oriel logo, sector signs, area codes, tank codes,
  "CONTAINMENT", "HALCYON RESEARCH", pillar bands, floor lane lines. All aged:
  faded, grimy, scratched, some blood over them.
- Fenlight growth kit: vines for pillars, walls and ceilings with glowing pods,
  spill pools and low mist where tanks broke.
- Wreck props per room from the table above.
- Ceiling layer per room.
- Issue #297 lighting lines (see Lighting below), plus the vent ledge and
  truck wreckage readability lines.
- One GPU re-bake and fps check at the end, by paste-ready prompt.

Not in (non-goals):

- Brightening the map, raising ambient, or the pre-breakout lighting (never,
  person's call 2026-11-17).
- A walkable catwalk or any layout, door, spawn or navmesh change (the catwalk
  is wall dressing with a collapsed stair; a playable upper floor is a new map
  feature, not this pass).
- Spill pools or fires that hurt players (later: idea issue if wanted).
- Destructible props, physics debris.
- `tests/unit/test_screens.gd` failing on Windows (stays open in #297, not a
  look item).
- Other maps.

### Lighting (issue #297)

- **Bake barely shows:** the ceiling fixtures stay Dynamic on purpose. They
  change colour with power and flicker, and `test_ceiling_lights_stay_real_time`
  guards that. The bake carries their bounce only. The new Fenlight glow lights
  are Static (bake only), so the re-bake in the last step shows them. Close
  this line with that reason.
- **Containment very dark:** decided: light it only
  with the green glow of the spilled tanks and pods (Static, baked), nothing
  else gets brighter.
- **Truck wreckage barely shows:** step 3 checks its fire light and moves it
  if needed (same fire light as the new kitchen fires).
- **Vent ledge not readable:** step 1 paints a hazard stripe on the ledge edge.

## Ready to build

```
### Ready to build
- Foundations touched (numbers from docs/FOUNDATIONS.md): map build pipeline
  (layout.json -> blockout_builder.gd), model pipeline (tools/assets, check_models.py),
  lightmap bake. All solid; this plan only adds data and models through them.
- Decision records that apply (docs/adr/): none touched. Does this go against one? no
- Co-op:
  - Who decides: nobody, everything is static scenery.
  - How a client triggers it: n.a.
  - What other players see: the same scenes, loaded locally with the map.
  - Works on a dedicated server with no local player: yes (scenes load; nothing runs).
- Data: new entries in levels/halcyon_labs/layout.json (props, dressing) and
  Decal / light nodes in decals.tscn and atmosphere.tscn. No content ids.
  Code compares against a specific id anywhere: no
- Save: changes what is saved? no
- Events and UI: none. New screens: n.a.
- Input through InputFrame, gameplay in _physics_process, randomness from the session RNG: yes
  (no gameplay code; spark and fire flicker use the existing atmosphere scripts)
- Tests: tests/content/test_halcyon_labs.gd, test_halcyon_labs_props.gd,
  test_halcyon_surfaces.gd, test_halcyon_atmosphere.gd, test_prop_models.gd extended per step.
- Logging: none new (no runtime systems).
- Performance: nothing per frame; fires reuse the existing fire light setup.
- Out of scope: see Not in.
```

## Design references

- `docs/design/images/halcyon_concept_after.jpg` (target),
  `halcyon_concept_before.jpg` (what rooms were).
- `docs/design/look-rules.md`: palette, rule 2 (bio-green only for the
  experiment: Fenlight vines, pods, spills and tanks qualify), rule 3 (emission
  above 1.0 only on gameplay objects and fixtures), rule 4 (one accent light per
  zone), light rules (effect lights: no shadow, bake mode 0, distance fade 20 m;
  particles at most 400 per room and 1,500 per map; story decals fade 25-30 m).
- `docs/design/lore.md` "Halcyon Labs: where it broke out": Oriel Biotechnic,
  Project HALCYON, cold tanks, the cold failed on Day 0, staff turned first.
- `docs/design/maps.md` Map 1: area names (sign text uses them exactly),
  Mess Hall table loop, late training ring, Brute arena in Containment.
- `docs/plans/halcyon-labs-props.md`: props vs dressing rules (dressing keeps
  1.0 m from openings, interactables and spawns; anything that blocks is a prop).
- `docs/plans/halcyon-labs-atmosphere.md`: sparks, beacons, screens shader,
  fog, story decals (reused, not rebuilt).

## Systems touched

| Folder or file | New / changed | What changes |
|---|---|---|
| docs/design/images/halcyon_concept_*.jpg | new | The two concept images |
| docs/design/look-rules.md | changed | Short "Halcyon Labs target" section linking the images |
| tools/assets/sign_decals.py | new | Draws sign textures (pure Python stencil stroke font, like story_decals.py) into assets/textures/signs/ |
| assets/textures/signs/ | new | Generated sign PNGs + .import |
| tools/assets/props_fenlight.py | new | Vines (pillar, wall, ceiling), pods, spill mound |
| tools/assets/props_wreck_mess.py | new | Kitchen line, overturned table/bench/chair, vending machine, hanging light strip, cases |
| tools/assets/props_wreck_labs.py | new | Screen pair, microscope bench, sample rack, stools, research room glass wall, Fenlight mass |
| tools/assets/props_wreck_containment.py | new | Big broken tanks, railings, catwalk wall piece, console, barrels, cables |
| tools/assets/props_ceiling.py | new | Trusses, ducts, cable trays, hanging cables (one merged model per room) |
| tools/assets/build_models.py | changed | Merges the new MODELS dicts |
| levels/halcyon_labs/layout.json | changed | New props and dressing entries |
| levels/halcyon_labs/blockout.tscn | regenerated | By the builder, never by hand |
| levels/halcyon_labs/signs.tscn | new | Sign decals (wall signs cannot go in decals.tscn, whose test wants every decal on a floor); one instance line in map.tscn |
| levels/halcyon_labs/atmosphere.tscn | changed | Fire spots, Fenlight glow lights, mist FogVolumes, extra sparks and red lamps |
| levels/halcyon_labs/map.exr / map.lmbake | re-baked | Last step, on the GPU |
| tools/room_shots.gd | changed | Also prints draw calls per room shot (baseline and budget) |

Autoloads, managers or base classes added: none.

## Data

- No new Resource types, no save fields, no network messages.
- `layout.json`: only new `props` (with `"model"`) and `dressing` entries,
  same fields as F-15.
- Save format change: none.
- Content checks: extend the existing Halcyon tests (see steps).

## Co-op behaviour

- Who owns the state: none. Static scenery, identical on every peer.
- What clients send / server sends: nothing.
- What a client sees that the host sees too: everything (same scene files).
- Late joiner: nothing to receive.
- Dedicated server: loads the scenes; lights, decals and fog cost nothing
  without a viewport. Nothing to skip.

## Performance

- Baseline now: 434-530 avg fps at 1440p with 24 zombies (target 120, gate 60).
  Mess Hall and Main Corridor already have about 4x the draw calls of the ramp.
- Step 1 records draw calls per room shot with `tools/room_shots.gd` (Forward+
  on software Vulkan, see the baseline below). Budget per step: each room at most baseline + 30 %,
  Mess Hall and Main Corridor at most + 15 %. A step over budget merges meshes
  before it merges.
- Baseline (step 1, `room_shots.gd`, Forward+ on software Vulkan, power on):
  Loading Dock 356, Guard Post 346, Mess Hall 227, Main Corridor 348,
  Generator Hall 213, Labs 146, Coolant Tunnel 239, Containment Wing 79 draw
  calls. Signs are decals and add none. Software Vulkan works in the cloud
  (`apt-get install mesa-vulkan-drivers`, `--rendering-driver vulkan`), so
  decals can be checked there; OpenGL has no decals.
- Vines, ceiling and wreck dressing: merged per model, visibility range 30 m
  on small dressing, `light_baking` 2 (Static Lightmaps), shadows from the bake.
- Fenlight glow lights: Static bake mode (1), zero run-time cost.
- Fires and new red lamps: no shadow, bake mode 0, distance fade 20 m (look
  rules). At most 2 new real-time lights per room.
- Mist: at most one FogVolume per room, only in Containment and the Labs
  research room. Particles stay under 400 per room, 1,500 per map.
- Lightmap stays under the size budget in `test_map_has_baked_lightmaps_under_the_size_budget`.

## Steps

Each step's look-check render (room_shots next to the concept crop) goes to
the person on a decision card before the next step starts.

### Step 1: References, signage and draw-call baseline

- Build: save the two concept images and the look-rules section. Write
  `sign_decals.py`: Oriel logo (original hexagon-ring mark drawn in code), one
  name sign per area ("A3 MESS HALL / HALCYON LABS - SECTOR A >>"; codes A1 to
  A4 front half, B1 to B3 back half, C1 Containment), floor lane line. Tank
  codes come with the tanks in step 5, "HALCYON RESEARCH" with the research
  room in step 4, pillar bands with pillars (none in the map yet).
  Signs hang at 2 to 3 m where the fixtures light the wall: higher walls stay
  black in this dark map, so a sign up there could not be read.
  Paint colour `#B9C2B0` at 60 to 80 % on walls, hazard colour taken from the
  existing `decal_hazard.png`. Every texture gets grime, fade and scratches;
  some get a blood overlay. Place them as Decals in a new
  `signs.tscn`, distance fade 25-30 m like story decals. Hazard stripe on the
  vent ledge edge (#297). `room_shots.gd` prints draw calls; write the baseline
  into this plan.
- Files: tools/assets/sign_decals.py, assets/textures/signs/,
  levels/halcyon_labs/signs.tscn, map.tscn (one line), tools/room_shots.gd.
- Tests: new `tests/content/test_halcyon_signs.gd`: every area in maps.md has
  its name sign, every sign uses a sign texture and fades like story decals,
  sits on a wall or floor of its room, and misses the doorways.
  `tools/ci/test_sign_decals.py`: output is byte-identical every run.
- Done when: renders show readable signs in every room; draw-call baseline
  written here.

### Step 2: Fenlight growth and the Containment glow

- Build: `props_fenlight.py` with vine models (pillar wrap, wall climb,
  ceiling hang, 2 sizes each) and pods with bio-green emission (same strength
  as the existing leak glow, provisional), a spill mound. Place vines across the map as dressing,
  heaviest in Containment and Labs, lighter toward the Dock. Leak pool decals
  under spills. Containment glow (decided): Static green
  OmniLights at the spill spots.
- Files: tools/assets/props_fenlight.py, build_models.py,
  assets/models/dressing/, layout.json, blockout.tscn, atmosphere.tscn,
  decals.tscn.
- Tests: `test_prop_models.gd` (new models load, under budget);
  `test_halcyon_labs_props.gd` (dressing clear of doors, machines, spawns);
  `test_halcyon_atmosphere.gd` (Fenlight glow lights are bake mode 1, no
  shadow, bio-green colour).
- Done when: render of Containment shows zombies readable against the glow,
  rest of the map as dark as before.
- Built (2026-11-17): five dressing models (`vine_wall`, `vine_wall_small`,
  `vine_pillar` around the Labs tanks, `vine_ceiling`, `fenlight_spill`), new
  `Vine` slot -> `levels/materials/fenlight_vine.tres`, pods reuse the `Fluid`
  slot (specimen tank glow, energy 0.8). The glow lights and leak pools live in
  their own `levels/halcyon_labs/fenlight.tscn` (one instance line in map.tscn),
  not atmosphere.tscn, because every atmosphere light must stay bake mode 0
  and these are bake mode 1. Test: `tests/content/test_halcyon_fenlight.gd`.
  Until the step 7 re-bake, the Static glow lights only reach zombies and new
  dressing, not the baked walls and floor.

### Step 3: Mess Hall, Main Corridor and Dock wreck

- Build: `props_wreck_mess.py`: kitchen line behind broken serving windows,
  overturned table, tipped benches and chairs, smashed vending machine with a
  cracked `Screen` surface, hanging broken light strip, green military cases.
  Kitchen fire spots (2) and existing spark spots on the hanging strips. Red
  wall lamps at the exits. Check the truck wreckage fire light from (34, 1.7, 56)
  and move it if it still does not show (#297).
- Files: tools/assets/props_wreck_mess.py, build_models.py,
  assets/models/props|dressing/, layout.json, blockout.tscn, atmosphere.tscn.
- Tests: `test_mess_hall_tables_make_a_loop` still passes with the new props;
  props clearance test; `test_prop_models.gd`; atmosphere test counts fires
  (no shadow, bake 0, fade 20 m).
- Done when: Mess Hall render matches the concept's layout of wreck and fire;
  draw calls within + 15 %.
- Built (2026-11-17): props `kitchen_line` (3.4 m, against the north wall
  between the corridor door and Second Wind), `overturned_table`,
  `vending_machine` (cracked `Screen` panel), `military_cases` (Corridor and
  Dock), dressing `hanging_strip` (two in the Mess Hall, a spark spot under
  the west one). Fires use a new shared `systems/effects/fire_spot.tscn`
  (flame and ember particles, an unshadowed orange light, FlickerLight):
  two on the stoves, and it replaces the truck wreckage's bare fire light so
  the wreck shows flames (#297). Red exit lamps are emissive boxes with no
  light, so no room passes its light cap. Test: `tests/content/test_halcyon_wreck.gd`.

### Step 4: Labs wreck

- Build: `props_wreck_labs.py`: wall screen pair (`Screen` surfaces: one
  cracked dark, one with the existing screen shader), microscope bench, sample
  rack with green jars, open drawers, knocked stools, papers; glass research
  room wall (cracked glass, "HALCYON RESEARCH" sign) with a Fenlight mass
  inside and one mist FogVolume.
- Files: tools/assets/props_wreck_labs.py, build_models.py, assets/models,
  layout.json, blockout.tscn, atmosphere.tscn.
- Tests: props clearance; late ring path test (Corridor, Generator Hall,
  Tunnel, Labs) still finds a path for a zombie-sized body; prop models test.
- Done when: Labs render matches the concept; ring still 4-player wide.
- Built (2026-11-17): the research room is a 4 m glass bay prop
  (`research_room`: steel frame, cracked panes, one pane gone, a Fenlight
  mass inside) built around the existing north jar shelf, which stays where
  it is because removing a baked node breaks the lightmap until step 7.
  `HALCYON RESEARCH` sign on the wall behind the glass, one mist FogVolume
  inside. Dressing `screen_pair` (one cracked, one running `Screen`) on the
  south wall and `lab_floor_wreck` (knocked stools, spilled jars) west of
  the bench. The two step 2 Labs wall vines went: one covered the Labs sign,
  the other stood where the bay is. No new bench: the island bench already
  carries the microscope, and a second one would narrow the late ring.

### Step 5: Containment wreck

- Build: `props_wreck_containment.py`: three big tanks C-01 to C-03 (C-01
  fully shattered and empty, C-02 and C-03 cracked and leaking), bent yellow
  railings around the tanks, catwalk office on the north wall with a collapsed
  stair (dressing, out of reach), toppled console with a cracked screen,
  fallen barrels, floor cable runs. Spill pools and one mist FogVolume. Big
  tanks and railings are props (they block); the Brute arena centre and its 3
  approaches stay clear.
- Files: tools/assets/props_wreck_containment.py, build_models.py,
  assets/models, layout.json, blockout.tscn, atmosphere.tscn, decals.tscn.
- Tests: props clearance; zombie path from each Containment spawn to the exfil
  hatch; vent duct tests still pass; prop models test.
- Done when: Containment render matches the concept.
- Built (2026-11-17): props `big_tank_shattered` (C-01, north of the
  north spill) and `big_tank_cracked` (C-02 by the east spill, C-03 on the
  west side north of the ramp lane), each inside a bent hazard railing with
  its gap facing its spill; `toppled_console` against the west wall;
  `fallen_barrels` under the catwalk. Dressing `catwalk_office` (5 m deck,
  office, stair torn off 1.4 m above the floor) on the north wall between
  Mule and the north-east window, and `floor_cables` out of C-03. Tank codes
  are decals under `TankCodes` in map.tscn (`sign_decals.py` draws them; it
  gained a `0` glyph). No new mist: Containment already has its one floor
  FogVolume, which the green glow lights now tint. Tests: arena centre and
  the ramp and vent approach lanes stay clear of the wreck props, every
  Containment spawn reaches the exfil hatch (`test_halcyon_wreck.gd`).
  Draw calls from the baseline Containment camera: 103 (+30 %, at the
  budget); the barrels and catwalk office use fewer materials to get there.

### Step 6: Ceiling layer

- Build: `props_ceiling.py`: one merged ceiling model per room (trusses,
  ducts, cable trays, hanging cables), cut around existing light fixtures.
- Files: tools/assets/props_ceiling.py, build_models.py, assets/models/dressing,
  layout.json, blockout.tscn.
- Tests: prop models test (one ceiling model per room, under budget);
  `test_each_room_keeps_the_shadow_light_budget` unchanged.
- Done when: all rooms within draw-call budget.

### Step 7: Re-bake, fps check and close-out

- Build: paste-ready prompt for the person's GPU agent: LightmapGI re-bake
  (High, 3 bounces, denoiser), 4-spot fps capture with 24 zombies at 1440p
  High, brightness capture per room. Commit `.exr` and `.lmbake`. Tick the
  #297 lines; set this plan to Done (finish-feature skill).
- Files: levels/halcyon_labs/map.exr, map.lmbake, ROADMAP.md, DECISIONS.md,
  this plan.
- Tests: lightmap size budget; things that move are not baked.
- Done when: fps at least 120 avg at 1440p High in every spot; person signs
  off on the look.

## Acceptance

- [ ] Every room has signage that names it with maps.md names (test).
- [ ] Mess Hall, Labs and Containment renders read as the post-breakout concept (person's card per step).
- [ ] The map is no brighter outside the new Fenlight, fire and lamp spots (GPU brightness capture vs F-13 numbers).
- [ ] Zombies are readable in Containment (GPU capture + person).
- [ ] Mess Hall table loop, late ring and Brute arena still work (tests, soak green).
- [ ] At least 120 fps avg at 1440p High with 24 zombies (GPU check).
- [ ] #297 lines for bake, Containment, truck and vent ledge closed.

## Risks

- Draw calls in the Mess Hall and Corridor (already the heaviest). Baseline in
  step 1 and a budget per step; merge meshes before adding more.
- Vines and pods turning the map green and breaking rule 2's "green means
  experiment" reading. Step 2 comes early and goes to the person on a card.
- Props blocking the training loops. Existing loop and path tests run every step.
- The bake changes after many steps; only one re-bake, at the end, so the
  map runs on the old bake between steps (new props show unbaked light until
  step 7, which is fine for play).

## Open decisions

- [x] Approve the plan: approved by the person, start with step 1 (2026-11-17).
- [x] How Containment stops being too dark: green glow from the broken tanks,
  spills and pods only (the person, 2026-11-17). Nothing else gets brighter.

## Provisional picks

Taken now; the person can change them on the step cards: kitchen fires are
the Mess Hall's one warm accent (rule 4); signs and railings use the existing
hazard colour, not the concept's yellow; pods glow at the leak-glow strength
(no rule 3 change); the catwalk is not walkable.
