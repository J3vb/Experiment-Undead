# Roadmap: what we build, in what order

The order of upcoming features and what each one waits on. Phases P0-P10 and
milestone gates come from `docs/design/game-design.md` (Build roadmap) and
`docs/PROCESS.md`. The issues hold the details; this file holds the order.

## Rules

1. Work top to bottom. Start a feature only when everything in its
   **Needs** column is Done.
2. A feature with **Plan: needed** starts with a plan
   ([docs/plans/README.md](plans/README.md)). No approved plan, no code.
3. **Plan: issue** means the Task issue is enough (one PR, follows a recipe).
4. Foundation fixes (F-00) go before new features that touch the same system.
5. When a feature finishes, set its Status to Done in the same PR. New
   features get a new row in the right place, with the next free id.

Status values: Todo, Planning, Ready (plan approved), Building, Done, Check
(may already be done, verify and close).

## Now: foundations and v0.1 Vertical slice

| Id | Feature | Issue | Needs | Plan | Size | Status |
|---|---|---|---|---|---|---|
| F-00 | Foundation fixes, in the ranked order of [FOUNDATIONS.md](FOUNDATIONS.md#foundation-fixes-in-order) | - | - | per fix: 1 (done, no plan: one CI PR), 2 = F-02 (done), [3](plans/item-effects-server.md) (done), [4](plans/ids-into-data.md) (done), [5](plans/ui-router.md) (done), 6 (done, no plan: one PR per issue), [7](plans/hot-path-allocations.md) (done), 8 (done, no plan: one test-only PR per issue), 9 (done, no plan: doc lines plus a test) | - | Done |
| F-01 | First-person arms on the guns | #102 | - | issue | S | Done (PR #136 fitted arms, sleeve fix) |
| F-02 | Co-op clients can use doors, wall-buys and machines | #138 | F-00 | [done](plans/coop-interactions.md) | M | Done (play-test: #191) |
| F-03 | Player footsteps and landing sounds | #103 | - | issue | S | Done |
| F-04 | Halcyon Labs ambience | #104 | - | issue | S | Done |
| F-05 | Rebind controls in Settings | #105 | - | [done](plans/control-rebinding.md) | M | Done |
| F-06 | Make the rounds 1-10 soak test a required CI check | #107 | - | issue | S | Done (branch rule: add `soak`) |
| F-07 | Balance pass rounds 1-10 for the slice guns | #106 | F-06 | issue | S | Todo |
| F-08 | Change log in the design doc | #110 | - | issue | S | Done |
| F-12 | Core loop gaps: round scaling, stuck zombies, swap, melee, slide, best round | - | - | [needed](plans/core-loop-gaps.md) | M | Done |
| F-13 | Finish Halcyon Labs: props, co-op spawn points, vent route, secret | - | - | [done](plans/halcyon-labs-finish.md) | M | Done (look follow-ups #297) |
| F-62 | Texture every surface in Halcyon Labs: textured sets, a floor per room, decals | - | - | [done](plans/halcyon-surfaces.md) | M | Done |
| F-14 | Zombie sounds and gore: steps, deaths, voice caps, blood, head pops | - | - | [done](plans/zombie-sounds-gore.md) | M | Done (play-test: #191) |
| F-15 | Halcyon Labs detail props: Blender models for every room prop, story clutter, barricades | - | - | [ready](plans/halcyon-labs-props.md) | M | Done |
| F-63 | Halcyon Labs door models: bulkheads, debris, shutters, vent grates, freezer door | - | - | [done](plans/halcyon-doors.md) | S | Done |
| F-64 | Halcyon Labs wall-buy racks (gun on the wall) and Specimen Vault model | - | - | [done](plans/halcyon-wall-buys-vault.md) | S | Done |
| F-68 | Halcyon Labs concept pass after the breakout: signage, Fenlight vines, wrecked rooms, ceilings, #297 look lines (stays dark) | #297 | - | [ready](plans/halcyon-concept-pass.md) | L | Ready |
| F-61 | Halcyon Labs atmosphere: dead and flickering lights, particles, fog, beacons, screens, sound spots, story decals | - | - | [ready](plans/halcyon-labs-atmosphere.md) | M | Done |
| F-16 | Game feel: camera punch, hitstop, downed and death screen | - | - | [ready](plans/game-feel-slice.md) | M | Done |
| F-65 | Client and server updates: clear version refusals, saves safe across channels, a launcher that installs and updates the game and a server, self-updating Docker servers (steps 1-5 before F-11) | - | - | [ready](plans/client-server-updates.md) | L | Ready |
| F-09 | v0.1 performance check | #108 | F-01..F-07, F-12, F-13, F-16 | issue | S | Todo |
| F-10 | First play-test (the person plays) | #109 | F-09 | issue | S | Todo |
| F-11 | Release v0.1.0 | #111 | F-10, F-65 steps 1-5 | issue | S | Todo |
| F-40 | Round state and power-ups in co-op (rest of #126 after F-02) | #126 | F-02 | [done](plans/coop-round-state-power-ups.md) | M | Done |
| F-47 | A full co-op match: co-op soak, pause, squad cards, hub and deploy flow | #213 | F-40 | [plan](plans/coop-full-match.md) | L | Building |
| F-48 | Full settings screen: Graphics page with presets, then Accessibility and Comfort | - | F-05 | [ready](plans/full-settings.md) | L | Done |
| F-49 | HUD feedback and loading: loading screen, damage numbers, level-up burst, drop feed | - | - | [done](plans/hud-feedback-loading.md) | M | Done |
| F-50 | First Lantern Post hub: town blockout, Deploy board and ready-up vote (first slice of F-45, pulled forward for the co-op week goal) | #131 | F-02, F-47 step 4 (#255), co-op #256 | [done](plans/lantern-post-hub.md) | M | Done |
| F-66 | Your own world, open to friends: Enter world into your own Lantern Post (listen server, UPnP), server browser with add by address and LAN discovery, no master server | - | F-02, F-50 | [ready](plans/join-any-game.md) | L | Ready |
| F-67 | Character select and create before Enter world (ui-hud screen 3: slots, create, delete) | - | F-66 step 2 | needed | M | Todo |
| F-68 | Lantern Post to the concept art: ridge sky, timber lodges, market stalls, concrete Deploy gate, props | - | F-50 | [ready](plans/lantern-post-concept.md) | L | Ready |
| F-70 | Player and gear to the concept art: bearded survivor body, headgear, gloves, backpack and boots models in three tiers (field, plated, Oriel), plate carrier vests, eye implant and vest vial | - | - | [ready](plans/player-gear-concept.md) | L | Ready |
| F-71 | Four new loot slots: headgear, gloves, backpack, boots (item bases, affix pools, drops, sets, save, inventory and character screen) | - | F-70 step 2 | needed | L | Todo |

## Next: v0.2 Progression and loot

| Id | Feature | Issue | Needs | Plan | Size | Status |
|---|---|---|---|---|---|---|
| F-20 | Skill effects (through the stat stack) | #113 | F-11 | needed | M | Todo |
| F-21 | Skill tree screen | #112 | F-20 | needed | M | Todo |
| F-22 | Field abilities | #114 | F-20 | needed | M | Todo |
| F-23 | Levelling pace check | #115 | F-20, F-22 | issue | S | Todo |
| F-24 | Frag grenades | #119 | F-11 | needed | M | Todo |
| F-25 | Mantle | #120 | F-11 | needed | M | Todo |
| F-26 | More power-ups in the drop deck | #118 | F-11 | needed | M | Todo |
| F-27 | Crawler | #121 | F-24 | needed | M | Todo |
| F-28 | Blackout rounds and Glowers | #122 | F-11 | needed | M | Todo |
| F-29 | Stalker | #123 | F-11 | needed | L | Todo |
| F-30 | Brute | #124 | F-11 | needed | L | Todo |
| F-31 | Legendaries and traits | #116 | F-20 | needed | L | Todo |
| F-32 | Item sets (needs set lore first) | #117 | F-31 | needed | M | Todo |
| F-33 | Run length target: solo runs end between round 15 and 30 | #125 | F-27..F-30 | issue | S | Todo |

## Later: v0.9 Alpha

| Id | Feature | Issue | Needs | Plan | Size | Status |
|---|---|---|---|---|---|---|
| F-41 | Third-person walk, run and downed animations | #128 | F-11 | [needed](plans/teammate-animations.md) | L | Done |
| F-42 | Gear in first person | #129 | F-11 | needed | M | Todo |
| F-43 | 4-player play-test to round 20 | #127 | F-47, F-41 | issue | S | Todo |
| F-44 | Finish the server package | #130 | F-43 | needed | L | Todo |
| F-45 | Town hub Lantern Post (split into features when it starts) | #131 | F-44 | needed | L | Todo |
| F-46 | Dyes | #132 | F-42 | needed | M | Todo |

## After v1.0: Growth (P10)

| Id | Feature | Issue | Needs | Plan | Size | Status |
|---|---|---|---|---|---|---|
| F-60 | Campaign: acts, descents and bosses (story in [lore.md](design/lore.md#the-long-campaign); split per act when it starts, first the Halcyon Labs Sublevel boss) | - | F-45, F-31 | needed | L | Todo |

## Notes

- v0.2 features after F-11 may run in parallel when their Needs are Done and
  they touch different systems.
- F-40 and F-47 were pulled into Now on 2026-11-17: the person set co-op as
  the goal for that week. They touch only co-op code, not the v0.1 rows.
- Loot and co-op were partly built before v0.1 shipped (see
  `docs/DECISIONS.md` and `docs/MULTIPLAYER.md`). From here on, the order
  above is the order.
