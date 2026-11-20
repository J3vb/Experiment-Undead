# Plan: Legendaries and traits

Status: Review
Roadmap: F-31 / issue #116
Phase: P6
Size: L
Approved by:
Lore link: docs/design/lore.md#story-links-for-game-content, "Legendaries" row: named items with a past, each name hinting at a place or person from the lore. Each Legendary gets a one-line flavour text in that spirit. One rename (Second Wind becomes Last Rites, below) to fix the name clash the lore audit flagged.

## Goal

A Legendary drop is a named gun or gear piece with one fixed trait that
changes how it plays (Tidewater, Lantern Fall, Quarantine Shell), and the
trait rolls in a range, so a good copy is still worth chasing. Pillar: every
run makes you stronger.

## Scope

In:

- `LegendaryData` content: name, base, trait text, range, flavour. One
  `.tres` per Legendary.
- The roller adds the trait (`"trait": [legendary_id, q]`) to a Legendary
  rolled on a base that has one. The saved dict already has the `trait` key.
- Item name and trait line in the tooltip, the loot feed and the results
  screen.
- 14 Legendaries whose trait only needs systems that exist today:

| Legendary | Base (id) | Trait | Range | Runs on | Step |
|---|---|---|---|---|---|
| Tidewater | Vanguard AR (`rifle_ar`) | Each hit on the same zombie +X% damage, up to 10 stacks; a new target keeps half | 3-5% | server | 1 |
| Lantern Fall | Vanguard AR (`rifle_ar`) | Headshot kills explode for X% of weapon damage | 25-40% | server | 2 |
| Ricochet | Mako PDW (`mako_pdw`) | Headshots bounce to the nearest zombie within 8 m for X% damage | 40-70% | server | 2 |
| Choir Mark | Talon DMR (`talon_dmr`) | Kills mark zombies within 6 m for 4 s; marked zombies take +X% damage from the whole squad | 15-25% | server | 2 |
| Bloodline | Kestrel SMG (`kestrel_smg`) | Hits heal X% of damage dealt while you are below half health | 2-4% | server | 2 |
| Black Ledger | Charm (`charm_keycard`) | Carrying more than 10,000 points gives +X% damage | 5-10% | server | 2 |
| Bottomless | Kestrel SMG (`kestrel_smg`) | Every Xth kill refills the magazine | 15th-10th | owner | 3 |
| Overpressure | Brenner Trench (`brenner_trench`) | First shot after a reload fires X times the pellets | 1.6-2x | owner | 3 |
| Dead Man's Hand | Hollis .44 (`hollis_44`) | The last round in the magazine deals X times damage and always staggers | 3-5x | owner | 3 |
| Cold Snap | Atlas Auto (`atlas_auto`) | Reloading an empty magazine freezes zombies within X m for 2 s | 3-5 m | owner asks, server freezes | 3 |
| Quarantine Shell | Vest (`vest_heavy`) | The first hit every X s is fully blocked | 10-6 s | server | 4 |
| Iron Lung | Vest (`vest_medium`) | Health regen starts at once after a kill streak of X | 6-4 | server | 4 |
| Last Rites (was Second Wind) | Warden P9 (`pistol_service`) | While downed, X kills with this gun revive you, once per round | 8-5 | server | 4 |
| Twin Pin | Implant (`implant_relay`) | Frags split into 2 smaller frags at X% damage each | 55-70% | server | 5 |

- From step 5: a Legendary roll only picks bases that have a Legendary, as
  affixes.md says ("each Legendary drops only on its base"). Until then,
  bases without one keep rolling unnamed Legendaries (as today), so drops do
  not shrink to one gun while the steps land.

Not in (non-goals, and where each one goes instead):

- Furnace (Halberd LMG): its "bullets ignite" needs burning, which does not
  run yet (the Incendiary affix is a `proc` line that does nothing). Later:
  new row F-90 "More Legendaries".
- Overkill (Corvid .338) and Overclock (Implant): need a rename first (name
  clashes with the Overkill power-up and the Overclock Serum, lore audit), and
  Overclock needs field abilities (F-22). Later: F-90.
- Gambler's Coin (Charm): the Specimen Vault hands out plain guns, not loot
  rolls, so "one rarity higher" has nothing to act on. Later: F-90.
- The 9 proposed traits for the newer bases in gun-roster.md (Last Word,
  Gravedigger, Kicking Mule, Long Furrow, Breakwater, Triple Tap, Hush, Iron
  Rain, Plate Splitter). Later: F-90.
- Set pieces and the 50% set share (later: F-32 Item sets).
- Branch-tag synergies ("Marksman-tagged lines 25% stronger"): no skill reads
  tags yet. `branch_tag` is not added until a reader exists (Keep it simple 1).
  Later: F-21.
- A visible mark on Choir Mark targets, and any new art or sound. Traits reuse
  existing effects (blast, chain arc, frost). New look: after play-test.
- Upgrading old Legendary items: Legendaries already in a stash keep no trait
  and keep their base name. Nothing migrates.

## Ready to build

### Ready to build
- Foundations touched (numbers from docs/FOUNDATIONS.md): 2 ids in data (all
  trait numbers and bases in `.tres`), 3 item effects where the server applies
  the hit (`HitClaims.apply_server_hit` already has the attacker and the item
  uid), 6 co-op messages (one new owner-to-server request in step 3). None
  shaky.
- Decision records that apply (docs/adr/): 0003 trusted-client co-op. Owner
  traits that change the owner's own gun (magazine, pellets, last-round
  damage) run on the owner; the server only widens its sanity bounds for that
  item. Does this go against one? no
- Co-op:
  - Who decides: server for damage bonuses, heals, freezes, blocks, revives,
    explosions; the owning client for its own magazine and pellets.
  - How a client triggers it: hits already arrive as claims with the item uid;
    the server looks up `player.item_guns[uid]`. Cold Snap is the one new
    request: `LegendaryTraits.request_cold_snap(item_uid)`; the server checks
    the item is the sender's, has the trait, and a cooldown of the gun's
    reload time.
  - What other players see, and how it reaches them: zombie health, deaths,
    freezes (synced `frozen` flag), chain arcs and blasts already sync.
  - Works on a dedicated server with no local player: yes.
- Data: `content/loot/legendaries/*.tres` (`LegendaryData`). Each trait has its
  own stat name, read by the code that runs it. Code compares against a
  specific id anywhere: no (code reads stat names, like skills and affixes).
- Save: changes what is saved? no. The item dict already has `"trait": null`;
  a Legendary now stores `[legendary_id, q]`. Unknown ids load as no trait
  (dormant, as affixes.md says). Renames or removes a saved id: no.
- Events and UI: no new Events, no new screens. Tooltip, loot feed and results
  screen change text only.
- Input through InputFrame, gameplay in _physics_process, randomness from the
  session RNG: yes (the trait's q and the Legendary pick use the roller's RNG).
- Tests: per step below; every trait has an effect test, co-op traits run from
  a client.
- Logging: `Log.warn(&"loot", &"unknown_legendary", ...)` once per item when a
  saved trait id is not in this build; `Log.warn(&"net", &"trait_rejected",
  ...)` for a refused Cold Snap request.
- Performance: per hit one dictionary lookup (item by uid) and one stat read;
  no per-frame work; marks and stacks are small dictionaries pruned on use.
- Lore link: above.
- Out of scope: see Not in.

## Design references

- docs/design/affixes.md#legendary-traits: names, bases, traits and ranges
  (all numbers in the table above come from it).
- docs/design/affixes.md#tooltips: trait on top in Legendary orange with a
  diamond; ranges written high-to-low are "lower is better".
- docs/design/affixes.md#network-and-save-format: `trait = [id, q]`, unknown
  ids stay dormant.
- docs/design/affixes.md#data-as-godot-resources: TraitData and LegendaryData
  (merged here, see Data).
- docs/design/game-design.md Loot table: Legendary 0.9% of zombie drops.
- docs/design/balance/roster.csv "Legendary" column: which base owns which.
- docs/design/lore.md "Legendaries" row and the open question on name clashes.
- docs/DECISIONS.md "Loot extras" line (traits save but do not run).
- docs/adr/0003-trusted-client-co-op.md.

## Systems touched

| Folder or file | New / changed | What changes |
|---|---|---|
| systems/loot/legendary_data.gd | new | `LegendaryData` resource |
| content/loot/legendaries/*.tres | new | one per Legendary (14 over the steps) |
| systems/loot/item_roller.gd | changed | adds the trait to Legendary rolls |
| systems/loot/item_instance.gd | changed | loads the trait as a stat line; `legendary()`; `display_name()` |
| systems/loot/legendary_traits.gd | new | server node: per-player trait state and the server-side trait effects |
| systems/game/game_session.gd | changed | creates `LegendaryTraits` next to `HitClaims` |
| systems/net/hit_claims.gd | changed | calls `LegendaryTraits` in `apply_server_hit`; wider bounds for Overpressure and Dead Man's Hand items |
| systems/weapons/weapon_instance.gd | changed | owner-side kill count and "first shot after reload" flag |
| systems/weapons/weapon.gd, systems/weapons/weapon_holder.gd | changed | owner traits (step 3) |
| systems/player/revive.gd | changed | Quarantine Shell block, Last Rites |
| systems/throwables/*.gd | changed | Twin Pin split (step 5) |
| systems/loot/loot_service.gd | changed | Legendary rolls pick only bases with a Legendary (step 5) |
| systems/ui/item_tooltip.gd, systems/ui/loot_feed.gd, results screen | changed | Legendary name and trait line |
| core/build.gd | changed | `PROTOCOL_VERSION` +1 in step 3 (new RPC) |

Autoloads, managers or base classes added: `LegendaryTraits` node (Keep it
simple 6: it owns state no node owns today, the per-player Tidewater stacks,
Choir marks, Quarantine timers and Last Rites counts). No base class: traits
are not one script each (see Data).

Files over 300 lines this plan grows: `systems/player/player.gd` (350, at the
limit) is not touched; player-side trait checks go in `Revive` and
`LegendaryTraits`. `weapon.gd` (288) and `weapon_holder.gd` (296) get one or
two calls each; the owner logic lives in a new small
`systems/weapons/owner_traits.gd` (static functions) so neither passes 350.

## Data

- `LegendaryData` (new Resource, `systems/loot/legendary_data.gd`):
  `id: StringName`, `display_name: String`, `base_id: StringName`,
  `stat: StringName` (the trait's own stat, e.g. `&"tidewater"`),
  `text: String` ("Each hit on the same zombie: +{v}% damage (10x)"),
  `low: float`, `high: float`, `step: float`, `lower_is_better: bool`,
  `flavour: String`. Read by `ItemRoller`, `ItemInstance`, the tooltip.
- TraitData and LegendaryData are merged into one file: every trait belongs
  to exactly one Legendary today, so a second resource is a second file per
  item with nothing to share (Keep it simple 2). Sets bring their own bonuses
  in F-32. DECISIONS line.
- A trait is one more line in the item's `StatBlock`: stat = `LegendaryData.stat`,
  op `flat`, value = `lerp(low, high, q)` snapped to `step` (for
  "lower is better" ranges `low` is the worse end, so a high q is always good).
  Gun traits sit on the gun's `ItemInstance`; gear traits fold into the
  player's stats through `equip_gear` like any gear line, so `player.stats`
  answers "does this player have Quarantine Shell and how strong". The code
  that runs a trait reads its stat (`item.stats.value(&"tidewater", 0.0)`),
  the same way skills read stats. No enum, no script per trait.
- `LegendaryTraits.STATS`: the list of trait stats that have code. A content
  test fails if a Legendary names a stat not in it, so a typo cannot ship a
  trait that does nothing.
- Item dict: `"trait": ["tidewater", 0.55]` (Legendary id, q). Two Legendaries
  on one base (Vanguard AR, Kestrel SMG) pick evenly with the roller's RNG.
- Save format change: none. `v` stays 1. Old Legendaries have
  `"trait": null` and stay as they are.
- Network: drops already send the whole dict. Step 3 adds one RPC
  (`request_cold_snap(item_uid: String)`), protocol +1 (one above main's
  value when that step merges).
- Content checks in `tests/content/test_legendaries.gd` (new): every
  Legendary's base exists (weapon or gear base) and is not a Prototype; stat
  is in `LegendaryTraits.STATS`; `low < high`; text has `{v}`; at most two
  Legendaries per base; flavour is not empty.

## Co-op behaviour

- Who owns the state: the server owns every trait's run state (stacks, marks,
  block timers, downed-kill counts, Cold Snap cooldown) in `LegendaryTraits`,
  keyed by player. The owning client owns Bottomless kill counts and the
  Overpressure flag on its `WeaponInstance` (like Dead Center).
- What clients send, what the server sends back: nothing new for server
  traits (hit claims carry the item uid). Cold Snap: the owner sends
  `request_cold_snap(uid)` after an empty-mag reload starts; the server
  freezes zombies and the existing `frozen` sync shows it everywhere.
- What a client sees that the host sees too: zombie deaths, health, freezes,
  chain arcs, blasts, the downed player getting up. Only the owner: magazine
  refills, extra pellets, the tooltip.
- Host checks: Dead Man's Hand and Overpressure send bigger or more hits. The
  server allows them only for an item uid whose `ItemInstance` has that trait:
  `_valid_hit` multiplies its maximum by the item's Dead Man's Hand value, and
  `take_claim` counts pellets times the Overpressure value. Any other gun keeps
  today's bounds.
- Late joiner: needs nothing; items are personal and server state starts
  empty.
- Dedicated server (no screen, no local player): runs all server traits;
  tooltip text is client-only.

## Performance

Per server hit: one `item_guns` lookup (already done for affixes), one
`StatBlock.value` read per trait stat on that item (a Legendary has 5
modifiers), and for Tidewater and Choir Mark one dictionary lookup by zombie
instance id. Marks expire by time checked on use; dead zombies are erased on
`Events.enemy_killed`. Lantern Fall and Ricochet search zombies only on a
headshot kill or headshot, using the spawner's children like `Chain._targets`
does. No per-frame cost, no allocation per hit beyond the existing
`DamageInfo`. Budget: no measurable change to the 24-zombie soak frame time.

## Steps

### Step 1: Legendary data, roll, save, tooltip and Tidewater

- Build: `LegendaryData`; `content/loot/legendaries/tidewater.tres`.
  `ItemRoller.roll_weapon` and `roll_gear`: for rarity `legendary` on a base
  with Legendaries, pick one with the RNG and add `[id, q]`. `ItemInstance`
  loads the trait as a flat stat line (unknown id: no line, one `Log.warn`),
  adds `legendary() -> LegendaryData` and static `display_name(item)` (the
  tooltip, loot feed and results screen all call it). Tooltip: trait line on
  top in Legendary orange with a diamond, value from the roll; Alt shows the
  range like other lines. New `LegendaryTraits` node (server) created by
  `GameSession` next to `HitClaims`; `apply_server_hit` calls
  `traits.scale_hit(zombie, info)` before `receive_hit`. Tidewater: per
  attacker, `[zombie id, stacks]`; each hit with that item adds a stack up
  to 10, a new target keeps half (rounded down); the hit's damage is multiplied
  by `1 + stacks * value / 100` (a "more" multiplier, after bounds checks).
  DECISIONS: rewrite "Loot extras" (traits now run), add "TraitData merged
  into LegendaryData" and "trait = stat line". Roadmap row: Building.
- Files: systems/loot/legendary_data.gd (new), content/loot/legendaries/tidewater.tres (new), systems/loot/item_roller.gd, systems/loot/item_instance.gd, systems/loot/legendary_traits.gd (new), systems/game/game_session.gd, systems/net/hit_claims.gd, systems/ui/item_tooltip.gd, systems/ui/loot_feed.gd, the results screen script, docs/DECISIONS.md, docs/ROADMAP.md.
- Tests: `tests/unit/test_item_roller.gd`: a seeded Legendary AR gets
  `trait = ["tidewater", q]` with q in 0..1, a Rare gets null, a Legendary on a
  base without one gets null. `tests/unit/test_item_instance.gd`: the trait
  value at q 0 and 1, "lower is better" maths, an unknown trait id loads with
  no line and no error, save round trip keeps the trait.
  `tests/content/test_legendaries.gd` (new, checks in Data).
  `tests/unit/test_legendary_traits.gd` (new): Tidewater stacks to 10 and no
  further, switching target keeps half, another gun adds nothing, a client's
  claim gets the bonus on the server (co-op). `tests/unit/test_item_tooltip.gd`:
  a Legendary shows its name and the trait line first.
- Done when: a Legendary AR drops as Tidewater with a working trait in solo
  and co-op; CI green.

### Step 2: Server hit and kill traits

- Build: four gun traits and one gear trait in `LegendaryTraits`, all on the
  server. Lantern Fall: a headshot kill with the item damages zombies within
  `LANTERN_FALL_RADIUS` for value% of the gun's damage, and shows the frag
  blast on every peer through `GrenadeClaims.broadcast_blast` (already
  server-to-all). Ricochet: a headshot also hits the nearest
  other zombie within 8 m for value% of the hit, shown with
  `Chain.show_arcs`. Choir Mark: a kill marks zombies within 6 m for 4 s;
  any player's hit on a marked zombie is multiplied by `1 + value / 100`.
  Bloodline: a hit heals the attacker value% of damage dealt while under half
  health. Black Ledger (gear): more than 10,000 points multiplies the
  player's hits by `1 + value / 100`. Bonus hits from Lantern Fall and
  Ricochet do not trigger traits again (no chains of chains).
- Files: systems/loot/legendary_traits.gd, systems/net/grenade_claims.gd (call only), content/loot/legendaries/{lantern_fall,ricochet,choir_mark,bloodline,black_ledger}.tres, systems/net/hit_claims.gd (kill hook only if `Events.enemy_killed` is not enough).
- Tests: `tests/unit/test_legendary_traits.gd`: each trait's effect at a fixed
  value (blast hits a zombie at 3 m and not at 6 m; ricochet picks the nearest
  in 8 m and none past it; marks expire after 4 s and boost another player's
  hit; Bloodline heals at 40% health and not at 60%; Black Ledger at 10,001
  points and not at 10,000); a bonus hit does not trigger Lantern Fall again;
  one trait from a client's claim (co-op).
- Done when: five more Legendaries drop and work in solo and co-op; CI green.

### Step 3: Owner gun traits and Cold Snap

- Build: new `systems/weapons/owner_traits.gd` (static, owner only, like Dead
  Center). Bottomless: `WeaponInstance.trait_kills` counts confirmed kills
  with the gun in hand; at value kills the magazine refills from reserve
  (`refill_magazine`) and the count resets. Overpressure: a reload sets
  `WeaponInstance.charged`; the next shot fires `round(pellets * value)`
  pellets and clears it. Dead Man's Hand: the shot that empties the magazine
  multiplies its damage by value and sets a stagger flag on the `DamageInfo`.
  Cold Snap: starting a reload with an empty magazine sends
  `LegendaryTraits.request_cold_snap(uid)`; the server checks sender owns the
  item, it has the trait, and one reload time has passed since the last one,
  then freezes every zombie within value m for 2 s (`Frost` gets a
  `freeze(zombie, seconds)` entry so the frozen flag, pose and shatter rules
  stay in one place). Server bounds: `HitClaims._valid_hit` and `take_claim`
  widen only for an item with Dead Man's Hand or Overpressure (Co-op
  behaviour). Protocol +1.
- Files: systems/weapons/owner_traits.gd (new), systems/weapons/weapon_instance.gd, systems/weapons/weapon.gd, systems/weapons/weapon_holder.gd, systems/weapons/effects/frost.gd, systems/loot/legendary_traits.gd, systems/net/hit_claims.gd, core/build.gd, content/loot/legendaries/{bottomless,overpressure,dead_mans_hand,cold_snap}.tres.
- Tests: `tests/unit/test_owner_traits.gd` (new): Bottomless refills on the
  value-th kill only; Overpressure fires more pellets once after a reload;
  Dead Man's Hand multiplies only the last round; none of them run on the
  server's copy of a client. `tests/unit/test_hit_claims.gd`: a 4x claim from
  a Dead Man's Hand item passes, the same claim from a plain Hollis is
  rejected; Overpressure pellets pass the claim rate. `test_legendary_traits.gd`:
  Cold Snap freezes in range only, a second request inside the cooldown and a
  request for someone else's uid are refused and logged (co-op, from a client).
- Done when: four owner traits work in solo and co-op; CI green (`test`,
  `quality`, `soak`, `coop-soak`).

### Step 4: Player traits and the Last Rites rename

- Build: Quarantine Shell: `Revive.absorbs` (server) asks
  `LegendaryTraits.blocks(player, info)`: the first hit after value s since
  the last block is ignored. Iron Lung: value kills in a row without taking
  damage start health regen at once (skip the regen delay). Last Rites (the
  Warden P9 Legendary, renamed from Second Wind): while downed, value kills
  with that item gun get the player up, once per round, the same way a Second
  Wind self-revive does (`Revive.second_wind`). The downed pistol must be the
  Legendary Warden when the player holds one (`PlayerStateSync` keeps an owned
  pistol today; check and fix if a plain one replaces it). Lore: rename note
  in lore.md's open question (Second Wind clash fixed; Overkill and Overclock
  left for F-90).
- Files: systems/player/revive.gd, systems/loot/legendary_traits.gd, systems/net/player_state_sync.gd (only if the pistol check needs it), content/loot/legendaries/{quarantine_shell,iron_lung,last_rites}.tres, docs/design/lore.md.
- Tests: `test_legendary_traits.gd`: Quarantine Shell blocks once per window;
  Iron Lung skips the delay after the streak and a hit resets the streak; Last
  Rites revives after value downed kills, only once per round, only with that
  gun, and a co-op client's Last Rites works through its claims.
- Done when: three more Legendaries work in solo and co-op; CI green.

### Step 5: Twin Pin, Legendary-only bases and close-out

- Build: Twin Pin: when a frag thrown by a player whose stats have the trait
  goes off, two smaller frags spawn beside it and go off after a short fuse at
  value% damage each; they do not split again. `LootService.eligible_bases`:
  for rarity `legendary`, only bases with a Legendary. Roadmap: F-31 Done, new
  row F-90 "More Legendaries" (Furnace, Overkill, Overclock, Gambler's Coin
  and the 9 new-base traits, with the two renames). Tick Acceptance, Status
  Done, DECISIONS lines for the provisional picks. Run `finish-feature`.
- Files: systems/throwables/*.gd (the frag's go-off), systems/loot/loot_service.gd, content/loot/legendaries/twin_pin.tres, docs/plans/legendaries-traits.md, docs/ROADMAP.md, docs/DECISIONS.md.
- Tests: `tests/unit/test_frag*.gd` or `test_legendary_traits.gd`: a Twin Pin
  frag makes two child blasts at value% damage, a plain frag none, children
  never split. `tests/unit/test_loot_service.gd` (or the existing drop test):
  a seeded Legendary drop is always on a base with a Legendary and carries a
  trait; lower rarities still use every base.
- Done when: every Legendary in `content/loot/legendaries/` has an effect test;
  CI green (`quality`, `test`, `soak`).

## Acceptance

- [ ] Traits are data files (`content/loot/legendaries/*.tres`) per affixes.md - `tests/content/test_legendaries.gd`
- [ ] Roller tests cover trait rolls and save/load - `test_item_roller.gd`, `test_item_instance.gd`
- [ ] Each trait has an effect test - `test_legendary_traits.gd`, `test_owner_traits.gd`
- [ ] Every trait works for a co-op client (server traits through claims, owner traits on the owner only) - co-op cases in the same files
- [ ] Tooltip shows the name and the trait line first in Legendary orange - `test_item_tooltip.gd`
- [ ] A Legendary drop always has a trait (after step 5) - drop test
- [ ] Soak passes with no new warnings - CI `soak` and `coop-soak` on the step PRs

## Risks

- Trait damage passing hit bounds. Server traits multiply after the bounds
  check, so bounds stay as they are; only Dead Man's Hand and Overpressure
  widen them, and only for an item that has the trait (step 3 tests both ways).
- Owner traits running twice (owner and the server's copy). Every owner hook
  checks `is_multiplayer_authority()` like Dead Center; tests cover the server
  copy.
- Lantern Fall and Ricochet chaining into each other or into Chain/Frost
  effects. Bonus hits carry a flag and skip trait hooks; tested in step 2.
- `player.gd` is at 350 lines. Nothing in this plan edits it.
- Protocol clash with other open PRs in step 3: merge main first and take one
  above main's value.
- Only one Legendary exists after step 1, but bases without one keep rolling
  unnamed Legendaries until step 5, so drops are not all Tidewater meanwhile.

## Open decisions

Provisional picks (reversible, written to DECISIONS when built):

- [x] Provisional: Second Wind (Warden P9) is renamed Last Rites to end the clash with the
  Second Wind Serum. Overkill and Overclock get new names when F-90 builds them.
- [x] Provisional: gear Legendary bases are Quarantine Shell on the heavy vest, Iron Lung on the
  medium vest, Black Ledger on the key card charm, Twin Pin on the relay implant
  (affixes.md names only the slot).
- [x] Provisional: Lantern Fall's blast radius is 4 m (affixes.md gives none; the middle of the
  other trait radii), as `LANTERN_FALL_RADIUS`, tuned in play-test.
- [x] Provisional: Iron Lung's "kill streak" is kills in a row without taking damage.
- [x] Provisional: Choir Mark marks have no visual yet; added after the play-test if needed.
- [x] Provisional: old Legendaries in stashes stay unnamed with no trait.

For the person:

- [ ] Approve this plan (size L): 14 Legendaries in 5 steps, the 13 others
  (Furnace, Overkill, Overclock, Gambler's Coin, 9 new-base traits) moved to a
  new roadmap row F-90.
