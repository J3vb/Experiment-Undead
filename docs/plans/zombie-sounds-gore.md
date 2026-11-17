# Plan: Zombie sounds and gore

Status: Approved
Roadmap: F-14
Phase: P4
Size: M
Approved by: Codex plan review on PR #241, 2026-11-17 (size M, no open decisions)

## Goal

Zombies sound and bleed like the design says: you hear them walk, attack and
die, every hit shows blood, kills leave a blood pool, and a headshot kill pops
the head. Serves the "tight gunplay" pillar (hit and kill confirms) and the
horror mood. Co-op players see and hear the same thing as the host.

## Scope

In:

- Generated zombie sounds (same approach as F-03/F-04: a numpy script in
  `tools/assets/`, shared helpers from `sfx_common.py`): Shambler death,
  Shambler dragging footsteps, Bloater gurgle idles, Bloater wet burst death,
  Bloater heavy wet footsteps, flesh hit, headshot bone crack.
- Voice caps from sound.md: 8 zombie vocals, 6 zombie footsteps, 4 impacts
  and gore. When full, the farthest (vocals, steps) or oldest (impacts) voice
  is stolen.
- Attack and death sounds also play on clients (today they only play where the
  AI runs, so clients hear no swings).
- Blood: flesh impacts with the design colours and counts, floor blood pools
  on kill (pooled decals), flesh hit sounds.
- Teammates' shots show impacts on every client (today only the shooter sees
  them).
- Head pop on headshot kill (3 chunks + mist), shown on every peer.
- Gore setting Full / Reduced / Off in Settings, default Full.

Not in (non-goals, and where each one goes instead):

- Limb loss, stump meshes and leg-loss Crawlers (later, with Crawler spawning:
  needs stump models and a behaviour change).
- Ragdolls and kill impulse (later: zombies keep the `fall_over` tween).
- Wound decals on the zombie mesh (later, asset pass after v0.1).
- Tells bus, Bloater inhale tell and low-health gurgle pitch (no Bloater burst
  in v0.1, enemy-ai.md; F-28/F-29/F-30 add tells with their types).
- Horde loop, occlusion rays, a full SoundManager, reverb zones (later, when
  more than 24 zombies or 8 players need it; F-09 measures first).
- Stalker, Brute, Crawler sound sets (with F-29, F-30 and limb loss).
- Plank tear sound on clients (stays host-only; separate small fix if the
  co-op play-test #191 asks for it).

## Ready to build

```
### Ready to build
- Foundations touched: 7 (hot-path allocations, done: Impact ring pattern is the model);
  Any of them shaky or missing? no
- Decision records that apply: 0003 trusted-client co-op, 0004 one code path, 0007 signals
  and events, 0008 code-built assets first. Does this go against one? no
- Co-op:
  - Who decides: server (kills, headshot kills); every peer shows effects locally.
  - How a client triggers it: it does not; clients react to synced Zombie.state,
    a new synced head_popped bool, and the shot relay RemoteShots already sends
    (which gains the shooter's hit points and hit kinds in step 3).
  - What other players see, and how it reaches them: death, attack, steps from
    Zombie.state (ZombieSync, already synced); head pop from head_popped (ZombieSync);
    teammates' impacts from new hit lists in the RemoteShots.shot relay (step 3).
  - Works on a dedicated server with no local player: yes, effects are skipped
    when DisplayServer is headless.
- Data: sounds as EnemyData fields in content/enemies/*.tres; gore and voice numbers
  are fixed rules from game-feel.md / sound.md, kept as constants (Keep it simple 10).
  Code compares against a specific id anywhere: no
- Save: changes what is saved? no (settings.cfg gets one key with a default; not a save)
- Events and UI: no new Events. Settings row goes through the existing settings screen.
- Input through InputFrame, gameplay in _physics_process, randomness from the session RNG:
  yes; all of this is cosmetic, so it uses randf() with `# cosmetic`.
- Tests: tests/unit/test_zombie_voice.gd, test_impact.gd, test_blood_pool.gd,
  test_remote_shots.gd, test_head_pop.gd, test_zombie_sync.gd, test_settings.gd,
  tests/content enemy checks.
- Logging: Log.warn when a voice is refused because every voice in its cap is closer
  (first time per match only).
- Performance: everything pooled in static rings (Impact pattern); nothing created per hit.
- Out of scope: see Not in.
```

## Design references

- docs/design/sound.md "Zombie sounds and danger tells" (table rows Shambler,
  Bloater: death, footsteps, idle) and "Hit reactions".
- docs/design/sound.md "3D attenuation": zombie vocals inverse, unit_size 3,
  25 m; zombie footsteps inverse square, unit_size 2, 15 m; impacts inverse,
  unit_size 2, 20 m.
- docs/design/sound.md "Voice limits and performance": vocals 8, footsteps 6
  (nearest), impacts and gore 4 (steal oldest).
- docs/design/game-feel.md "Blood and gore": colours #5A0F0F and #8DFF3A at
  15 %, burst 12 particles 0.4 s gravity on, head pop 3 chunks + mist, physics
  off after 1.5 s, pools Full 24 / 45 s, Reduced 8 / 20 s half particles no
  head pop, Off grey dust no pools.
- docs/design/game-feel.md settings table: Gore Full / Reduced / Off, default Full.
- docs/DECISIONS.md "No Pool autoload yet": rings live inside the class.

## Systems touched

| Folder or file | New / changed | What changes |
|---|---|---|
| tools/assets/zombie_sfx.py | new | Generates the zombie and gore sounds |
| assets/audio/ | changed | New .wav files + .import sidecars |
| systems/enemies/enemy_data.gd | changed | `death_sounds`, `footstep_sounds` |
| systems/enemies/zombie_voice.gd | changed | Feet player, vocal and step caps, death/attack from state |
| systems/enemies/zombie_rig.gd | changed | `stepped` signal when a foot lands |
| systems/enemies/zombie.gd | changed | Plays state sounds and gore from `_process` on every peer; sets `head_popped` |
| systems/effects/impact.gd | changed | Design blood colours/counts, flesh sounds (ring of 4), gore setting |
| systems/effects/blood_pool.gd | new | Pooled floor decal ring |
| systems/effects/head_pop.gd | new | Pooled head pop ring (chunks + mist) |
| systems/weapons/weapon.gd | changed | Records each real hit (point, flesh) for the relay, not only the tracer end |
| systems/net/zombie_sync.gd | changed | One synced property `head_popped` (agreed with the co-op thread) |
| systems/net/remote_shots.gd | changed | `shot`/`play_shot` carry hit points + hit kinds, validated by the server |
| systems/net/remote_shot_effects.gd | changed | Spawns impacts at the relayed hit points |
| core/settings.gd | changed | `video.gore` default 2 (Full) |
| systems/ui/settings_screen.* | changed | Gore option row |
| content/enemies/*.tres | changed | New sound fields filled |

Autoloads, managers or base classes added: none.

## Data

- `EnemyData.death_sounds: Array[AudioStream] = []` and
  `EnemyData.footstep_sounds: Array[AudioStream] = []`, read by ZombieVoice.
  Walker and Bloater .tres get their own sets; Bloater's `groan_sounds` move to
  the new gurgle files.
- `Zombie.head_popped: bool = false`, set by the server in `_on_died` when
  `info.is_headshot()`, synced by ZombieSync.
- Settings `video.gore: int` 0 Off, 1 Reduced, 2 Full, default 2.
- Save format change: none.
- Network messages: no new RPCs. Step 3 adds two arguments to
  `RemoteShots.shot` and `play_shot`: `hits: PackedVector3Array` (each real
  hit of the shot, every pierced target, never a miss) and
  `kinds: PackedByteArray` (the `Impact.Kind` value: 0 surface, 1 flesh,
  2 head, decided by the shooter at trace time, so lethal hits keep their kind
  even though the zones are disabled after).
  The server drops a shot whose arrays differ in size, hold a non-finite point,
  or exceed pellets x 4 entries. Step 4 adds one property to ZombieSync's synced
  list. Both steps bump Build.PROTOCOL_VERSION (take the next free number when
  rebasing; the co-op thread also bumps it).
- Content checks to add in `tests/content/`: every EnemyData has at least one
  death sound and one footstep sound.

## Co-op behaviour

- Who owns the state: server owns death and headshot kill; each client shows
  sounds and gore locally.
- What clients send, what the server sends back: the shooter's shot message
  gains its hit list (step 3) and the server relays it as it relays tracers
  today. The server already syncs `state`; step 4 adds `head_popped`.
- What a client sees that the host sees too: steps, groans, attacks, deaths,
  death pools, head pops, and impacts from every player's shots. Only the owner
  hears its own hit marker (unchanged).
- Late joiner: zombies arrive with synced state; a corpse already DEAD shows
  its pose without a sound or pool (the trigger only fires on a seen change
  away from a live state).
- Dedicated server: skips all sound and gore nodes when DisplayServer is
  headless; it still sets and syncs `head_popped`.

## Performance

With 24 zombies and 4 players: at most 8 vocal + 6 step + 4 gore 3D voices
playing; 48 impacts (existing ring), 24 decals, 8 head pops (3 chunks each),
all reused. Per frame: one float phase check per zombie for steps, one state
compare per zombie. Voice stealing scans a fixed array of at most 8 entries,
no allocations. Budget: within game-feel.md's 0.4 ms CPU / 0.5 ms GPU for all
feel systems; F-09 measures it.

## Steps

### Step 1: Zombie sound set and voice caps

- Build: `tools/assets/zombie_sfx.py` (Shambler death x3, Shambler drag steps
  x4, Bloater gurgle x3, Bloater burst death x2, Bloater wet steps x4). New
  EnemyData fields, filled in both .tres. ZombieRig emits `stepped` when the
  walk phase crosses a foot plant. ZombieVoice gets a `Feet` player and two
  static caps (8 vocals, 6 steps; steal the farthest from the camera if the new
  one is closer, else refuse). Zombie `_process` watches state changes on every
  peer: entering ATTACKING plays the attack sound, entering DEAD plays a death
  sound (replaces the AI-side `voice.say(attack_sound)` in `_tick_chasing`).
  Attenuation from sound.md.
- Files: tools/assets/zombie_sfx.py, assets/audio/zombie_*.wav(+.import),
  systems/enemies/{enemy_data,zombie_voice,zombie_rig,zombie}.gd,
  content/enemies/*.tres, docs/CREDITS.md or asset log line as F-03 did.
- Tests: test_zombie_voice.gd (cap of 8 holds with 12 callers; a closer zombie
  steals the farthest; steps above 15 m are refused), test_zombie_rig.gd
  (`stepped` fires twice per walk cycle), a state-change test that DEAD plays a
  death sound once and a late-joined DEAD zombie plays none; content check for
  the new fields.
- Done when: you can hear zombies walk and die in solo and on a client.

### Step 2: Blood bursts, floor pools and hit sounds

- Build: `Weapon.traced` changes from `hit_flesh: bool` to
  `kind: Impact.Kind`, and `Impact.Kind` gains `HEAD`. `Weapon._hit` picks the
  kind at trace time from the HitZone (`zone == DamageInfo.Zone.HEAD` gives
  HEAD), so lethal hits keep their kind. Impact flesh uses #5A0F0F, 12
  particles, 0.4 s, gravity (bio-green tint at 15 % is not used yet: no mutated
  types in v0.1). FLESH and HEAD hits show blood; FLESH plays
  `impact_flesh` (x4) or `hit_head` crack (x2) from a static ring of 4
  AudioStreamPlayer3D (steal oldest). New `BloodPool` ring of 24 (a flat lit quad: Decals do not draw in the
  Compatibility renderer),
  fades out over the last 5 s of 45 s; one pool under each zombie when it is
  seen dying (same state watch as step 1, so clients get pools too). Renders
  of the look go to the person (taste check below).
- Files: zombie_sfx.py (flesh, crack), systems/effects/{impact,blood_pool}.gd,
  systems/enemies/zombie_rig.gd (`fall_over`), systems/weapons/weapon.gd.
- Tests: test_impact.gd (flesh audio ring never exceeds 4, reuses oldest; HEAD
  plays a crack and FLESH an impact_flesh), a weapon trace test (a head hit
  emits HEAD, a body hit FLESH, a lethal head hit still HEAD),
  test_blood_pool.gd (ring of 24, 25th reuses the oldest, hidden after 45 s),
  a client-path test (a zombie copy whose synced state turns DEAD places one pool).
- Done when: your own hits bleed and every player sees kills leave pools.

### Step 3: Teammates' impacts

- Build: `Weapon._trace` reports every entry of `Pierce.trace` to
  `RemoteShots.record_hit(point, kind)` (misses report nothing; the tracer
  end point stays as it is). `RemoteShots.shot` / `play_shot` / `_relay` /
  `_show` carry `hits` and `kinds`; the server validates them (see Data).
  `RemoteShotEffects.play` spawns one Impact per hit with the relayed kind,
  normal = the reverse shot direction (good enough for a puff and a mark).
  Bump Build.PROTOCOL_VERSION. Keeps the teammate-animation thread's
  `body.fire()` line in `play()`.
- Files: systems/weapons/weapon.gd, systems/net/remote_shots.gd,
  systems/net/remote_shot_effects.gd, core/build.gd.
- Tests: test_remote_shots.gd: a miss relays no impact; a piercing shot
  through two zombies relays two flesh hits; a lethal head hit (zones disabled
  after death) still relays as HEAD; a kind byte above 2 is dropped; mismatched array sizes and too many entries
  are dropped by the server.
- Done when: a client sees blood and dust where teammates' bullets land.

### Step 4: Head pop and the gore setting

- Build: Server sets `head_popped` on a headshot kill; ZombieSync syncs it;
  bump Build.PROTOCOL_VERSION. The head is part of the one skinned `Body`
  mesh (and its face details are in `AnatomyDetails`), so `ZombieRig.head`
  (the `HeadCenter` marker) cannot be hidden. Instead `ZombieRig.pop_head()`
  sets the `head` bone's pose scale to 0.01: every vertex skinned to the head
  bone, including the face details, collapses into the neck top, which reads
  as a stump. No model change. The missing head is persistent and the effect
  is one-shot: whenever a zombie copy is DEAD with `head_popped` and this
  peer's gore setting is Full (including a late joiner's first sync of an
  existing corpse) it calls `pop_head()`; on Reduced or Off the head stays and
  slumps (the existing `pose_dead`). The setting is read when the corpse first
  shows dead; corpses last only a few seconds, so a live change applies to the
  next deaths and existing corpses are not restored; only
  a seen change from a live state to DEAD also plays a `HeadPop` from a ring of 8
  (3 chunk RigidBody3D + mist particles at the head marker, freeze after
  1.5 s, hide after 10 s). Settings `video.gore` with a row in the settings
  screen; Impact, BloodPool and HeadPop read it (Reduced: half particles,
  darker, 8 pools / 20 s, no head pop; Off: grey dust, no pools, no head pop).
- Files: systems/effects/head_pop.gd, systems/enemies/{zombie,zombie_rig}.gd,
  systems/net/zombie_sync.gd, core/settings.gd, core/build.gd,
  systems/ui/settings_screen.{gd,tscn}, systems/effects/{impact,blood_pool}.gd.
- Tests: test_head_pop.gd (ring of 8, chunks frozen after 1.5 s),
  test_zombie_rig.gd (`pop_head()` leaves the head bone's global scale under
  0.05 for both Shambler and Bloater models), test_zombie_sync.gd
  (`head_popped` is in SYNCED and a client copy pops the head; a late-joined
  copy that is already DEAD with `head_popped` collapses the head but plays no
  HeadPop or sound),
  test_settings.gd (gore default 2, clamps 0-2), gore Off spawns no pool,
  a `head_popped` corpse on Reduced and on Off keeps its head bone at scale 1.
  Visual check (look-check skill): a headless render before and after
  `pop_head()` shows no head or face left; the render goes in the PR.
- Done when: headshot kills pop heads for every player; the setting changes it live.

## Acceptance

- [ ] Every zombie type has death and footstep sounds (content test).
- [ ] No more than 8 zombie vocals, 6 steps, 4 gore sounds at once (unit tests).
- [ ] A client hears attacks and deaths and sees pools and head pops (unit tests on
      the client path + co-op play-test #191).
- [ ] Reduced and Off never decapitate a corpse (unit test).
- [ ] Teammates' hits show impacts on every client, with the head crack on
      headshots (unit test).
- [ ] Gore setting Off shows no blood (unit test).
- [ ] Soak rounds 1-10 still pass.

## Risks

- Generated sounds may read as cheap. Same risk F-03/F-04 accepted; asset packs
  replace them after v0.1 without code changes (data fields).
- The step trigger from the rig's procedural phase may drift from the visible
  foot plant. Step 1 tests it first, and the phase is the same value the pose uses.
- Gore look is a taste call: step 2 renders it and asks the person before step 4.
- Collapsing the head bone might leave a neck spike if neck vertices carry
  head weight. Step 4's render check catches it; the fallback is a stump cap
  mesh on the head attachment, still no model change.

## Open decisions

- none

The gore strength is a look check on renders after step 2, sent to the person
as a decision card; the design doc's Full numbers are the starting point.
