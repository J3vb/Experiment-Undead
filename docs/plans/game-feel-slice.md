# Plan: Game feel and death screen

Status: Review
Roadmap: F-14 / no issue (audit of the v0.1 slice against docs/design/game-feel.md)
Phase: P1 + P4 (feel layer the slice still misses)
Size: M
Approved by:

## Goal

Shots, kills and getting hit move the camera the way the game-feel doc
describes (view kick, trauma shake, FOV punch, hitstop), and going down, being
revived and dying have their own screen, sound and "Gear kept" death screen.
Pillar: tight, modern gunplay that feels good from the first shot; the death
moment tells the player loot is safe.

## Scope

In:

- `FeelData` (per weapon class) and `FeedbackRules` (global) resources, seven
  class files, every gun points at its class file.
- Camera: view kick spring, trauma shake (rotation only, noise), FOV punch on
  heavy shots; hit shake when the local player takes damage; 0.15 trauma
  rumble on round start.
- Hitstop on the local viewmodel and camera for headshot kills, shotgun and
  marksman kills; kill FOV punch on headshot kills.
- Comfort hooks: `comfort/shake_own_gun`, `comfort/shake_hits`,
  `comfort/flash_reduction` in `Settings.DEFAULTS`.
- Downed screen (20% saturation, 50% red vignette, camera drop and 6° roll),
  revive flash, death fade to black with world sound dropping out, then the
  results screen (solo) or spectating (co-op); a "Gear kept" banner on the
  results screen after a death and in the co-op spectate prompt.
- Generated `downed`, `revived` and `bled_out` sounds for the local player.

Not in (and where it goes instead):

- Moving `WeaponData.viewmodel_kick` into FeelData: 44 tuned values, no feel
  gain now. Later, with F-42 Gear in first person, which reworks the viewmodel.
- New hit marker tiers, score pops, damage numbers: the existing HitMarker
  covers v0.1. Later polish issue.
- Muzzle flash budget, tracers, surface impacts, gore, ragdoll impulse: the
  effects already in the build stay. Later polish issue.
- Freezing the killed zombie's pose during hitstop: `Events.hit_confirmed`
  carries no enemy, and changing it touches co-op hit claims. Later, with the
  hit claims rework.
- The round transition timeline (sirens, light flicker): later, with audio.
- Health-state effects (Hurt/Critical vignette, heartbeat): the existing damage
  vignette stays; later polish issue.
- Teammate-downed callout sound: later, with F-47 squad cards.
- Comfort menu rows: the settings thread adds SettingData rows (F-05 step 2).
- Hitstop on/off setting: not in the controls doc's Comfort table; later if
  play-tests ask for it.

## Ready to build

```
### Ready to build
- Foundations touched (numbers from docs/FOUNDATIONS.md): content as data,
  Settings autoload, player camera. None shaky for this work.
- Decision records that apply (docs/adr/): 0003 trusted-client co-op (feel
  is local presentation only). Goes against one: no
- Co-op:
  - Who decides: nobody; every effect is local to the owning client.
  - How a client triggers it: local Events (weapon_fired on the owner,
    hit_confirmed on the shooter's owner, player_damaged on the owner) and
    the synced is_downed / is_dead flags it already receives.
  - What other players see: nothing new (remote heads use synced Head
    rotation, which shake never touches).
  - Works on a dedicated server with no local player: yes, every handler
    returns early unless the player is the local authority.
- Data: content/feel/class_*.tres, content/feel/feedback_rules.tres; numbers
  from docs/design/game-feel.md. Code compares against a specific id: no
- Save: changes what is saved? no (settings.cfg gains a [comfort] section with
  defaults; old files load with defaults)
- Events and UI: no new Events. No new screens (one overlay node in hud.tscn).
- Input through InputFrame, gameplay in _physics_process, randomness from the
  session RNG: yes (feel runs in _process; shake noise is cosmetic)
- Tests: tests/content/test_feel_data.gd, tests/unit/test_camera_feel.gd,
  tests/unit/test_hitstop.gd, tests/unit/test_down_screen.gd,
  results screen test extended.
- Logging: Log.warn when a WeaponData has no feel (content test also fails).
- Performance: no per-frame allocation; noise is one FastNoiseLite made once.
- Out of scope: see Not in.
```

## Design references

- docs/design/game-feel.md#starting-numbers-per-weapon-class (view kick,
  return, FOV punch, fire trauma per class; ADS view kick x0.6)
- docs/design/game-feel.md#screen-shake (trauma², decay 1.6/s, 2.5° pitch/yaw
  and 1.5° roll at trauma 1, 18 Hz noise, rotation only, cap 0.35 from firing,
  0.25 melee hit, 0.15 round start, ADS halves incoming trauma)
- docs/design/game-feel.md#fov-punch (rise 25 ms, ±4° cap, −0.8° for 120 ms on
  headshot kill)
- docs/design/game-feel.md#hitstop (25 headshot kill, 35 shotgun, 30 marksman,
  never stacks, cap 4 per second, simulation never pauses)
- docs/design/game-feel.md#downed-and-death (0.9 m drop over 300 ms, 6° roll,
  20% saturation, 50% vignette, 8% white flash 150 ms, 0.6 s fade to black,
  "Gear kept")
- docs/design/game-feel.md#validator-ranges
- docs/design/controls.md#comfort-and-motion-sickness (two shake sliders,
  flash reduction, sliders never change aim)
- docs/design/balance/roster.csv (gun classes)

## Systems touched

| Folder or file | New / changed | What changes |
|---|---|---|
| systems/feel/feel_data.gd | new | FeelData resource |
| systems/feel/feedback_rules.gd | new | FeedbackRules resource |
| systems/feel/down_screen.gd + .gdshader | new | downed / revived / death overlay and sounds |
| content/feel/*.tres | new | seven class files + feedback_rules.tres |
| content/weapons/*.tres | changed | `feel = ` line on every gun |
| systems/weapons/weapon_data.gd | changed | `@export var feel: FeelData` |
| systems/player/player_camera.gd | changed | view kick spring, trauma, FOV punch, `aim_basis()` |
| systems/player/player.tscn | changed | PlayerCamera gets `rules = feedback_rules.tres` |
| systems/weapons/weapon.gd, gravity_well.gd | changed | aim from `camera_rig.aim_basis()` (one line each) |
| systems/weapons/weapon_holder.gd | changed | `hold(seconds)`: pauses the gun's visual `_process` |
| core/settings.gd | changed | `comfort` section, three keys, 0-1 clamp |
| systems/net/player_state_sync.gd | changed | downed roll: tween to 6° instead of instant 25° (one line) |
| systems/ui/hud.tscn | changed | DownScreen overlay node (no hud.gd change) |
| systems/ui/results_screen.gd/.tscn | changed | "Gear kept" banner when not exfil |
| systems/net/coop_hud.gd | changed | spectate prompt "Gear kept · Respawn next round" |
| tools/generate_sfx.py, assets/audio/ | changed | downed.wav, revived.wav, bled_out.wav |

Autoloads, managers or base classes added: none. DownScreen owns new state
(the overlay's fade), so it is a plain node, not a manager.

## Data

`FeelData` (Resource, `systems/feel/feel_data.gd`), read by PlayerCamera and
WeaponHolder through `weapon.data.feel`:

- `view_kick_pitch: float` (°, default 0.5), `view_kick_return_ms: float` (75)
- `fire_trauma: float` (0.0), `fov_punch_deg: float` (0.0), `fov_punch_ms: float` (0.0)
- `kill_hitstop_ms: float` (0.0)

Only the fields this plan uses; the doc's viewmodel, muzzle and dismember
fields come with their features.

`FeedbackRules` (Resource, `systems/feel/feedback_rules.gd`, one file
`content/feel/feedback_rules.tres`, exported on PlayerCamera and DownScreen):

- shake: `trauma_decay` 1.6, `max_shake_pitch_deg` 2.5, `max_shake_yaw_deg`
  2.5, `max_shake_roll_deg` 1.5, `shake_noise_hz` 18, `fire_trauma_cap` 0.35,
  `hit_trauma` 0.25, `round_start_trauma` 0.15, `ads_trauma_mult` 0.5,
  `ads_view_kick_mult` 0.6
- kill: `headshot_kill_hitstop_ms` 25, `max_hitstops_per_second` 4,
  `headshot_kill_fov_deg` −0.8, `headshot_kill_fov_ms` 120
- downed and death: `downed_drop_m` 0.9, `downed_drop_s` 0.3, `downed_roll_deg`
  6, `downed_saturation` 0.2, `downed_vignette` 0.5, `revive_flash_alpha`
  0.08, `revive_flash_s` 0.15, `death_fade_s` 0.6

Class files (numbers from the class table; class per roster.csv, Reforged
copies share their base's file):

| File | Guns |
|---|---|
| class_pistol.tres | pistol_service, hollis_44 |
| class_smg.tres | kestrel_smg, mako_pdw, nightjar_sd, wren_mp |
| class_rifle.tres | rifle_ar, sentry_br3, rampart_br |
| class_lmg.tres | halberd_lmg, bastion_lmg |
| class_shotgun.tres | brenner_trench, atlas_auto, coachman_2b, grubber_sawnoff |
| class_marksman.tres | talon_dmr, corvid_338, fieldhand_lever |
| class_heavy.tres | ironwood_50, cryo_lance, siphon, synapse |

Shotgun `kill_hitstop_ms` = 35 and marksman 30. The doc's "< 4 m" condition
for shotguns is dropped: hit_confirmed has no distance, and a shotgun kill is
almost always close. Written in DECISIONS.md.

Settings: `comfort/shake_own_gun` (float, 1.0), `comfort/shake_hits` (float,
1.0), `comfort/flash_reduction` (bool, false), names from
docs/design/controls.md. Old settings files load with these defaults.

- Save format change: none (profile save untouched).
- Content checks in `tests/content/test_feel_data.gd`: every WeaponData has a
  feel; every FeelData within the doc's validator ranges; FeedbackRules loads
  and its values are in range (caps ≤ 1, durations > 0).

## Co-op behaviour

- Who owns the state: each client owns its own camera feel and overlay. No
  shared state.
- What clients send, what the server sends back: nothing new.
- What a client sees that the host sees too: nothing; others see the synced
  Head rotation and the existing downed icon.
- Late joiner: nothing (overlay reads the synced is_downed / is_dead flags
  from the first snapshot).
- Dedicated server: PlayerCamera handlers and DownScreen return early when no
  local player is the authority; no sound or tween runs there.

## Performance

Per frame for the one local player: one noise sample per axis, a few lerps,
one shader uniform write while downed or fading. No allocations (the
FastNoiseLite is created in `_ready`). Well under the doc's 0.4 ms CPU feel
budget.

## Steps

### Step 1: Feel data

- Build: FeelData and FeedbackRules scripts, seven class files and
  feedback_rules.tres, `WeaponData.feel`, `feel = ` on every gun .tres
  (base and Reforged). No behaviour change.
- Files: systems/feel/feel_data.gd, systems/feel/feedback_rules.gd,
  content/feel/*.tres, systems/weapons/weapon_data.gd, content/weapons/*.tres,
  docs/HOW_TO_ADD.md (new gun: pick a feel class).
- Tests: tests/content/test_feel_data.gd (fails without the files or with any
  gun missing a feel).
- Done when: every gun has a class file, content tests green.

### Step 2: Camera punch and comfort keys

- Build: PlayerCamera gains `aim_basis()` (RecoilPivot basis), a view kick
  spring on the Camera3D's own rotation (pitch kick, returns in
  `view_kick_return_ms`), trauma (add/decay/trauma² rotation shake from
  noise), FOV punch (rise 25 ms, ease back, ±4° cap). It listens to
  `Events.weapon_fired` (local player only: view kick, fire trauma capped at
  0.35, FOV punch), `Events.player_damaged` (local: 0.25 trauma) and
  `Events.round_started` (0.15). ADS halves trauma and scales view kick by
  0.6. Own-gun effects scale by `comfort/shake_own_gun`, the rest by
  `comfort/shake_hits`. Weapon traces and Gravity Well aim from
  `aim_basis()`, so cosmetic camera motion never moves bullets. Settings gets
  the comfort section.
- Files: systems/player/player_camera.gd, systems/player/player.tscn,
  systems/weapons/weapon.gd (one line), systems/weapons/gravity_well.gd
  (one line), systems/weapons/melee.gd (one line, once the knife from PR #239
  is merged), core/settings.gd.
- Tests: tests/unit/test_camera_feel.gd: trauma decays at 1.6/s and caps at
  1.0; fire trauma caps at 0.35; shake 0 leaves the camera rotation at zero;
  the trace basis is the same with shake at 0 and 1 (the controls doc test);
  ADS halves trauma; a remote player copy ignores weapon_fired. Settings test:
  comfort keys default and clamp to 0-1.
- Done when: firing a shotgun visibly punches, a 0 slider turns it off,
  aim tests green.

### Step 3: Hitstop and kill punch

- Build: on `Events.hit_confirmed` for the local player with `is_kill`:
  hitstop = max(headshot 25 ms if headshot, `feel.kill_hitstop_ms`);
  `WeaponHolder.hold(seconds)` pauses the current gun's `_process` and the
  holder's sway, PlayerCamera freezes its spring and shake for the same time.
  Longer replaces shorter, never stacks, at most 4 per second. Headshot kills
  also get the −0.8° / 120 ms FOV punch. Simulation and `_physics_process`
  never pause. Hitstop follows `comfort/shake_own_gun` > 0.
- Files: systems/player/player_camera.gd, systems/weapons/weapon_holder.gd.
- Tests: tests/unit/test_hitstop.gd: headshot kill holds 25 ms; shotgun kill
  holds 35; a shorter one does not cut a longer one; the 5th within a second
  is skipped; the gun still fires during a hold (physics tick runs).
- Done when: a headshot kill gives a tiny freeze, firing never stutters.

### Step 4: Downed and death screen

- Build: DownScreen (Control + canvas shader) in hud.tscn. It watches the
  local player's `is_downed` / `is_dead` in `_process` (two bool reads; no new
  Events, no net code). Downed: saturation tween to 0.2, vignette 0.5, camera
  rig drops 0.9 m over 0.3 s (solo Second Wind and co-op), roll 6°
  (`player_state_sync._present` tweens to `downed_roll_deg` instead of setting
  25°). Revived: colour returns, 8% white flash for 0.15 s (skipped with
  flash_reduction). Died: 0.6 s fade to black, and an AudioEffectAmplify on
  the SFX bus (added to default_bus_layout.tres) tweens to −60 dB; Music and
  UI stay. Solo: the results screen follows after the existing restart delay
  and shows a "Gear kept" banner when the run did not exfil. Co-op: fade back
  in on the spectate camera, prompt reads "Spectating · Gear kept · Respawn
  next round"; SFX returns on respawn. `_exit_tree` always restores the bus.
- Files: systems/feel/down_screen.gd, systems/feel/down_screen.gdshader,
  systems/ui/hud.tscn, default_bus_layout.tres, systems/ui/results_screen.gd
  and .tscn, systems/net/coop_hud.gd, systems/net/player_state_sync.gd (one
  line), docs/DECISIONS.md.
- Tests: tests/unit/test_down_screen.gd: downed sets saturation and vignette
  targets; died fades to black and drops the SFX amplify; respawn and
  `_exit_tree` restore 0 dB; flash_reduction skips the flash; no local player
  does nothing. Results test: "Gear kept" banner visible on death, hidden on
  exfil.
- Done when: dying in solo fades out before results; dying in co-op fades
  into spectating; the bus is never left muted.

### Step 5: Downed, revive and death sounds

- Build: three generated sounds in tools/generate_sfx.py (`downed`: low
  falling thud with a ringing tail; `revived`: short rising sting;
  `bled_out`: deep heartbeat stop). DownScreen plays them 2D on the Player bus
  for the local player only.
- Files: tools/generate_sfx.py, assets/audio/downed.wav, revived.wav,
  bled_out.wav (+ .import), systems/feel/down_screen.gd, docs/CREDITS.md
  not needed (generated).
- Tests: tests/unit/test_down_screen.gd: each state change plays its stream
  once; a remote player's state change plays nothing.
- Done when: going down, getting up and bleeding out each have a sound.

## Acceptance

- [ ] Every gun has a FeelData within the validator ranges (content test).
- [ ] Bullet direction is identical with shake at 0% and 100% (unit test).
- [ ] Both comfort sliders at 0 remove all camera shake and punch (unit test).
- [ ] Hitstop never pauses the simulation and never exceeds 4 per second (unit test).
- [ ] Death fades to black with world sound dropping, then results or spectate;
      the SFX bus is always restored (unit test + play-test).
- [ ] The results screen says "Gear kept" after a death (unit test).
- [ ] Soak stays green.
- [ ] The person's feel play-test (list in the handoff).

## Risks

- Aim honesty: if anything else reads `camera.global_basis` for aim, shake
  would leak into gameplay. Step 2 greps for every use and the trace test
  catches the main path; interact focus may follow shake (harmless).
- The SFX bus left muted after a crash in the death fade: `_exit_tree` and
  respawn both reset it, and the test covers both.
- File-size limits: weapon.gd is at 350 lines, so it gets one-line swaps only;
  feel code lives in PlayerCamera, WeaponHolder and DownScreen.
- Other threads edit player_state_sync.gd, hud.tscn and weapon_holder.gd;
  each touch is a line or a node, coordinated through the coordinator.

## Open decisions

- none (all numbers come from game-feel.md; feel tuning happens in the
  person's play-test after merge)
