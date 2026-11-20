# Plan: Gear in first person

Status: Approved
Roadmap: F-42 / issue #129
Phase: P7, pulled forward 2026-11-20: the person called the v0.1 solo play-test done and asked to go on with v0.2 features. F-11 (the v0.1.0 release) is not needed: this is client-side visuals only, on the gear swap path from F-84.
Size: M
Approved by: plan review on PR #406 (Claude reviewer, Codex out of quota); the person on the implant card (2026-11-20)
Lore link: lore.md "Story links for game content": Vests (salvaged body armour, its sleeve cuffs), Charms ("Salvagers hang them on the gun for luck"), Implants (forearm module).

## Goal

You see your own loot while you play, not only in menus: the cuffs on your
first-person forearms come from the vest you wear (frame, rarity trim and glow,
dyes), the charm you wear hangs from your primary gun's rail, and your implant
shows on your left forearm. Swapping gear mid-run (F-84) changes what you see at
once. Serves the pillar "Every run makes you stronger".

## Scope

In:

- First-person cuffs follow the worn vest: its frame's `CuffFP_L/R` nodes, its
  rarity look and tier scene, its dyes. No vest: no cuffs (bare jacket sleeve).
  Today every player shows Common medium-vest cuffs whatever they wear.
- The worn charm hangs from a `CharmMount` marker on every primary viewmodel,
  with a small swing. Sidearm viewmodels have no mount, so the charm is not
  shown while a sidearm is in hand (gear-visuals.md: charm on the primary).
- The worn implant's forearm module on the left first-person forearm (step 3).
  The person picked forearm only (2026-11-20): no eye plate.
- A booth render of hip and ADS views per rarity for the look-check.

Not in (non-goals, and where each one goes instead):

- Gloves and jacket sleeves in first person: there is no glove slot or glove
  model yet. F-70 step 3 makes glove models, F-71 the slot, F-70 step 6 the
  sleeve materials. Whichever lands later adds the first-person glove with the
  same pattern as the cuffs in step 1.
- Charm on teammates' third-person guns: teammates keep the charm on the vest
  clip as today (remote players have no viewmodel). Later, with gear-visuals
  set crests and effects.
- Dyes picked by the player (F-46); this plan passes the look's dyes through,
  which are the defaults until F-46.
- Legendary signature effects and the 5/5 set pulse in first person
  (gear-visuals.md steps 5 and 6).
- Weapon inspect key (gear-visuals.md, own feature).
- The DECISIONS.md "Game feel" line that says "Fix when: F-42" is about
  hitstop, not gear; it stays open and is not part of this plan.

## Ready to build

### Ready to build
- Foundations touched (numbers from docs/FOUNDATIONS.md): content as data
  (gear visuals, rarity looks), first-person arms. Neither is shaky for this:
  the arm rig and GearRig look path are in use and tested.
- Decision records that apply (docs/adr/): 0002 content as resources, 0003
  trusted client, 0007 signals and events, 0015 baked player body. Goes against
  one: no.
- Co-op:
  - Who decides: the owning client (its CharacterLook, as today).
  - How a client triggers it: no request. The local GearRig already applies the
    look when gear changes; the first-person view listens to it.
  - What other players see, and how it reaches them: nothing new. They already
    get the look through LookSync and see the third-person body.
  - Works on a dedicated server with no local player: yes. WeaponHolder builds a
    PlayerArmView only when `Build.is_server()` is false and the player is the
    multiplayer authority: a dedicated server and remote players never build one,
    a listen-server host builds one for its own player (correct).
- Data: charm placement is a `CharmMount` Marker3D in each primary viewmodel
  scene; cuff and implant pieces come from the existing GearVisual scenes.
  Code compares against a specific id anywhere: no.
- Save: changes what is saved? no. Renames or removes a saved id: no.
- Events and UI: new Events: none (GearRig's existing `look_changed` signal is
  used, a node signal to the player's own weapon holder). New screens: n.a.
- Input through InputFrame, gameplay in _physics_process, randomness from the
  session RNG: yes; this is visuals only, in `_process`.
- Tests: unit tests on PlayerArmView looks and charm mounting, a content test
  for the mounts; co-op: a remote player builds no first-person gear.
- Logging: `Log.warn(&"gear", &"fp_piece_missing", ...)` once per visual when a
  vest scene has no `CuffFP_*` node or an implant has no module.
- Render settings: every piece made after `_ready` (cuffs, charm, implant) gets
  `ScopeLens.VIEWMODEL_LAYER` and shadows off, like the arm mesh.
- Performance: pieces are made only when the look changes; the charm is moved,
  not rebuilt, on weapon switch; the swing uses fields only.
- Lore link: Vests, Charms, Implants rows in lore.md.
- Out of scope: gloves, sleeves, dyes UI, effects (see Not in).

## Design references

- docs/design/gear-visuals.md: slot table ("Seen in first person?"), "First
  person, in a run" row, first-person arms paragraph (three sockets: cuffs,
  implant, charm on the gun), build step 4 "First-person view".
- docs/design/look-rules.md: rarity trim colours come from `content/looks/rarity/`.
- docs/DECISIONS.md: gear budgets line (first-person arms up to 10,000 tris);
  "Model looks" line (first-person arms are an agent look until the person sees them).
- docs/plans/player-gear-concept.md (F-70): tier per piece rarity
  (`GearVisual.scene_for`), implant step 5, sleeves step 6.
- docs/plans/wear-gear-mid-run.md (F-84): gear swaps mid-run call `GearRig.apply`.
- docs/adr/0015-baked-player-body.md.

## Systems touched

| Folder or file | New / changed | What changes |
|---|---|---|
| systems/gear/gear_rig.gd | changed | Keeps the last applied look in `look: CharacterLook` |
| systems/player/player_arm_view.gd | changed | `apply_look()`: cuffs from the worn vest, charm, implant; charm moves to the bound gun's `CharmMount` |
| systems/player/fp_gear.gd | new (only if player_arm_view.gd would pass 300 lines) | The cuff, charm and implant code moved out of PlayerArmView by job |
| systems/player/charm_swing.gd | new | Small spring swing for the hanging charm (`_process`, visual only) |
| tests/unit/test_player_arm_view.gd, tests/content/test_vest_models.gd | changed | Cuff asserts wear a vest first; cuff check covers tier scenes |
| systems/weapons/weapon_holder.gd | changed | Connects the player's `gear_rig.look_changed` to the arm view when it makes it |
| systems/weapons/viewmodels/*_viewmodel.tscn (18 primary) | changed | One `CharmMount` Marker3D each |
| tools/fp_gear_review.tscn + .gd | new | Hip and ADS renders per rarity for the look-check |
| tests/unit/test_fp_gear.gd | new | Cuffs, charm, implant follow the look |
| tests/content/test_charm_mounts.gd | new | Every primary viewmodel has one CharmMount, sidearms none |
| docs/design/gear-visuals.md, docs/DECISIONS.md, docs/LOGGING.md | changed | What is built, provisional picks, the new warning |

Autoloads, managers or base classes added: none.

Files over 300 lines this plan grows: player_arm_view.gd is 145 lines; if it
would pass 300, the gear code goes to `fp_gear.gd` (split by job) in step 1.

## Data

- `GearRig.look: CharacterLook` (new var, default empty look): the last look
  applied, read by the first-person view when the weapon holder makes it late.
- `CharmMount` Marker3D in the 18 primary viewmodel scenes, placed on the left
  side of the rail in front of the receiver, clear of the support hand's grip
  (checked in the booth render).
- No new Resource types or fields. Vest cuffs come from
  `GearVisual.scene_for(tier)` of the worn vest, so F-70's vest tier scenes work
  without changes as long as they keep `CuffFP_L/R`.
- Save format change: none.
- Network message change: none.
- Content checks in `tests/content/`: new test_charm_mounts.gd (every primary
  viewmodel has exactly one `CharmMount`, no sidearm viewmodel has one); the
  existing cuff check in test_vest_models.gd extended to every vest tier scene.

## Co-op behaviour

- Who owns the state: the owning client (CharacterLook, ADR 0003).
- What clients send, what the server sends back: nothing new.
- What a client sees that the host sees too: teammates see the third-person
  body as today; only the owner sees the first-person cuffs, charm and implant.
- Late joiner: nothing new; the third-person look already reaches them.
- Dedicated server: no first-person view is built, so nothing runs.

## Performance

Look changes are rare (spawn, gear swap). On a change the view frees and makes
at most two cuffs, one charm and one implant module (about 3,000 tris, under the
10,000 first-person arms budget with the arms). Weapon switch reparents the one
charm node. The swing reads the mount's global position once per frame and
keeps two floats; no allocations. One player's view only, never per zombie.

## Steps

### Step 1: Cuffs follow the worn vest

- Build: `GearRig.look`; `PlayerArmView.apply_look(look)` replaces the fixed
  `CUFFS`/`COMMON` cuffs: frees old pieces, takes `CuffFP_L/R` from the worn
  vest's tier scene, attaches them to the forearms as today, and applies the
  vest's RarityLook and dyes with `GearLook.apply`, and sets the viewmodel layer
  and shadows off on them. No vest: no cuffs. A holder with no player (tests)
  uses an empty look. The arm mesh keeps the Common look. WeaponHolder connects `gear_rig.look_changed` to
  the view and applies the current look when it makes the view. Warning
  `fp_piece_missing`. Fp gear review tool renders hip and ADS with Common,
  Rare and Legendary heavy vests.
- Files: gear_rig.gd, player_arm_view.gd (or new fp_gear.gd), weapon_holder.gd,
  tools/fp_gear_review.tscn/.gd, tests/unit/test_fp_gear.gd,
  tests/unit/test_player_arm_view.gd (the cuff asserts at lines 59-60 first wear
  a vest; the scoped-layer test wears a vest on talon_dmr so it checks the cuffs),
  tests/content/test_vest_models.gd (cuff check covers every tier scene),
  docs/LOGGING.md.
- Tests: test_fp_gear.gd: Legendary heavy vest gives cuffs with the Legendary
  trim on both forearms; no vest gives no cuffs; a new look after a gear swap
  replaces the cuffs (no leftovers); a remote player whose GearRig gets a look
  (as LookSync does) still has no arm view. Content check: every vest scene and
  tier scene has both cuff nodes.
- Done when: the review render shows Common, Rare and Legendary cuffs on the
  rifle. Until F-70 adds vest tier scenes they differ by frame, trim and glow,
  not shape.

### Step 2: Charm on the primary gun

- Build: `CharmMount` in the 18 primary viewmodels; the view makes the worn
  charm's scene once per look (rarity look, viewmodel layer, no shadows) and
  keeps it as a child of PlayerArmView, never of a gun: each frame it copies the
  bound gun's `CharmMount` global transform, and hides when the gun has no mount
  or there is no gun. A gun that is replaced or freed (also a primary replaced
  while the sidearm is in hand) can never free the charm;
  `charm_swing.gd` swings it from the mount's motion (spring, clamped angle).
- Files: 18 viewmodel .tscn, player_arm_view.gd / fp_gear.gd, charm_swing.gd,
  tests/content/test_charm_mounts.gd, test_fp_gear.gd, review tool.
- Tests: content check for mounts; test_fp_gear.gd: the charm sits under the
  rifle's mount, moves to the new primary after replace, is hidden with a
  sidearm in hand, survives a primary replaced while the sidearm is in hand,
  and is gone when the charm is unequipped; the swing returns
  to rest when the gun stops.
- Done when: review renders of every primary at hip show the charm on the rail,
  clear of the hands.

### Step 3: Implant on the left forearm, and close-out

- Build: the worn implant's module attaches to `forearm_L` of the first-person
  arms with its rarity look, viewmodel layer and no shadows (the neck port is
  not shown in first person).
  Close-out: gear-visuals.md first-person section and slot table (Implant row)
  updated to the decision, DECISIONS lines,
  roadmap row Done, issue #129 ticked, renders sent to the person.
- Files: player_arm_view.gd / fp_gear.gd, test_fp_gear.gd, docs.
- Tests: test_fp_gear.gd: the implant module follows the left forearm bone and
  changes with the implant; no implant, no module.
- Done when: acceptance ticked and the renders are sent.

## Acceptance

- [ ] Equipped gear changes the first-person arms look: cuffs by vest frame and
      rarity, charm on primaries, implant per the decision (test_fp_gear.gd).
- [ ] A gear swap mid-run updates the first-person view at once (test).
- [ ] Remote players and dedicated servers build no first-person gear (test).
- [ ] Look-check renders at hip and ADS per rarity, sent to the person.

## Risks

- Cuffs or charm clipping the hands or the sights in some grip poses: the
  review tool renders every primary at hip and ADS in step 1 and 2 before merge.
- F-70 vest tier scenes may drop the `CuffFP_*` nodes: the content check fails
  if any vest scene lacks them.
- F-70 step 5 planned an eye plate: settled 2026-11-20 (forearm only); this plan
  PR updates F-70's step 5 to match.
- F-70 step 6 (sleeve materials on `player_arms`) must keep the Common
  `GearLook.apply` on the arm mesh, so the cuffs and arms keep separate looks.
- A charm in view while aiming could distract: it hangs on the left side, below
  the sight line; the person sees the ADS render.

## Open decisions

- [x] Implant placement: forearm only; the concept's eye plate is dropped (the
      person, 2026-11-20).
