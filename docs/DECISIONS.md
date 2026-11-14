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
- **Look reference (Cold Containment):** `levels/look_reference/halcyon_corridor.tscn` rebuilds the style guide's Halcyon Labs corridor in Godot. Its `WorldEnvironment` points at the shared `levels/looks/halcyon_interior.tres`; interior game scenes must use this file, not a copy. Render it with `tools/look_shot.gd` (command in the file). Differences from the guide's table, on purpose: AgX instead of ACES; ambient energy 0.5 instead of 0.35, plus a weak unshadowed spill light above each fixture, standing in for LightmapGI bounce until lightmaps are baked; fog albedo is a light teal-grey because Godot's fog albedo is the scatter colour (the guide's #0A1416 was the web renderer's fog colour). Grain and vignette come from `systems/effects/film_post.tscn` (a CanvasLayer any scene can add). Zombies there are the code-built Shambler, Crawler and Bloater models (static, no game logic), and no light flickers so renders stay comparable. Style-guide light budget: at most 6 shadowed real-time lights in view (tested). Surface detail is procedural and world-space, no texture files: `levels/materials/grime.gdshader` (wall drips, floor-level dirt, ceiling stains; the wall panel's glTF materials are remapped to it in its `.import` file) and `wet_tiles.gdshader` (tiles, grout, mirror puddles for SSR). Fixtures have a dark housing; one unshadowed `ZombieRim` spot behind the zombies shines back toward the player so silhouettes read. LightmapGI is still to come: baking needs the editor on a real GPU, so the spill lights stay until then.
- **Halcyon Labs (default map, blockout):** `levels/halcyon_labs/layout.json` holds rooms (rect, floor height, ceiling height), door cuts and ramps as plain data. `tools/blockout_builder.gd` turns it into `blockout.tscn` (command in the file; never hand-edit the output, a test fails if it is stale). Walls are runs of the code-built wall panel with one collision box per run; ceiling lights are the kit scene `levels/kit/ceiling_light.tscn`, two shadowed per room. `map.tscn` holds the gameplay nodes: player spawn, 21 `ZombieSpawnPoint`s (each tagged with its area), dock props, orange doors and green machine placeholders. `Level.open_area()` puts an area's spawn points into the Spawner's group; only the Loading Dock is open at the start. Closed doorways cut the navmesh (tested). Layout and costs follow the maps doc (https://claude.ai/artifact/UxyrXQqFfonMxh3MgFMYWY). The prototype courtyard is removed.
- **Interactables:** `Interactable` (Area3D on the interactable layer, `get_prompt()` + `interact()`); the player ray-casts 2.5 m from the camera each tick into `Player.focus`, presses interact, and the HUD shows the prompt. `Door` (cost, area, needs power; doors to the same area open together; opening frees its blocker and rebakes the navmesh at the end of the frame, one bake for any number of doors; the bake runs on the main thread because threaded bakes never finished on the 2-core CI runner, so a purchase costs one short hitch (move to per-area regions if it shows in profiling)), `PowerSwitch` (`Level.turn_power_on()`, free power doors open themselves), `WallBuy` (gun at its `WeaponData.cost`, ammo for half). Med Dispensers, Vault spots, Reforger, exfil and the wall guns that do not exist yet are green placeholder blocks with labels, in groups the map test counts. The map's NavigationMesh is local to scene, so a restarted match never shares a mesh that is still baking.
- **Serums and Med Dispensers:** `SerumData` (`content/serums/`) is a name, a cost and a dictionary of stat multipliers. `Player.get_stat()` multiplies the multipliers of every Serum the player holds; the gun reads `reload_time`, `fire_interval`, `ads_time` and `head_damage` through it, and the player applies `max_health` and `weapon_slots` when a Serum is bought. This is the small first step toward the StatBlock of P5, which replaces it. `MedDispenser` (`systems/interactables/med_dispenser.tscn`) sells one Serum, needs power (its strip lights up when the power comes on), once per run. Five Serums are real: Ironhide, Quickhands, Overclock, Deadeye, Mule. Prices are the design doc's base prices, like the doors (the balance sheet's provisional x2.5 is not applied). Provisional: all dispensers need power, no limit on how many Serums a player holds.
- **Tests:** GUT, headless, 41 tests. GitHub Actions runs import, boot test and GUT.
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
- **Grey-box art:** boxes with procedural noise materials. First code-built models (wall panel, rifle, Shambler, Crawler, Bloater) exist in `assets/models/` from `tools/assets/build_models.py` and are only placed in the look reference scene so far. Zombie models face +Z with their origin at the feet; each limb is its own node with its origin at the joint (shoulder, hip, neck) so code-driven animation can rotate it. In game, Walker and Runner use the Shambler and the Bloater (`zombie_bloater`, from round 8, no death gas yet) uses the Bloater; `ZombieRig` poses the limbs in code (walk, reach, attack, slack on death) until real clips exist, and the head hit zone is parented to the model's head so headshots follow the animation. The poses run in `_process`, so the head zone's exact spot is a render-loop value; fine for solo, but P7 (server-authoritative hits, rewind) must pose hit zones on the physics tick or use a fixed head anchor. The Crawler is not spawned yet: by design it is made when explosives take a Shambler's legs, and there are no explosives. The player rifle is `rifle_ar.glb`; its bolt kicks on each shot and the magazine drops on reload. Aiming uses a picture-in-picture scope (`ScopeLens`): a second camera renders a 2x view only while aiming, and first-person gun meshes sit on render layer 20 so it skips them.

## Not started

Emergency lighting before power, barriers, Specimen Vault, Reforger, exfil, the Serums Second Wind (needs a downed state), Stride (needs sprint stamina) and Scavenger (needs ammo packs and grenades; their dispensers are still green placeholders), power-ups,
menus and settings, debug console and F3 overlay, levels/skills/loot,
networking, dedicated server.
