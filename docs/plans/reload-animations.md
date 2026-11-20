# Plan: Real reload animations

Status: Done
Roadmap: F-85 (was F-83, a number three plans took the same day) / solo play-test 2026-11-19
Phase: P1
Size: M
Approved by: the person (decision card, 2026-11-19, all 4 steps)
Lore link: none: moves parts of guns that are already in the game (magazines, bolts, the BR-12 shells on its stock holder); no new thing for the world to explain

## Goal

Reloads look like reloads. Today the whole gun dips and the magazine slides
down and back up on its own while the left hand stays on the fore-end
(solo play-test 2026-11-19: "reload animations need to be actual reload
animation of changing mags"). After this, the left hand pulls the magazine
out, fetches a fresh one, seats it and, on an empty reload, works the
charging handle or bolt. The BR-12 loads shell by shell. Serves the "gun is
the star" pillar (docs/design/game-design.md#gunfeel-and-movement: "crisp reloads").

## Scope

In:

- A code-driven reload motion for every gun whose model has a `Magazine`
  node: the left hand leaves its grip, takes the magazine down and out of
  view (tactical) or lets it drop (empty), comes back with a magazine,
  pushes it home with a short slap, and returns to the grip. The gun rolls
  toward the camera while this happens. Empty reloads add a pull on
  `ChargingHandle` (VX-9, MR-28) or a slap on the bolt release beside `Bolt`
  (AR-17).
- The four starter guns are tuned and checked by eye. Other guns with a
  `Magazine` node get the same motion from their own node positions and are
  checked on one contact sheet.
- The left hand follows the motion through the existing arm IK
  (`PlayerArmPose`), which gets a weapon-space target for the support hand
  (position and turn), blended in and out.
- BR-12 shell-by-shell loading: one shell per cycle from below into the
  loading port, firing stays possible mid-reload (already true for
  per-round guns). From empty, the first cycle drops a shell into the
  ejection port and racks the pump.
- Separate generated sounds at the motion's moments: mag out, mag in, bolt
  or charging handle, shell in, pump rack
  (docs/design/game-design.md#audio: "separate sounds for the mag out, mag
  in and bolt or slide, timed to the reload animation").
- Before/after frames and short clips for the person's feel check.

Not in (non-goals, and where each one goes instead):

- Keyframed Blender reload clips for the first-person arms: the arms are an
  IK rig solved every frame, so a code motion on the same rig is less work
  and fits every gun. Keyframed clips stay a Stage B option
  (game-design.md#art) if the play-test asks for more.
- New finger shapes during the reload: the hand keeps its gun's grip morph.
  The cupped grip reads fine around a magazine at reload speed. Later polish
  issue if the look check asks for it.
- A dropped magazine that stays on the floor: the one `Magazine` node falls
  out of view and comes back as the fresh one. No spawned props.
- Third-person teammate reloads: keep the F-41 `reload` clip, already timed
  by the synced `reload_time`.
- Pistol slide-lock, belt-fed (Bastion, Halberd) and lever (Fieldhand)
  motions: guns without a `Magazine` node keep today's dip. Later issue per
  gun family.
- Reload timing changes for magazine guns: `reload_time` and
  `empty_reload_time` stay as they are; the motion stretches to fit.

## Ready to build

```
### Ready to build
- Foundations touched: 4 ids into data (solid: the motion finds parts by node name, no gun ids in code),
  7 game tick (solid: ammo stays in Weapon.tick, the motion is visual only in _process),
  9 tests and CI (solid). Nothing shaky.
- Decision records: 0002 content as resources, 0004 one code path, 0008 code-built assets first.
  Goes against one: no.
- Co-op:
  - Who decides: the owning client, as today (reload state and ammo live in the owner's Weapon).
  - How a client triggers it: no request; reloading is owner-local, ammo is not shared state.
  - What other players see: the existing third-person reload clip, driven by PoseSync reload_time.
    No change, no protocol bump.
  - Works on a dedicated server with no local player: yes, there is no viewmodel there.
- Data: BR-12 gets reload_per_round = true and per_round_time in content/weapons/brenner_trench.tres
  (and its Reforged copy). For per-round guns, empty_reload_time becomes "time of the first round from
  empty". Fieldhand's empty_reload_time is set to its per_round_time so it plays exactly as today.
  Code compares against a specific id: no.
- Save: no.
- Events and UI: no new Events, no screens. HUD reload hint unchanged.
- Input through InputFrame, gameplay in _physics_process, randomness from the session RNG: yes. The
  motion reads the weapon's existing reload timer; no randomness.
- Tests: unit tests for the motion curve (rest at start and end, magazine seated before ammo lands,
  hand on the magazine while it moves, empty extra phase), RoundReload first-cycle timing, content
  check that every gun with a Magazine node has a reachable mag well, generated-model check for the
  BR-12 LoadShell node.
- Logging: Log.warn reload_motion_unreachable when the IK cannot reach a motion target (hand stops
  short by more than 2 cm), once per gun.
- Performance: a handful of Vector3 lerps per frame for the one active weapon; no allocations.
- Lore link: none (existing gun parts).
- Out of scope: see Not in.
```

## Design references

- docs/design/game-design.md#gunfeel-and-movement item 5: two reload lengths, tactical and
  empty (empty has the extra bolt or slide motion); sprint cancels; ammo in
  the magazine is kept.
- docs/design/game-design.md#audio: separate mag out, mag in, bolt sounds
  timed to the animation.
- docs/design/gun-roster.md "Build order" row B: "Shell-by-shell reload (also
  fixes the Brenner)".
- BR-12 today: magazine 6, empty_reload_time 3.6 s. New numbers keep the full
  empty reload at 3.6 s: first shell from empty 1.1 s (port load and rack),
  then 5 x 0.5 s. Partial top-ups get faster (2 shells: 1.0 s instead of 2.6 s);
  that is the point of shell loading. Logged in docs/DECISIONS.md and the
  balance sheet change log.
- docs/adr/0008-code-built-assets-first.md: the shell part is built in the
  Blender script, not hand-edited.

## Systems touched

| Folder or file | New / changed | What changes |
|---|---|---|
| systems/weapons/reload_motion.gd | new | Pure function of (reload kind, t, part positions): left-hand target, magazine offset, bolt offset, gun roll, sound moments |
| systems/weapons/weapon_pose.gd | changed | Uses ReloadMotion for magazine, bolt and gun pose instead of the dip; plays the moment sounds |
| systems/weapons/round_reload.gd | changed | First cycle from empty lasts empty_reload_time; exposes cycle progress for the shell motion |
| systems/player/player_arm_pose.gd | changed | Left hand can take a weapon-space target transform with a blend weight |
| systems/player/player_arm_view.gd | changed | Feeds the reload hand target from the weapon's pose |
| tools/assets/shotgun_model.py | changed | Hidden `LoadShell` node (one shell, red and brass) for the hand to carry |
| tools/generate_sfx.py | changed | mag_out, mag_in, bolt_pull, shell_in, pump_rack sounds |
| content/weapons/brenner_trench*.tres, fieldhand_lever*.tres | changed | Per-round data as above |

Autoloads, managers or base classes added: none.

Files over 300 lines this plan grows: none (weapon.gd 276 is not grown; the
motion lives in its own file).

## Data

- `brenner_trench.tres` and `_reforged`: `reload_per_round = true`,
  `per_round_time = 0.5`, `empty_reload_time = 1.1` (Reforged keeps its own
  ratio to the base).
- `fieldhand_lever.tres` and `_reforged`: `empty_reload_time` = their
  `per_round_time`, so nothing changes in play.
- `WeaponData.empty_reload_time` doc comment says what it means for
  per-round guns.
- No new Resource types, fields, save fields or network messages.
- Save format change: none.
- Content checks: every gun with `reload_per_round` has
  `empty_reload_time >= per_round_time`; every viewmodel with a `Magazine`
  node has the hand's reach to it (IK reaches within 2 cm at the key poses).

## Co-op behaviour

- Who owns the state: the owning client (unchanged).
- What clients send, what the server sends back: nothing new.
- What a client sees that the host sees too: teammates see the F-41
  third-person reload clip, as today. Only the owner sees the first-person
  motion.
- Late joiner: nothing to receive.
- Dedicated server: no viewmodel, so no motion runs.

## Performance

One active viewmodel per local player. The motion is a few lerps and one
extra IK target per frame, no nodes created, no allocations. Budget: under
0.05 ms per frame, checked by the existing frame-time soak.

## Steps

### Step 1: Magazine reload motion

- Build: `ReloadMotion` with the tactical and empty timelines below (as
  fractions of the reload duration, so Serums and affixes that speed up
  reloads stay in step), hand target support in `PlayerArmPose` and
  `PlayerArmView`, `WeaponPose` driving magazine, bolt, charging handle and
  gun roll from it. Guns without `Magazine` keep the dip.
  - Tactical: 0-0.12 hand to magazine, 0.12-0.30 magazine out and down,
    0.30-0.45 out of view, 0.45-0.65 back with magazine under the well,
    0.65-0.75 push home, 0.75-0.80 slap, 0.80-1.0 back to grip.
  - Empty: the same squeezed into 0-0.72 (magazine drops instead of being
    carried), then 0.72-0.90 charging handle pull and release or bolt
    release slap, 0.90-1.0 back to grip.
- Files: systems/weapons/reload_motion.gd (new), weapon_pose.gd,
  systems/player/player_arm_pose.gd, player_arm_view.gd, docs/LOGGING.md.
- Tests: tests/unit/test_reload_motion.gd (rest at t=0 and t=1, magazine
  offset zero from 0.75 on so it is seated before ammo lands at 1.0, hand
  within 1 cm of the magazine while the magazine moves, empty adds the
  handle phase, no-magazine gun gets the dip); a content check that the arm
  IK reaches every key pose for the four starter guns.
- Done when: the AR-17, VX-9 and MR-28 change magazines with the hand in
  a headless render, CI green.

### Step 2: BR-12 shell by shell

- Build: `LoadShell` node in the shotgun model (hidden until the hand
  carries it), RoundReload first-cycle-from-empty timing, shell cycle motion
  (hand from pump to the stock shell holder, up to the loading port, push,
  back), empty first cycle into the ejection port plus pump rack. Data
  changes above.
- Files: tools/assets/shotgun_model.py, assets/models/weapons/brenner_trench.glb
  (regenerated), systems/weapons/round_reload.gd, reload_motion.gd,
  content/weapons/brenner_trench*.tres, fieldhand_lever*.tres,
  docs/DECISIONS.md, balance sheet change log.
- Tests: tests/unit/test_round_reload.gd (from empty with 6 shells: first
  round after 1.1 s, full at 3.6 s; top-up of 2 takes 1.0 s; firing mid-cycle
  keeps loaded shells; Fieldhand timing unchanged), content check for
  per-round data, generated-model check for `LoadShell`.
- Done when: the BR-12 loads shells one at a time in a render, CI green
  including soak.

### Step 3: Reload sounds on the motion

- Build: five generated sounds; `ReloadMotion` names the moments
  (mag out at 0.20, mag in at 0.72, slap at 0.78, handle at 0.80 and 0.86,
  shell in per cycle at 0.70, pump rack in the empty first cycle);
  `WeaponPose` plays each once as the reload passes it. The old single
  `reload.wav` stays for guns that keep the dip.
- Files: tools/generate_sfx.py, assets/audio/*.wav (generated),
  weapon_pose.gd, reload_motion.gd, docs/CREDITS.md if needed (generated:
  none).
- Tests: tests/unit/test_reload_motion.gd (each moment fires exactly once
  per reload, and not after a sprint cancel).
- Done when: sounds land on the hand's moves in a recorded clip, CI green.

### Step 4: Look check and close-out

- Build: before/after frames and clips of the four starter guns (tactical
  and empty, BR-12 from empty and top-up), one contact sheet of every other
  gun with a `Magazine` node at the "magazine out" and "push home" poses;
  fix any gun whose parts sit wrong; decision card to the person.
- Files: tools/ render script (reuse look_shot.gd / gun_lineup.gd),
  plan and roadmap status.
- Tests: none new beyond fixes.
- The feel check goes to the person as a decision card with the clips.
- Done when: the person signs off the feel, plan Done.

## Acceptance

- [x] Every starter gun's left hand pulls and seats a magazine (or loads
      shells) on reload, in a recorded clip. (Clip: `tools/reload_frames.tscn -- --clip`;
      tests `test_left_arm_reaches_every_key_pose_and_returns_to_its_grip`,
      `test_brenner_hand_carries_one_shell_into_the_port_per_round`.)
- [x] Empty reloads add the charging handle or bolt move; tactical do not.
      (`test_empty_reload_presses_the_bolt_catch_then_releases_the_bolt`; bolt catch, see DECISIONS.)
- [x] Ammo lands only after the magazine is seated (`test_magazine_seated_before_ammo_lands`).
- [x] Sprint cancel returns the hand to the grip without a pop
      (`test_sprint_cancel_eases_the_hand_back_to_its_grip`).
- [x] BR-12 full reload from empty still takes 3.6 s (`test_round_reload.gd`, first-round rack test).
- [x] The person signs off the feel from the before/after clips (decision card "Good, keep them", 2026-11-20).

## Risks

- The IK cannot reach under the magazine well on some guns without a bad
  elbow. Step 1 checks the four starter guns' key poses in a test before the
  look work; the gun roll toward the camera brings the well closer.
- Faster BR-12 top-ups change its balance. Kept the full empty time equal;
  the soak and the F-07 balance pass will show if it is too strong.
- Fieldhand's `empty_reload_time` meaning changes: step 2 sets it so its
  play stays identical and tests that.

## Open decisions

- none
