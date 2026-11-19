# Plan: Wear loot gear mid-run from the Pack

Status: Approved
Roadmap: F-83 / issue none (solo play-test 2026-11-19)
Phase: P6
Size: M
Approved by: the person on decision card and reference image (layout, 2026-11-19); plan review by a separate Claude reviewer on PR #380 (Codex out of quota), 3 blocking findings fixed
Lore link: docs/design/lore.md#gear-and-abilities, rows Vests, Charms, Implants (salvaged armour and keepsakes you strap on in the field); one provisional line added for swapping implant modules in the field

## Goal

A vest, charm or implant you pick up in a run can be worn right away from the
Tab Pack overlay, and the overlay shows your character with its gear slots.
Serves "Every run makes you stronger": a good drop changes the run you are in,
not only the next one. Asked for in the person's solo play-test (2026-11-19).

## Scope

In:

- Pack overlay: the Equip key (`pack_equip`, E) on a gear item wears it. The
  piece it replaces goes into the same Pack slot (a swap, so the Pack never
  overflows). An empty worn slot just takes the item out of the Pack.
- The worn gear counts at once: stats (server and owner), look (teammates see
  it through the existing LookSync), and the profile loadout saved at the end
  of the run.
- Pack overlay layout, left half: your character on top as a live 3D preview
  (the existing `GearRig` in a `SubViewport`, as the character screen does)
  with gear slot boxes on its left and the two guns in your hands on its
  right; the Pack grid underneath. The item card stays on the right half.
  Selecting a slot shows the worn piece in the tooltip; selecting a Pack gear
  item compares it with the worn piece in its slot.
- Slots come from one list, so F-71's four new slots appear without new code
  in the overlay.
- No free heals: changing gear mid-run never heals. Max health still moves
  with the gear; current health is only capped.
- Held item guns are rebuilt after a gear change, so gear affixes that change
  gun numbers (damage, magazine) apply to guns already in your hands.

Not in (non-goals, and where each one goes instead):

- Taking a piece off into an empty Pack slot without a replacement: not needed
  for the ask (later, if play-tests want it).
- Equipping stash items mid-run: the stash stays a town thing (F-45).
- Gun loadout slots (primary, sidearm) in the overlay: guns already go "into
  hands" today; the saved gun loadout still changes only in town.
- Pausing the game while the overlay is open: the overlay stays a quick check
  with the match running (ui-hud screen 11).
- New slots, their bases and models: F-71 and F-70.

## Ready to build

```
### Ready to build
- Foundations touched (numbers from docs/FOUNDATIONS.md): 3 saves (profile
  loadout changes in memory, saved by the existing bank), 5 UI router (the
  overlay already uses UI.hold_mouse). Any of them shaky or missing? no
- Decision records that apply (docs/adr/): 0003 trusted-client co-op, 0010
  personal loot kept on death, 0011 one UI router. Does this go against one? no
- Co-op:
  - Who decides: the owning client owns its Pack and loadout (ADR 0003, as
    today); the server rebuilds stats from what the owner sends.
  - How a client triggers it: the existing LoadoutSync.send_loadout /
    submit_loadout (pattern 5). The server already checks the gear count and
    dict shape. No new RPC, no protocol bump.
  - What other players see, and how it reaches them: the new look through the
    existing GearRig.look_changed -> LookSync relay (sent only when it changes).
  - Works on a dedicated server with no local player: yes (it only receives
    submit_loadout, as at spawn).
- Data: no new ids or numbers. Gear slots come from GearBaseData.slot via
  Inventory.slot_for. Code compares against a specific id anywhere: no
- Save: changes what is saved? no new fields. The loadout keys already exist;
  the bank after the run saves the swapped loadout. Renames or removes a saved
  id: no
- Events and UI: no new Events. New screens: n.a. (Pack overlay changes)
- Input through InputFrame, gameplay in _physics_process, randomness from the
  session RNG: yes (the swap runs in LootService._physics_process like the gun
  equip; no randomness)
- Tests: unit (loot service swap, no-heal, pack replace, overlay slots),
  integration (a client wears a vest mid-run and the server's copy gains its
  max health; bank saves the swapped loadout).
- Logging: Log.warn `gear_equip_refused` when an equip is asked with no
  profile or a non-gear item (catalogue in docs/LOGGING.md).
- Performance: the preview SubViewport renders only while the overlay is open
  (UPDATE_DISABLED when closed). Stats rebuild only on a swap.
- Lore link: Vests, Charms, Implants rows; one provisional line for field
  implant swaps.
- Out of scope: stash access mid-run, unequip to empty, pausing.
```

## Design references

- docs/design/game-design.md "What you carry": the Pack line ("Guns you pick
  up can be equipped right away") gains gear. Change log row added.
- docs/design/ui-hud.md "11. Pack overlay": half-screen panel, game keeps
  running, mouse look paused. Mockup docs/design/images/ui_pack_overlay.jpg.
- docs/design/ui-hud.md "Character screen" mockup ui_character_screen.jpg for
  the slot buttons and preview style.
- docs/design/gear-visuals.md: you always look like what you wear (no
  transmog), so the look must follow a mid-run swap.
- docs/adr/0010-personal-loot-kept-on-death.md: everything worn or in the Pack
  is banked at every run exit.
- docs/plans/four-gear-slots.md: F-71 grows the slot list to seven gear slots.

## Systems touched

| Folder or file | New / changed | What changes |
|---|---|---|
| systems/loot/loot_service.gd | changed | `_equip_from_pack` also handles gear: swap into `session.profile.loadout`, Pack slot gets the old piece, `ItemLoadout.apply_gear`, look, send_loadout |
| systems/loot/pack.gd | changed | new `replace(index, item)` (emits `changed`) |
| systems/progression/character_profile.gd | changed | new `GEAR_SLOTS: Array[StringName] = [&"vest", &"charm", &"implant"]` (the name F-71 planned; F-71 adds its four slots here) |
| systems/loot/item_loadout.gd | changed | gear loop (line 8) uses `CharacterProfile.GEAR_SLOTS`; new `apply_gear(player, loadout)` for swaps (`equip_gear(gear, false)`, then `refit_item_guns`); new `refit_item_guns(player)` |
| systems/weapons/weapon_holder.gd | changed | new `refit(weapon, data)`: swaps a held gun's data in place, ammo capped to the new magazine, keeps the gun in hand and any reload, no `weapon_acquired` |
| systems/loot/inventory.gd | changed | new `is_gear(item)` (`slot_for(item) in CharacterProfile.GEAR_SLOTS`) |
| systems/player/player.gd | changed | `equip_gear(items, heal = true)`; `_refresh_stats(heal)` skips `health.heal(gained)` when false |
| systems/net/loadout_sync.gd | changed | `_apply_loadout` heals only on its first apply for this Player (`_applied` flag); every later apply (swaps, gun pickups) passes `heal = false`; `_loadout_problem` rejects a gear slot that appears twice or a non-gear base (`slot_for`) |
| systems/ui/pack_overlay.gd | changed | label "Wear" vs "Into hands"; character column moves to new `pack_character.gd` |
| systems/ui/pack_character.gd | new | character column: preview SubViewport with GearRig, slot buttons, guns in hands |
| systems/ui/character_screen.gd | changed | `SLOTS` becomes `[&"primary", &"sidearm"] + CharacterProfile.GEAR_SLOTS`; the gear filter (line 148) uses `Inventory.is_gear` |

`systems/gear/look_builder.gd:5` and `CharacterLook.SLOTS` stay: they are the look's own list, and F-70/F-71 change them. F-83 builds before F-71 (F-71 waits on F-70 step 2); F-71 then extends `CharacterProfile.GEAR_SLOTS` instead of adding it.

Autoloads, managers or base classes added: none.

Files over 300 lines this plan grows: `systems/ui/character_screen.gd` (341)
only swaps a constant (no growth). `systems/player/player.gd` (349, limit
350) may not grow: the heal flag goes into the existing signatures and the
`health.heal(gained if heal else 0.0)` line, no new lines. `pack_overlay.gd`
(240) stays under 300 by putting the character view in its own script.

## Data

- `Pack.replace(index: int, item: Dictionary) -> bool` (new): swaps one item.
- `CharacterProfile.GEAR_SLOTS: Array[StringName] = [&"vest", &"charm", &"implant"]`
  (new); F-71 appends its four slots here.
- `WeaponHolder.refit(weapon: Weapon, data: WeaponData)` (new).
- `Player.equip_gear(items: Array[Dictionary], heal: bool = true)`.
- No Resource types, `.tres` files or network messages change.
- Save format change: none (loadout keys exist; values change at bank time).
- Content checks to add in `tests/content/`: none (no new data).

## Co-op behaviour

- Who owns the state: the owning client owns Pack and profile loadout; the
  server owns the stats it rebuilds from the sent loadout (as at spawn).
- What clients send, what the server sends back: the owner calls
  `LoadoutSync.send_loadout()` (gear dicts + item guns, existing message). The
  server answers nothing; it rebuilds `stats` and max health. Look goes owner
  -> server -> others through LookSync.
- What a client sees that the host sees too: the new worn look on the body.
  Only the owner sees its Pack and the overlay.
- Late joiner: gets the current look from LookSync's join snapshot (existing).
- Dedicated server: no overlay, no Pack; it only applies `submit_loadout`.

## Performance

One 3D preview of one character, drawn only while the overlay is open
(SubViewport `UPDATE_ALWAYS` while open, `UPDATE_DISABLED` when closed, 512 px tall). Nothing per frame when
closed. A swap rebuilds a StatBlock and up to `max_slots` gun datas once.
Budget: no measurable change with the overlay closed; overlay open may cost
under 1 ms on the 4080 target.

## Steps

### Step 1: Wear gear from the Pack (rules, co-op, save)

- Build: `Pack.replace`; `CharacterProfile.GEAR_SLOTS` and `Inventory.is_gear`;
  `ItemLoadout.apply_gear` and `refit_item_guns` (held item guns get new data
  in place through `WeaponHolder.refit`: same gun in hand, ammo kept and
  capped, reload not cancelled, no pickup event); `Player.equip_gear(items,
  heal)`; `LoadoutSync` heals only on its first apply per Player and rejects
  doubled or non-gear slots;
  `LootService._equip_from_pack` wears a gear item (swap with the worn piece
  into the same Pack slot, update `session.profile.loadout`, apply gear,
  `gear_rig.apply(LookBuilder.from_equipped(...))`, `send_loadout()`);
  refuse when downed, dead, match over, the run already banked (`LootService._banked`) or no profile (`gear_equip_refused`).
  Pack overlay button reads "Wear" for gear, "Into hands" for guns.
  Lore row, game-design Pack line and change log, LOGGING catalogue line.
- Files: systems/loot/{pack,inventory,item_loadout,loot_service}.gd,
  systems/player/player.gd, systems/net/loadout_sync.gd,
  systems/ui/pack_overlay.gd, systems/ui/character_screen.gd,
  docs/design/{game-design,lore}.md, docs/LOGGING.md, docs/DECISIONS.md.
- Tests: tests/unit/test_pack.gd (replace), tests/unit/test_loot_service.gd
  (vest swap: Pack slot holds the old vest, loadout holds the new one, refused
  when downed), tests/unit/test_item_loadout.gd (swapping a +health vest off
  and on does not heal, on the host and through a client's resend; held item
  gun gets the new damage, stays in hand and keeps its ammo),
  tests/unit/test_loadout_sync.gd or the existing loadout test (two vests
  rejected), integration
  (client wears a vest, server's player max health changes; bank saves the
  new loadout and puts the old vest in the stash).
- Done when: in solo, E on a Pack vest wears it, the stats and body change at
  once, and after the run the stash has the old vest and the loadout the new.

### Step 2: Character view in the Tab overlay

Layout (the person's reference, 2026-11-19: a loot-game character sheet; not
committed, it is another game's art): inside the half-screen panel, the top
part is your character standing in the middle with gear slot boxes down the
left side and the two guns in your hands down the right side, plus a narrow
column with Level and Max health. The six Pack items sit in a grid
underneath. The item card stays on the right half with the match visible.

- Build: `pack_character.gd`: the top part (SubViewport + body + GearRig,
  look rebuilt on every swap, no turntable input), one square slot box per
  `Inventory.GEAR_SLOTS` entry with rarity border and shape, the guns in
  hands, Level and Max health. The Pack grid moves under it. Focus and mouse
  select a slot to show the worn piece; a selected Pack gear item compares
  with its worn piece (`ItemTooltip.set_comparing`). Preview stops rendering
  when closed. Update ui-hud screen 11 text and re-render the mockup in our
  Cold Containment look.
- Files: systems/ui/pack_character.gd (new), systems/ui/pack_overlay.gd,
  docs/design/ui-hud.md, docs/design/images/ui_pack_overlay.jpg.
- Tests: tests/unit/test_pack_overlay.gd (one slot box per gear slot, labels
  follow a swap, the Pack grid sits under the character, the preview viewport
  is disabled while closed), test_scripts_compile covers the new script.
- Done when: Tab shows the character in its worn gear with its slots on the
  sides and the Pack below, a swap updates the body and slots in the same
  frame, and the finish-feature check passes.

## Acceptance

- [ ] E on a Pack gear item wears it, the old piece takes its Pack slot (test).
- [ ] Swapping gear never heals (test).
- [ ] A client's swap changes the server's stats for that player (integration test).
- [ ] The run's bank saves the new loadout and the old piece (integration test).
- [ ] Tab shows the character and gear slots, and teammates see the new look (play-test).

## Risks

- Free heals by swapping a health vest: fixed in step 1 and tested.
- Gun affixes on gear left stale on held guns: step 1 rebuilds held item guns.
- A full stash at bank time drops the old piece like any Pack item: same as
  today's rule (results screen shows "loot lost"); not new.
- The 3D preview costs frames mid-fight: renders only while open, small size;
  checked in the step 2 play-test with `--print-fps`.

## Open decisions

- [x] Tab overlay layout: half screen, game visible (the person, decision card 2026-11-19)
- [x] Arrangement: character on top with slots on its sides, Pack items underneath (the person, reference image 2026-11-19)
