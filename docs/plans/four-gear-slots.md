# Plan: Four new loot slots (headgear, gloves, backpack, boots)

Status: Approved
Roadmap: F-71 / issue none (split out of F-70, docs/plans/player-gear-concept.md)
Phase: P6
Size: M
Approved by: the person on decision cards (sets, slot strength, drop mix; 2026-11-17), plan PR (this one)

## Goal

Headgear, gloves, backpack and boots become real loot: they drop, roll
affixes, sit in the stash, equip on the character screen, change your stats
and show on your character (F-70 models). Serves "Every run makes you
stronger": more slots to fill means more drops that matter, and you see the
upgrade on your body.

## Scope

In:

- Four new gear slots with the ids F-70 fixed: `headgear`, `gloves`,
  `backpack`, `boots`. Loadout goes from 5 slots to 9.
- One item base per new slot to start, matching the F-70 visuals:
  `headgear_cap`, `gloves_tactical`, `backpack_pack`, `boots_field`.
- An affix pool per new slot (each slot has one job), three new affixes.
- Drop weights so the new slots drop.
- Save format version 3 with the four empty slots; co-op loadout check and
  protocol bump.
- Character screen with nine slots; stash filter knows the new slots.
- The set rule for nine slots, written down for F-32 (decided 2026-11-17:
  a set is the five armour pieces). F-71 builds no set code.

Not in (non-goals, and where each one goes instead):

- Set code, set bonuses and set drops: F-32 (follows the rule below).
- Named Legendaries for the new slots: F-31 (one per new slot, proposed
  there).
- More bases per new slot (a second helmet shape, a second pack): new content
  later, one `.tres` plus an F-70-style model each.
- Models, tiers and the look payload: F-70 (steps 2 and 3).
- Gear in first person: F-42. Dyes: F-46.
- A bigger Pack or stash: not needed; Pack stays 6, stash stays 60.

## Ready to build

```
### Ready to build
- Foundations touched (numbers from docs/FOUNDATIONS.md): 3 saves (version 3
  + migration), 4 content ids in data (LookBuilder's id table goes away).
  Any of them shaky or missing? no
- Decision records that apply (docs/adr/): 0003 trusted-client co-op, 0005
  local versioned saves, 0002 saved ids permanent. Does this go against one? no
- Co-op:
  - Who decides: server rolls drops (LootService, as today); the owning client
    owns its stash and loadout (as today).
  - How a client triggers it: equips in the character screen; at spawn
    LoadoutSync.submit_loadout sends up to 7 gear dicts; the server checks
    the count and that each base exists, then rebuilds stats.
  - What other players see: the worn pieces through LookSync (F-70 step 2).
  - Works on a dedicated server with no local player: yes (server only rolls
    and validates).
- Data: bases in content/loot/gear/*.tres, affixes in
  content/loot/affixes/gear/*.tres, weights in the base files.
  Code compares against a specific id anywhere: no (step 1 removes the
  LookBuilder id table)
- Save: changes what is saved? yes: loadout gains four keys. Defaults are
  empty dicts, SaveFile version 2 -> 3 with a migration and an old-sample test.
  Renames or removes a saved id: no
- Events and UI: no new Events. New screens: n.a. (character screen changes)
- Input through InputFrame, gameplay in _physics_process, randomness from the
  session RNG: yes (rolls use ItemRoller with session.rng)
- Tests: unit (profile, inventory, roller, loadout check), content (gear slots
  and pools), integration (save round trip, client loadout to server).
- Logging: none new; profile_unreadable and the loadout refusal already exist.
- Performance: nothing per frame; stats rebuild only on equip and spawn.
- Out of scope: sets code, Legendaries, extra bases, models.
```

## Design references

- docs/design/affixes.md: rarity affix counts, prefix/suffix half rule, tiers,
  "gun stats on gear roll at about 40% of the gun version", caps.
- docs/design/balance/loot.csv: rarity shares (unchanged); drops per run
  (unchanged; only the gun/gear split moves, see Data).
- docs/plans/player-gear-concept.md: slot ids, visual ids, F-70 step 2 adds
  the slots to CharacterLook and the 35-byte look.
- docs/plans/client-server-updates.md and ADR 0005: whatever v0.1.0 ships is
  what later builds must read; never lower `SaveFile.CURRENT_VERSION`.
- Decisions by the person, 2026-11-17: four new loot slots (F-70 card); sets
  are the five armour pieces (this plan's card).

## The design

### Slot jobs

Each slot has one job so a player knows where to look for a stat. Existing
jobs stay: Vest = staying alive, Charm = economy and luck, Implant = abilities.

| Slot | Job | Prefixes | Suffixes |
|---|---|---|---|
| Headgear | Head and aim | Max health, Damage reduction | Explosion guard, Steady aim (new), Grab escape |
| Gloves | Handling | Recoil grip (new), Grenade damage | Reload focus, Quick hands (new), Fast revive |
| Backpack | Carrying | Max health, Grenade damage | Mule, Extra grenade, Scrap find |
| Boots | Moving | Max health, Damage reduction | Move speed, Sprint duration, Grab escape |

Every new slot has at least 2 prefixes and 2 suffixes, so a 4-line Legendary
(2+2) always fills. The shared damage lines (All damage, Headshot focus) stay
on vest, charm and implant only (decided 2026-11-17: full pieces, utility
stats).
Existing affixes only gain slots in their `slots` list; their ids, ranges and
weights do not change.

New affixes, ranges from the 40% rule (gun line x 0.4, rounded):

| Affix id | Text | Kind | Stat | Range | Weight | From |
|---|---|---|---|---|---|---|
| `steady_aim` | +X% aim speed, all guns | suffix | `ads_pct` | 3-8% | 90 | ADS speed 8-20% |
| `recoil_grip` | -X% recoil, all guns | prefix | `recoil_pct` | 3-8% | 90 | Recoil control 8-20% |
| `quick_hands` | +X% swap and sprint-to-fire speed, all guns | suffix | `handling_pct` | 6-14% | 70 | Swap speed 15-35% |

All three stats are already read by the gun code through `player.stats`.

### Affix counts

Same as all gear: Common 0, Uncommon 1, Rare 2-3, Epic 3-4, Legendary 4
(decided 2026-11-17). No new rarity rule.

### Drops

Today guns weigh about 1,630 (sum of `crate_weight x 100` at full unlock) and
gear 1,300 (13 bases x 100), so guns are about 56% of drops. Decided
2026-11-17: gear is added on top. Old bases keep `drop_weight = 100`; each new
base gets 300, the same total as the vest slot today, so a new slot drops as
often as a vest:

| Slot | Bases | `drop_weight` per base | Slot total |
|---|---|---|---|
| Vest | 3 | 100 | 300 |
| Charm | 5 | 100 | 500 |
| Implant | 5 | 100 | 500 |
| Headgear, Gloves, Backpack, Boots | 1 each | 300 | 300 each |

Gear weighs 2,500 and guns 1,630, so guns fall to about 40% of drops and each
new slot is about 7%. Rarity odds and drops per run (loot.csv) do not change.

### Sets (rule for F-32, decided 2026-11-17)

A set is exactly five pieces: headgear, vest, gloves, backpack and boots.
Guns, charm and implant are never set pieces. Bonuses stay at 2/3/5, and the
three starter sets keep their bonuses from affixes.md. What changes for F-32:

- `SetData.pieces` maps those five slots to a base; the content check is
  "exactly the five armour slots", not "one per slot".
- Set guns are gone ("the set's AR is always a Vanguard AR" no longer holds).
- Bad-luck protection (x2 weight per missing piece) and the 50% share of
  Legendaries are unchanged, so the "about 30 runs per set" check still holds.
- A full set reads as one outfit, which fits the F-70 tiers and the set crest
  in gear-visuals.md.

Step 2 writes this into `docs/DECISIONS.md` and F-32's roadmap row.

## Systems touched

| Folder or file | New / changed | What changes |
|---|---|---|
| systems/progression/character_profile.gd | changed | `SLOTS` (9) and `GEAR_SLOTS` (7) constants; loadout and `_valid_inventory` use them |
| systems/save/save_file.gd | changed | `CURRENT_VERSION` 3, `_v2_to_v3` adds the four empty slots |
| systems/loot/gear_base_data.gd | changed | `slot` enum gains the four slots |
| systems/loot/item_loadout.gd | changed | gear loop uses `CharacterProfile.GEAR_SLOTS` |
| systems/net/loadout_sync.gd | changed | `GEAR_SLOTS` from the profile (7) |
| core/build.gd | changed | `PROTOCOL_VERSION` bump |
| systems/gear/look_builder.gd | changed | visual from `GearBaseData.visual_id`; `BASE_VISUALS` table and its baseline lines removed |
| content/loot/gear/*.tres | new / changed | four new bases; drop weights (step 2) |
| content/loot/affixes/gear/*.tres | new / changed | three new affixes; `slots` lists |
| systems/ui/character_screen.gd (+ new `loadout_slots.gd`) | changed / new | nine slots in two columns; the file is at 340 of 350 lines, so slot buttons move out |
| systems/ui/character_screen.tscn | changed | two slot columns beside the turntable |
| tools/ci/content_id_baseline.txt | changed | shrinks (LookBuilder lines gone) |
| docs/DECISIONS.md, docs/ROADMAP.md | changed | slot jobs, drop split, set rule |

Autoloads, managers or base classes added: none. `loadout_slots.gd` is a
split by job (slot column building and focus) under the file limit.

## Data

- `GearBaseData.slot`: enum gains `headgear`, `gloves`, `backpack`, `boots`.
- New bases (`content/loot/gear/`): `headgear_cap`, `gloves_tactical`,
  `backpack_pack`, `boots_field`; `visual_id` = same id (F-70 GearVisuals),
  `loot_tags` = their slot, `unlock_level` 1. Step 1 ships them with
  `drop_weight = 0` (equip and save work, nothing drops yet); step 2 sets the
  weights.
- New affixes: `steady_aim`, `recoil_grip`, `quick_hands` (table above),
  5 tiers like every gear affix.
- `CharacterProfile.SLOTS`: primary, sidearm, vest, charm, implant, headgear,
  gloves, backpack, boots (this order is also the order on screen and in
  saves). `GEAR_SLOTS`: the last seven.
- Save format change: `SaveFile.CURRENT_VERSION` 2 -> 3. `_v2_to_v3` adds
  `headgear`, `gloves`, `backpack`, `boots` as `{}` to `loadout` when missing.
  Old saves load with empty new slots. Older builds refuse a version 3 save
  instead of loading it and dropping the new slots' items on the next save
  (today's `to_dict` only writes the slots it knows). New base and affix ids
  are permanent once shipped (ADR 0002).
- Network: `submit_loadout` may carry up to 7 gear dicts (was 3); protocol
  bump so an old server never refuses a new client mid-join. Item dicts and
  the drop RPC do not change.
- Content checks to add in `tests/content/`: every gear slot has at least one
  base with `drop_weight > 0` (from step 2); every gear slot's pool has at
  least 2 prefixes and 2 suffixes; new affixes have 5 rising tiers; each
  base's `visual_id` names a GearVisual of the same slot.

## Co-op behaviour

- Who owns the state: server rolls items (LootService); each client owns its
  stash and loadout file; the server owns the stats it applies (as today).
- What clients send, what the server sends back: client sends its gear and
  item guns once at spawn (`submit_loadout`, now up to 7 gear); server checks
  count and base ids and applies stats. Drops go server to owner as today.
- What a client sees that the host sees too: worn pieces through the F-70
  look. Item stats are private to the owner and the server.
- Late joiner: submits its loadout at spawn like everyone; receives looks
  from the LookSync cache (F-70).
- Dedicated server: rolls and validates only; no screen, no save.

## Performance

No per-frame cost. Stats rebuild on spawn and equip only (7 gear items x up
to 4 lines = 28 modifiers, was 12). Rolling a drop scans the loot ids once,
as today.

## Steps

### Step 1: Slots, save and loadout

- Needs: F-70 step 2 merged (CharacterLook has the four slots and the four
  GearVisuals exist).
- Build: `CharacterProfile.SLOTS` / `GEAR_SLOTS`; every hard-coded slot list
  in profile, ItemLoadout, LoadoutSync and LookBuilder uses them.
  `GearBaseData.slot` enum; four new bases with `drop_weight = 0`. SaveFile
  version 3 with `_v2_to_v3`. LookBuilder reads `GearBaseData.visual_id` and
  drops `BASE_VISUALS` (baseline shrinks). Protocol bump.
- Files: character_profile.gd, save_file.gd, gear_base_data.gd,
  item_loadout.gd, loadout_sync.gd, look_builder.gd, core/build.gd,
  four `content/loot/gear/*.tres`, content_id_baseline.txt, tests.
- Tests: `test_save_file.gd`: a version 2 sample loads with four empty new
  slots and saves as version 3. `test_character_profile.gd`: loadout has 9
  slots; a headgear item survives a save round trip. `test_inventory.gd`:
  equipping `boots_field` from the stash fills `boots`. Player state sync
  test: a client loadout with 7 gear dicts is applied, 8 is refused.
  `test_look_builder.gd`: a `gloves_tactical` item maps to its visual without
  the table.
- Done when: a debug-granted headgear equips, saves, reloads and shows on a
  co-op teammate.

### Step 2: Affix pools and drops

- Build: three new affix files; slot lists from the Slot jobs table; drop
  weights from the Drops table; DECISIONS.md entries
  (slot jobs, drop split, set rule); F-32 roadmap row gets the set rule and
  Needs F-71.
- Files: content/loot/affixes/gear/*.tres, content/loot/gear/*.tres,
  docs/DECISIONS.md, docs/ROADMAP.md, tests.
- Tests: `tests/content/test_gear_content.gd`: the checks from Data.
  `test_item_roller.gd`: seeded Legendary rolls for each new slot give 4
  lines, 2 prefixes and 2 suffixes, only from that slot's pool, never All
  damage or Headshot focus. Loot service test: with a fixed seed, 10,000
  base picks give each new slot 7% +-1% and guns 40% +-2%.
- Done when: a soak run drops all four new slots and CI's soak passes.

### Step 3: Character screen and close-out

- Build: nine slot buttons in two columns beside the turntable: armour on
  the left in body order (Headgear, Vest, Gloves, Backpack, Boots), guns and
  small gear on the right (Primary, Sidearm, Charm, Implant). Slot buttons
  and their focus wiring move to `loadout_slots.gd`. Stash Category filter
  gets an "Armour" entry (the five armour slots). Tooltip "Slot:" line shows
  the new names. Plan to Done, roadmap row Done.
- Files: character_screen.gd, character_screen.tscn, new
  systems/ui/loadout_slots.gd, docs.
- Tests: `test_character_screen.gd` (or the existing screen test): nine slot
  buttons in that order; gamepad down from Boots reaches the filters; equipping
  a backpack from the stash updates its slot button and the turntable rig.
- Done when: screenshot of the screen with all nine slots filled, sent to the
  person.

## Acceptance

- [ ] A version 2 save loads with four empty new slots and saves as version 3
      (test).
- [ ] All four new slots drop in a soak run and roll from their own pools
      (test + soak log).
- [ ] A client with all nine slots filled joins a co-op game and the server
      applies its gear stats (test).
- [ ] The character screen shows and equips all nine slots with mouse and
      gamepad (test + screenshot).

## Risks

- F-70 step 2 slips: step 1 waits for it; nothing else here depends on the
  models.
- Stat creep from 7 gear pieces: damage lines stay off the new slots and caps
  (StatCaps) already limit move speed and damage reduction.
- Fewer gun drops (about 40%, was 56%): soak and play-test watch whether
  players still find gun upgrades often enough; the weights are data, so a
  retune is one `.tres` change.
- Save shipped in v0.1.0 without the new slots: the version 3 migration covers
  it either way.
- character_screen.gd at 340 lines: step 3 splits slot building out first.

## Open decisions

- [x] Sets with nine slots: a set is the five armour pieces (headgear, vest,
      gloves, backpack, boots); guns, charm and implant are never set pieces
      (the person, 2026-11-17).
- [x] How strong the new slots are: full pieces (same affix counts), utility
      stats only; damage lines stay on vest, charm and implant (the person,
      2026-11-17).
- [x] Drop mix: gear is added on top; guns fall to about 40% of drops (the
      person, 2026-11-17).
