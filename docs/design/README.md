# Design references

Repo copies of the design docs, so every agent works from the same style and
numbers. Read the file for your task **before** you start UI, art, audio,
weapon, enemy or map work.

**Which wins:** the code and `docs/DECISIONS.md` beat these files. These are
the design targets; `DECISIONS.md` says what was built and what changed on
purpose. If you find a conflict that matters, follow `DECISIONS.md` and say so
in your PR.

| File | Read it for |
|---|---|
| [look-rules.md](look-rules.md) | **Any visual work.** Cold Containment palette, Godot environment values, light and material rules, code-built model conventions, rarity colours, renders |
| [game-design.md](game-design.md) | The whole game: rounds, enemies, weapon list, economy, machines, Halcyon Labs, levels, loot, town, build phases P0 to P10 |
| [maps.md](maps.md) | The four maps: areas, door costs, wall-buys, spawn points, events, map file layout and checks |
| [game-feel.md](game-feel.md) | Hit markers, recoil layers, screen shake, hitstop, muzzle flash, impacts, gore, damage feedback, `FeelData` |
| [sound.md](sound.md) | Gun sound layers, zombie tells, music stems, bus tree, voice caps, mixing order, sourcing |
| [ui-hud.md](ui-hud.md) | Every screen and the match HUD, with mockups in `images/ui_*.jpg` |
| [controls.md](controls.md) | Default bindings, controller, accessibility and comfort settings |
| [zombie-ai.md](zombie-ai.md) | Zombie states, pathing, attacks, special types, performance limits |
| [gun-roster.md](gun-roster.md) | All 22 base guns: niches, wall/loot sources, unlock levels, Legendary traits, build order (numbers in `balance/roster.csv`) |
| [affixes.md](affixes.md) | Loot affixes, rarity rules, sets, Legendaries |
| [gear-visuals.md](gear-visuals.md) | How equipped gear shows on characters (vertex-colour zones, dyes) |
| [lore.md](lore.md) | Story, factions, map stories, names. Use these names in text and data |
| [balance/](balance/) | CSV export of the balance sheet (weapons, enemies, rounds, economy, prices, TTK, XP, loot). Damage in the game is sheet damage x 0.57 for now (provisional, see `DECISIONS.md`) |

## Known differences from the code (follow the code)

- **FOV:** `controls.md` says default 95. The game uses horizontal FOV 70 to
  120, **default 110**.
- **Tonemap and ambient:** the style guide said ACES and ambient 0.35. The
  repo uses AgX and 0.2 (`look-rules.md` has the repo values).
- **Gun damage:** balance-sheet damage x 0.57. Talon DMR head multiplier 3.0.
  Both provisional.
- Diagrams from the original docs (map layouts, state machine, roadmap) were
  not copied; the tables next to them hold the same facts.

## Images

`images/` holds compressed copies (1280 px JPEG): `style_*` are the
style-guide renders, `ui_*` the UI mockups, `gear_*` the gear visuals. They
are references, not game assets: never load them from game code.

## Turnarounds

`turnarounds/` holds the approved four-view render of every model
(`tools/render_turnarounds.py`). The `Turnarounds` CI check fails when a model
looks different from its approved render. After checking the sheet in the
`turnarounds` artifact, run `python tools/render_turnarounds.py --approve` and
commit the changed PNGs; GitHub then shows the old and new look in the PR.
