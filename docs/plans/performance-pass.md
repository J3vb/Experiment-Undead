# Plan: Performance pass

Status: Review
Roadmap: F-91
Phase: P7
Size: M
Approved by:
Lore link: none: pure tech work, nothing new the player sees or reads (the upscaler setting already exists)

## Goal

Hold the frame-rate target in the busiest real case, not just the solo test:
120 fps average at 1440p High on an RTX 4080 Super with 24 zombies, and
still above 90 fps with the 8-player co-op cap of 66 zombies. Measure first,
fix only what the numbers show, and keep a check so new content cannot
quietly undo it. Serves the "tight, modern gunplay" pillar (steady frames).

## Scope

In:

- One repeatable fps run on a real GPU (`tools/benchmark/`), so every number
  in this plan comes from the same spots, presets and zombie counts.
- A baseline on the person's PC after tonight's release (solo 24 zombies and
  the 66-zombie co-op cap with 8 flashlights on), then fixes for the top
  measured costs only.
- The headless CPU benchmark at 66 zombies in CI as a report line, so CPU
  regressions show up on every PR.
- Upscaler: FSR 2 now, DLSS later (the person's pick). Keep FSR 2 (already in
  Settings > Graphics), tune its default per preset, no engine fork.

Not in (and where each goes):

- DLSS Super Resolution: not built into Godot 4.7.2; today only engine forks
  offer it (Windows only). Later: a new row when a DLSS add-on works on
  stock Godot, or a new ADR if the person picks a fork.
- DLSS 5: an RTX 50-only neural lighting filter that costs 50-60% fps, not an
  upscaler. Never for this pass.
- Prediction, lag compensation, network bandwidth: ADR 0003, separate work.
- Lower-end PC targets (60 fps mid-range 1080p Medium): measured by the same
  tool if the person has such a PC; fixes only if this pass finds a cheap one.

## Ready to build

- Foundations touched: 7 (hot-path allocations, done), logging/HealthWatch (done). None shaky.
- Decision records: 0003 trusted client (no prediction added), 0004 one code
  path (benchmark runs the real GameSession), 0008 code-built assets
  (merging meshes happens in the builder scripts, never by hand). Goes against one: no.
- Co-op:
  - Who decides: no new shared state. Zombie AI frame-skip runs on the server
    only, where AI already runs.
  - How a client triggers it: n.a.
  - What other players see: same as today; positions still sync every tick.
  - Dedicated server: yes, the CPU fixes help it most; GPU fixes are skipped there.
- Data: no new content types. The benchmark spots live in the benchmark script
  (a tool, not game content). Code compares against a specific id: no.
- Save: no.
- Events and UI: none new. Upscaler row already exists in `content/settings/graphics_upscaler.tres`.
- Input through InputFrame, gameplay in `_physics_process`, session RNG: yes (benchmark seeds `GameSession.rng`).
- Tests: `tests/unit/test_benchmark.gd`, `tools/benchmark/test_benchmark.py`, a test per fix (see steps).
- Logging: `perf.low_fps`, `perf.long_frames`, `perf.health` already exist; step 1 adds draw calls per spot to the benchmark JSON.
- Performance: the point of the plan.
- Lore link: none (tech).
- Out of scope: as listed above.

## Design references

- Architecture targets (memory of the 2026-11-14 decision, AGENTS.md code rule 6):
  120 fps at 1440p High with 24 zombies; stress case above 90 fps.
- `content/waves/default_waves.tres`: `max_alive = 24`, `max_alive_per_extra_player = 6`
  (8 players = 66 zombies).
- `docs/DECISIONS.md`: "Zombie AI tiers: only the re-path interval is tiered.
  Fix when: the performance pass adds frame-skip and off-screen checks." This
  plan is that pass.
- `docs/DECISIONS.md` lightmaps line: Halcyon Labs 197-439 avg fps at 1440p High,
  24 zombies (F-68). Lantern Post 302-468 fps, 2,639 draw calls on the street.
- Earlier GPU check: Mess Hall and Main Corridor have about 4x the draw calls
  of the Containment ramp.
- `core/graphics.gd`: presets, `Upscaler { OFF, FSR1, FSR2 }`, render scale.

## Systems touched

| Folder or file | New / changed | What changes |
|---|---|---|
| tools/benchmark/gpu_benchmark.gd, .tscn | new | Windowed fps run: fixed spots, presets, zombie count, flashlights |
| tools/benchmark/benchmark_run.gd | changed | `--players N` for the 66-zombie case |
| .github/workflows (quality or soak job) | changed | Run the CPU benchmark at 66 zombies, print its table in the job summary |
| systems/enemies/zombie.gd | changed (step 4, only if measured) | Far, unseen zombies think every 2nd or 3rd tick |
| tools/levels/ builder, levels/halcyon_labs/ | changed (step 3, only if measured) | Fewer draw calls in Mess Hall and Main Corridor |
| core/graphics.gd | changed (step 5) | Upscaler default per the decision |

Autoloads, managers or base classes added: none.

Files over 300 lines this plan grows: `systems/enemies/zombie.gd` if step 4
runs; split by job first in that step if it would pass 350.

## Data

- No new Resource types, fields or saves.
- Benchmark writes `user://benchmark/<date>_<preset>.json` (tool output, not committed).
- Save format change: none.
- Content checks to add: none.

## Co-op behaviour

- Who owns the state: nothing new. AI frame-skip is server-side, where zombie AI runs.
- What clients send / server sends: unchanged. Zombie positions still sync every tick, so a skipped think tick is invisible to clients.
- What a client sees that the host sees too: unchanged.
- Late joiner: nothing new.
- Dedicated server: GPU steps do nothing there; CPU steps (AI skip, CPU benchmark) are aimed at it.

## Performance

This plan only removes cost. Budget per fix: no new per-frame allocations,
and the CPU benchmark at 66 zombies may not get slower than the step-2 baseline.

## Steps

No step merges before tonight's release. Steps 3 to 5 only build what the
step-2 numbers ask for; a step whose cost is already inside budget is
dropped with one line in the close-out.

### Step 1: one fps run for every measurement

- Build: `tools/benchmark/gpu_benchmark.tscn` (a scene, so autoloads load) runs the
  real `game_session.tscn` with seed 1, power on and all doors open, then for each
  preset Low to Ultra holds the camera 10 s at 5 spots (Mess Hall, Main Corridor
  west, Containment ramp, Loading Dock, plus the Lantern Post street from the hub scene) and prints avg fps,
  1% low, draw calls and primitives per spot. Options: `--zombies N`,
  `--flashlights N` (extra player flashlights with shadows at the spawn points),
  `--presets High` to limit the run. Writes the same table as JSON.
  `benchmark_run.gd` gets `--players N` to spawn the co-op zombie cap.
- Files: tools/benchmark/gpu_benchmark.gd/.tscn (new), tools/benchmark/benchmark_run.gd, tools/benchmark/test_benchmark.py, tests/unit/test_benchmark.gd
- Tests: argument parsing and the 1% low maths on a fixed frame list (fail
  without the step); headless smoke run of one spot for 1 s exits 0 with valid JSON.
- Done when: CI green; the person's PC runs it from one paste-ready prompt.

### Step 2: baseline on the person's PC (no PR, a prompt)

- Build: nothing. The person's local agent measures the release build (the
  first run uses the throwaway script in
  `/mnt/project-files/performance-pass/baseline-fps-prompt.md`, so it can run
  tonight before step 1 merges; later runs use step 1's tool): High at 24 zombies, High at 66 zombies with 8 flashlights, and all
  presets at 24 zombies. Results go into this plan's Baseline section in the
  step-3 PR, plus `docs/DECISIONS.md` if a target is missed.
- Done when: a table of preset, spot, avg fps, 1% low, draw calls is posted in the thread.

### Step 3: draw calls in the busiest rooms (only if a spot misses 120 avg or 1% low under 60 on High)

- Build: in the Halcyon Labs builder, share materials between repeated props and
  set `visibility_range_end` on small clutter, then re-check draw calls. MultiMesh
  only if one prop repeats 20 or more times in a room.
- Files: tools/levels/ builder scripts, levels/halcyon_labs/ generated scene
- Tests: a level test that the Mess Hall and Main Corridor mesh-instance counts
  stay under the new numbers (fails on the old scene).
- Done when: the benchmark shows the spot at or above target; look-check renders match.

### Step 4: zombie AI frame-skip (only if 66 zombies costs over 4 ms of physics on the CPU benchmark)

- Build: zombies far from every player and out of every player's view think
  (path, target pick) every 2nd tick past 20 m, every 3rd past 40 m. Movement
  still runs every tick. Removes the DECISIONS "AI tiers" line.
- Files: systems/enemies/zombie.gd, docs/DECISIONS.md
- Tests: tests/unit zombie test: a zombie at 45 m unseen skips 2 of 3 think
  ticks; one in view or within 20 m never skips (fails without the step).
- Done when: CPU benchmark at 66 zombies under the step-2 number by a clear margin; soak green.

### Step 5: upscaler defaults

- Build (the person picked FSR 2 now, DLSS later): Low and Medium presets turn on FSR 2 at 77% render
  scale; High and Ultra stay native. The Settings hint names what FSR 2 does.
- Files: core/graphics.gd, content/settings/graphics_upscaler.tres, tests/unit/test_graphics.gd
- Tests: applying the Low preset sets FSR 2 and 0.77 scale; High leaves both off (fails without the step).
- Done when: benchmark Low and Medium faster than before at equal or better look in a look-check render.

### Step 6: guard against regressions and close out

- Build: the CI job runs the headless CPU benchmark at 24 and 66 zombies and
  prints both lines in the job summary (report only, CI runners are too noisy
  for a hard gate). Roadmap row to Done, `finish-feature` close-out.
- Files: .github/workflows/*.yml, tools/ci/, docs/ROADMAP.md
- Tests: tools/ci test that the summary writer formats the benchmark JSON.
- Done when: the numbers show on a PR's job summary.

## Acceptance

- [ ] 1440p High, 24 zombies: every benchmark spot at 120 fps avg or more, 1% low 60 or more (person's PC, recorded).
- [ ] 1440p High, 66 zombies, 8 flashlights: every spot at 90 fps avg or more (recorded).
- [ ] Each lower preset at least as fast as the one above it.
- [ ] CPU benchmark at 66 zombies shown on every PR's job summary.
- [ ] Soak green after each step.

## Risks

- The machine numbers move between runs (shader compiles, background apps): the
  tool runs a warm-up pass and the prompt keeps the better of two runs.
- Halcyon Labs may already be inside budget at 66 zombies: then steps 3 and 4
  are dropped, which is a fine outcome.
- Merging meshes can break lightmap UVs: step 3 re-uses the builder and the
  existing bake test, and asks the person for a re-bake only if meshes change.

## Open decisions

- [x] Upscaler: FSR 2 now, DLSS later (the person's pick on a decision card, 2026-11-21). DLSS gets a new roadmap row once a DLSS add-on works on stock Godot.
- [x] 66-zombie target of 90 fps avg: provisional pick, taken from the stress target (48 zombies above 90 fps) in the architecture decisions; the person can change it after the baseline.
