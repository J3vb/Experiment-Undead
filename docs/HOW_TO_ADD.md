# How to add things

Start with [AGENTS.md](../AGENTS.md), [KEEP_IT_SIMPLE.md](KEEP_IT_SIMPLE.md),
[CODE_RULES.md](CODE_RULES.md) and [DECISIONS.md](DECISIONS.md).
These recipes describe the current code. `<id>`, `<name>` and `<feature>` are
placeholders; use snake_case filenames and matching `class_name`s.
Read [design/README.md](design/README.md) for content and visual work: code and
DECISIONS win over design targets. Loaded content Resources stay unchanged;
live state belongs in objects such as `WeaponInstance`.

## A gun

1. Check `design/gun-roster.md`, `design/balance/roster.csv` and `weapons.csv`;
    follow the documented provisional damage values in DECISIONS.
2. Create `content/weapons/<id>.tres` using `systems/weapons/weapon_data.gd`
    (`WeaponData`), with `id` matching the filename. Follow `kestrel_smg.tres`.
3. Embed `RecoilData` (`systems/weapons/recoil_data.gd`) as its `recoil`
    sub-resource, as existing guns do; fill handling, sounds and presentation.
4. For Tier I, create `<id>_reforged.tres` and link `upgraded`: damage ×2,
    magazine `int(base * 1.5)`, `max_reserve` ×2.
5. Build a model under `tools/assets/`, register it in `build_models.py`'s
    `MODELS`, and export to `assets/models/weapons/`; follow the
    [model](../.agents/skills/blender-model/SKILL.md) and [import](../.agents/skills/godot-asset-import/SKILL.md) skills.
6. Create `systems/weapons/viewmodels/<name>_viewmodel.tscn` and assign
    `viewmodel_scene`; preserve `Muzzle`, `FlashLight`, `FlashMesh` and animated `Magazine`/`Bolt` parts.
    Set `world_model` to the bare gun `.glb` (teammates hold it in third person; a Reforged copy uses the same one).
    Fit its first-person hands in `tools/assets/player_grip_profiles.py`, reusing the
    existing curl helpers. Rebuild `player_arms` and commit its GLB and generated `player_arm_grips.json`.
    Add `content/grips/<id>.tres` (`GripData`, `systems/player/grip_data.gd`, follow
    `rifle_ar.tres`): hand anchors, directions and shoulders, `shot_peak` if the shot
    moves the hands. Set `grip` on the gun and its Reforged copy. No code change.
    Check hip, ADS and reload poses with `tools/weapon_arm_review.tscn` and the
    arm anatomy, marker and contact checks; a new weapon must have an authored fit.
7. `Content.reload()` discovers it by filename; use `Content.weapon(&"<id>")`.
    Make it obtainable through `WallBuy.weapon` or `SpecimenVault.pool` in `levels/halcyon_labs/map.tscn`.
8. Add `tests/content/test_<id>.gd` like `test_kestrel_smg.gd`; extend
    `tests/content/test_generated_models.gd` for model parts and `tests/unit/test_weapon_viewmodel.gd` for new poses.
9. Done when `test_content.gd`, `test_content_rules.gd`, the new tests and asset
    checks pass, and the gun can be bought, fired, aimed and reloaded.

## An enemy type

1. Check `design/zombie-ai.md`, `design/balance/enemies.csv` and DECISIONS.
2. Create `content/enemies/<id>.tres` using `systems/enemies/enemy_data.gd`
    (`EnemyData`); match `id` to the filename and set stats and `scene`.
    Loot: leave `loot_drop_chance` at -1 for the zombie round curve, or set a fixed
    chance (0..1) and `loot_min_rarity` (for example a boss: 1.0 and `rare`).
3. Reuse `systems/enemies/zombie.tscn` for existing behaviour. For a different
    model/collision, inherit it under `systems/enemies/`, as `bloater.tscn` does.
4. Keep a `Zombie` root: `Spawner.spawn()` casts to `Zombie` and calls `setup()`.
    Preserve `HealthComponent`, `NavigationAgent3D`, `Visual`, `Voice`, `HitZones/Head` and `HitZones/Body`.
5. `Content.reload()` indexes it automatically; use `Content.enemy(&"<id>")`.
6. Add an `EnemySpawnEntry` in `content/waves/default_waves.tres`: `enemy`,
    `weight`, `weight_per_round`, `first_round`, optional `last_round` (0 = no limit).
7. Let `WaveDirector` spawn the mix; explicit requests use
    `session.spawner.spawn(enemy, round_number, session.wave_rules)`.
    `Spawner` guards authority, assigns `net_id` and emits `Events.enemy_spawned`.
8. Extend `tests/content/test_content.gd` and `test_content_rules.gd` with the
    new enemy's contract; add seeded mix-boundary checks in `tests/unit/test_wave_rules.gd`
    and extend `tests/integration/test_session.gd` for new behaviour.
9. Done when content checks pass, its scene loads as `Zombie`, and the seeded
    wave mix spawns it at the intended round through `Spawner` with a network id.

## A serum

1. Create `content/serums/<id>.tres` using `systems/serums/serum_data.gd`
    (`SerumData`), following `quickhands.tres`; set matching `id`, `display_name`, `cost` and `description`.
    Set `badge` (1 or 2 unique letters) and `badge_colour` for its HUD square.
2. Use positive `multipliers` keyed by `SerumData.STATS`. `Player.get_stat()`
    reads them; `Player.add_serum()` applies health/slots and emits `Events.serum_gained`.
3. A new stat needs its consumer and tests. Code-only effects like Second Wind
    and Scavenger use `SerumData.EFFECTS` and consumers checking `Player.has_serum()`.
4. Instance `systems/interactables/med_dispenser.tscn` under
    `NavigationRegion3D/Machines` in `levels/halcyon_labs/map.tscn`; set `serum` and optional `max_sales`.
5. Discovery is automatic; lookup is `Content.get_item(&"serums", &"<id>") as SerumData`.
6. Extend `tests/content/test_content.gd`, `tests/unit/test_serums.gd` and
    `tests/integration/test_med_dispenser.gd`; update placement/count expectations for a new dispenser.
7. Done when content validates, power/points gate the sale, repeat purchases
    do not charge, and the intended stat or effect changes play.

## A power-up

1. Create `content/power_ups/<id>.tres` using `systems/power_ups/power_up_data.gd`
    (`PowerUpData`); set matching `id` and `display_name`.
2. Add its effect to `match data.id` in `PowerUp.collect(player)` in
    `systems/power_ups/power_up.gd`; data alone does not implement an effect.
3. Keep collection behind `_on_body_entered()`'s living-player and
    `Net.is_authority()` checks. Existing code emits `Events.power_up_collected` after applying the effect.
4. For normal drops, add it to `PowerUpDrops.power_ups` in
    `systems/game/game_session.tscn`. Scavenger's `ammo_pack` stays in the separate `ammo_pack` export.
5. `PowerUpDrops` owns seeded kill rolls, the round cap and shuffled deck;
    lookup is `Content.get_item(&"power_ups", &"<id>") as PowerUpData`.
6. Extend `tests/content/test_content.gd` and `tests/integration/test_power_ups.gd`
    for the effect and deck; update assertions that assume every normal drop is Resupply.
7. Done when content validates, the intended players receive the effect once,
    and drops still obey their round cap and pickup lifetime.

## A buyable or machine

1. Reuse `systems/interactables/door.tscn`, `wall_buy.tscn`, `med_dispenser.tscn`,
    `reforger.tscn` or `specimen_vault.tscn` when its behaviour fits.
2. Configure the instance in `levels/halcyon_labs/map.tscn` through exports:
    `WallBuy.weapon`, `MedDispenser.serum`, `SpecimenVault.pool`, or `Door.opens_area`/`cost`/`needs_power`.
3. For new behaviour, create `systems/interactables/<name>.gd` extending
    `Interactable` and `<name>.tscn` with an `Area3D` root and collision shape.
4. Override `get_prompt(player: Player) -> String` and
    `interact(player: Player) -> void`; call `super()` if overriding `_ready()`.
5. Paid interactions call inherited `_pay(player, amount)` and provide direct
    `BuySound`/`DeniedSound` `AudioStreamPlayer3D` children; `_pay()` calls `Economy.try_spend()`.
6. `Player.apply_frame()` invokes interactions only with authority. Use
    `Level.power_on`/`power_turned_on` for power gates and public methods for purchases.
7. Extend `tests/content/test_halcyon_labs.gd` and the matching integration test
    `test_med_dispenser.gd`, `test_reforger.gd`, `test_specimen_vault.gd` or `test_halcyon_doors.gd`;
    new behaviour gets `tests/integration/test_<name>.gd`; check `test_machine_sounds.gd` too.
8. Done when focus/prompts work, rejected purchases preserve points/state, and
    success charges once and applies the effect. `BuyableData` is not implemented; use these scenes.

## A wave mix or balance change

1. Follow the [design-change skill](../.agents/skills/design-change/SKILL.md);
    compare current data and DECISIONS before applying sheet values.
2. Mix/count/timing/scaling: edit `content/waves/default_waves.tres`
    (`WaveRules`, `EnemySpawnEntry`); reference `design/balance/rounds.csv` and `enemies.csv`.
3. Enemy stats: `content/enemies/<id>.tres` ↔ `design/balance/enemies.csv`.
4. Gun numbers: `content/weapons/<id>.tres` and its Reforged resource ↔
    `design/balance/weapons.csv`, `roster.csv`, `prices.csv` and `ttk.csv`.
5. Points earned: `content/economy/default_economy.tres` (`EconomyRules`) ↔
    `design/balance/economy.csv` and `prices.csv`; serum price/stat changes use `content/serums/<id>.tres`.
6. Change data only. CSVs are design exports, refreshed only when their source
    changes; record intentional runtime differences in DECISIONS, never in balance formulas in code.
7. Add/extend `tests/content/test_<subject>.gd` to lock values and outcomes;
    `test_content_rules.gd` checks numeric constraints. Extend `tests/unit/test_wave_rules.gd`
    for mix first/last-round boundaries with a fixed seed.
8. Done when content and seeded mix tests pass and the PR gives old/new values,
    source rows and relevant TTK/economy effects.

## A new content type

1. Create `systems/<feature>/<type>_data.gd`, with a `##` doc comment, matching
    `class_name` and `extends Resource`; follow `systems/serums/serum_data.gd`.
2. Export only fields someone tunes now. Create instances in `content/<type>/`;
    keep scripts/scenes under `systems/`, and ids unique within the whole type.
3. `core/content.gd` needs no registry edit: `Content.reload()` scans every
    type directory recursively, strips `.remap` and indexes `.tres` filename stems.
4. Use `Content.get_item(type, id)` and cast to the new class, following
    `Content.get_item(&"serums", &"quickhands") as SerumData`; list with `Content.ids(type)`.
    Keep feature/level resource paths out of `core/`.
5. Wire the resource into its actual consumer's exports or public API;
    automatic discovery alone does not make it sold, dropped or used.
6. Add `tests/content/test_<type>.gd`: assert index/lookup, expected class,
    filename/id agreement if it has an `id`, references and type-specific constraints.
    Extend `test_content.gd`'s indexed-type list and `test_content_rules.gd` for new rules.
7. Test all nested resources too: `test_content_rules.gd` recurses, but
    `test_content.gd`'s `_files()` only checks the immediate type directory.
8. Done when the consumer loads it through `Content`, every instance validates,
    and runtime code leaves the shared Resource unchanged.

## A new system

1. Put code/scenes in `systems/<feature>/`, with matching snake_case filenames,
    typed declarations and a `##` doc comment within each script's first five lines.
2. Use a plain script for logic/data (`WeaponInstance` extends `RefCounted`);
    use a `.tscn` for reusable child nodes (`MusicPlayer`), or attach a Node script
    to the owning scene (`Economy` in `systems/game/game_session.tscn`).
3. Wire session references in `GameSession._ready()` in
    `systems/game/game_session.gd`, following `PowerUpDrops.session`/`WaveDirector.session`.
4. Hear completed facts through `Events` (for example `enemy_killed`);
    make requests through direct public calls such as `Economy.try_spend()`.
5. Signal up to the owner for local facts. Never reach into another system's
    children; the owner passes references and connects public APIs/signals.
6. Gameplay uses physics ticks, `InputFrame`, `GameSession.rng`, `Net.is_authority()`,
    `Spawner` and `ProgressionService` as required by AGENTS; visuals use `_process()`.
7. Add `tests/unit/test_<feature>.gd` for logic; cross-system flows go in
    `tests/integration/test_<feature>.gd` with a seeded `GameSession`.
8. Add early-warning logs using the recipe below. An autoload is almost never
    needed: only add an architecture-listed global owner when this phase needs it;
    follow [KEEP_IT_SIMPLE.md](KEEP_IT_SIMPLE.md) and AGENTS rule 5 before changing `project.godot`.
9. Done when its owner wires it, tests exercise its real behaviour, and
    `tools/ci/check_rules.py` accepts its dependencies and test coverage.

## A new Events signal

1. First check `core/events.gd` for an existing fact. Keep local facts on the
    owning node; requests remain direct calls.
2. Add a past-tense `signal` in `core/events.gd`, with a short `##` meaning
    and typed arguments, following `enemy_spawned(enemy: Node3D)` or `round_ended(round_number: int)`.
    Add a `## Peers:` line saying where it fires (server only, owner, every peer);
    `tests/unit/test_events.gd` fails without it.
3. Choose and document the emitter: only the system that owns and completes
    the change may emit. `Spawner` emits `enemy_spawned`; `Zombie` emits `enemy_killed`.
4. For damage/spawns/points/XP, guard the mutation path with `Net.is_authority()`
    and emit after the change succeeds. Listeners must not re-emit the fact or reapply the change.
5. Connect listeners in their `_ready()` or the owner's wiring; keep `Events`
    signal-only, with no routing logic or resource/scene paths into systems/levels.
6. Extend the emitter's `tests/unit/test_<feature>.gd` or
    `tests/integration/test_<feature>.gd`; watch signals and assert typed payload, timing and count.
7. Done when success emits once, rejected requests emit nothing, and listeners
    observe the completed change without causing duplicate gameplay effects.

## A screen

1. Make the scene in `systems/ui/` (or the feature's folder). Its root has
    `signal closed`, handles its own Back (Esc / `ui_cancel` / controller B)
    and emits `closed`, like `settings_screen.gd` or `pause_screen.gd`.
2. Add one `content/screens/<id>.tres` (`ScreenData`): `scene`, `layer` 20 for
    screens or 30 for overlays. `root` and `captures_mouse` stay false; only
    the main menu and the match are roots.
3. Open it with `UI.push(&"<id>")`; it returns the screen so you can pass it
    data (`UI.push(&"character").open(profile)`). The router hides what is
    under it, frees the mouse, pops it on `closed` and gives focus back.
    Never `add_child` a screen or set `Input.mouse_mode` yourself (CI rule `ui-router-only`).
4. Ask the opener with signals, as `ResultsScreen.restart_requested` does;
    the owner connects them after the push.
5. Add `tests/unit/test_<screen>.gd`: push it, check `UI.top()`, Back pops
    and focus returns. `tests/content/test_screens.gd` already instances every
    `ScreenData`.

## A new player setting

1. Add its default under the right section in `core/settings.gd`'s `DEFAULTS`
    (graphics keys go in `core/graphics.gd`'s `DEFAULTS`); extend `_normalize()`
    (or `Graphics.normalize()`) for its range. Settings saves `user://settings.cfg`.
2. Engine application: graphics in `Graphics.apply()`, audio buses in `Settings._apply()`;
    feature-specific application belongs in the consumer.
3. Read initially with `Settings.get_value(section, key)`, cache it, and listen to
    `Settings.changed(section, key, value)`, as `LocalInput`/`PlayerCamera` do.
4. Add its row as `content/settings/<section>_<key>.tres` (`SettingData`): page,
    section, key, label, a one-line hint, kind (toggle, slider, choice), range or
    options, order. The settings screen builds it; no scene or screen code changes.
    A new page also needs a tab (ScrollContainer + `SettingsPage`) in `settings_screen.tscn`.
5. Write through `Settings.set_value()`; it normalizes, applies, emits and saves.
6. Tests: defaults, clamping and save/load in `tests/unit/test_settings*.gd`;
    the consumer's live change in its own test. `tests/content/test_setting_data.gd`
    checks every row automatically.
7. Done when it survives reopening, applies immediately, Defaults and Revert work and
    it works while paused; tests use isolated `config_path`s and restore Settings afterwards.

## A Log.warn early-warning line

1. Read [LOGGING.md](LOGGING.md). Put the warning where the owning system
    detects a recoverable problem; use `Log.error()` when the feature cannot work.
2. Follow `Spawner._pick_marker()` in `systems/waves/spawner.gd`:
    `Log.warn(&"waves", &"spawn_points_missing", {"spawn_group": spawn_group})`.
    Use the feature folder as system and a snake_case past-tense event or state; no `print()`/`push_warning()`.
3. Include useful ids, positions, counts or timings, with no player names or
    personal data. Report once or group repeats; never warn every frame/shot/hit.
4. Add `system.event`, level, trigger, fields and what to check to the
    `docs/LOGGING.md` event catalogue in the same PR.
5. Extend the owning system's unit test; follow `tests/unit/test_spawner.gd`
    or `test_health_watch.gd` to assert `Log.event_counts` deltas and `Log.problems` payloads.
    Extend `tests/unit/test_log.gd` only if the logger's behaviour changes.
6. Done when the trigger produces the expected warning and payload in
    `user://logs/*.jsonl`/summary, normal operation stays quiet, and repeats stay bounded.

## Before you open the PR

- Run the `quality` commands from [AGENTS.md](../AGENTS.md): quality-gate unit
    tests, `tools/ci/check_pr.py origin/main`, `tools/ci/check_rules.py` and `tools/ci/check_skills_mirror.py`.
- Run the `test` steps in [.github/workflows/ci.yml](../.github/workflows/ci.yml):
    Godot 4.7.2 import, 300-frame boot and all GUT tests; no `SCRIPT ERROR`/`Parse Error`.
- For models, pass [Assets](../.github/workflows/assets.yml) and
    [Turnarounds](../.github/workflows/turnarounds.yml), including reviewed approved renders.
- Check the diff for accidental editor/formatter changes, fill the PR template
    and simplicity check, list any inconsistencies found, apply one release-note label,
    open as draft, then mark ready for review. CI `quality` and `test` must be green.
