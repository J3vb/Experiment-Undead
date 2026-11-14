# Prototype decisions

The prototype follows the architecture doc
(https://claude.ai/artifact/XNJ12WAbMJAy2mRNPd5PCx). This file lists what is
built, what was simplified on purpose, and what is still to do.

## Built and matching the doc

- **Godot 4.7.2, Forward+, Jolt at 60 Hz, physics interpolation on.**
- **Typed GDScript enforced:** `untyped_declaration` and `inferred_declaration` are errors (addons excluded).
- **Folders:** `core/` autoloads, `systems/<feature>/` code + scenes, `content/<type>/` data only.
- **Autoloads:** `Events` (past-tense facts only), `Content` (id = file name, strips `.remap`), `Net` (`is_authority()`, id allocation).
- **Content as Resources:** `WeaponData` + `RecoilData` (per-shot pattern), `EnemyData`, `WaveRules` + `EnemySpawnEntry`, `EconomyRules`. Live state is in `WeaponInstance`; `.tres` files are never mutated (tested).
- **Damage:** `DamageInfo` (amount, attacker, weapon id, type, zone, position, normal, impulse) → `HitZone` (Area3D on layer 4) → `HealthComponent`. Weapon head/limb multipliers from data, per-zone armour on the HitZone.
- **Collision layers 1-8** named as in the doc.
- **Multiplayer rules:**
  1. Player reads `InputFrame`s from a `LocalInput` node, never the keyboard.
  2. Damage, spawns, XP only apply where `Net.is_authority()`.
  3. Logic emits facts; muzzle flash, sound, impacts and hit markers react (weapon `fired`/`traced` signals).
  4. Gameplay in `_physics_process`; `GameSession.tick` counts ticks. Weapon `tick()` runs from the player's physics step; `_process` is visuals only.
  5. All enemies come from `Spawner`, which assigns `net_id`.
  6. Gameplay randomness uses `GameSession.rng` (seedable).
  7. XP goes through `ProgressionService` (one in-memory class for now).
  8. No global player: everything loops the `players` group.
- **Economy:** per-player `Wallet`; `Economy` pays from `EconomyRules` and owns `try_spend()`.
- **Wave director:** intermission → `round_started` → spawning (max alive cap, extra per player) → clearing → `round_ended`.
- **Zombie AI:** enum state machine (Spawning, Chasing, Attacking, Dead), NavigationAgent3D with avoidance off plus cheap separation, re-path interval by distance (0.25 / 0.5 / 1.5 s), target = nearest living player every 0.5 s.
- **Fire timing:** time accumulator plus a 0.12 s input buffer, semi / burst / auto.
- **Look:** volumetric fog, depth fog, AgX, SSAO, glow, flickering shadowed lamps, moonlight, player flashlight.
- **Look reference (Cold Containment):** `levels/look_reference/halcyon_corridor.tscn` rebuilds the style guide's Halcyon Labs corridor in Godot. Its `WorldEnvironment` points at the shared `levels/looks/halcyon_interior.tres`; interior game scenes must use this file, not a copy. Render it with `tools/look_shot.gd` (command in the file). Differences from the guide's table, on purpose: AgX instead of ACES; ambient energy 0.2 instead of 0.35 (baked bounce now fills the shadows); fog albedo is a light teal-grey because Godot's fog albedo is the scatter colour (the guide's #0A1416 was the web renderer's fog colour). Grain and vignette come from `systems/effects/film_post.tscn` (a CanvasLayer any scene can add). Zombies there are the code-built Shambler, Crawler and Bloater models (static, no game logic), and no light flickers so renders stay comparable. Style-guide light budget: at most 6 shadowed real-time lights in view (tested). Surface detail is procedural and world-space, no texture files: `levels/materials/grime.gdshader` (wall drips, floor-level dirt, ceiling stains; the wall panel's glTF materials are remapped to it in its `.import` file) and `wet_tiles.gdshader` (tiles, grout, mirror puddles for SSR). Fixtures have a dark housing; one unshadowed `ZombieRim` spot behind the zombies shines back toward the player so silhouettes read. Bounce light is baked with LightmapGI (High, 3 bounces, denoiser, texel scale 2; about 2.3 MB in `halcyon_corridor.exr` + `.lmbake`, plain git). Fixtures and the bio-leak glow use bake mode Dynamic: direct light and shadows stay real-time, only their bounce is baked. `ZombieRim` and the camera `ViewFill` are cheat lights with bake mode Disabled. Zombies and the rifle import with light baking Dynamic, so they are not baked and take light from the lightmap probes. The wall panel imports with Static Lightmaps (UV2, `.unwrap_cache` committed so UV2 is the same on every machine). `Block` builds its box at runtime as an internal child, which LightmapGI skips (it ignores unowned nodes), so `Block` hands the box over through `get_bake_meshes()` / `get_bake_mesh_instance()`, the hooks GridMap uses. **Re-bake after any geometry or light change:** Godot 4 has no command-line bake, so open the scene in the editor on a GPU, select `LightmapGI`, press Bake Lightmaps, save, and commit the new `.exr` and `.lmbake`.
- **Tests:** GUT, headless, 52 tests. GitHub Actions runs import, boot test and GUT.
- **Assets:** binaries are in plain git (about 1 MB). No Git LFS for now (decided 2026-11-14); revisit when asset packs arrive, the lines to switch it on are in `.gitattributes`. Up to v0.1 all art is built in code to the style-guide look; packs come after. All sounds are generated by `tools/generate_sfx.py` (original, no licence needed). No third-party assets yet, so `docs/CREDITS.md` is empty.
- **Builds and releases:** see `docs/RELEASING.md`. Exports run on Linux only (Windows cross-exported, no rcedit). Git tag = version. Separate `Build.PROTOCOL_VERSION` and `SaveFile.CURRENT_VERSION`. Godot ignores SIGTERM, so the server quits on a stop file the Docker entrypoint writes. No code signing yet.

## Simplified on purpose (fix before or during the matching build step)

- **Navmesh bakes at load** from the grey-box blocks instead of being baked ahead. Keeps edits safe while the map changes; switch to a baked `.tres` when the layout settles.
- **Zombie AI tiers:** only the re-path interval is tiered. Frame-skipping by tier and off-screen checks come with the performance pass.
- **No Pool autoload yet.** Impacts are capped at 48 and freed; zombies are freed after the corpse fades.
- **No Settings / Audio / Game autoloads yet.** Mouse sensitivity sits on `LocalInput`; sounds use plain players on the audio buses in `default_bus_layout.tres`.
- **Viewmodel** is a normal mesh close to the camera (near plane 0.03), not the depth-pulling shader. It can poke into walls when you hug them.
- **Procedural animation** for zombies and guns (bob, sway, kick, reload dip). Real clips replace it later.
- **Range falloff** uses start/end distances instead of a Curve.
- **Grey-box art:** boxes with procedural noise materials. First code-built models (wall panel, rifle, Shambler, Crawler, Bloater) exist in `assets/models/` from `tools/assets/build_models.py` and are only placed in the look reference scene so far. Zombie models face +Z with their origin at the feet; each limb is its own node with its origin at the joint (shoulder, hip, neck) so code-driven animation can rotate it. The game zombie (`systems/enemies/zombie.tscn`) still uses its box blockout; swapping these models in is a follow-up.

## Not started

Interactables (wall buys, doors, barriers, Med Dispensers, Specimen Vault, Reforger), power-ups,
menus and settings, debug console and F3 overlay, levels/skills/loot,
networking, dedicated server.
