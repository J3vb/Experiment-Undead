# Plan: Teammate animations in third person

Status: Building
Roadmap: F-41 / issue #128
Phase: P7
Size: L
Approved by: Codex plan review on PR #217 (2026-11-17), and the person (decision card, 2026-11-17, all 3 steps)

## Goal

In co-op, teammates move like people: they walk, run, crouch, crawl when
downed, hold their gun, kick when they fire and dip it when they reload. Today
a teammate is a T-ish body that slides around with its arms lowered and empty
hands. Serves "Co-op you can read at a glance" (docs/design/gear-visuals.md:
co-op teammates are the main way gear is seen, at 2 to 40 m) and is needed for
the P7 exit test (F-43, 4 players to round 20).

## Scope

In:

- Animation clips built in code in Blender and exported inside `player.glb`:
  idle, walk (forward, back, left, right), run, crouch idle, crouch walk,
  downed idle, downed crawl, and two upper-body clips: fire kick and reload.
  All standing clips hold a long gun at the ready.
- One `AnimationTree` on the player body, driven by synced state: ground speed
  and direction (worked out from the synced position), crouch, downed, held
  gun, reloading, and shots.
- Head and upper-spine pitch follow the synced look pitch on top of the clips.
- The teammate holds their current gun in the right hand (plain gun model,
  no arms, no inspect detail).
- The owner's own body (shadow only) uses the same tree, so the shadow walks.
- A headless state test per move state, and a look render the person checks.

Not in (non-goals, and where each one goes instead):

- Pistol, shotgun-pump or launcher specific holds: every gun uses the one long-gun
  hold. Per-class holds are a later polish issue if the play-test asks for it.
- Jump, fall and land clips: a later polish issue (F-43 play-test decides).
- Throwing, melee, revive-kneel and interact clips: come with frag grenades
  (F-24) and melee; revive uses the crouch pose for now.
- Zombies on the new clip pipeline: zombies keep `ZombieRig` procedural poses
  (docs/DECISIONS.md "Procedural animation"). Moving them is its own issue.
- Interpolation buffers or prediction for remote players: not without a new
  ADR (AGENTS.md Keep it simple 9).
- Town third-person camera and the owner seeing their own body: P9.
- Gear in first person: F-42.

Needs column: F-11 (v0.1 release) is not done. The person's week goal
(2026-11-17: co-op fully working) pulls this ahead. It touches no v0.1
gameplay system, only the player body, its sync and the gun data.

## Ready to build

```
### Ready to build
- Foundations touched: 1 Co-op authority (shaky in places, not made worse: everything here is
  owner-decided cosmetic state, sent the same way as position), 2 Content and ids (solid: one new
  WeaponData field, no id literals), 7 Game tick (solid), 9 Tests and CI (solid).
- Decision records: 0003 trusted client, 0004 one code path, 0008 code-built assets first,
  0002 content as resources. Goes against one: no.
- Co-op:
  - Who decides: the owning client (its own crouch, held gun, reload). Downed comes from the server's
    existing PlayerStateSync snapshot.
  - How a client triggers it: no request. The owner's values ride the existing PoseSync
    MultiplayerSynchronizer, like position and pitch today.
  - What other players see: the animated body and held gun of every teammate; shots already reach
    them through RemoteShots.
  - Works on a dedicated server with no local player: yes, the tree is switched off there (no screen).
- Data: one new field WeaponData.world_model (PackedScene, the gun .glb). Clip names are constants in
  BodyAnimator because the clips come from one script, not content. Code compares a specific id: no.
- Save: no.
- Events and UI: no new Events, no screens.
- Input through InputFrame, gameplay in _physics_process, randomness from the session RNG: yes; the
  animator is visual only and uses no randomness.
- Tests: content test for clips in player.glb and world_model on every gun; unit state test for
  BodyAnimator; two-peer test that a client's crouch, held gun and reload reach the other peer.
- Logging: Log.warn when a held gun has no world_model, or player.glb is missing a clip.
- Performance: no per-frame allocations; one AnimationTree per player (8 max).
- Out of scope: see Not in.
```

## Design references

- docs/design/gear-visuals.md "Same rig everywhere", the co-op teammate row
  (2 to 40 m, silhouette must read in fog) and "Teammates' guns skip the
  inspect detail mesh entirely".
- docs/design/game-feel.md "Downed and death": the downed player keeps a
  pistol (shown with the long-gun hold, see Not in).
- docs/design/game-design.md player movement numbers come from `player.gd`
  exports: walk 5.0 m/s, sprint 7.6 m/s, crouch x0.55, downed x0.2. Clip
  stride lengths are set so feet do not slide at those speeds (no new number).
- docs/DECISIONS.md GearRig entry ("With no idle clip, arms are lowered from
  the source A-pose ... no walking animation"): this plan replaces that part.
- docs/adr/0008-code-built-assets-first.md: clips are made by a Blender script.
- docs/MULTIPLAYER.md "Who owns what": own movement and look belong to the
  owning client and go through the synchronizer.

## Systems touched

| Folder or file | New / changed | What changes |
|---|---|---|
| tools/assets/player_clips.py | new | Keyframes the shared skeleton for each clip, as Blender actions |
| tools/assets/player_body_model.py | changed | Calls player_clips after binding, so `player.glb` carries the clips |
| tools/assets/character_checks.py | changed | Checks the clip list, lengths and that loops end where they start |
| assets/models/characters/player.glb | changed | Rebuilt with clips |
| systems/player/body_animator.gd | new | `BodyAnimator`: builds the AnimationTree, reads player state, sets its parameters |
| systems/player/aim_pitch.gd | new | `AimPitch` (`SkeletonModifier3D`): bends upper spine and head by the look pitch after the clips |
| systems/player/player.tscn | changed | BodyAnimator under Body; PoseSync gets three more properties (step 2, 3) |
| systems/player/player.gd | changed | Owner fills `held_weapon` and `is_reloading` each physics tick (step 3) |
| systems/gear/gear_rig.gd | changed | Arm lowering and head pitch removed (clips and AimPitch own them) |
| systems/ui/character_screen.gd | changed | Plays the `idle` clip so the preview is not in A-pose (step 2) |
| systems/net/player_state_sync.gd | changed | `_present()` stops overwriting `is_crouching` (step 2) |
| systems/weapons/weapon_data.gd | changed | New `world_model: PackedScene` |
| content/weapons/*.tres | changed | `world_model` set to each gun's .glb |
| systems/net/remote_shot_effects.gd | changed | One call to the animator's `fire()` when a shot packet arrives |
| core/build.gd | changed | `PROTOCOL_VERSION` +1 in steps 2 and 3 |

Autoloads, managers or base classes added: none. `AimPitch` extends Godot's
`SkeletonModifier3D` (a built-in made for "pose bones after the animation").

## Data

- `WeaponData.world_model: PackedScene`, default null. Read by BodyAnimator.
  Null = no gun shown and one `Log.warn`. All guns get it in step 3; Reforged
  copies point at the same .glb as their base.
- Synced Player properties (owner to all, PoseSync, replication mode on
  change, spawn = true so late joiners get them):
  - `is_crouching: bool` (exists; step 2 adds it to PoseSync)
  - `held_weapon: StringName`, default `&""` (new, step 3): content id of the
    gun in hand
  - `is_reloading: bool`, default false (new, step 3)
- Clip names (constants in BodyAnimator and player_clips.py, checked against
  each other by the content test): `idle`, `walk_fwd`, `walk_back`,
  `walk_left`, `walk_right`, `run`, `crouch_idle`, `crouch_walk`,
  `downed_idle`, `downed_crawl`, `fire`, `reload`.
- Save format change: none.
- Network: PoseSync config grows twice; each step bumps
  `Build.PROTOCOL_VERSION` so mixed builds are refused at hello.
- Content checks to add in `tests/content/`: every WeaponData has a
  `world_model` whose root has a `Muzzle` node; `player.glb` has every clip.

## Co-op behaviour

- Who owns the state: owning client for move, crouch, held gun, reload and
  look pitch. Server for downed and dead (existing snapshot).
- What clients send, what the server sends back: the owner's PoseSync sends
  position, yaw, pitch and the three new properties to all peers (the server
  relays like today). Shots already arrive through RemoteShots. Nothing new
  goes to the server for checking: all of it is cosmetic.
- What a client sees that the host sees too: the same animated teammates.
  Only the owner's own body is hidden (shadow only), as today.
- Late joiner: the synchronizer's spawn state carries crouch, held gun and
  reload; downed comes with the existing PlayerStateSync snapshot.
- Dedicated server: BodyAnimator sets the tree inactive and stops processing
  when `DisplayServer.get_name() == "headless"`; nothing is posed or drawn.

## Performance

Per frame with 4 players (8 max): one AnimationTree each over 22 bones, one
SkeletonModifier3D each, one BoneAttachment3D each. Speed comes from
`position` minus last position (two Vector3, no allocation). Parameters are
written as cached StringName paths. Budget: under 0.2 ms CPU for 8 players on
the soak machine; step 2 measures it with the existing `--print-fps` run.

## Steps

### Step 1: Clips in player.glb (pipeline proof + look check)

- Build: `tools/assets/player_clips.py` keyframes the shared `BONES` skeleton
  for all 12 clips as Blender actions (pose rotations given in body space and
  turned into bone space, like `ZombieRig._pose_part` does). The exporter
  writes each action as a glTF animation. `player_body_model.py` calls it.
  Rebuild `player.glb`. Add a render scene
  `tests/manual/teammate_clips.tscn` that plays each clip on the real body
  with gear and saves frames, and turn them into GIFs for the person.
- Files: tools/assets/player_clips.py (new), player_body_model.py,
  character_checks.py, assets/models/characters/player.glb,
  tests/manual/teammate_clips.gd/.tscn (new), tools/assets/tests/.
- Tests: `tests/content/test_character_models.gd` checks the imported
  player has an AnimationPlayer with all 12 clip names, loops on the 9 loop
  clips, and the vest still binds; `character_checks.py` fails a looping clip
  whose last key differs from its first; python test in tools/assets/tests.
  Fails without the step: no clips in the .glb.
- Done when: Assets CI and the look check are green, and the person picks
  "looks right" on the GIF decision card (or the fixes they ask for are in).

### Step 2: AnimationTree on the body, driven by movement, crouch and downed

- Build: `BodyAnimator` (new) under `Body`. It builds an `AnimationTree` in
  `_ready` with a state machine: `ground` (BlendSpace2D of idle, 4 walks and
  run, by local velocity), `crouch` (BlendSpace1D crouch_idle to crouch_walk),
  `downed` (BlendSpace1D downed_idle to downed_crawl). It measures velocity
  from position change in `_physics_process` (works for owner and remote
  alike), smooths it, and travels between states from `is_crouching` and
  `is_downed`. `AimPitch` (new) replaces GearRig's head pitch; GearRig's
  arm lowering is deleted. The character screen (`systems/ui/character_screen.gd`,
  which uses `player.glb` and GearRig without the Player scene) plays the
  `idle` clip on the model's AnimationPlayer instead, so it does not fall back
  to the A-pose. PoseSync adds `is_crouching`; protocol bump. Remove the
  second crouch writer: `PlayerStateSync._present()` sets
  `_player.is_crouching = _player.is_downed` on every snapshot, which would
  clear a teammate's synced crouch whenever their health or points change.
  The owner already crouches while downed (`Player._read_input`), so that line
  goes; the co-op thread is told before the PR. Headless: tree inactive.
- Files: systems/player/body_animator.gd (new), systems/player/aim_pitch.gd
  (new), systems/player/player.tscn, systems/gear/gear_rig.gd,
  systems/ui/character_screen.gd, systems/net/player_state_sync.gd,
  core/build.gd, docs/DECISIONS.md (GearRig line).
- Tests: `tests/unit/test_body_animator.gd`: for still, walk forward, walk
  back, strafe, sprint speed, crouch, crouch walk, downed and downed crawl,
  the tree's current state and blend position pick the right clip; headless
  leaves the tree inactive. `test_gear_rig.gd` updated (no arm lowering,
  pitch through AimPitch). `test_character_screen.gd`: the preview plays
  `idle`. Two-peer test: a client's `is_crouching` reaches the server's copy
  and a third peer, and stays true after a health or points snapshot arrives.
  Fails without the step: no BodyAnimator.
- Done when: CI and soak green; a two-instance run shows a teammate walking,
  running, crouching and crawling.

### Step 3: Held gun, fire kick and reload

- Build: `WeaponData.world_model` on every gun. Owner's `Player` writes
  `held_weapon` and `is_reloading` from `weapons.current` each physics tick
  (only assigns when changed). BodyAnimator attaches the gun's world model to
  `hand_R` with a BoneAttachment3D (swaps on change; when downed the held gun
  is the downed sidearm, so no special case), adds an upper-body
  OneShot for `fire` (filter: spine and arm bones) and a Blend2 for
  `reload`. `RemoteShotEffects` calls `fire()` on the player's animator.
  PoseSync adds `held_weapon` and `is_reloading`; protocol bump. Close out:
  roadmap row Done, DECISIONS entry, MULTIPLAYER "Who owns what" row.
- Files: systems/weapons/weapon_data.gd, content/weapons/*.tres,
  systems/player/player.gd, systems/player/player.tscn,
  systems/player/body_animator.gd, systems/net/remote_shot_effects.gd,
  core/build.gd, docs/ROADMAP.md, docs/DECISIONS.md, docs/MULTIPLAYER.md.
- Tests: content test (every gun has a `world_model` with a `Muzzle`);
  `test_body_animator.gd` adds held gun swap, fire one-shot fires, reload
  blend on/off; two-peer test that `held_weapon` and `is_reloading` reach
  the other peer and a shot packet fires the remote one-shot. Fails without
  the step: no world_model field.
- Done when: CI and soak green, look render of a teammate holding the AR-7
  and the Kestrel, finish-feature checklist done.

## Acceptance

- [ ] Every move state picks the right clip (unit test, step 2).
- [ ] A client's crouch, held gun and reload reach the other peers and a
      late joiner (two-peer tests, steps 2 and 3).
- [ ] A remote shot plays the fire kick (unit test, step 3).
- [ ] Dedicated server runs no animation (unit test, step 2).
- [ ] The person approves the clip GIFs (decision card, step 1).
- [ ] Soak rounds 1-10 stay PASS with no new warnings (CI, every step).
- [ ] Two-instance play-test shows walking, running, crouching, crawling,
      holding, firing and reloading teammates (play-test, F-43 or #191).

## Risks

- **Blender 5.3 glTF export of several actions.** Slotted actions may export
  only the active one. Checked while planning: one NLA track per action with
  `export_animation_mode="NLA_TRACKS"` exports every clip by name. Step 1
  still proves the Godot import.
- **Bone axes.** Each bone has its own local axes, so a "pitch forward" must
  be converted per bone. Step 1 uses the same body-space-to-bone conversion
  `ZombieRig` already uses and renders every clip before any game code.
- **Clips fighting GearRig/AimPitch.** Head pitch written in `_process`
  would be overwritten by the tree. `SkeletonModifier3D` runs after the
  animation by design; step 2 tests the head bone after a tree update.
- **Vest and implant attachments under animation.** The vest is skinned to
  the same skeleton, charm and implant use BoneAttachment3D, so they follow;
  step 1's render shows them moving with the body.
- **Feet sliding at odd speeds (ADS walk, Stride, gear speed).** The
  BlendSpace blends by real measured speed, and the tree's time scale follows
  speed / clip speed, so feet stay planted within a range.
- **Look quality of code-made clips.** The person judges GIFs in step 1,
  before any game code depends on them.

## Open decisions

- [x] Approve this plan, including step 3 (teammates hold their gun, which the issue did not list)? Approved, all 3 steps (the person, decision card, 2026-11-17).
