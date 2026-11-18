---
name: look-check
description: Render a model, scene or the game headless and compare it with the Cold Containment style references before opening a PR. Use for any visual change (model, material, lighting, VFX, UI colour).
---

# Check the look against the style guide

Tests prove a model loads. Only a picture proves it looks right. Every visual
PR gets a render next to its reference.

## 1. Render

No display in a cloud container, so wrap Godot in `xvfb-run`. Cloud sessions
have Mesa's software Vulkan (lavapipe, installed by the session-start hook), so
render with the game's real Forward+ renderer (SSAO, glow, shadows):
`--rendering-driver vulkan --rendering-method forward_plus`. It is slower than
OpenGL (about 45 s for one gun in the weapon review) but judges light and
materials as the game shows them. OpenGL is fine for quick shape checks.

```bash
# Godot renders (lighting, materials, scenes)
xvfb-run -s "-screen 0 1600x900x24" ./godot --path . --rendering-driver opengl3 -s res://tools/zombie_lineup.gd
xvfb-run -s "-screen 0 1600x900x24" ./godot --path . --rendering-driver opengl3 -s res://tools/look_shot.gd
xvfb-run -s "-screen 0 1600x900x24" ./godot --path . --rendering-driver opengl3 -s res://tools/gun_lineup.gd
xvfb-run -s "-screen 0 1600x900x24" ./godot --path . --rendering-driver opengl3 res://tools/screenshot.tscn

# Guns with real lighting: booth, 10 m, hip and ADS views per rarity
xvfb-run -a -s "-screen 0 1920x1080x24" ./godot --path . --rendering-driver vulkan --rendering-method forward_plus \
  res://tools/weapon_review.tscn -- --out /tmp/weapon-review --guns rifle_ar

# Gun plates from the committed .glb files (CPU Blender, no Godot)
python tools/render_weapon_comparison.py --out screenshots/weapons
```

| Script | Output | Compare with |
|---|---|---|
| `tools/zombie_lineup.gd` | `screenshots/zombie_lineup.png` | `docs/design/images/style_lineup.jpg` |
| `tools/look_shot.gd` | `screenshots/look_reference.png` | `docs/design/images/style_corridor.jpg` |
| `tools/gun_lineup.gd` | `screenshots/gun_*.png` (guns with their finish shader) | `weapon_comparison_*.png` |
| `tools/screenshot.tscn` | `screenshots/*.png` in a real match | `style_corridor.jpg`, `ui_match_hud.jpg` |
| `tools/render_weapon_comparison.py` | `side.png`, `first_person.png` | `docs/design/images/weapon_comparison_*.png` |

`screenshots/` is git-ignored. OpenGL renders skip SSR, SDFGI and some glow,
so judge shape, colour and value there, not final lighting; use Forward+ for that. The game pauses
when its window loses focus; that does not matter for these scripts.

A new kind of visual (a prop, a machine) with no render script: add a few lines
to `zombie_lineup.gd` or copy it, do not build a render framework.

## 2. Compare (answer each in the PR)

Put your render and the reference side by side and check:

1. **Silhouette:** in black only, can you tell the type apart? (Shambler
   upright, Crawler flat, Bloater round.)
2. **Value:** zombie head is the lightest value; things you use or shoot are
   one step brighter than the walls.
3. **Palette:** only colours from `docs/design/look-rules.md`. Bio-green only
   on experiment parts. Blood dark red-brown.
4. **Temperature:** inside cold teal, outside warm sodium.
5. **Edges:** bevels catch the light; no razor-sharp grey-box edges.
6. **Scale:** the player capsule is 1.8 m tall and a wall panel 2.7 m.
7. **Guns:** matte black / gunmetal / one secondary colour, no full recolour.

## 3. Report

Attach the render (or a side-by-side) to the PR description and list anything
that still differs from the reference. If you could not render (no Godot, no
xvfb), say so in the PR; do not claim the look matches.

Real fps and final lighting need the game on a GPU (target 120 fps at 1440p
High on an RTX 4080 Super, v0.1 gate 60 fps). Note in the PR when a change
needs that check.
