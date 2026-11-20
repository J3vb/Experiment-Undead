# Plan: HUD to the concept art

Status: Building
Roadmap: F-87 / no issue (concept art from the person, 2026-11-20)
Phase: P2
Size: M
Approved by: Claude subagent plan review on PR #438 (2026-11-20), fixes applied; size M with no open decisions
Lore link: HUD readouts are the survivor's own gear and a game layer like points; Serum icons follow the Serums row in docs/design/lore.md (Oriel trial products), the compass gets a provisional row in "Grenades and field kit"

## Goal

The match HUD looks like the person's FENLIGHT concept art: dark angled
panels at the bottom corners (health and stamina left, gun, ammo and frag
right), a row of Serum slots with real icons, a compass strip and a
"ROUND 3" counter at the top, and a pickup prompt that points at the thing
you look at. Pillar: tight modern gunplay (clear, quiet HUD that reads at a
glance).

## Scope

In:

- The three concept images, saved under `docs/design/concepts/screens/` with this plan
  (`hud_concept.jpg`, `hud_concept_2.jpg`, `hud_serum_slots.png`).
- Bottom-left vitals panel: health cross icon, a 5-segment health bar, a
  stamina bar with a runner icon under it (concept 1).
- Serum slot row above the vitals panel: at least 4 square slots, filled ones show the
  Serum's icon on its colour, empty ones dark; the row grows past 4 when more are
  held (there is no Serum limit, docs/DECISIONS.md "Serums" line) (person's third image, "for the
  perks you bought"). New `icon` on `SerumData`, one SVG per Serum.
- Bottom-right weapon panel: gun icon, magazine big, reserve small
  ("30 / 210"), divider, frag icon and count (concept 1). New `hud_icon` on
  `WeaponData`, one SVG per gun class.
- Top centre compass strip (W / NW / N with ticks) and top-right
  "ROUND 3" with a red underline (concept 2).
- Pickup prompt anchored to the focused Interactable: rounded dark box with
  the key cap and action, a thin leader line, corner brackets around the
  object (concept 2).
- Crosshair: thinner, shorter white ticks (concept 1); the spread behaviour stays.
- Keep everything that works now: damage numbers, level-up ring, drop feed,
  power-up timer ring row (bottom centre), points and points delta, XP bar,
  squad cards, exfil box, hint label, centre flash, down screen, vignette.

Not in (non-goals, and where each one goes instead):

- The green heartbeat line from concept 1: the person said to leave it out (2026-11-20).
- Menu and front-end look, shared menu theme: the "Restyle main menu" thread
  owns `systems/ui/theme.tres`, `menu_theme.tres` and ui-hud.md sections 1 and 5.
- Field ability icon and tactical slot: their features (F-22, Lure Beacon) add them.
- Objective list (ui-hud.md section 10): not built yet, stays its own task.
- Text-size setting scaling the new panels: the HUD has no text-size hook
  today; later with the accessibility pass.

## Ready to build

- Foundations touched: 4 Events and signals (HUD listens only), 2 Content and
  ids in data (two new Resource fields). Both solid.
- Decision records: ADR 0002 (content as resources: icons are data fields,
  no id checks in code), ADR 0003 (trusted client: the HUD only reads),
  ADR 0011 (UI router: no new screens, the HUD is not a routed screen),
  ADR 0008 (code-built assets: SVG icons written by hand as text files are
  the source). Goes against none.
- Co-op:
  - Who decides: nothing new is decided. The HUD shows the local player's
    replicated state.
  - How a client triggers it: n.a. (no requests).
  - What other players see: nothing; each player's HUD is their own.
  - Dedicated server: the HUD is instanced there too (game_session.tscn,
    hub_session.tscn) with no local player and stripped visual resources
    (hud.gd guards the vignette material). New nodes must work with a null
    player and null textures, and the `hud_icon_missing` warn must not fire
    on the server (it fires only when a local player is shown an item).
- Data: `SerumData.icon` and `WeaponData.hud_icon` (Texture2D, default null)
  set in `content/serums/*.tres` and `content/weapons/*.tres`. Code compares
  against a specific id: no.
- Save: no change.
- Events and UI: no new Events. Uses `player_health_changed`, `ammo_changed`,
  `weapon_switched`, `serum_gained`, `player_revived`, `round_started`,
  `intermission_started`. New screens: n.a.
- Input through InputFrame: the HUD reads no input. Gameplay in
  `_physics_process`: the HUD is visuals only, `_process` is right.
  Randomness: none.
- Tests: unit tests per new HUD node (`tests/unit/test_vitals_panel.gd`,
  `test_serum_slots.gd`, `test_weapon_panel.gd`, `test_compass.gd`,
  `test_world_prompt.gd`), content checks for the new icon fields. Existing
  tests that read the replaced nodes move with each step (named per step):
  `test_hud.gd`, `test_ui_fonts.gd`, `test_coop_hud.gd`, `test_grenade_slot.gd`,
  `tests/helpers/coop_hud_shot.gd`, `tests/manual/loot_preview.gd`.
  `test_power_up_timers.gd` stays green unchanged.
- Logging: `Log.warn` when a Serum or gun has no icon (`hud_icon_missing`),
  once per id, listed in docs/LOGGING.md.
- Performance: panels draw with `_draw` and redraw only when a value changes;
  no per-frame allocations (cached strings, fonts, textures).
- Lore link: see the header line.
- Out of scope: see Not in.

## Design references

- Concept images: `docs/design/concepts/screens/hud_concept.jpg`,
  `hud_concept_2.jpg`, `hud_serum_slots.png` (added with this plan).
- docs/design/ui-hud.md "UI style" tokens: panel #121A20 at 88%, line
  #2C3B44, text #E6ECEC, text_dim #8FA3A8, warn #FF9F1C, danger #C3201B,
  experiment #8DFF3A. Type sizes at 1080p: 56 HUD ammo, 72 round number
  (the concept's "ROUND 3" is smaller; see DECISIONS line below).
- docs/design/ui-hud.md section 10 Match HUD (layout); this plan updates it.
- docs/design/game-design.md line 182 says "You hold up to 4" Serums, but
  docs/DECISIONS.md ("Serums": no limit on Serums held) wins, so the row shows
  4 slots and grows; line 412: ammo orange at 25% of the magazine, red when
  empty; line 86: sprint 4 s then 3 s cooldown.
- docs/design/lore.md Serums row (line 55) and "Grenades and field kit".
- docs/DECISIONS.md HUD line (XP bar, ring, feed).
- docs/adr/0002, 0003, 0008, 0011.

## Systems touched

| Folder or file | New / changed | What changes |
|---|---|---|
| systems/ui/hud/vitals_panel.gd | new | Angled panel, health cross, 5 health segments, runner + stamina bar |
| systems/ui/hud/serum_slots.gd | new | Row of square slots (4 minimum, grows with Serums held) |
| systems/ui/hud/weapon_panel.gd | new | Gun icon, ammo, divider, frag icon + count (absorbs GrenadeSlot) |
| systems/ui/hud/compass_strip.gd | new | Heading strip from the local camera yaw |
| systems/ui/hud/round_counter.gd | new | "ROUND n" top right with the red underline and the intermission blink |
| systems/ui/hud/world_prompt.gd | new | Prompt box, leader line and brackets around player.focus |
| systems/ui/hud.gd / hud.tscn | changed | Old Vitals, Loadout ammo, RoundInfo and Prompt nodes replaced by the new nodes; serum, ammo and round code moves out |
| systems/ui/grenade_slot.gd | deleted (step 3) | Folded into weapon_panel.gd |
| systems/ui/crosshair.gd | changed | Default line length / thickness thinner |
| systems/serums/serum_data.gd | changed | `@export var icon: Texture2D`; `badge` and `badge_colour` stay (badge_colour is the slot colour; badge text is the fallback when icon is null) |
| systems/weapons/weapon_data.gd | changed | `@export var hud_icon: Texture2D` |
| assets/ui/hud/*.svg | new | 8 Serum icons, 7 gun class silhouettes, cross, runner, frag |
| content/serums/*.tres, content/weapons/*.tres | changed | Point at the icons |

Autoloads, managers or base classes added: none. The angled panel is drawn
inline in VitalsPanel and copied into WeaponPanel; the prompt box turned out
rounded (a StyleBox), so there is no third user and no shared helper (Keep it
simple rule 2).

Files over 300 lines this plan grows: `hud.gd` (321) shrinks; every step moves
code out of it. `hud.tscn` shrinks too.

## Data

- `SerumData.icon: Texture2D = null`: read by SerumSlots. Missing icon draws the badge text.
- `WeaponData.hud_icon: Texture2D = null`: read by WeaponPanel. Missing icon draws nothing and warns once.
- Gun class icons (provisional, one SVG per class): pistol, smg, rifle,
  shotgun, lmg, sniper, special (Siphon, Cryo Lance, Synapse). Each gun's
  `.tres` and its `_reforged` copy point at its class icon.
- Save format change: none.
- Content checks to add in `tests/content/`: every Serum has an `icon`, every
  WeaponData in `content/weapons/` and `content/melee/` has a `hud_icon`
  (the knife gets a knife icon). `tests/fixtures/weapons/*.tres` are test
  fixtures and are excluded.
- Colours: the new nodes use the ui-hud.md tokens as constants (text #E6ECEC,
  warn #FF9F1C, danger #C3201B, panel #121A20 at 88%, line #2C3B44), replacing
  GrenadeSlot's e8ece6 / ff8a1c.

## Co-op behaviour

- Who owns the state: unchanged. Health, Serums and frag count come from the
  server through the existing snapshot and Events; ammo, stamina, focus and
  camera yaw are the owning client's own simulation (ADR 0003).
- What clients send, what the server sends back: nothing new.
- What a client sees that the host sees too: each player sees only their own
  HUD; teammates keep the squad cards.
- Late joiner: health arrives through `player_health_changed`, grenades from
  the snapshot, and held Serums as `serum_gained` from player_state_sync.gd,
  as today; no new message.
- Dedicated server: the HUD exists with no local player. New nodes do nothing
  while `player` is null and draw nothing when a texture is null.

## Performance

Six small `_draw` Controls. Each caches its last shown values and calls
`queue_redraw()` only when one changes (compass: when the heading moves more
than 0.2 degrees; world prompt: while a prompt is visible). Strings are built
only on change. No allocations per frame. Budget: under 0.1 ms CPU per frame
for the whole HUD at 1080p with 24 zombies.

## Steps

### Step 1: vitals panel

- Build: new `VitalsPanel` in an angled dark panel (cut top-left and
  bottom-right corners, thin line border, drawn inline):
  cross icon + 5 health segments (each = max / 5, the last partly filled,
  danger red under 30%), runner icon + stamina bar from
  `player.sprint_left / (player.sprint_time * player.get_stat(&"sprint_time"))`,
  drawn in warn orange while `not player.can_sprint()` (cooldown). Replace
  `Root/Vitals/Health` in hud.tscn; the Serum row stays where it is for now.
  Level label stays above the XP strip, the panel sits above it.
  Update ui-hud.md section 10 bottom left.
- Files: systems/ui/hud/vitals_panel.gd,
  systems/ui/hud.gd, systems/ui/hud.tscn, docs/design/ui-hud.md, docs/DECISIONS.md, docs/ROADMAP.md.
- Tests: `tests/unit/test_vitals_panel.gd`: filled segments for 100/100,
  50/100, 10/250; red under 30%; stamina share and cooldown flag from a stub
  player; null player draws nothing. `test_hud.gd` health-bar tests move here.
- Done when: the left panel matches concept 1 in a look-check render, tests green.

### Step 2: Serum slots with icons

- Build: `SerumData.icon`; 8 SVG icons (Ironhide cross, Stride runner,
  Quickhands hand, Overclock gauge, Deadeye eye, Scavenger crate, Second Wind
  heart, Mule third gun), white line art. New `SerumSlots`: 4 square slots,
  one more for each Serum past 4, filled slot = `badge_colour` square + icon, empty =
  dark slot with line border. Moves `_on_serum_gained` and `_drop_lost_serums`
  out of hud.gd. Sits above the vitals panel. Content check for icons.
- Files: systems/serums/serum_data.gd, assets/ui/hud/serum_*.svg (+ .import),
  content/serums/*.tres, systems/ui/hud/serum_slots.gd, hud.gd, hud.tscn,
  tests/content/ (serum check), docs/LOGGING.md, tests/unit/test_hud.gd
  (serum tests move out).
- Tests: `tests/unit/test_serum_slots.gd`: 0, 2 and 8 Serums give the right
  filled and empty slots; losing Serums on down empties them; missing icon
  falls back to badge text and warns once; no warn with a null player. Content test: every Serum has an icon.
- Done when: buying a Serum fills the next slot with its icon; going down empties them.

### Step 3: weapon panel

- Build: `WeaponData.hud_icon`; 7 gun class SVGs; every weapon `.tres`
  points at one. New `WeaponPanel` in an angled panel: gun icon, magazine
  (Mono 56) and "/ reserve" (Mono 28), magazine warn orange at 25% and danger
  red at 0 (game-design.md line 412; today it is red at 25%), a divider, frag
  icon + count (dim at 0,
  warn orange while cooking, key text kept small). Moves `_on_ammo_changed`
  and `_on_weapon_switched` out of hud.gd; deletes `grenade_slot.gd` and its
  test, moving its checks to the new test. Points and points delta stay above
  the panel; the gun name shows small above the panel. Hint label unchanged.
- Files: systems/weapons/weapon_data.gd, assets/ui/hud/gun_*.svg,
  content/weapons/*.tres, systems/ui/hud/weapon_panel.gd, hud.gd, hud.tscn,
  systems/ui/grenade_slot.gd (deleted), tests/unit/test_grenade_slot.gd
  (deleted, checks moved), tests/unit/test_hud.gd (ammo and weapon tests move
  out), tests/unit/test_ui_fonts.gd (AmmoLabel, PointsLabel paths),
  tests/content/ (weapon icon check).
- Tests: `tests/unit/test_weapon_panel.gd`: ammo text, orange at 25% and red
  at 0, frag
  count dim at 0 and orange while cooking (from the old grenade test), icon
  swap on weapon switch. Content test: every WeaponData has a hud_icon.
- Done when: the right panel matches concept 1; frag count from F-24 still right.

### Step 4: round counter, compass and crosshair

- Build: new `RoundCounter` top right: "ROUND 3" (Mono, 40 px provisional)
  with a red underline that fades in on round start and blinks at
  intermission, replacing `Root/RoundInfo` (map name moves under it, small).
  Squad cards move down under it. New `CompassStrip` top centre: 120 degree
  window, ticks every 15 degrees, N / NE / E ... letters, north = world -Z
  (provisional). Exfil box moves below the compass. Crosshair default line
  length 7, thickness 1.5. Lore row for the compass. Moves round code out of hud.gd.
- Files: systems/ui/hud/round_counter.gd, systems/ui/hud/compass_strip.gd,
  systems/ui/crosshair.gd, systems/ui/squad_cards.gd (offset only), hud.gd,
  hud.tscn, docs/design/lore.md, docs/design/ui-hud.md, docs/DECISIONS.md
  (round counter moves from top left to top right and is smaller than the
  72 px token), tests/unit/test_ui_fonts.gd (RoundLabel, MapName paths),
  tests/helpers/coop_hud_shot.gd and tests/manual/loot_preview.gd
  (`hud.round_label`). Both stay hidden in the town (hub_session) until the
  first `round_started`, like the round label today.
- Tests: `tests/unit/test_compass.gd`: yaw 0 shows N centred, yaw -90 shows
  E centred, letters wrap at 360; hidden before the first round. `test_hud.gd` round tests move to the
  round counter test (text on round start, blink at intermission).
- Done when: top of the screen matches concept 2; exfil box and squad cards do not overlap.

### Step 5: pickup prompt on the object

- Build: new `WorldPrompt`: when `coop_hud.get_prompt()` returns text and
  `player.focus` is set, project the focus's bounds (its first
  CollisionShape3D's AABB, cached when the focus changes) to screen, draw four
  corner brackets around it, a thin leader line from the brackets' top-right
  to a rounded dark box with the key cap and the action text (price kept).
  With no focus (revive, downed, spectating) the box shows at today's fixed
  spot without brackets. Off-screen or behind the camera: fixed spot. The
  existing `Root/Prompt` box and `_update_prompt` in hud.gd stay (less code);
  WorldPrompt only moves the box and draws the brackets and line. The box gets
  the concept's rounded light border, a white key cap and capital letters.
- Files: systems/ui/hud/world_prompt.gd, hud.gd, hud.tscn,
  tests/unit/test_coop_hud.gd (prompt_label / prompt_box checks),
  tests/unit/test_hud.gd (prompt and rebind tests move out).
- Tests: `tests/unit/test_world_prompt.gd`: price split from "[F] 950" text
  (moved from test_hud.gd), brackets rect from a known camera and box shape,
  fallback to the fixed spot when the focus is behind the camera or null.
- Done when: looking at a wall-buy, door or Med Dispenser shows the bracketed prompt; revive prompt still works.

## Acceptance

- [ ] The HUD in a look-check render of Halcyon Labs matches the concept's
  layout: left vitals panel, Serum slots, right weapon panel, compass, round counter.
- [ ] Damage numbers, level-up ring, drop feed, power-up timer row, frag
  count, points, XP bar, squad cards and exfil box still work (existing tests green).
- [ ] In the town the compass and round counter stay hidden; the HUD on a
  dedicated server logs no errors or icon warnings.
- [ ] Co-op client HUD shows its own health, Serums and frags (coop soak and `test_hud.gd`).
- [ ] The person play-tests the new HUD and signs off the provisional picks.

## Risks

- hud.gd is near the 350-line limit: every step moves code out before adding any.
- Godot SVG import differences: step 2 adds the first SVGs and their imports
  first, so a bad import fails cheap.
- Interactables with odd shapes (doors, barriers) may give huge brackets:
  step 5 clamps the bracket box to 40% of the screen and falls back to the fixed spot past that.
- The menu thread edits the shared theme at the same time: this plan never
  touches `theme.tres`; HUD colours stay as constants in the new scripts.

## Open decisions

- [x] What the green heartbeat line shows: leave it out (the person, 2026-11-20). Other picks are provisional and go in docs/DECISIONS.md with each step.
