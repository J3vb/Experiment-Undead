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
| F-05 | Rebind controls in Settings | #105 | - | needed | M | Todo |
| F-06 | Make the rounds 1-10 soak test a required CI check | #107 | - | issue | S | Done (branch rule: add `soak`) |
| F-07 | Balance pass rounds 1-10 for the slice guns | #106 | F-06 | issue | S | Todo |
| F-08 | Change log in the design doc | #110 | - | issue | S | Done |
| F-12 | Core loop gaps: round scaling, stuck zombies, swap, melee, slide, best round | - | - | [needed](plans/core-loop-gaps.md) | M | Building |
| F-13 | Finish Halcyon Labs: props, co-op spawn points, vent route, secret | - | - | [needed](plans/halcyon-labs-finish.md) | M | Ready |
| F-09 | v0.1 performance check | #108 | F-01..F-07, F-12, F-13 | issue | S | Todo |
| F-10 | First play-test (the person plays) | #109 | F-09 | issue | S | Todo |
| F-11 | Release v0.1.0 | #111 | F-10 | issue | S | Todo |

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
| F-40 | Machines, doors and power-ups in co-op (rest after F-02) | #126 | F-02 | needed | M | Todo |
| F-41 | Third-person walk, run and downed animations | #128 | F-11 | needed | L | Todo |
| F-42 | Gear in first person | #129 | F-11 | needed | M | Todo |
| F-43 | 4-player play-test to round 20 | #127 | F-40, F-41 | issue | S | Todo |
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
- Loot and co-op were partly built before v0.1 shipped (see
  `docs/DECISIONS.md` and `docs/MULTIPLAYER.md`). From here on, the order
  above is the order.
