# Concept renders

Rough blockout renders of areas that are not built yet. They are design
references for mood, layout and scale, **not game assets**: the game loads
nothing from here, and nothing in `assets/`, `levels/` or `content/` comes
from these scripts.

## Act I boss Sublevels

Story and fight ideas: [lore.md, "The long campaign"](../lore.md#the-long-campaign).

| Area | Boss | Brief | Script |
|---|---|---|---|
| Halcyon Labs Sublevel | The Night Supervisor | [halcyon_sublevel.md](act1/halcyon_sublevel.md) | `tools/concepts/halcyon_sublevel.py` |
| Kessel Dam turbine pit | The Turbine Keeper | [kessel_turbine_pit.md](act1/kessel_turbine_pit.md) | `tools/concepts/kessel_turbine_pit.py` |
| Under the Marrow Junction yard | The Courier | [marrow_underyard.md](act1/marrow_underyard.md) | `tools/concepts/marrow_underyard.py` |
| Grauwald cold baths | The Sleeper (act boss) | [grauwald_cold_baths.md](act1/grauwald_cold_baths.md) | `tools/concepts/grauwald_cold_baths.py` |

Each area has a one-page brief and three 1920x1080 JPGs in `act1/<area_id>/`:

| Shot | Camera |
|---|---|
| `overview.jpg` | High wide view. The ceiling and the two near walls are hidden. |
| `player.jpg` | From the descent point, eye height 1.7 m, 80 degree horizontal FOV. |
| `boss.jpg` | The boss framed from player eye height, same FOV. |

Every scene has 1.8 m Lit hosts for scale; the boss placeholders are 3.6 to 4 m.

## Re-render

Needs Blender 5.3. From the repo root:

```bash
blender -b -P tools/concepts/<area_id>.py
```

The script is the source: change it and re-render, never edit a JPG by hand.
It renders with Cycles on an OptiX GPU when there is one (about 45 seconds per
area on an RTX 4080 Super) and on the CPU otherwise.

Shared helpers live in `tools/concepts/blockout.py`: the
[look-rules](../look-rules.md) palette, AgX colour management, bloom, volumetric
fog, wet floors and the shot renderer. Use its colour names instead of new hex
values: teal light inside, sodium only from outside, bio-green only where
Fenlight is.

## Game screens (2026-11-17)

[screens/screens_concept.jpg](screens/screens_concept.jpg) is the person's concept art for four screens: main menu with Enter World, match HUD, server browser and character select. The UI mockups in `../images/ui_*.jpg` and [ui-hud.md](../ui-hud.md) follow it, except where the game has no such system (no master server, so no Official/Community/Modded lists or Region filter; no minimap, armour, medkits or seasons). The profile card's name was replaced with "Survivor": never put a real person's name in a screen.
