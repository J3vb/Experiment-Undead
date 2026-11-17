# Plan: Halcyon Labs atmosphere and motion

Status: Building
Roadmap: F-61
Phase: P4 (v0.1 Vertical slice)
Size: M
Approved by: Claude plan review on PR #250 (2026-11-17, two blocking findings fixed: no runtime global uniform, dead lights written by the builder), size M, no open decisions

## Goal

Halcyon Labs feels alive and broken instead of empty: dead and flickering
tubes, sparking cables, steam, drips, dust in the light, low fog, alarm
beacons in the Containment Wing, screens that flicker, things that sway, and
small staged scenes that tell what happened on Day 0. Each area keeps its own
accent so players learn the map. Serves "The pressure always builds" (mood
and map reading) and fits `docs/design/lore.md` (Halcyon: where it broke out).

## Scope

In:

- Dead and flickering ceiling lights as data: a top-level `light_states`
  section in `layout.json` that the blockout builder applies. Flickering
  offices accent in the Guard Post, a few dead tubes in the Main Corridor and
  Containment Wing.
- Alarm beacons in the Containment Wing (red `#C3201B` accent, the "red alarm
  wing" from the look rules), rotating, unshadowed.
- Particles and fog in a new `levels/halcyon_labs/atmosphere.tscn`: dust motes
  in the big rooms, steam from pipes (Generator Hall, Coolant Tunnel), drips
  (Coolant Tunnel, Containment Wing), sparking torn cables with a short light
  flash (Main Corridor, Labs), smoke and embers over the burning truck, low
  `FogVolume`s (Containment Wing floor, Coolant Tunnel).
- Motion: one hanging fixture swinging on its cable in the Main Corridor,
  loose cables swaying, flickering monitor screens (Guard Post desk, Labs
  bench) with a small screen shader.
- Power changes the mood: steam, monitors and the generator hum start with
  power; sparks and alarm beacons run from the start (battery backup).
- Positional sound spots built on the F-04 ambience: spark crackle, steam
  hiss, drips, monitor and generator hum, a short alarm klaxon burst.
- Story moments, dressed with effects and decals around the props thread's
  models (that thread models the tipped chairs and trays, guard desk with
  monitors, barricades, bent cell door and body bags): Guard Post last stand
  (blood smear, spent shells), Mess Hall evacuation scramble (drag trail),
  Labs cracked specimen tank leaking bio-green (leak particles, green pool
  decal), Containment bent cell door (scratch marks), Generator Hall tally
  marks by the switch (the Night Supervisor keeping the cold on), one Wick
  symbol. Story decal textures come from a code-built script.

Not in (non-goals, and where each one goes instead):

- Blood from combat (bursts, floor pools): F-14 (zombie sounds and gore).
  Static story decals never share its ring or code.
- Generic grime, hazard stripes, signs and all surface materials: the
  Halcyon Labs texturing thread (`levels/materials/`, `decals.tscn`).
- New Blender models and story props (chairs, trays, desks, monitors,
  barricades, cell door, body bags, tanks): the Halcyon Labs props thread.
  This plan places no prop geometry; it only adds effects and decals near
  those props, anchored by world position.
- Lore notes and radio lines (`content/lore/`): F-45, as in the lore doc.
- Blackout rounds and Glowers changing the lights: F-28.
- Power and Blackout ambience bed swaps, `SoundManager`: later audio work.
- Physics-driven swinging (rigid bodies, joints): cosmetic tweens are enough.
- An effects quality setting: F-48 (full settings) may add a toggle later.

## Ready to build

```
### Ready to build
- Foundations touched: none of the shaky ones. Uses the Level power signal and
  net_state (F-02, done) and the F-04 Ambience scene (done). Nothing in systems/net/.
- Decision records: 0008 code-built assets first (decal textures from a Python
  script, sounds from ambience_sfx.py), 0004 one code path (same scene in solo,
  host and client). Goes against none.
- Co-op:
  - Who decides: each client, locally. Purely cosmetic; only power state is
    shared, and the server already owns and syncs it.
  - How a client triggers it: it does not. Effects read Level.power_on at ready
    and connect Level.power_turned_on.
  - What other players see: the same scene on every peer; random timing differs
    per peer (cosmetic), which is fine.
  - Dedicated server: works; particles and sound do nothing without a screen or
    audio device (Dummy driver), scripts only tick timers.
- Data: light_states in layout.json (map data, builder input). No content ids
  in code, no balance numbers.
- Save: no.
- Events and UI: none.
- Input through InputFrame, gameplay in _physics_process, randomness: no
  gameplay; all randomness is visual and ends in `# cosmetic`, in _process.
- Tests: tests/content/test_halcyon_labs.gd (light budget, light_states applied),
  new tests/unit/test_spark_spot.gd, tests/unit/test_atmosphere.gd,
  tests/content/test_halcyon_atmosphere.gd (budgets per area).
- Logging: none needed (no failure states; content tests catch budget breaks).
- Performance: nothing created per frame; particles and materials are scene
  resources, sparks reuse one particle node and one light each.
- Out of scope: see Not in.
```

## Design references

- docs/design/look-rules.md#rules: one accent light per zone (red alarm wing,
  sodium dock, flickering offices), bio-green only for leaks and machines,
  emission above 1.0 only on gameplay objects and fixtures.
- docs/design/look-rules.md#light-rules: max 6 shadowed real-time lights in
  view; bake modes (cheat lights 0 Disabled). New lights here are all
  unshadowed and bake mode 0, so the lightmap and the 2-per-room shadow test
  stay as they are.
- docs/design/look-rules.md palette: alarm `#C3201B`, fluorescent `#CDEEE8`,
  fog `#0A1416`; volumetric fog density 0.03 base.
- docs/design/maps.md#map-1-halcyon-labs-refined: setting and mood (burning
  truck, flickering teal tubes, emergency red before power, green tank glow).
- docs/design/lore.md: Day 0 cold failure, staff turned first, the Night
  Supervisor, the Wick symbol as graffiti, "every room tells one small story".
- Spark (3 to 9 s) and klaxon (20 to 40 s) timings are provisional feel picks,
  single export values; step 5 writes the final ones into look-rules.md.
- docs/design/sound.md and F-04 (`levels/halcyon_labs/ambience.tscn`, Ambient bus).

## Systems touched

| Folder or file | New / changed | What changes |
|---|---|---|
| levels/halcyon_labs/layout.json | changed | New top-level `light_states` section only |
| tools/blockout_builder.gd | changed | `_build_lights` applies light_states (flicker, dead) |
| levels/halcyon_labs/blockout.tscn | regenerated | Builder output |
| levels/kit/ceiling_light_dead.tscn | new | Dead fixture: housing and dark tube, no light |
| levels/halcyon_labs/atmosphere.tscn | new | All particles, fog, beacons, motion, sound spots, story moments |
| levels/halcyon_labs/map.tscn | changed | One instance line for atmosphere.tscn |
| systems/level/atmosphere.gd | new | Shows `after_power` / `before_power` groups by Level power |
| systems/effects/spark_spot.gd | new | Random spark bursts with a flash light and crackle |
| systems/effects/monitor_screen.gdshader | new | Scanlines, roll and flicker for screen quads |
| tools/assets/ambience_sfx.py | changed | Crackle, hiss, hum, klaxon one-shots and loops |
| systems/effects/monitor_screen.tres | new | Screen material the props thread's `Screen` surfaces use |
| tools/assets/story_decals.py | new | Blood smear, scratch, tally, leak and Wick symbol PNGs |
| assets/audio/ambience/, assets/textures/story/ | new files | Generated output + imports |

Autoloads, managers or base classes added: none. `Atmosphere` owns one rule no
node owns (which effects run before and after power), so rule 6 allows it.

## Data

- `layout.json` gains `"light_states": {"<room id>": {"flicker": [i...],
  "dead": [i...]}}` where `i` is the light index the builder already gives
  (`Light<i>`). Missing room = all normal. Read only by the builder.
- Save format change: none.
- Content checks: tests/content/test_halcyon_atmosphere.gd (below).

## Co-op behaviour

- Who owns the state: nothing new. Power is server-owned and already synced.
- What clients send, what the server sends back: nothing new.
- What a client sees that the host sees too: the same effects and story
  moments; flicker and spark timing differ per peer (cosmetic).
- Late joiner: receives power in Level net_state (existing); Atmosphere reads
  `power_on` at ready, so a late joiner after power sees steam and screens.
- Dedicated server: nothing skipped by code; no rendering or audio happens.

## Performance

Client cost does not grow with player count (all local visuals). The numbers
below are provisional picks (none are in docs/design/ yet); step 5 adds the
final ones to docs/design/look-rules.md after the fps check. Budget for
the whole scene at the worst camera spot (Main Corridor looking into the Mess
Hall), checked in the step 5 fps check:

- No new shadowed lights. New lights unshadowed, bake mode 0, distance fade
  on at 20 m, at most 3 new lights in any one area.
- At most 1,500 live particles map-wide, at most 400 in one area; every
  particle node has a visibility range (end 30 m).
- Sound spots: `max_distance` 14 m, so only the nearby few play; loops only
  for hums and steam, the rest one-shots.
- Scripts: SparkSpot and the swing tween only; no per-frame allocation, no
  get_node in _process. Target under 0.1 ms CPU and 0.5 ms GPU on the
  person's RTX 4080 Super; v0.1 still holds 60 fps with 24 zombies.

## Steps

### Step 1: Dead and flickering lights, alarm beacons

- Build: `light_states` in layout.json and `_build_lights` applies it. A
  dead light is a separate kit scene `levels/kit/ceiling_light_dead.tscn`
  (housing and a dark tube, no light, no script), so the editor bake sees it
  dark without any `_ready` code. (Changed while building: overriding the
  instanced Fixture per light saved repeated blocks into blockout.tscn that
  trip the `no-triple-copy` rule.) Flickering lights get `flickers = true`
  from the builder (FlickerLight already exists). Flicker on the Guard Post (offices accent). Two red rotating alarm beacons
  in the Containment Wing (unshadowed SpotLight3D, bake 0, AnimationPlayer
  loop, emissive housing) inside a first, small atmosphere.tscn with its
  instance line in map.tscn. Tell the Halcyon Labs build thread that the
  re-bake can include these changes. The committed lightmap is allowed to be
  stale between this PR and that re-bake (dead tubes keep their old bounce
  for a while); no test checks bake freshness.
- Files: layout.json, tools/blockout_builder.gd, blockout.tscn,
  levels/kit/ceiling_light_dead.tscn, levels/halcyon_labs/atmosphere.tscn, map.tscn.
- Tests: new test_halcyon_atmosphere.gd: lights listed in light_states
  flicker, or are dead fixtures with no Light3D, in the saved blockout.tscn;
  every room keeps working lights; shadow budget (test_halcyon_labs.gd) still
  holds. Every light in
  atmosphere.tscn is unshadowed and bake mode 0, at most 3 per area box.
- Done when: the blockout is regenerated and tests pass. The cloud only
  renders with OpenGL compatibility (no lightmap, no volumetric fog), so the
  real look check of this step happens on the person's GPU with the re-bake.

### Step 2: Particles, fog and sparks

- Build: dust motes (Mess Hall, Generator Hall, Labs, Main Corridor), steam
  (Generator Hall, Coolant Tunnel, `after_power`), drips (Coolant Tunnel,
  Containment Wing), truck smoke and embers, low FogVolumes (Containment Wing,
  Coolant Tunnel). `SparkSpot`: one GPUParticles3D burst plus a short
  OmniLight3D flash every 3 to 9 s (cosmetic). `Atmosphere` root script shows
  `after_power` nodes when the Level power comes on and hides `before_power`.
  It sits directly under the Level in map.tscn and finds it with
  `get_parent() as Level` (no third copy of the `_find_level` loop). On
  clients `Level.apply_net_state` calls `turn_power_on()`, so the signal
  fires there too; reading `power_on` at ready covers late joiners.
- Files: atmosphere.tscn, systems/level/atmosphere.gd, systems/effects/spark_spot.gd.
- Tests: test_spark_spot.gd (burst restarts the particles and lights the
  flash, flash is off again after its time, next burst lands in 3 to 9 s);
  test_atmosphere.gd (after_power hidden before power, shown after, a scene
  added after power starts shown: late joiner); test_halcyon_atmosphere.gd
  (particle totals under budget, every particle node has a visibility range).
- Done when: tests pass and look-check renders of Corridor, Generator Hall
  and Containment Wing go to the person on a decision card (amount of fog,
  dust and steam).

### Step 3: Screens and things that move

- Build: monitor screen shader and material `systems/effects/monitor_screen.tres`
  (scanlines, slow roll, flicker; emission 1.0 max, teal text-like bars;
  static noise before power through `instance uniform float powered`, which
  Atmosphere sets with `set_instance_shader_parameter()` on each screen in
  the `monitor_screen` group when power comes on; no global uniform, no
  project.godot edit). The props thread's monitor models name their screen surface
  `Screen`; their import maps it to this material. Until those land, two
  flat screen quads sit on the existing Guard Post desk and Labs bench. One
  hanging fixture in the Main Corridor swinging on a looped tween with its
  own unshadowed light (bake mode 0, not the fixture default 2, because it
  moves and a baked bounce would stay behind); two loose cables swaying
  (AnimationPlayer).
- Files: systems/effects/monitor_screen.gdshader, atmosphere.tscn.
- Tests: test_halcyon_atmosphere.gd: shader compiles (material loads with no
  error and has the `powered` instance uniform); test_atmosphere.gd: screens
  get powered 0 before power and 1 after; swing light unshadowed and bake 0, every AnimationPlayer loops and
  autoplays.
- Done when: tests pass, one look-check render posted.

### Step 4: Sound spots

- Build: generated sounds in ambience_sfx.py (spark crackle, steam hiss loop,
  hum loop, klaxon burst, drip loop). AudioStreamPlayer3D spots in
  atmosphere.tscn on the Ambient bus: crackle played by SparkSpot on each
  burst, hiss on steam, hums on monitors and generators (`after_power`),
  klaxon from the alarm beacons every 20 to 40 s, drips by the drip particles.
- Files: tools/assets/ambience_sfx.py, assets/audio/ambience/*, atmosphere.tscn,
  systems/effects/spark_spot.gd.
- Tests: test_spark_spot.gd: a burst plays its crackle player if it has one;
  test_halcyon_atmosphere.gd: every sound spot is on Ambient, max_distance at
  most 14 m, loops only on hum/hiss/drip streams, every referenced stream
  file exists. A Python test in tools/ci/ checks ambience_sfx.py produces each
  new sound name it lists (GUT cannot run Python).
- Done when: tests pass.

### Step 5: Story moments and story decals

- Build: story_decals.py makes small PNGs (blood smear, drag trail, scratch
  marks, tally marks, the Wick symbol, green leak pool). Decal nodes and the
  tank leak particles placed beside the props thread's story props (built
  after their models land; no collision, no prop geometry). Then a GPU-agent
  prompt for the person's PC:
  fps at the worst spots with 24 zombies, and the shared lightmap re-bake if
  the build thread has not done it yet.
- Files: tools/assets/story_decals.py, assets/textures/story/*,
  atmosphere.tscn, docs/DECISIONS.md, docs/ROADMAP.md, this plan.
- Tests: test_halcyon_atmosphere.gd: decals use only story textures, nothing
  in atmosphere.tscn has collision, the leak is the only bio-green effect. A
  Python test in tools/ci/ runs story_decals.py into a temp folder and checks
  each PNG it writes has the size and alpha the decals expect. Existing navmesh and spawn tests in
  test_halcyon_labs.gd still pass.
- Done when: tests pass, renders of all five scenes go to the person on a
  decision card, fps check prompt written, plan set to Done.

## Acceptance

- [ ] Every area has its accent (Guard Post flicker, Containment red beacons,
      Dock fire and smoke, Labs green leak) in a look-check render.
- [ ] Steam, screens and hums start with power, also for a late joiner (test).
- [ ] Shadow budget, light bake modes and particle budget hold (tests).
- [ ] Story moments dressed with decals and effects; atmosphere.tscn has no collision (test).
- [ ] Fps check on the person's PC still meets the v0.1 target.

## Risks

- Lightmap churn: only step 1 changes what the bake sees. It goes first and
  the build thread re-bakes once after it. Every later light is bake mode 0.
- Collisions with the props and texturing threads: all new nodes live in
  atmosphere.tscn, anchored by position; layout.json changes stay in a
  separate top-level section. Step 5 waits for the props thread's story
  models so decals line up.
- Too much fog or dust hurts readability (look rule 1): each look step ends on
  a screenshot card, and amounts are single export values to tune.
- GPU particles on the 2-core CI runner: headless renders nothing, tests only
  check node settings and script timing.

## Open decisions

- none

Look amounts (fog, dust, steam, grime) are provisional picks, confirmed by
screenshot cards after steps 2 and 5; each is a single value to change.
