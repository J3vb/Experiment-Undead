# Plan: Four new loot slots (headgear, gloves, backpack, boots)

Status: Done
Roadmap: F-71 / issue none (split out of F-70, docs/plans/player-gear-concept.md)
Phase: P6
Size: M
Approved by: first version: the person on decision cards (sets, slot strength, drop mix; 2026-11-17), PR #309. This rewrite: the person on the max health card (2026-11-20), plan PR #412
Lore link: lore.md "Gear and abilities": new Headgear, Gloves, Backpacks and Boots rows (provisional, added in this PR); names follow the Salvager Vest pattern

Rewrite (2026-11-20): a fresh code-vs-plan review found the first version
could not be built as written: a wrong F-70 dependency, tests it would break
with no step to fix them, affix lines no code reads, recoil and mule lines that
only work on loot guns, no swap-speed reader, unlimited max health, the Pack
panel growing unplanned, and no names or lore. This version fixes all of them.
The three decisions from 2026-11-17 stand unchanged.

## Goal

Headgear, gloves, backpack and boots become real loot: they drop, roll
affixes that all do something, sit in the stash, equip in town and mid-run,
and change your stats. Serves "Every run makes you stronger": more slots to
fill means more drops that matter. They show on your body once F-70 steps 2
and 3 land (this plan does not wait for them).

## Scope

In:

- Gear gun lines (All damage, Mule, recoil, aim, swap) work on every gun:
  starter, wall-buy and Vault guns too, as affixes.md says ("all guns").
  Today they only touch loot guns. Damage reduction gets its reader.
- Four gear slots with the ids F-70 fixed: `headgear`, `gloves`,
  `backpack`, `boots`. Loadout goes from 5 slots to 9.
- One base per new slot: `headgear_cap`, `gloves_tactical`, `backpack_pack`,
  `boots_field`, with names and lore rows.
- One affix pool per new slot, built only from lines that have a reader;
  three new affixes.
- A cap on max health from gear (number on a decision card).
- Drop weights so the new slots drop.
- Save format version 3; co-op loadout count and protocol bump.
- Character screen with nine slots; the Tab Pack panel with seven gear boxes.
- The set rule for F-32, written down (decided 2026-11-17).

Not in (non-goals, and where each one goes instead):

- Models, tiers and the look payload for the new slots: F-70 steps 2 and 3.
  Until then the new pieces give stats but are not drawn.
- Readers for Explosion guard, Grab escape, Fast revive, Grenade damage,
  Extra grenade, Scrap find: the features that add grenades, grabs, scrap
  and revive tuning. These six stay on their current slots and stay off the
  new ones (see Risks).
- Set code and set drops: F-32. Named Legendaries for the new slots: F-31.
- More bases per slot: later content, one `.tres` plus an F-70 model each.
- An "Armour" stash filter: not needed; the Gear filter already covers it.
- A bigger Pack or stash: Pack stays 6, stash stays 60.

## Ready to build

```
### Ready to build
- Foundations touched (numbers from docs/FOUNDATIONS.md): 3 saves (version 3),
  4 content ids in data (LookBuilder's id table goes away).
  Any of them shaky or missing? no
- Decision records that apply (docs/adr/): 0003 trusted-client co-op, 0005
  local versioned saves, 0002 saved ids permanent. Does this go against one? no
- Co-op:
  - Who decides: server rolls drops (LootService) and checks hit claims
    against the server copy's gear stats; the owning client owns its stash
    and loadout.
  - How a client triggers it: equips in the character screen or the Pack;
    LoadoutSync.submit_loadout sends up to 7 gear dicts; the server checks
    count, slot and base, then rebuilds stats.
  - What other players see: nothing new until F-70 draws the pieces.
  - Works on a dedicated server with no local player: yes (rolls, validates,
    applies damage reduction).
- Data: bases in content/loot/gear/*.tres, affixes in
  content/loot/affixes/gear/*.tres, weights in the base files, caps in
  content/loot/stat_caps.tres.
  Code compares against a specific id anywhere: no (step 2 removes the
  LookBuilder id table)
- Save: changes what is saved? yes: loadout gains four keys. Version 2 -> 3
  so older builds refuse the file instead of dropping the new slots on save.
  Renames or removes a saved id: no
- Events and UI: no new Events. Changed screens: character screen, Pack panel.
- Input through InputFrame, gameplay in _physics_process, randomness from the
  session RNG: yes (rolls use ItemRoller with session.rng)
- Tests: unit, content and integration per step (listed below), including
  every existing test that pins 5 slots or 13 bases.
- Logging: none new; profile_unreadable, loot.gear_equip_refused and the
  loadout refusal already exist.
- Performance: nothing per frame; stats and gun data rebuild on spawn, equip
  and gun grant only.
- Out of scope: models, sets code, Legendaries, extra bases.
```

## Design references

- docs/design/affixes.md: affix counts, prefix/suffix half rule (a 4-line
  item is 2+2), the 40% rule for gun stats on gear, the caps table, gear
  lines that say "all guns".
- docs/design/balance/loot.csv: rarity shares and drops per run (unchanged).
- docs/plans/player-gear-concept.md: slot ids and visual ids; F-70 step 2
  adds the slots to CharacterLook, step 3 the glove, boot and backpack models.
- docs/plans/wear-gear-mid-run.md: the Pack panel builds its gear boxes from
  `CharacterProfile.GEAR_SLOTS`; character_screen.gd was meant to as well.
- ADR 0005 and client-server-updates.md: never lower
  `SaveFile.CURRENT_VERSION`.
- Decisions by the person, 2026-11-17: four new loot slots; sets are the five
  armour pieces; new slots are full pieces with utility lines only; gear is
  added on top of guns in the drop mix.

## The design

### What works today (checked 2026-11-20)

| Line | Read by | Works on |
|---|---|---|
| Max health, Regen delay, Move speed, Sprint duration | Player | always |
| Reload focus (`reload_pct`), aim (`ads_pct`), sprint-to-fire (`handling_pct`) | Weapon._stat through Player.get_stat | every gun |
| Headshot focus (`hs_pct`) | Weapon._stat (`head_damage`) | every gun |
| All damage (`dmg_pct`), Mule (`deep_reserve`), recoil (`recoil_pct`) | ItemInstance.weapon_data | loot guns only |
| Swap (`swap_time`) | WeaponHolder, Serum multiplier only | no gear line reaches it |
| Damage reduction | nothing | never |
| Explosion guard, Grab escape, Fast revive, Grenade damage, Extra grenade, Scrap find | nothing | never |

Step 1 moves the "loot guns only" row and swap and damage reduction to
"works". The last row stays dormant and off the new slots.

### Slot jobs and pools

Each slot has one job. Existing jobs stay: Vest = staying alive, Charm =
economy and luck, Implant = abilities. Every new slot has exactly 2 prefixes
and 2 suffixes, so a 4-line Legendary always fills, and every line has a
reader after step 1. All damage and Headshot focus stay off (decided
2026-11-17).

| Slot | Job | Prefixes | Suffixes |
|---|---|---|---|
| Headgear | Head and aim | Max health, Steady aim (new) | Regen delay, Reload focus |
| Gloves | Handling | Recoil grip (new), Steady aim (new) | Reload focus, Quick hands (new) |
| Backpack | Carrying | Max health, Damage reduction | Mule, Sprint duration |
| Boots | Moving | Max health, Damage reduction | Move speed, Sprint duration |

Existing affixes only gain slots in their `slots` list; ids, ranges and
weights do not change.

New affixes, ranges from the 40% rule (gun line x 0.4, rounded). On gear the
two aim lines are prefixes, because the gear prefix pool is the "helps you
shoot" side and the new slots have no damage lines:

| Affix id | Text | Kind | Stat | Range | Weight | From |
|---|---|---|---|---|---|---|
| `steady_aim` | +X% aim speed, all guns | prefix | `ads_pct` | 3-8% | 90 | ADS speed 8-20% |
| `recoil_grip` | -X% recoil, all guns | prefix | `recoil_pct` | 3-8% | 90 | Recoil control 8-20% |
| `quick_hands` | +X% swap and sprint-to-fire speed, all guns | suffix | `handling_pct` | 6-14% | 70 | Swap speed 15-35% |

### Caps

- Damage reduction: the existing 30% cap. Four slots roll it (vest,
  backpack, boots at up to 10% each), so the cap can be reached with three
  top pieces.
- Max health: today one slot rolls +10 to +40. With four slots it could reach
  +160 on a 100 base (410 with Ironhide). Decided 2026-11-20: gear max
  health is capped at **+100** in total, as a StatCaps entry on the flat part
  only, so Ironhide's x2.5 still multiplies the base. The character screen
  already shows a capped stat in amber.

### Names and lore (provisional)

| Base id | Name | Story (row in lore.md) |
|---|---|---|
| `headgear_cap` | Salvager Cap | Knit cap, then a headset half-helmet, then an Oriel visor as rarity rises (F-70 tiers) |
| `gloves_tactical` | Salvager Gloves | Work gloves with forearm guards from Rare up |
| `backpack_pack` | Salvager Pack | Field pack; armoured and Oriel packs at higher rarity |
| `boots_field` | Salvager Boots | Field boots; knee and shin plates from Rare up |

Same story as the vests: kit salvaged from Oriel security, the army and the
Cordon, patched together at Lantern Post. More named bases come later.

### Drops

Unchanged from the first version (decided 2026-11-17). At character level 30
and Rare rarity, `LootService.eligible_bases` gives guns 1,630 weight and
today's 13 gear bases 1,300 (100 each). Each new base gets 300, the vest
slot's total, so each new slot drops as often as a vest:

| Slot | Bases | `drop_weight` per base | Slot total |
|---|---|---|---|
| Vest | 3 | 100 | 300 |
| Charm | 5 | 100 | 500 |
| Implant | 5 | 100 | 500 |
| Headgear, Gloves, Backpack, Boots | 1 each | 300 | 300 each |

Gear weighs 2,500 and guns 1,630, so guns fall to about 39% and each new slot
is about 7%. Rarity odds and drops per run do not change.

### Sets (rule for F-32, decided 2026-11-17)

A set is exactly five pieces: headgear, vest, gloves, backpack and boots.
Guns, charm and implant are never set pieces. Bonuses stay at 2/3/5.
`SetData.pieces` maps those five slots to a base; set guns are gone;
bad-luck protection and the 50% Legendary share are unchanged. Step 4 writes
this into docs/DECISIONS.md and F-32's roadmap row.

### Slot order

`CharacterProfile.SLOTS` (save and network order): primary, sidearm, vest,
charm, implant, headgear, gloves, backpack, boots. `GEAR_SLOTS` is the last
seven. Screens use their own display order (below); nothing depends on the
two orders matching.

## Systems touched

| Folder or file | New / changed | What changes |
|---|---|---|
| systems/weapons/weapon.gd | changed | new `refit(gear: StatBlock)`: data rebuilt from the Content base with the item's and the gear's lines, ammo clamped |
| systems/weapons/weapon_holder.gd | changed | `give` / `replace` refit the new gun before filling ammo |
| systems/loot/item_instance.gd | changed | `TIMING_STATS` maps `swap_time` to `handling_pct` |
| systems/loot/item_loadout.gd | changed | `refit_item_guns` becomes `refit_guns` (every gun); `equip_weapon` refits after setting the item; gear loop already uses GEAR_SLOTS |
| systems/net/hit_claims.gd | changed | non-item guns also get the player's gear lines before the bounds check |
| systems/player/player.gd | changed | server `take_damage` scales by 1 - damage reduction |
| systems/loot/stat_block.gd | changed | damage reduction and max health caps (relative / flat part) |
| systems/progression/character_profile.gd | changed | `SLOTS` (9), `GEAR_SLOTS` (7); default loadout built from SLOTS |
| systems/save/save_file.gd | changed | `CURRENT_VERSION` 3, `_v2_to_v3` |
| systems/loot/gear_base_data.gd | changed | `slot` enum gains the four slots |
| systems/gear/look_builder.gd | changed | visual from `GearBaseData.visual_id`; `BASE_VISUALS` and `EQUIPPED_SLOTS` removed |
| core/build.gd | changed | `PROTOCOL_VERSION` 21 -> 22 (or next free at build time) |
| systems/ui/pack_character.tscn | changed | `Slots` VBox becomes a 2-column GridContainer (7 boxes fit) |
| systems/ui/character_screen.gd, .tscn | changed | slots from `CharacterProfile.SLOTS`, two columns; focus code moves out |
| systems/ui/loadout_slots.gd | new | `class_name LoadoutSlots extends HBoxContainer`: builds the slot buttons in two columns, wires their focus, `button_for(slot)`, `paint(loadout)` |
| content/loot/gear/*.tres | new / changed | four new bases; drop weights (step 4) |
| content/loot/affixes/gear/*.tres | new / changed | three new affixes; `slots` lists |
| content/loot/stat_caps.tres | changed | `max_health` cap |
| tools/ci/content_id_baseline.txt | changed | shrinks (LookBuilder lines gone) |
| docs/design/lore.md, affixes.md, DECISIONS.md, ROADMAP.md | changed | lore rows (this PR), pools and cap (step 4), set rule |

Autoloads, managers or base classes added: none. `loadout_slots.gd` is a
split by job (slot buttons and focus) because character_screen.gd is at 345
of 350 lines.

## Data

- `GearBaseData.slot`: enum gains `headgear`, `gloves`, `backpack`, `boots`.
- New bases: ids, names from the table above; `visual_id` = the base id (the
  F-70 GearVisual ids); `loot_tags` = their slot; `unlock_level` 1. Step 2
  ships them with `drop_weight = 0`; step 4 sets 300.
- New affixes: `steady_aim`, `recoil_grip`, `quick_hands`, 5 tiers each like
  every gear affix, `min_rarity` common.
- StatCaps: `max_health` = 100 (decided 2026-11-20), meaning the flat gear bonus.
- Save: `SaveFile.CURRENT_VERSION` 2 -> 3. `_v2_to_v3` returns the data
  unchanged (`CharacterProfile.from_dict` already fills missing slots with
  `{}`); the bump exists so a version 2 build refuses a version 3 file instead
  of loading it and dropping the new slots on its next save. New base and
  affix ids are permanent once shipped (ADR 0002).
- Network: `submit_loadout` may carry up to 7 gear dicts (was 3); the
  server's check already uses `GEAR_SLOTS`. Protocol bump. Item dicts and the
  drop RPC do not change.

## Co-op behaviour

- Who owns the state: server rolls items; each client owns its stash and
  loadout file; the server owns the stats it applies (server copy rebuilt by
  LoadoutSync, as today).
- Gun data: the owner refits its guns with its gear for feel (recoil, aim,
  swap, reserve); the server refits the same way in `hit_claims.gd` before
  checking a claim, so All damage on a wall gun is not refused.
- Damage reduction: applied on the server in `Player.take_damage`, from the
  server copy's stats. Clients only see the lower health through the usual
  health sync.
- Late joiner: submits its loadout at spawn like everyone.
- Dedicated server: rolls, validates and applies damage reduction; no screen.

## Performance

No per-frame cost. A gun's data is rebuilt on grant and on gear change (one
`WeaponData.duplicate()` per held gun). Stats rebuild on spawn and equip
(7 gear items x up to 4 lines = 28 modifiers, was 12).

## Steps

### Step 1: Gear lines on every gun, swap speed, damage reduction

Riskiest part first: it touches the co-op hit check. Label `fix`.

- Needs: none.
- Build: `Weapon.refit(gear)`: `data` = (item or an empty ItemInstance)
  `.weapon_data(Content.weapon(data.id), gear)`, mag and reserve clamped.
  `WeaponHolder.give` / `replace` call it with the owner's `stats` before
  filling ammo, so Mule raises the starting reserve. `ItemLoadout.equip_weapon`
  calls it again after setting `item`; `refit_item_guns` becomes `refit_guns`
  and refits every held gun. `hit_claims.gd` refits non-item guns with the
  sender's gear too. `TIMING_STATS[&"swap_time"] = &"handling_pct"` (serums
  still multiply). Damage reduction: `Player.take_damage` (server) scales a
  copy of the hit by `1 - reduction`. Gotcha: `StatBlock.value(stat, 1.0)`
  for a capped stat clamps the whole result to 0.3, so give damage reduction
  a relative cap like `move_speed` and read it as `get_stat(..., 1.0) - 1.0`.
- Files: weapon.gd, weapon_holder.gd, item_instance.gd, item_loadout.gd,
  hit_claims.gd, player.gd, stat_block.gd, tests.
- Tests: `test_item_instance.gd`: swap time with 10% `handling_pct` is
  base / 1.1, and Quickhands still multiplies. A weapon holder test: a wall
  gun given to a player wearing a vest with Mule and a recoil line gets the
  higher reserve and smaller kicks; taking the vest off and refitting brings
  them back. `test_hit_claims.gd`: a wall-gun claim boosted by All damage is
  accepted, the same claim without the gear is refused. `test_stat_block.gd`:
  five 10% damage reduction lines give 30%. A player test: a 50 hit with 10%
  reduction takes 45 on the server. `test_gear_health_sync.gd`: a client
  wearing damage reduction takes less damage on the server copy.
- Done when: CI green incl. soak (wall guns still behave the same with no
  gear).

### Step 2: Slots, save and loadout

- Needs: step 1 (not F-70: the new slots give stats now and get drawn when
  F-70 adds them to `CharacterLook.SLOTS`).
- Build: `CharacterProfile.SLOTS` / `GEAR_SLOTS`; default loadout from
  `SLOTS`. `GearBaseData.slot` enum; four bases with `drop_weight = 0`.
  SaveFile version 3. LookBuilder loops `CharacterProfile.SLOTS`, reads
  `GearBaseData.visual_id`, drops `BASE_VISUALS` (baseline shrinks); a base
  whose GearVisual does not exist yet uses the slot fallback, as a bad id
  does today. Protocol bump. Pack panel `Slots` becomes a 2-column grid.
  Lore and names already landed in this plan's PR.
- Files: character_profile.gd, save_file.gd, gear_base_data.gd,
  look_builder.gd, core/build.gd, pack_character.tscn, four
  `content/loot/gear/*.tres`, content_id_baseline.txt, tests.
- Existing tests this step must update (they pin 5 slots or 13 bases):
  `tests/unit/test_character_profile.gd` (lines 48, 88, 98, 126, 137),
  `tests/integration/test_character_save.gd:125`,
  `tests/content/test_gear_content.gd` (`SLOTS`, 13 bases at line 51,
  drop weight 100 at line 68: new bases are 0 until step 4),
  `tests/unit/test_inventory.gd:223` (13 checked), `test_look_builder.gd`.
  Gear visual counts (13) stay: F-71 adds no GearVisual.
- New tests: `test_save_file.gd`: a version 2 sample loads with four empty
  new slots and saves as version 3. `test_character_profile.gd`: a headgear
  item survives a save round trip. `test_inventory.gd`: equipping
  `boots_field` from the stash fills `boots`. `test_loadout_sync` / player
  state sync test: 7 gear dicts are applied, 8 are refused, a headgear dict in
  the `vest` key is refused. `test_look_builder.gd`: a vest maps through
  `visual_id` with no table; `gloves_tactical` is skipped (not a look slot
  yet) with no error. `test_pack_overlay.gd`: seven gear boxes in two columns.
  Content: each base's `visual_id` is non-empty, and if that GearVisual
  exists its slot matches.
- Done when: integration test: a headgear item equips, saves, reloads and
  its Max health reaches the server copy in a two-peer test.

### Step 3: Character screen with nine slots

- Needs: step 2.
- Build: new `LoadoutSlots` takes the slot buttons and their focus out of
  character_screen.gd; slots come from `CharacterProfile.SLOTS` (the F-84
  gap at `character_screen.gd:7`). Two columns beside the turntable: armour
  on the left in body order (Headgear, Vest, Gloves, Backpack, Boots), guns
  and small gear on the right (Primary, Sidearm, Charm, Implant). Slot
  labels use the slot names; the tooltip "Slot:" line shows them too. No
  new filter.
- Files: character_screen.gd, character_screen.tscn, new
  systems/ui/loadout_slots.gd, item_tooltip.gd if its slot text is
  hand-written, tests.
- Tests: `test_character_screen.gd`: nine slot buttons in that order; gamepad
  down from Boots and from Implant reaches the stash; right from Headgear
  reaches Primary; equipping a backpack from the stash updates its button and
  the rig rebuilds without error.
- Done when: screenshot of the screen with all nine slots filled (debug
  profile in the test), sent to the person.

### Step 4: Affix pools, drops, cap and close-out

- Needs: step 3 (so drops start only when every screen can equip them).
- Build: three affix files; `slots` lists from the pools table; drop weights
  300; StatCaps `max_health`; affixes.md (pools, new lines, cap row),
  DECISIONS.md (slot jobs, aim lines as gear prefixes, drop split, set rule,
  six dormant lines), F-32 row gets the set rule and Needs F-71. Plan Done,
  roadmap row Done.
- Files: content/loot/affixes/gear/*.tres, content/loot/gear/*.tres,
  content/loot/stat_caps.tres, stat_block.gd (flat max health cap),
  docs, tests.
- Tests: `test_gear_content.gd`: each new slot's pool is exactly its row in
  the pools table; every slot has a base with `drop_weight > 0`; new affixes
  have 5 rising tiers; no new-slot affix is one of the six dormant ones.
  `test_item_roller.gd`: seeded Legendary rolls for each new slot give 2
  prefixes and 2 suffixes from that pool only. `test_loot_service.gd`: from
  `eligible_bases(30, &"rare")`, the weight shares are guns 39% +-2% and each
  new slot 7% +-1% (no RNG). `test_stat_block.gd`: four +40 max health lines
  give +100 on a 100 base, and Ironhide x2.5 gives 350.
- Done when: a soak run drops all four new slots and CI's soak passes.

## Acceptance

- [x] Gear gun lines change starter, wall and Vault guns, and the server
      accepts the boosted hits (test).
- [x] A version 2 save loads with four empty new slots and saves as version 3
      (test).
- [x] A client with all nine slots filled joins a co-op game and the server
      applies its gear stats (test).
- [x] The character screen and the Pack show and equip all new slots with
      mouse and gamepad (test + screenshot).
- [x] All four new slots drop in a soak run and roll only live lines (test +
      soak log).

## Risks

- Step 1 changes every gun a geared player holds: All damage now also boosts
  wall guns, as the design says. Soak and the hit-claims test watch it.
- Six existing lines still roll dead on vest, charm and implant. Out of scope
  here; step 4 records them in DECISIONS.md so their features wire them.
- F-70 steps 2 and 3 slip: the pieces work but are not drawn; the fallback
  look covers it.
- Fewer gun drops (about 39%, was 56%): soak and play-test watch it; weights
  are data.
- character_screen.gd at 345 lines: step 3 splits first.

## Open decisions

- [x] Sets with nine slots: the five armour pieces; guns, charm and implant
      never set pieces (the person, 2026-11-17).
- [x] How strong the new slots are: full pieces, utility lines only (the
      person, 2026-11-17).
- [x] Drop mix: gear added on top; guns fall to about 40% (the person,
      2026-11-17).
- [x] Max health with four slots that roll it: gear max health capped at +100
      on the flat part; Ironhide still multiplies the base (the person,
      2026-11-20).
