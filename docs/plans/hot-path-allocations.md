# Plan: Hot-path allocations (foundation fix 7)

Status: Review
Roadmap: F-00 foundation fix 7 / issues #139, #141, #142, #150, #151
Phase: P7
Size: S
Approved by:

## Goal

Shots, impacts and zombie steering stop creating new arrays, meshes,
materials and scenes every tick or every shot, so frame time stays flat when
8 players fire automatic guns into a crowd. Serves the "tight, modern
gunplay" pillar (steady frame rate) and code rule 6 (120-friendly hot paths)
before the 4-player play-test (#127).

## Scope

In:

- Zombie separation reads one live-zombie list owned by the `Spawner`
  instead of `get_nodes_in_group(&"enemies")` per zombie per tick (#139).
- `Impact`: shared meshes and materials made once, and a fixed ring of at
  most 48 impact nodes reused instead of new nodes, meshes, materials and a
  timer per pellet (#141).
- `RemoteShotEffects`: one tracer node with one `ImmediateMesh` and one
  material, rebuilt per shot and hidden by a countdown (#142).
- `Chain` arcs: one shared unit cylinder mesh and one shared material;
  segment length set by scale (#151).
- `GravityWell`: the scene is loaded once and kept (#150).

Not in (non-goals, and where each one goes instead):

- A `Pool` autoload or a general pooling helper. `docs/KEEP_IT_SIMPLE.md`
  says build it when a stress test shows spawn/free stutter; only impacts
  churn nodes often enough to need reuse, so the ring lives inside `Impact`
  (later: only if the v0.1 performance check F-09 / #108 shows a need).
- Pooling zombies (nav agents need careful reset; later, same trigger).
- A spatial grid for separation. 24 zombies = 576 distance checks, 48 = 2304,
  both cheap once nothing is allocated (later: only if the benchmark shows
  separation in the top costs).
- Chain arc nodes and the per-arc timer: a Synapse hit makes at most 3 arcs;
  sharing the mesh and material removes the expensive part.
- `Frost` coating (one material per frozen zombie, made once per zombie) and
  `LootDrop` material (one per drop, rare): not per shot or per tick (never,
  unless profiling says so).
- Real decals, new impact looks or more VFX (later: art pass after v0.1).

## Ready to build

```
### Ready to build
- Foundations touched (numbers from docs/FOUNDATIONS.md): 12 Performance (this plan fixes it), 1 Co-op authority (separation runs only on the server's zombies; no change).
  Any of them shaky or missing? 12 is shaky; this plan is its fix.
- Decision records that apply (docs/adr/): 0003 trusted-client co-op (server runs zombie AI). Does this go against one? no
- Co-op:
  - Who decides: server for separation (only server zombies steer); each peer for its own visuals.
  - How a client triggers it: unchanged. Impacts, remote tracers and arcs are already local or cosmetic RPCs.
  - What other players see, and how it reaches them: unchanged messages; same look.
  - Works on a dedicated server with no local player: yes (separation runs there; visuals are not created without a screen exactly as today).
- Data: where new ids and numbers live: no new ids or numbers; existing constants (MAX_ALIVE 48, lifetimes, colours) stay in their scripts.
  Code compares against a specific id anywhere: no
- Save: changes what is saved? no
  Renames or removes a saved id: no
- Events and UI: new Events: none. New screens: n.a.
- Input through InputFrame, gameplay in _physics_process, randomness from the session RNG: yes (separation stays in _physics_process; impact/tracer countdowns are visual-only _process)
- Tests: unit tests per step (test_spawner.gd, new test_impact.gd, test_remote_shots.gd, test_chain.gd, test_gravity_well.gd).
- Logging: none new; Impact already caps at 48, so nothing new to warn about.
- Performance: this plan is the preload/pool work.
- Out of scope (later phases, not built now): Pool autoload, zombie pooling, spatial grid, decals.
```

## Design references

- docs/FOUNDATIONS.md#12-performance-pooling-and-hot-paths: "shot, impact
  and effect visuals reuse resources (preloaded meshes and materials, a small
  pool where nodes are created often)".
- AGENTS.md code rule 6: no per-frame allocations in hot paths, no
  `get_node()` in loops, cache lookups.
- docs/DECISIONS.md "No Pool autoload yet. Impacts are capped at 48 and
  freed": the cap stays 48; this plan reuses them instead of freeing.
- docs/KEEP_IT_SIMPLE.md table row "Pool autoload": not built here.
- docs/adr/0003-trusted-client-co-op.md: server owns zombies.
- No balance numbers change. Look and feel stay as they are.

## Systems touched

| Folder or file | New / changed | What changes |
|---|---|---|
| systems/waves/spawner.gd | changed | New `zombies: Array[Zombie]` live list; `_create` adds each zombie and hands it the list; removed on `tree_exiting`. `alive_count()` reads the list |
| systems/enemies/zombie.gd | changed | New `neighbours: Array[Zombie]` (empty by default); `_separation()` loops it instead of the group |
| systems/effects/impact.gd | changed | Static shared `QuadMesh`/`StandardMaterial3D` (flesh particle, surface particle, mark); static ring of up to 48 `Impact` nodes, reused oldest-first; countdown in `_process` hides it instead of a timer + `queue_free` |
| systems/net/remote_shot_effects.gd | changed | One `Tracers` `MeshInstance3D` + `ImmediateMesh` made in `_ready`, shared static material; `_draw_tracers` clears and rebuilds; `_process` hides it after 0.06 s |
| systems/weapons/effects/chain.gd | changed | Static shared unit `CylinderMesh` and material; `_segment` scales y by length |
| systems/weapons/gravity_well.gd | changed | `static var _scene: PackedScene` filled on first use, used by `spawn_orb` and `open` |

Autoloads, managers or base classes added: none.

## Data

- No Resource types, `.tres`, save fields or network messages change.
- Save format change: none
- Content checks to add in `tests/content/`: none

## Co-op behaviour

- Who owns the state (server / owning client / each client): the live
  zombie list is per `Spawner`, so per session and per peer; only the
  server's zombies run `_separation()` (client copies run no AI, unchanged).
  In-process two-peer tests keep separate lists because each peer has its
  own `Spawner`. Impact ring, tracer node and arc meshes are per peer and
  visual only.
- What clients send, what the server sends back: unchanged.
- What a client sees that the host sees too: unchanged; same visuals.
- Late joiner: nothing new; zombies a late joiner receives are created through
  `Spawner._create` and join that peer's list.
- Dedicated server (no screen, no local player): separation runs; visuals
  are created only where they are today.

## Performance

Today with 24 zombies: 24 group arrays per tick for separation; each pellet
impact makes 2 meshes, 2 materials, 2 to 3 nodes and a timer; each remote
shot a mesh, material, node and timer; each Synapse hit up to 9 meshes and
materials. After: zero arrays per tick for separation and zero meshes or
materials per shot or hit. Impacts create at most 48 nodes per scene and
then only reposition them. Separation stays O(n²) (576 checks at 24, 2304 at
48) with no allocation. The CPU benchmark (`tools/benchmark/benchmark.gd`,
24 and 48 zombies) is run before and after step 1 and the numbers go in the
PR; it must not get worse.

## Steps

### Step 1: Zombie separation over the Spawner's list

- Build: `Spawner.zombies` live list (add in `_create`, erase on
  `tree_exiting`), `Zombie.neighbours` set to that same array, `_separation()`
  loops `neighbours` (skips self and dead). `alive_count()` counts the list.
- Files: systems/waves/spawner.gd, systems/enemies/zombie.gd,
  tests/unit/test_spawner.gd.
- Tests: spawned zombies appear in `Spawner.zombies` and leave it when
  freed; each zombie's `neighbours` is the spawner's list; two zombies 0.5 m
  apart push each other apart through `_separation()`; a zombie of another
  peer's spawner never pushes. Fails without the step (no `zombies` field,
  separation ignores a zombie that is not in the enemies group).
- Done when: no `get_nodes_in_group` in the separation path; benchmark
  numbers for 24 and 48 zombies in the PR, not worse than main.

### Step 2: Impact reuse

- Build: shared static meshes and materials; static ring of up to
  `MAX_ALIVE` impacts, the oldest reused once full (dropped from the ring if
  freed, for example on scene change); `_process` countdown hides the node
  (no timer, no `queue_free`); particles `restart()` on reuse.
- Files: systems/effects/impact.gd, tests/unit/test_impact.gd (new).
- Tests: 60 spawns leave at most 48 `Impact` nodes; the 49th spawn returns
  the first node moved to the new point; two impacts of the same kind share
  the same mesh and material; an impact hides after its lifetime. Fails
  without the step (60 spawns create 60 nodes before frees, meshes differ).
- Done when: no `.new()` mesh or material in `Impact.spawn` after the first
  use of each kind.

### Step 3: Remote tracers, chain arcs, gravity well scene, close-out

- Build: one reusable tracer node in `RemoteShotEffects`; shared unit
  cylinder and material in `Chain`; cached scene in `GravityWell`. Update
  docs/FOUNDATIONS.md (fix 7 done, section 12 solid), docs/DECISIONS.md
  ("No Pool autoload yet" line: impacts reused in a ring of 48), roadmap row,
  plan Status: Done.
- Files: systems/net/remote_shot_effects.gd, systems/weapons/effects/chain.gd,
  systems/weapons/gravity_well.gd, tests/unit/test_remote_shots.gd,
  tests/unit/test_chain.gd, tests/unit/test_gravity_well.gd, docs.
- Tests: two remote shots keep one `Tracers` child and it hides after
  0.06 s; two chain segments share one mesh and material, and segment scale
  matches its length; two `GravityWell` spawns use the same `PackedScene`.
  Each fails without the step.
- Done when: issues #139, #141, #142, #150, #151 closed by the step PRs.

## Acceptance

- [ ] Separation allocates no array per tick (test_spawner.gd, code check).
- [ ] Impacts, remote tracers and chain arcs create no mesh or material per
      shot after first use (test_impact.gd, test_remote_shots.gd, test_chain.gd).
- [ ] At most 48 impact nodes exist per scene (test_impact.gd).
- [ ] Gravity well scene loads once (test_gravity_well.gd).
- [ ] CPU benchmark at 24 and 48 zombies is not worse than before (step 1 PR).

## Risks

- Static state (impact ring, shared materials) leaking between tests or
  scenes: the ring drops freed nodes with `is_instance_valid`, and shared
  resources hold no per-scene state. Step 2 tests cover a freed parent.
- Sharing one array between Spawner and zombies: a zombie freed outside the
  Spawner must leave the list; `tree_exiting` handles every exit. Step 1
  tests free a zombie directly.
- Reused `CPUParticles3D` not re-emitting: `restart()` is the Godot call for
  one-shot particles; step 2 test checks `emitting` after reuse.

## Open decisions

- none
