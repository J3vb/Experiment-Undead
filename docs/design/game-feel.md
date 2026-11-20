# Fenlight: Game Feel

Source: copy of the design doc as of Nov 14, 2026. Where this file and the code differ, the code and `docs/DECISIONS.md` win.

Every shot answers the player within one frame, every kill pays off with sound and motion, and nothing blocks the view of the zombie you are aiming at. All values below are starting numbers for P1 (Gun feel) and live in data files, so tuning never needs code.

## Goals and rules

1. **Instant answer.** Hit marker, hit sound and impact effect appear on the same frame the hit is confirmed. Budget: 0 frames of delay locally, 1 server tick in co-op (the client shows a predicted marker, the server confirms kills).
2. **Readable, not noisy.** Feedback scales with importance: body hit < headshot < kill < headshot kill < multi-kill. With 24 zombies on screen, small events stay small.
3. **Never block the aim.** No effect may cover the centre 6% of the screen for more than 80 ms, except the muzzle flash on the first frame.
4. **Camera moves, aim stays honest.** Viewkick and shake move the camera; bullets follow the gun's real aim point. Recoil you can see is recoil you can control.
5. **Pressure always builds.** Player damage, low health and round transitions are louder and darker as rounds climb, so the feel itself tells the story.
6. **Data first.** One `FeelData` resource per weapon class, overrides per weapon, plus one global `FeedbackRules` resource. No magic numbers in scripts.
7. **Accessible by default.** Every shake, flash and blur has a slider. Colours never carry meaning alone (shape and sound back them up).

## Hit markers and kill feedback

The hit marker is four short diagonal ticks around the crosshair; it changes size, colour and sound by event tier. Headshots use gold #FFC845, kills use white with a red #C3201B core, so colour-blind players still read them by shape and sound.

| Event | Marker | Size (px at 1440p) | Hold + fade (ms) | Sound cue | Extra |
| --- | --- | --- | --- | --- | --- |
| Body / limb hit | 4 ticks, white #F2F2EE | 10 long, 2 thick, 6 gap | 60 + 90 | `hit_body` tick | none |
| Headshot | 4 ticks, gold, 1 px dark outline, plus a small 6 px diamond in the centre (reads without colour) | 12 long, 3 thick | 80 + 120 | `hit_head` crisp ping | none |
| Kill (body) | 4 ticks + red core dot, X shape | 14 long, 3 thick, scale pop 1.25 to 1.0 over 70 ms | 120 + 160 | `kill_confirm` thud | +1 kill counter tick, score pop |
| Headshot kill | gold X + red core | 16 long, 3 thick, pop 1.35 to 1.0 | 140 + 180 | `kill_head` (thud + ping layered) | head pop gib, 25 ms hitstop |
| Multi-kill (2+ in 0.25 s) | kill X + outer ring | ring 28 px, expands to 40 px | 180 + 200 | `kill_multi` | ring count shows x2, x3 |
| Shielded / armoured hit | 4 ticks, grey #8A8F94, broken line | 10 long | 60 + 90 | `hit_armour` clank | sparks instead of blood |
| Crit (loot affix) | 4 ticks, Legendary orange #FF8A1C | 12 long | 80 + 120 | `hit_crit` | only with crit gear |

Rules:

- One marker on screen at a time; a new hit restarts it and upgrades the tier, never downgrades inside its hold time.
- Shotguns: one marker per trigger pull, tier = best pellet result. Sound plays once, volume +1.5 dB per extra pellet that hit, capped at +4.5 dB.
- Hit sounds play from the player (2D), not from the zombie, so they always cut through. Pitch varies ±4% to avoid machine-gun repetition.
- Rate limit: hit sound at most every 45 ms (an LMG at 800 rpm still ticks every shot at 75 ms).
- Co-op: local player sees only their own markers. The marker shows on client hit prediction; if the server rejects the hit, nothing is undone (it is gone after 150 ms anyway). Kill X waits for server confirm (≤ 1 tick).

**Score pop.** Points earned show as a small text near the lower right of the crosshair (+10, +60 HS, +100 KILL), drifting up 18 px over 600 ms. Same font as the HUD (Atkinson Hyperlegible Mono), XP brass #E3CF9A. Same-target pops merge into one number instead of stacking.

**Damage numbers: off by default, on as an option.** Floating numbers fight the military-shooter feel and clutter a 24-zombie screen. Because loot and gear rolls matter, the setting offers Off / Crits only / All. When on: numbers in the world above the hit point, 14 px, white (gold for headshot, orange for crit), merged per target every 120 ms, max 12 on screen.

## Recoil, camera and screen motion

Recoil is split into three layers that stack, each with its own spring: aim recoil (moves where bullets go, the player pulls down), view kick (camera only, springs back) and viewmodel kick (the gun model only). Screen shake and FOV punch sit on top and never move the aim point.

### The layers

| Layer | Moves | Already in code | Feel target |
| --- | --- | --- | --- |
| Aim recoil | camera + bullet direction | `RecoilData.pattern`, `permanent_ratio` | learnable pattern, 80% springs back on its own (design doc); the prototype file has 65%, so set permanent\_ratio to 0.2 in P1 |
| View kick | camera only, not bullets | new: `FeelData.view_kick_*` | the "punch" you feel in the head, returns in 60–120 ms |
| Viewmodel kick | gun model: back, up, roll | `WeaponData.viewmodel_kick` 0.045 m (move to FeelData) | weight and size of the gun |
| Screen shake | camera, noise-based | new | explosions and big hits only |
| FOV punch | camera FOV | new | heavy shots and kills feel bigger |

### Starting numbers per weapon class

| Class | View kick pitch (°) | View kick return (ms) | Viewmodel back (m) | Viewmodel up (°) | Viewmodel roll (°, random ±) | FOV punch (°) | Fire shake |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Pistol | 0.6 | 70 | 0.030 | 4.0 | 1.5 | 0 | none |
| SMG | 0.35 | 60 | 0.020 | 1.8 | 1.2 | 0 | none |
| Assault rifle | 0.5 | 75 | 0.035 | 2.2 | 1.5 | 0 | none |
| LMG | 0.55 | 80 | 0.040 | 2.0 | 2.0 | 0 | 0.04 trauma per shot |
| Shotgun | 1.8 | 120 | 0.070 | 7.0 | 3.0 | +1.5 for 90 ms | 0.18 trauma |
| Marksman / sniper | 2.2 | 140 | 0.080 | 6.0 | 2.0 | +2.0 for 110 ms | 0.20 trauma |
| Launcher / Prototype heavy | 2.5 | 160 | 0.100 | 5.0 | 2.5 | +3.0 for 140 ms | 0.30 trauma |

ADS multiplies view kick by 0.6 and viewmodel kick by 0.45 (the gun is braced). Springs use stiffness 320 and damping 26 as the default (critically damped for a 70 ms return); FeelData can override.

### Screen shake

Trauma model: each event adds trauma (0 to 1); shake amount = trauma²; trauma decays 1.6 per second. Shake = rotation only (max 2.5° pitch/yaw, 1.5° roll at trauma 1), driven by smooth noise at 18 Hz. No position shake, it reads as cheap and makes aim feel off.

| Source | Trauma added | Notes |
| --- | --- | --- |
| Own heavy shot | per class table above | capped at 0.35 from firing alone |
| Explosion | 0.6 at 0 m, linear to 0 at 15 m | grenades, barrels, launcher |
| Player hit by melee | 0.25 | plus direction tilt, see Player damage |
| Brute / boss slam nearby | 0.45 at 0 m, 0 at 12 m |  |
| Round start | 0.15 | low rumble, sells the siren |
| Mystery crate / Reforger use | 0.1 |  |

Total trauma caps at 1.0. ADS halves all incoming trauma so sniping stays possible.

### FOV punch

FOV punch is added to the current FOV (hip or ADS), rises in 25 ms and eases back over the listed time. Kill punch: −0.8° (a tiny zoom-in) for 120 ms on a headshot kill only. Never more than ±4° total.

### Hitstop

Hitstop is local and visual only: the game simulation never pauses (it must work in co-op and on a server). For the hit duration, the killed zombie's animation and the player's viewmodel freeze, then resume.

| Event | Hitstop (ms) |
| --- | --- |
| Headshot kill | 25 |
| Shotgun or melee kill at < 4 m | 35 |
| Kill with sniper / marksman | 30 |
| Elite or boss kill | 80, plus 0.3 s slow-motion on the ragdoll only |
| Normal kills | 0 (too frequent; it would stutter) |

Hitstop never stacks: a new one replaces the old if longer. Hard cap 4 hitstops per second.

## Muzzle flash, tracers, impacts and gore

Effects are short, bright and pooled. Gore is stylized "Full" by default (blood, head pops, limb loss), with a setting to tone it down, because the experiment-gone-wrong setting earns it and the stylized look keeps it from being gross-out.

### Muzzle flash

- Mesh flash (3 random star cards, rotated per shot) + one OmniLight3D, no shadow.
- Visible 1 frame at 60 fps (16 ms), light fades over 40 ms. Light energy 2.5, range 4 m, colour #FFD9A0 (warm, contrasts the teal fluorescents).
- Max 4 muzzle lights alive across all players; extras get the mesh only.
- ADS: flash scale ×0.7 and pushed forward so it never covers the sight dot.
- Smoke puff after 6+ shots in a row, 0.8 s life, soft alpha, max 3 per gun.

### Tracers

Every 3rd round on rifles/LMGs, every round on Prototype guns, none on pistols and shotguns. Tracer = stretched quad, 0.03 m wide, 6 m long, speed 400 m/s, colour #FFE6B0 (Prototype guns use #8DFF3A). First-person tracers start 1.5 m ahead of the muzzle so they don't streak across the sight.

### Impacts per surface

Surface comes from a `surface` metadata tag on physics materials (fallback: concrete).

| Surface | Particles | Decal (life) | Sound tag |
| --- | --- | --- | --- |
| Concrete / tile | grey dust puff + 4 chips | bullet hole, 30 s | `impact_concrete` |
| Metal | 6 sparks (light, 30 ms) | dent, 30 s | `impact_metal` |
| Glass | 8 shards | crack, 60 s; panes break after 3 hits | `impact_glass` |
| Wood | splinters + light dust | hole, 30 s | `impact_wood` |
| Dirt / grass (outdoor maps) | dirt kick | none | `impact_dirt` |
| Water | splash column | none | `impact_water` |
| Flesh (zombie) | blood burst, see gore | wound decal on mesh | `impact_flesh` |
| Armoured zombie | sparks + grey chips | none | `impact_armour` |

Budgets: 64 world decals (oldest fades first), 40 active impact emitters, all from the Pool autoload. Impacts further than 60 m skip particles and play the decal only.

### Blood and gore

| Gore setting | Blood | Head pop | Limb loss | Floor decals |
| --- | --- | --- | --- | --- |
| Full (default) | dark red #5A0F0F with bio-green tint #8DFF3A at 15% on mutated types | yes, on headshot kill | yes, limb hit dealing > 60% of max health | 24 pooled blood pools, 45 s; each death lays a 1.6x pool and 2 small splats |
| Reduced | darker, half particles | no, head slumps | no | 8 pools, 20 s |
| Off | grey dust puff | no | no | none |

Gore rules: blood burst = 24 particles on Full (12 on Reduced), 0.4 s, gravity on. Head pop = 3 chunk meshes + mist, physics off after 1.5 s. Limb loss swaps the limb to a stump mesh and spawns the limb as a pooled rigid body (max 16 alive, despawn after 8 s). A zombie that loses a leg crawls (behaviour thread decides speed).

### Death and ragdoll

Kill impulse = damage × 0.02 N·s along the bullet direction, capped at 6 (shotgun at close range sends them back about 1 m). Ragdolls freeze after 3 s and fade after 12 s; max 16 active ragdolls, older bodies switch to a static pose.

Damage numbers: decided above under Hit markers (off by default).

## Player damage, low health and downed

The player always knows three things within 100 ms of being hit: that they were hit, from which side, and how close to death they are. Health thresholds are percentages, so they keep working when skills raise max health.

### Getting hit

| Feedback | Value |
| --- | --- |
| Direction indicator | red #C3201B arc around the crosshair, 70 px radius, 40° wide, points to the attacker; 0.9 s life; max 4 at once |
| Camera tilt | 2.5° roll away from the hit side, 0.8° pitch up, springs back in 180 ms |
| Shake | 0.25 trauma per melee hit, 0.1 per spit / ranged hit |
| Screen edge flash | red vignette pulse, 35% alpha peak, 220 ms |
| Aim flinch | none on bullets (aim is never moved by taking damage), 0.6° random camera nudge only |
| Sound | `player_hurt` grunt (max every 0.6 s) + `hit_taken` thump, low-passed by health |
| Controller | rumble 0.4 strength, 120 ms |

### Health states

| State | Health | Screen | Sound | Movement |
| --- | --- | --- | --- | --- |
| Healthy | > 70% | clean | normal | normal |
| Hurt | 40–70% | soft red vignette at edges, 15% alpha | none | normal |
| Critical | < 40% (matches the design doc's red vignette under 40 HP) | vignette 35% alpha pulsing with heartbeat (70 bpm), saturation down to 45%, slight chromatic edge (0.6 px) | heartbeat, world audio low-passed to 2.5 kHz, ringing on big hits | normal; sprint still allowed |
| Regen | no damage for 4 s | effects fade out over the regen time | heartbeat slows, low-pass opens | normal |

Critical never blurs the centre of the screen: the vignette mask is clear inside 45% of screen height.

### Downed and death

- Downed: camera drops 0.9 m over 300 ms with a 6° roll, screen to 20% saturation, red vignette 50%, revive timer ring in the HUD. Player keeps a pistol (design doc rules).
- Being revived: saturation and colour return over the revive time, ending in a short white flash (8% alpha, 150 ms) and a `revived` sting.
- Death / bleed-out: 0.6 s fade to black with the world sound dropping out, then the spectate camera. Loot is kept (design doc), so the death screen shows "Gear kept" and the run summary.

## Round transitions and big moments

Round end is a 10-second breath with a clear rhythm: relief, reward, dread. Every step is an event on the `Events` bus, so sound, HUD, lights and music react without knowing about each other.

### Round end to round start

| Time (s) | What happens | Event |
| --- | --- | --- |
| 0.0 | Last zombie dies: its kill gets 80 ms hitstop + `round_last_kill` sting; world audio ducks 6 dB for 1 s | `round_cleared` |
| 0.3 | Round number in the HUD flashes white then fades to grey; light hum returns |  |
| 1.0 | Round summary toast (kills, headshots, points, XP), lower centre, 3 s | `round_summary` |
| 2.0–8.0 | Quiet: ambient only, emergency lights steady, zombies' distant moans |  |
| 8.0 | Siren wind-up starts; lights flicker once | `round_warning` |
| 10.0 | New round number slams in: scale 1.6 to 1.0 in 180 ms, red #C3201B; 0.15 trauma rumble; music layer up | `round_started` |

The 10 s gap is a `WaveRules.intermission_seconds` value; the timeline above scales to it.

### Escalation by round

- Every 5th round: round number gets a red glow and a second siren layer.
- Round 10+: base fog density +10%, fluorescent flicker chance up, so the map feels more broken.
- Round 20+: heartbeat-style low pulse in the music at critical health starts earlier (at 40%).
- Special rounds (hound-style fast rounds, boss rounds): own colour and sting, defined in `WaveRules` per round type.

### Other big moments

| Moment | Feel |
| --- | --- |
| Level up | gold ring burst behind the XP bar, `level_up` sting, no screen effect (never during a fight) |
| Loot drop | beam in rarity colour, height by rarity; Legendary and Prototype add a 0.1 trauma thump and a sting audible map-wide |
| Power-up pickup | 0.4 s screen tint in power-up colour at 12% alpha, voice line, HUD icon timer |
| Wall buy / crate | gun raise animation 0.6 s with `weapon_get` sound, short FOV pull −1° |
| Reforger upgrade | 1.2 s machine sequence, Prototype green #8DFF3A glow on the gun, first shot after upgrade gets doubled FOV punch |

## Data: how it plugs into the weapon files

Add one new resource, `FeelData`, and point every `WeaponData` at a shared class file. A gun that needs to feel different gets its own copy; everything else inherits the class defaults. Global, non-weapon values go in one `FeedbackRules` resource loaded by the `Content` autoload.

### Files

```
content/feel/
  feedback_rules.tres      # markers, hitstop, shake caps, health states, round timeline
  class_pistol.tres        # FeelData per weapon class
  class_smg.tres
  class_rifle.tres
  class_lmg.tres
  class_shotgun.tres
  class_marksman.tres
  class_heavy.tres
systems/feel/
  feel_data.gd
  feedback_rules.gd
  camera_rig.gd            # owns springs, trauma, FOV punch
  hit_marker.gd            # HUD widget
  hitstop.gd
```

### FeelData (per weapon)

```gdscript
class_name FeelData
extends Resource

@export_group("View kick")
@export var view_kick_pitch: float = 0.5
@export var view_kick_yaw_random: float = 0.15
@export var view_kick_return_ms: float = 75.0
@export var spring_stiffness: float = 320.0
@export var spring_damping: float = 26.0

@export_group("Viewmodel")
@export var vm_kick_back: float = 0.035
@export var vm_kick_up_deg: float = 2.2
@export var vm_roll_random_deg: float = 1.5
@export var ads_view_kick_mult: float = 0.6
@export var ads_vm_kick_mult: float = 0.45

@export_group("Camera")
@export var fire_trauma: float = 0.0
@export var fov_punch_deg: float = 0.0
@export var fov_punch_ms: float = 0.0

@export_group("Muzzle and tracers")
@export var muzzle_flash_scene: PackedScene
@export var muzzle_light_energy: float = 2.5
@export var muzzle_flash_scale: float = 1.0
@export var tracer_every: int = 3
@export var tracer_color: Color = Color("#FFE6B0")

@export_group("Kills")
@export var kill_impulse_scale: float = 0.02
@export var kill_hitstop_ms: float = 0.0
@export var can_dismember: bool = true
```

### Changes to existing code

- `WeaponData` gets `@export var feel: FeelData` in the Recoil group. `viewmodel_kick` moves into `FeelData.vm_kick_back`; keep the old field one release with a validator warning, then delete it.
- `RecoilData` stays as is: it is aim recoil only. Feel never touches bullet direction.
- Upgraded (Reforger) guns point `feel` at the same class file unless they want a bigger punch.
- Loot affixes can change feel through the existing stat modifier system with keys like `feel.view_kick_pitch` (for example a "Steady" affix −15% kick).
- Content validator test: every `WeaponData` has a `feel`; all values within the ranges in the next section.

### FeedbackRules (global)

Holds the hit marker tiers table, score pop, damage number settings, the trauma table, hitstop table and caps, player damage and health-state values, gore budgets and the round timeline. Each table above maps 1:1 to an exported group in this resource, so tuning any number in this doc means editing one `.tres` field.

### Events used

`Events.enemy_hit(info: DamageInfo)`, `Events.enemy_killed(info)`, `Events.player_damaged(player, info)`, `Events.player_downed(player)`, `Events.round_cleared(round)`, `Events.round_warning(round)`, `Events.round_started(round)`, `Events.loot_dropped(item)`. `DamageInfo` gains `is_crit`, `pellet_index` and `surface` fields. Feel systems only listen; they never change game state, so they can be stripped from the dedicated server build.

## Settings, limits, performance and build order

### Player settings (Settings autoload)

| Setting | Range | Default |
| --- | --- | --- |
| Screen shake | 0–100% | 100% |
| View kick (camera only, not aim recoil) | 25–100% | 100% |
| FOV punch | on / off | on |
| Hitstop | on / off | on |
| Low-health effects (vignette, desaturation, blur) | 0–100% | 100% |
| Flash reduction (muzzle light, revive, power-up tint; Reduced = no more than 3 flashes per second) | Full / Reduced | Full |
| Gore | Full / Reduced / Off | Full |
| Damage numbers | Off / Crits only / All | Off |
| Hit marker colour | Default / Deuteranopia / Protanopia / Tritanopia / custom hex | Default |
| Hit marker size | 75–150% | 100% |
| Controller rumble | 0–100% | 70% |

**Gameplay recoil is never scaled by a setting.** Sliders only touch the cosmetic layers: view kick, viewmodel kick, screen shake (trauma), FOV punch, hitstop and the health-state effects. Aim recoil (RecoilData pattern and permanent\_ratio) and bullet spread stay the same for everyone, so turning shake to 0% changes how the gun looks, not how it shoots. In code, the camera rig keeps aim recoil and cosmetic offsets as separate values and applies the setting multiplier only to the cosmetic sum. A test checks that the bullet direction is identical with shake at 0% and 100%. Head bob and the other comfort sliders are defined in the [controls and accessibility doc](controls.md).

To match the accessibility doc, the single Screen shake slider is split into two: **shake from own gun** (fire trauma, view kick, FOV punch) and **shake from explosions and hits** (all other trauma and the hit tilt). The low-health slider also covers screen blood. Head bob, weapon bob and sway, sprint FOV kick and landing dip are cosmetic too and follow the same rule. Visual punch lives in FeelData rather than RecoilData, so RecoilData only ever holds where the bullets go.

### Validator ranges (content test fails outside these)

| Field | Min | Max |
| --- | --- | --- |
| view\_kick\_pitch (°) | 0 | 3.0 |
| view\_kick\_return\_ms | 40 | 250 |
| vm\_kick\_back (m) | 0 | 0.12 |
| fire\_trauma | 0 | 0.35 |
| fov\_punch\_deg | −4 | 4 |
| kill\_hitstop\_ms | 0 | 100 |
| tracer\_every | 0 (off) | 10 |

### Performance budget

All feel systems together: ≤ 0.4 ms CPU and ≤ 0.5 ms GPU per frame at 1440p with 24 zombies, measured in the test range stress scene. Everything is pooled (Pool autoload); no `instantiate()` during a fight. Budgets: 4 muzzle lights, 40 impact emitters, 64 decals, 24 blood pools, 16 ragdolls, 16 loose limbs. The dedicated server never loads any of it.

### Build order (inside P1 Gun feel)

1. `FeelData` + `FeedbackRules` resources, class files, validator test.
2. Camera rig: springs for view kick, trauma shake, FOV punch. Move `viewmodel_kick` over.
3. Hit marker widget with all tiers + hit sounds hooked to `Events.enemy_hit` / `enemy_killed`.
4. Muzzle flash, tracers, surface impacts with pooling.
5. Blood, head pop, ragdoll impulse (limb loss can wait to P3 if time runs short).
6. Hitstop and score pops.
7. Player damage: direction arcs, vignette, health states, downed camera.
8. Round transition timeline (lands in P2 Wave loop, since it needs the WaveDirector).
9. Settings menu entries for every slider above.

### How we know it feels right

- Test range has a "feel bench": 10 dummies at 5/15/30/60 m, a moving target, one armoured dummy, and a debug overlay showing the active FeelData values with live sliders (save back to `.tres` from the debug console).
- Play-test check per gun: 30-round mag dump at 15 m with ADS should keep 70% of hits on a man-sized target for an average player. If not, tune `RecoilData`, not feel.
- Record a 60 fps clip of each gun and compare frame by frame: marker on the hit frame, flash on the fire frame, nothing late.
- Ask after each play-test: "Which gun felt best, which felt weakest, and why?" Log answers on the production board.

Open question: the sound thread owns the actual hit and kill sounds; this doc only names the cues (`hit_body`, `kill_confirm` and so on) so both docs use the same names.
