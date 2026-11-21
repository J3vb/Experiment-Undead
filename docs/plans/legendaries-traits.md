# Plan: Legendaries and traits

Status: Building
Roadmap: F-31 / issue #116
Phase: P6
Size: L
Approved by: plan PR #466 (fresh Claude review, Codex out of quota), the person on the approval card (2026-11-20)
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
| Tidewater | Vanguard AR (`rifle_ar`) | Each hit on the same zombie +X% damage, up to 10 stacks; a new target keeps half | 3-5% | server | 2 |
| Lantern Fall | Vanguard AR (`rifle_ar`) | Headshot kills explode for X% of weapon damage | 25-40% | server | 3 |
| Ricochet | Mako PDW (`mako_pdw`) | Headshots bounce to the nearest zombie within 8 m for X% damage | 40-70% | server | 3 |
| Choir Mark | Talon DMR (`talon_dmr`) | Kills mark zombies within 6 m for 4 s; marked zombies take +X% damage from the whole squad | 15-25% | server | 3 |
| Bloodline | Kestrel SMG (`kestrel_smg`) | Hits heal X% of damage dealt while you are below half health | 2-4% | server | 3 |
| Black Ledger | Charm (`charm_keycard`) | Carrying more than 10,000 points gives +X% damage | 5-10% | server | 3 |
| Bottomless | Kestrel SMG (`kestrel_smg`) | Every Xth kill refills the magazine | 15th-10th | owner | 4 |
| Overpressure | Brenner Trench (`brenner_trench`) | First shot after a reload fires X times the pellets | 1.6-2x | owner | 4 |
| Dead Man's Hand | Hollis .44 (`hollis_44`) | The last round in the magazine deals X times damage (the "always staggers" part waits for F-90: zombies have no stagger yet) | 3-5x | owner | 4 |
| Cold Snap | Atlas Auto (`atlas_auto`) | Reloading an empty magazine freezes zombies within X m for 2 s | 3-5 m | owner asks, server freezes | 4 |
| Quarantine Shell | Vest (`vest_heavy`) | The first hit every X s is fully blocked | 10-6 s | server | 5 |
| Iron Lung | Vest (`vest_medium`) | Health regen starts at once after a kill streak of X | 6-4 | server | 5 |
| Last Rites (was Second Wind) | Warden P9 (`pistol_service`) | While downed, X kills with this gun revive you, once per round | 8-5 | server | 5 |
| Twin Pin | Implant (`implant_relay`) | Frags split into 2 smaller frags at X% damage each | 55-70% | server | 6 |

- From step 6: a Legendary roll only picks bases that have a Legendary, as
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
  uid), 6 co-op messages (one new owner-to-server request in step 4). None
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
| systems/loot/item_instance.gd | changed | loads the trait as a stat line; `legendary()` |
| systems/loot/loot_drop.gd | changed | `item_name` returns the Legendary's name |
| systems/loot/item_loadout.gd | changed | Bloodline beside Leech in `apply_hit` |
| systems/loot/legendary_traits.gd | new | server node: per-player trait state and the server-side trait effects |
| systems/game/game_session.gd | changed | creates `LegendaryTraits` on every peer next to `HitClaims` |
| systems/net/hit_claims.gd | changed | one `LegendaryTraits.on_hit` call in `apply_server_hit`; `claim_hit` scales the item's WeaponData for Overpressure and Dead Man's Hand |
| systems/weapons/weapon_instance.gd | changed | owner-side kill count and "first shot after reload" flag |
| systems/weapons/weapon.gd, systems/weapons/weapon_holder.gd | changed | owner traits (step 4) |
| systems/player/revive.gd | changed | takes the go-down rule from player.gd; Quarantine Shell, Last Rites |
| systems/player/player.gd | changed | lines moved out to Revive only (step 5) |
| systems/damage/health_component.gd | changed | public `start_regen_now()` for Iron Lung |
| systems/weapons/effects/frost.gd | changed | `hold(zombie, seconds)`: frozen without shatter |
| systems/throwables/*.gd | changed | Twin Pin split (step 6) |
| systems/loot/loot_service.gd | changed | Legendary rolls pick only bases with a Legendary (step 6) |
| systems/ui/item_tooltip.gd, systems/ui/character_screen.gd, systems/ui/results_screen.gd | changed | trait line; names through `LootDrop.item_name` |
| core/build.gd | changed | `PROTOCOL_VERSION` +1 in step 4 (new RPC) |

Autoloads, managers or base classes added: `LegendaryTraits` node (Keep it
simple 6: it owns state no node owns today, the per-player Tidewater stacks,
Choir marks and Cold Snap cooldowns). No base class: traits are not one
script each (see Data). Split by job so no file passes 350: hit and kill
traits in `legendary_traits.gd`, owner gun traits in
`systems/weapons/owner_traits.gd`, player traits (Quarantine Shell, Iron
Lung, Last Rites) in `Revive`, Twin Pin in the throwables code.

Files over 300 lines this plan grows: `systems/player/player.gd` (350, at the
limit) only shrinks: step 5 moves the go-down rule (`_on_died`,
`can_self_revive`) into `Revive` before Last Rites uses it. `claim_hit` is
about 54 lines and `apply_server_hit` near complexity 10, so each gets one
call, not inline trait code. `weapon.gd` (288) and `weapon_holder.gd` (296) get one or
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
- Network: drops already send the whole dict. Step 4 adds one RPC
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

### Step 1: Legendary data, roll, save and names

- Build: `LegendaryData`; `content/loot/legendaries/tidewater.tres` (its stat
  does nothing until step 2). `ItemRoller.roll_weapon` and `roll_gear`: for
  rarity `legendary` on a base with Legendaries, after the affixes (so seeded
  tests keep their outputs), pick one with the RNG and add `[id, q]`.
  `ItemInstance` loads the trait as a flat stat line (unknown id: no line, one
  `Log.warn`) and adds `legendary() -> LegendaryData`.
  `LootDrop.item_name` returns the Legendary's name (it already feeds the loot
  feed, pickup prompt, Pack overlay and Pack character view);
  `CharacterScreen._item_name` and the results screen call it instead of their
  own copies. Tooltip: trait line on top in Legendary orange with a diamond,
  value from the roll; Alt shows the range like other lines. DECISIONS:
  "Loot extras" says traits roll (they run from step 2), "TraitData merged
  into LegendaryData", "trait = stat line", "an unknown trait shows no line"
  (affixes.md wants a greyed "Inactive bonus" line; nothing shows one for
  affixes either). Roadmap row: Building.
- Files: systems/loot/legendary_data.gd (new), content/loot/legendaries/tidewater.tres (new), systems/loot/item_roller.gd, systems/loot/item_instance.gd, systems/loot/loot_drop.gd, systems/ui/item_tooltip.gd, systems/ui/character_screen.gd, systems/ui/results_screen.gd, docs/DECISIONS.md, docs/ROADMAP.md.
- Tests: `tests/unit/test_item_roller.gd`: a seeded Legendary AR gets
  `trait = ["tidewater", q]` with q in 0..1, a Rare gets null, a Legendary on a
  base without one gets null, earlier seeded outputs unchanged.
  `tests/unit/test_item_instance.gd`: the trait value at q 0 and 1, "lower is
  better" maths, an unknown id loads with no line and no error, save round
  trip keeps the trait. `tests/content/test_legendaries.gd` (new, checks in
  Data; the known-stat list is `LegendaryTraits.STATS` from step 2, so step 1
  checks against a list in the test and step 2 points it at the constant).
  `tests/unit/test_item_tooltip.gd` and the loot feed test: a Legendary shows
  its name and the trait line first.
- Done when: a Legendary AR drops named Tidewater with its trait line; CI
  green.

### Step 2: LegendaryTraits node and Tidewater

- Build: new `LegendaryTraits` node, created on every peer in
  `GameSession._setup_shooting` next to `HitClaims` and named
  `"LegendaryTraits"` (the step 4 RPC needs the same path on all peers);
  state and effects run only on the server. `apply_server_hit` makes one call,
  `traits.on_hit(zombie, info)`, before `receive_hit` (keeps it under
  complexity 10). Tidewater: per attacker `[zombie id, stacks]`; each hit with
  that item adds a stack up to 10, a new target keeps half (rounded down); the
  hit is multiplied by `1 + stacks * value / 100` (a "more" multiplier, after
  the bounds check). `STATS` constant.
- Files: systems/loot/legendary_traits.gd (new), systems/game/game_session.gd, systems/net/hit_claims.gd, tests/content/test_legendaries.gd.
- Tests: `tests/unit/test_legendary_traits.gd` (new): Tidewater stacks to 10
  and no further, switching target keeps half, another gun adds nothing, a
  client's claim gets the bonus on the server (co-op).
- Done when: Tidewater works in solo and co-op; CI green.

### Step 3: Server hit and kill traits

- Build: four gun traits and one gear trait in `LegendaryTraits`, all on the
  server. Lantern Fall: a headshot kill with the item damages zombies within
  `LANTERN_FALL_RADIUS` for value% of the gun's damage, and shows the frag
  blast on every peer through `GrenadeClaims.broadcast_blast` (already
  server-to-all). Ricochet: a headshot also hits the nearest other zombie
  within 8 m for value% of the hit, shown with `Chain.show_arcs`. Choir Mark:
  a kill marks zombies within 6 m for 4 s; any player's hit on a marked
  zombie is multiplied by `1 + value / 100`. Black Ledger (gear): more than
  10,000 points multiplies the player's hits by `1 + value / 100`. Bloodline:
  a hit heals the attacker value% of damage dealt while under half health; it
  sits beside Leech in `ItemLoadout.apply_hit`. Bonus hits from Lantern Fall
  and Ricochet carry an empty `item_uid`, so they pay no per-hit points, no
  Leech and trigger no trait again.
- Files: systems/loot/legendary_traits.gd, systems/loot/item_loadout.gd, systems/net/grenade_claims.gd (call only), content/loot/legendaries/{lantern_fall,ricochet,choir_mark,bloodline,black_ledger}.tres.
- Tests: `tests/unit/test_legendary_traits.gd`: each trait at a fixed value
  (blast hits a zombie at 3 m and not at 6 m; ricochet picks the nearest in
  8 m and none past it; marks expire after 4 s and boost another player's
  hit; Bloodline heals at 40% health and not at 60%; Black Ledger at 10,001
  points and not at 10,000); a bonus hit pays no points and does not trigger
  Lantern Fall again; one trait from a client's claim (co-op).
- Done when: five more Legendaries drop and work in solo and co-op; CI green.

### Step 4: Owner gun traits and Cold Snap

- Build: new `systems/weapons/owner_traits.gd` (static, owner only, like Dead
  Center). Bottomless: `WeaponInstance.trait_kills` counts confirmed kills
  with the gun in hand; at value kills the magazine refills from reserve
  (`refill_magazine`) and the count resets. Overpressure: a reload that adds at
  least one round (a full reload, or one shell on the Brenner's shell-by-shell
  reload) sets `WeaponInstance.charged`; the next shot fires
  `round(pellets * value)` pellets and clears it. Dead Man's Hand: the shot
  that empties the magazine multiplies its damage by value (the design's
  "always staggers" waits for a stagger mechanic, F-90). Cold Snap: starting a
  reload with an empty magazine sends `request_cold_snap(uid)` to the server
  (MULTIPLAYER.md request/handler shape); the server checks the sender owns
  the item, it has the trait, and one reload time has passed since the last
  one, then freezes every zombie within value m for 2 s through a new
  `Frost.hold(zombie, seconds)`: a hold sets the synced frozen flag and pose
  but does not shatter, so only the Cryo Lance shatters. Server bounds: in
  `claim_hit`, an item with Dead Man's Hand or Overpressure gets its
  duplicated `WeaponData` (from `item.weapon_data()`) scaled (damage by the
  Dead Man's Hand value, pellets by the Overpressure value), so
  `_valid_hit` and `take_claim` keep their signatures. Protocol +1.
- Files: systems/weapons/owner_traits.gd (new), systems/weapons/weapon_instance.gd, systems/weapons/weapon.gd, systems/weapons/weapon_holder.gd, systems/weapons/effects/frost.gd, systems/loot/legendary_traits.gd, systems/net/hit_claims.gd, core/build.gd, content/loot/legendaries/{bottomless,overpressure,dead_mans_hand,cold_snap}.tres.
- Tests: `tests/unit/test_owner_traits.gd` (new): Bottomless refills on the
  value-th kill only; Overpressure fires more pellets once after a reload and
  once after one Brenner shell; Dead Man's Hand multiplies only the last
  round; none run on the server's copy of a client. `tests/unit/test_hit_claims.gd`:
  a 4x claim from a Dead Man's Hand item passes, the same claim from a plain
  Hollis is rejected; Overpressure pellets pass the claim rate.
  `test_legendary_traits.gd`: Cold Snap freezes in range only, a held zombie
  takes normal damage (no shatter), a second request inside the cooldown and a
  request for someone else's uid are refused and logged (co-op, from a
  client).
- Done when: four owner traits work in solo and co-op; CI green (`test`,
  `quality`, `soak`, `coop-soak`).

### Step 5: Player traits and Last Rites

- Build: first move the "go down or die" rule out of `Player._on_died` and
  `Player.can_self_revive` into `Revive` (`Revive.can_get_up()`), so
  player.gd shrinks before anything is added; `MatchEnd.check_squad` keeps
  calling through the player. Player traits live in `Revive`, not
  `LegendaryTraits`, which keeps both files under 350. Quarantine Shell:
  `Revive.absorbs` (server) ignores the first hit after value s since the
  last block. Last Rites (the Warden P9 Legendary, renamed from Second Wind):
  a co-op player holding it goes down instead of dying (solo has no downed
  state, so it does nothing in solo; DECISIONS); while downed,
  value kills with that item gun get them up through
  `state_sync.revive_player()`, once per round, without touching Serums or
  the Undying charge; `can_get_up()` counts an unused Last Rites, so the squad
  is not out. The downed pistol is the Legendary Warden when the player holds
  one (`PlayerStateSync` keeps an owned pistol; checked and fixed if a plain
  one replaces it). Iron Lung: value kills in a row without taking damage
  skip the regen delay; `HealthComponent` gets a public `start_regen_now()`
  and the streak resets on `Events.player_damaged`. Lore: open question on
  name clashes updated.
- Files: systems/player/player.gd (lines moved out only), systems/player/revive.gd, systems/game/match_end.gd (only if the call changes), systems/damage/health_component.gd, systems/net/player_state_sync.gd (only if the pistol check needs it), content/loot/legendaries/{quarantine_shell,iron_lung,last_rites}.tres, docs/design/lore.md.
- Tests: `tests/unit/test_legendary_traits.gd` or `test_skill_rules.gd`:
  Quarantine Shell blocks once per window; Iron Lung skips the delay after the
  streak and a hit resets the streak; Last Rites puts a co-op player down and
  gets them up after value downed kills, once per round, only with that gun,
  Serums and Undying untouched; the run does not end while a downed player has
  an unused Last Rites; a co-op client's Last Rites works through its claims.
  Existing Second Wind and Undying tests still pass unchanged.
- Done when: Quarantine Shell and Iron Lung work in solo and co-op, Last Rites in co-op; player.gd no
  longer than before; CI green.

### Step 6: Twin Pin, Legendary-only bases and close-out

- Build: Twin Pin, in the throwables code: when a frag thrown by a player
  whose stats have the trait goes off, two smaller frags spawn beside it and
  go off after `TWIN_PIN_FUSE` (0.4 s) at value% damage and half the radius; they do not split again and hurt the thrower like any frag.
  `LootService.eligible_bases`: for rarity `legendary`, only bases with a
  Legendary. Roadmap: F-31 Done, new row F-90 "More Legendaries" (Furnace,
  Overkill, Overclock, Gambler's Coin, Dead Man's Hand stagger and the 9
  new-base traits, with the two renames). Tick Acceptance, Status Done,
  DECISIONS lines for the provisional picks. Run `finish-feature`.
- Files: systems/throwables/*.gd (the frag's go-off), systems/loot/loot_service.gd, content/loot/legendaries/twin_pin.tres, docs/plans/legendaries-traits.md, docs/ROADMAP.md, docs/DECISIONS.md.
- Tests: frag test or `test_legendary_traits.gd`: a Twin Pin frag makes two
  child blasts at value% damage, a plain frag none, children never split.
  `tests/unit/test_loot_service.gd`: a seeded Legendary drop is always on a
  base with a Legendary and carries a trait; lower rarities still use every
  base.
- Done when: every Legendary in `content/loot/legendaries/` has an effect
  test; CI green (`quality`, `test`, `soak`).

## Acceptance

- [ ] Traits are data files (`content/loot/legendaries/*.tres`) per affixes.md - `tests/content/test_legendaries.gd`
- [ ] Roller tests cover trait rolls and save/load - `test_item_roller.gd`, `test_item_instance.gd`
- [ ] Each trait has an effect test - `test_legendary_traits.gd`, `test_owner_traits.gd`
- [ ] Every trait works for a co-op client (server traits through claims, owner traits on the owner only) - co-op cases in the same files
- [ ] Tooltip shows the name and the trait line first in Legendary orange - `test_item_tooltip.gd`
- [ ] A Legendary drop always has a trait (after step 6) - drop test
- [ ] Soak passes with no new warnings - CI `soak` and `coop-soak` on the step PRs

## Risks

- Trait damage passing hit bounds. Server traits multiply after the bounds
  check, so bounds stay as they are; only Dead Man's Hand and Overpressure
  widen them, and only for an item that has the trait (step 4 tests both ways).
- Owner traits running twice (owner and the server's copy). Every owner hook
  checks `is_multiplayer_authority()` like Dead Center; tests cover the server
  copy.
- Lantern Fall and Ricochet chaining into each other or into Chain/Frost
  effects. Bonus hits carry an empty `item_uid`, so they skip trait hooks,
per-hit points and Leech; tested in step 3.
- Cold Snap freezing a crowd that any bullet then shatters (Frost's shatter
  kills outright). Step 4 adds a hold that does not shatter.
- `player.gd` is at 350 lines. Step 5 moves lines out before adding any.
- Protocol clash with other open PRs in step 4: merge main first and take one
  above main's value.
- Only one Legendary exists after step 1, but bases without one keep rolling
  unnamed Legendaries until step 6, so drops are not all Tidewater meanwhile.

## Open decisions

Provisional picks (reversible, written to DECISIONS when built):

- [x] Second Wind (Warden P9) is renamed Last Rites to end the clash with the
  Second Wind Serum (name chosen by the person, decision card 2026-11-20).
  Overkill and Overclock get new names when F-90 builds them.
- [x] Provisional: Cold Snap holds zombies frozen without the Cryo Lance's shatter.
- [x] Provisional: Dead Man's Hand ships without "always staggers" (no stagger mechanic yet); F-90.
- [x] Provisional: Overpressure charges on any reload that adds a round, one Brenner shell included.
- [x] Provisional: Twin Pin child frags use `TWIN_PIN_FUSE` 0.4 s and half the frag radius (no
  design numbers), tuned in play-test.
- [x] Provisional: an unknown trait id shows no line (affixes.md's greyed "Inactive bonus"
  line is not built for affixes either).
- [x] Provisional: gear Legendary bases are Quarantine Shell on the heavy vest, Iron Lung on the
  medium vest, Black Ledger on the key card charm, Twin Pin on the relay implant
  (affixes.md names only the slot).
- [x] Provisional: Lantern Fall's blast radius is 4 m (affixes.md gives none; the middle of the
  other trait radii), as `LANTERN_FALL_RADIUS`, tuned in play-test.
- [x] Provisional: Iron Lung's "kill streak" is kills in a row without taking damage.
- [x] Provisional: Choir Mark marks have no visual yet; added after the play-test if needed.
- [x] Provisional: old Legendaries in stashes stay unnamed with no trait.

For the person:

- [x] Approve this plan (size L): 14 Legendaries, the 13 others (Furnace,
  Overkill, Overclock, Gambler's Coin, 9 new-base traits) moved to a new
  roadmap row F-90: approved as written (the person, decision card
  2026-11-20). Review fixes after the card: step 1 split in two (6 steps),
  Cold Snap hold, stagger deferred, player.gd lines moved out first.
