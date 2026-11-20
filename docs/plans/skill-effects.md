# Plan: Skill effects

Status: Review
Roadmap: F-20 / issue #113
Phase: P5
Size: M
Approved by:
Lore link: none: no new thing the player sees or reads. The 20 skills, their names and texts already exist in `content/skills/`, and the branches have their story reason in docs/design/lore.md (Skill branches row). The skill tree screen (F-21) shows them.

## Goal

Spent skill points change how your character plays: every skill in
`content/skills/` does what its text says, through the same stat modifier
stack that gear and Serums use, in solo and in co-op. Pillar: every run makes
you stronger.

## Scope

In:

- Skill ranks reach the player's `StatBlock` (solo, host, and the server's copy
  of a client), and a respec or rank change rebuilds it from scratch.
- The 14 stat skills write to the stack under the stat names gear affixes
  already use, so skills, gear and Serums add up and share caps.
- The design's hard caps that are missing from `stat_caps.tres`: reload +60%,
  recoil reduction 50%, max health 400, points +50% (loot luck +100% is there).
- Code that reads each stat where none reads it yet: recoil and reserve ammo on
  every gun (not only item guns), sprint speed, points earned, barrier repair
  speed, revive speed.
- The 6 rule skills: Dead Center, Execution Line, Last Stand, Undying, Bargain
  Hunter, Chain Supply, keyed by a rule value in data, not by id.

Not in (non-goals, and where each one goes instead):

- Spending points, the tree screen and the Trainer respec (later: F-21). Until
  then ranks only change through tests or by editing a save.
- Reachable keystones and capstones: the 15/25-point branch gates cannot be
  reached with today's nodes (Marksman 14, Survivor 10, Tinkerer 13 points).
  More nodes or lower gates is a tree-content call for F-21 (DECISIONS line
  stays, reworded).
- Gadgeteer, Sturdy and Overtime have nothing to change yet: field abilities
  (F-22), grenades (F-24) and timed power-ups (F-26) do not exist. Their stat
  goes in the stack now; the feature that adds the thing reads it (later:
  F-22, F-24, F-26). Same for gear's `ability_cooldown`, `explosion_guard` and
  `power_up_duration` affixes.
- Execution Line's "Brutes under 5%" (later: F-30 Brute).
- Item-gun-only stats (damage, magazine, pellets, falloff, hip fire) on wall
  guns: gear does not roll them, so nothing changes. Only `recoil_pct` and
  `deep_reserve` move to all guns.

## Ready to build

### Ready to build
- Foundations touched (numbers from docs/FOUNDATIONS.md): 2 data ids (skills
  are `.tres`), 3 server-side item effects (stats on the server's player copy),
  6 co-op messages (`LoadoutSync`). None shaky: item-effects-server already
  rebuilds gear stats on the server, this rides on it.
- Decision records that apply (docs/adr/): 0003 trusted-client co-op (the owner
  sends its ranks, the server checks shape only). Does this go against one? no
- Co-op:
  - Who decides: server for health, points, repair, revive, vault price,
    executions, Last Stand, self-revive charges and power-up drops; owning
    client for its own gun handling, ammo, sprint (as today for gear).
  - How a client triggers it: on spawn and every Pack equip the owner already
    sends `LoadoutSync.submit_loadout(gear, guns)`; it gains the skill ranks.
    The server checks ids exist, ranks are 1..max_ranks and the total is at
    most 54 (the design's points at level 50).
  - What other players see: nothing new; health and points already sync.
  - Works on a dedicated server with no local player: yes.
- Data: ids and per-rank numbers live in `content/skills/*.tres`; caps in
  `content/loot/stat_caps.tres`. Code compares against a specific id anywhere:
  no. Rule skills carry a `rule` enum value in data (like `PowerUpData.Effect`).
- Save: changes what is saved? no. `skill_ranks` is already saved; its String
  keys become StringName when read. Renames or removes a saved id: no.
- Events and UI: no new Events, no new screens.
- Input through InputFrame, gameplay in _physics_process, randomness from the
  session RNG: yes (Chain Supply rolls `GameSession.rng`).
- Tests: unit tests per skill (below), content test on every skill's stat and
  op, a co-op test that the server's copy of a client gets its ranks.
- Logging: `Log.warn(&"net", &"skills_rejected")` when a sent rank set fails
  the check.
- Performance: no per-frame work; ranks fold into the StatBlock once per
  loadout change.
- Lore link: none (above).
- Out of scope: see Not in.

## Design references

- docs/design/game-design.md#skill-tree: the 20 nodes and their numbers.
- docs/design/game-design.md#how-this-fits-with-serums: one modifier stack,
  hard caps reload +60%, recoil 50%, max health 400, points +50%, loot luck
  +100%.
- docs/design/game-design.md#skill-tree: 54 points by level 50 (also
  `docs/design/balance/xp_and_levels.csv`).
- docs/DECISIONS.md: "Skill tree" (rewritten), "Loadout trust" (still true for
  ranks), "Co-op hit bounds".
- docs/adr/0003-trusted-client-co-op.md.

## Systems touched

| Folder or file | New / changed | What changes |
|---|---|---|
| systems/progression/skill_node_data.gd | changed | adds `op` and `rule` (enum) |
| systems/progression/skill_effects.gd | new | ranks to modifiers and a rule set, ranks from a save dict, rank check |
| content/skills/*.tres | changed | stack stat names and `op` |
| content/loot/stat_caps.tres | changed | 4 caps added |
| systems/player/player.gd | changed | `skill_ranks`; `equip_gear` adds skill modifiers; sprint speed; Last Stand |
| systems/net/loadout_sync.gd | changed | sends and checks ranks |
| core/build.gd | changed | `PROTOCOL_VERSION` +1 |
| systems/game/game_session.gd | changed | sets the profile player's ranks before the loadout goes out |
| systems/weapons/weapon_holder.gd | changed | guns are fitted to the player's stats |
| systems/loot/item_loadout.gd | changed | `refit_item_guns` refits every gun |
| systems/economy/economy.gd | changed | points earned, with a per-player remainder |
| systems/interactables/barrier.gd | changed | repair speed |
| systems/player/revive.gd | changed | revive speed, Undying charge |
| systems/damage/hit_zone.gd | changed | Execution Line |
| systems/interactables/specimen_vault.gd | changed | Bargain Hunter price |
| systems/power_ups/power_up_drops.gd | changed | Chain Supply |

Autoloads, managers or base classes added: none. `SkillEffects` is a static
helper next to `SkillTree` (same shape), not a service node.

Files over 300 lines this plan grows: `systems/player/player.gd` (335). Step 4
moves Last Stand into `systems/player/revive.gd` (163 lines, owns going down
and getting up) instead of growing player.gd; step 3's sprint line replaces an
existing one. If player.gd still passes 350, step 1 moves `_refresh_stats` and
`equip_gear` into `skill_effects.gd`'s neighbour by job, not a helper class.
`systems/interactables/specimen_vault.gd` and `power_up_drops.gd` stay under
300.

## Data

- `SkillNodeData.op: String = "increased"`: "increased", "flat" or "more",
  read by `SkillEffects`. `per_rank` keeps the description's units; percent
  values divide by 100 like `ItemInstance._add`. Flat `regen_delay` is
  negated, same as the gear affix.
- Skill stats (rule skills keep `stat = &""` except Undying):

| Skill | stat | op | per rank | Read by |
|---|---|---|---|---|
| steady_hands | recoil_pct | increased | 5 | gun fit (step 2) |
| quick_draw | ads_pct | increased | 5 | Weapon `_stat(&"ads_time")` (exists) |
| weak_spot | hs_pct | increased | 5 | `get_stat(&"head_damage")` (exists) |
| fast_hands | reload_pct | increased | 5 | Weapon `_stat(&"reload_time")` (exists) |
| deep_pockets | deep_reserve | increased | 10 | gun fit (step 2) |
| thick_skin | max_health | flat | 10 | `_refresh_stats` (exists) |
| second_breath | regen_delay | flat | 0.3 | `_refresh_stats` (exists) |
| light_feet | sprint_speed (new) | increased | 5 | `Player._move` (step 3) |
| sturdy | explosion_guard | increased | 25 | F-24 |
| scrounger | points_earned | increased | 5 | Economy (step 3) |
| lucky_find | loot_luck | increased | 5 | `LootService.player_luck` (exists) |
| overtime | power_up_duration | flat | 3 | F-26 |
| gadgeteer | ability_cooldown | increased | 8 | F-22 |
| carpenter | repair_speed (new) | increased | 30 | Barrier (step 3) |
| undying | fast_revive | increased | 50 | Revive (step 3) + charge (step 4) |

- Caps added to `stat_caps.tres` (values are the stack result with base 1.0,
  or units): `reload_pct` 1.6, `recoil_pct` 1.5, `max_health` 400,
  `points_earned` 1.5. These caps hold for gear too, as the design says.
- `SkillNodeData.rule: Rule = Rule.NONE`, enum `NONE, DEAD_CENTER,
  EXECUTION_LINE, LAST_STAND, UNDYING, BARGAIN_HUNTER, CHAIN_SUPPLY`. Code
  checks the rule, never the skill id, the same pattern as
  `PowerUpData.Effect`; a renamed skill keeps working. Each rule's numbers (1
  bullet, 15%, 1 health and 2 s, 1 charge, 750, 25%) are constants next to the
  code that runs it, from the design table (fixed rules, Keep it simple 10).
- `Player.skill_rules: Dictionary[int, bool]`, rebuilt with the stats, so a
  rule check on a hit is one lookup.
- Network message: `LoadoutSync.submit_loadout(gear, guns, skills)`; skills is
  a `Dictionary` of String id to int rank. `PROTOCOL_VERSION` 21 to 22 (or one
  above main's value when step 1 merges). Old clients are refused by the
  version handshake, as for every RPC change.
- Save format change: none. `CharacterProfile.skill_ranks` stays a dict of
  id to rank; `SkillEffects.ranks_from()` turns JSON String keys into
  StringName and drops unknown ids and bad ranks.
- Content checks to add in `tests/content/`: new `test_skill_content.gd`:
  every skill with a stat has a known op, per_rank > 0, and its stat is in the
  table's list; each rule value is used by exactly one skill.

## Co-op behaviour

- Who owns the state: the owning client owns its ranks (from its save). The
  server holds a copy on its `Player` for that client, set by `LoadoutSync`.
  The server owns per-run rule state: Last Stand used this round, Undying
  charge left.
- What clients send, what the server sends back: the owner sends ranks with
  its loadout (spawn and every Pack equip). The server sends nothing new:
  health, max health and points already sync through `PlayerStateSync` and
  Economy; vault price and power-ups already reach clients.
- What a client sees that the host sees too: health, points, power-ups,
  executed zombies dying. Only the owner: faster reload, ADS, less recoil,
  more reserve, sprint speed, Dead Center refund (owner simulates its guns and
  movement, as for gear today).
- Late joiner: sends its own ranks with its first loadout like everyone; needs
  nobody else's ranks.
- Dedicated server: no local player, no profile; it only applies received
  ranks. Nothing skipped.
- Host checks: hit bounds already use `get_stat(&"head_damage")`, so Weak Spot
  claims pass. Recoil, ADS and reload are owner-side and not checked.

## Performance

No per-frame cost. Ranks become at most 15 modifiers, added once per loadout
change. `StatBlock.value` loops modifiers per call as today; with 3 gear
pieces plus 15 skill lines that is under 40 entries. Rule checks are one
dictionary lookup per hit (Execution Line) or per death (Last Stand), no
allocation.

## Steps

### Step 1: Ranks into the stat stack, solo and co-op

- Build: `SkillNodeData.op` and `rule`. New `systems/progression/skill_effects.gd`:
  `add_to(stats, ranks)`, `rules_for(ranks)`, `ranks_from(raw)`,
  `ranks_problem(ranks) -> String`. `Player.skill_ranks`; `equip_gear` adds
  skill modifiers (source `&"skill"`) after gear, so any rebuild (respec,
  new loadout) drops old ones. `GameSession._on_player_added` sets the profile
  player's ranks before `ItemLoadout.apply`. `LoadoutSync` sends ranks and the
  server checks and applies them; protocol bump. Fill every skill `.tres` with
  the table's stat and op, and the six rule skills with their rule. Add the 4 caps. Rewrite the DECISIONS "Skill tree"
  line. Roadmap row to Building.
- Files: systems/progression/skill_node_data.gd, systems/progression/skill_effects.gd (new), content/skills/*.tres, content/loot/stat_caps.tres, systems/player/player.gd, systems/net/loadout_sync.gd, systems/game/game_session.gd, core/build.gd, docs/DECISIONS.md, docs/ROADMAP.md.
- Tests: new `tests/unit/test_skill_effects.gd`: for each of Quick Draw, Weak
  Spot, Fast Hands, Thick Skin, Second Breath, Lucky Find the stat the player
  reads changes by the table value per rank; respec (empty ranks, re-equip)
  puts it back; gear plus skill stack and hit the cap; `ranks_from` drops
  unknown ids and clamps. New `tests/content/test_skill_content.gd`.
  `tests/unit/test_item_effects_coop.gd`: a client's sent ranks raise the
  server copy's max health; a bad rank set is refused and logged.
- Done when: a player with ranks in the save has the six "exists" skills
  working in solo and as a co-op client; CI green.

### Step 2: Recoil and reserve ammo on every gun

- Build: `WeaponHolder.give` and `replace` fit non-item guns to the player's
  stats with `ItemInstance.new({}).weapon_data(base, player.stats)` (the same
  code item guns use); item guns keep their own path so nothing is counted
  twice. `ItemLoadout.refit_item_guns` becomes `refit_guns` and refits every
  gun from its Content base (`Content.weapon(data.id)`) after a stat change,
  keeping ammo capped. Steady Hands, Deep Pockets and gear's recoil and Mule
  affixes now reach wall guns, the starter pistol, Vault and Reforged guns.
- Files: systems/weapons/weapon_holder.gd, systems/loot/item_loadout.gd, systems/player/player.gd (calls refit after `equip_gear`).
- Tests: `tests/unit/test_skill_effects.gd`: Steady Hands 3 scales a wall gun's
  recoil pattern by 0.85; Deep Pockets 2 gives +20% max reserve on a wall gun
  and on an item gun once (not twice); a respec puts both back.
- Done when: both skills change wall and item guns; reserve stays capped on
  refit; CI green.

### Step 3: Sprint, points, repair and revive speed

- Build: `Player._move` multiplies sprint speed by `get_stat(&"sprint_speed")`.
  Economy pays hits, kills, round clears and repairs times
  `get_stat(&"points_earned")`, keeping each player's fraction so 5% of 10
  stays 5% over time. Barrier repair time divides by
  `get_stat(&"repair_speed")`. Revive hold time divides by the reviver's
  `get_stat(&"fast_revive")` (gear's Fast revive affix starts working too).
- Files: systems/player/player.gd, systems/economy/economy.gd, systems/interactables/barrier.gd, systems/player/revive.gd.
- Tests: `tests/unit/test_skill_effects.gd`: Light Feet 2 sprint speed x1.10,
  walk unchanged; Scrounger 3 pays 115 points over ten 10-point hits; Carpenter
  2 repair time / 1.6; Undying revive hold 3 s to 2 s. Server-only: a client
  copy does not pay points.
- Done when: the four stats change play; CI green.

### Step 4: Server rule skills

- Build: Last Stand: on the server, a killing blow with Last Stand unused this
  round leaves the player at 1 health with 2 s where damage is ignored; reset
  on `Events.round_started`. Undying: one self-revive charge per run; when
  downed with a charge and no Second Wind, the charge works like Second Wind
  and is used up (`can_self_revive` counts it so the squad is not out).
  Execution Line: `HitZone.receive_hit` on the server kills a zombie already
  under 15% health when the attacker has the skill. Bargain Hunter:
  `SpecimenVault` charges and shows 750 for a player with it. Rule state lives
  in `Revive` (going down and getting up) to keep player.gd under its limit.
- Files: systems/player/revive.gd, systems/player/player.gd (calls only), systems/damage/hit_zone.gd, systems/interactables/specimen_vault.gd.
- Tests: `tests/unit/test_skill_effects.gd`: Last Stand once per round and
  immunity ends after 2 s; Undying charge self-revives once per run and keeps
  the match going; Execution Line kills at 14% and not at 16%, and not without
  the skill; Bargain Hunter pays 750, others 950. A co-op test: the server
  applies Last Stand from a client's sent ranks.
- Done when: all four rules work on the server, solo and co-op; CI green.

### Step 5: Dead Center, Chain Supply and close-out

- Build: Dead Center: the owner adds 1 round to the gun in hand (up to its
  magazine) on a confirmed headshot kill (`Events.hit_confirmed`, which
  clients already raise for their own kills). Chain Supply: when the killer
  has it and a power-up drops, a 25% `GameSession.rng` roll drops a second,
  different one from the deck (none if the deck has only one kind). Tick
  Acceptance, set `Status: Done`, roadmap row Done, DECISIONS lines for the
  provisional picks below. Run `finish-feature`.
- Files: systems/weapons/weapon_holder.gd, systems/power_ups/power_up_drops.gd, docs/plans/skill-effects.md, docs/ROADMAP.md, docs/DECISIONS.md.
- Tests: `tests/unit/test_skill_effects.gd`: Dead Center refunds on a headshot
  kill, not a body kill, never past a full magazine; Chain Supply with a fixed
  seed drops a second, different power-up and never the same one.
- Done when: every skill in `content/skills/` has a test on what it changes;
  CI green (`quality`, `test`, `soak`).

## Acceptance

- [ ] Every skill in content/skills applies through the shared stat modifier stack (rule skills by id) - tests in `test_skill_effects.gd`
- [ ] Each skill has a unit test on the stat or rule it changes
- [ ] Respec (empty ranks) and a new loadout remove the effect - tested
- [ ] A co-op client's ranks reach the server's copy and change server-side results - tested
- [ ] Skills, gear and Serums stack and stop at the design caps - tested
- [ ] Soak passes with no new warnings

## Risks

- Counting gun stats twice (item guns already fold in player stats). Step 2
  keeps item guns on their own path and tests an item gun once.
- Rounding eats small point bonuses (10 x 1.05 rounds to 11, a hidden +10%).
  Step 3 keeps the fraction per player.
- `PROTOCOL_VERSION` clashes with other open PRs (F-79, F-71). Step 1 merges
  main first and takes one above main's value.
- New caps also cut existing gear rolls at the cap. Rolls are far below the
  caps today (reload focus and reload_pct at most ~+30% together), so no
  current item changes.
- F-71 (four new gear slots) adds `recoil_pct` on gloves and also needs it on
  every gun. Step 2 here fixes that for both; F-71 should build after it.
- Players cannot spend points until F-21, so the effects are only seen in
  tests and edited saves until then.

## Open decisions

Provisional picks (reversible, written to DECISIONS in step 5):

- Execution Line checks health before the hit (the design's "a zombie under
  15% health"), not after.
- Dead Center refunds into the gun in hand, capped at its magazine.
- Scrounger boosts every point source (hits, kills, round clear, repairs),
  not power-up rewards (none pay points today).
- Undying's charge is used only when Second Wind is not held, so the two never
  stack into one revive.

For the person:

- none
