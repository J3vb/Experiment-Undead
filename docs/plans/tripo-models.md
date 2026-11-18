# Plan: Props and vendors made in Tripo

Status: Review
Roadmap: F-80 (changes how F-76 vendors and F-77 props are made)
Phase: P5 (art)
Size: L
Approved by:
Lore link: no new content. The vendors and props are the ones already in docs/design/lore.md (the stall keepers) and docs/plans/prop-library.md; only how they are made changes.

## Goal

The person picked "Everything to Tripo" after the F-78 trial (decision card,
2026-11-18): vendors and library props are made in Tripo (image to 3D) and
put through our intake, not built in Blender scripts. Threads make the models
themselves through the Tripo API, so the person only approves images and
boards. Pillar: the look matches the concept art.

## Scope

In:

- ADR 0016: models made in Tripo are allowed in `assets/` (an exception to
  AGENTS rule 8 "built in code up to v0.1" and to ADR 0008 for these two
  features). Source of truth = the manifest row (prompt, image, Tripo task
  id, intake settings) plus the source `.glb` in the project files, not a
  Blender script. One `docs/CREDITS.md` line for Tripo (paid plan, commercial
  rights), and the Steam AI-content disclosure noted in the ADR.
- `tools/assets/tripo_make.py`: calls the Tripo REST API with
  `TRIPO_API_KEY` (image to model; characters also rig with the Mixamo
  preset), waits for the task, downloads the `.glb`, then runs
  `tripo_intake.py`. Works from a manifest so each asset is one row.
- Manifests `tools/assets/tripo/<family>.json`: one row per model (name,
  folder, kind, image prompt, image file, height or length, yaw, Tripo task
  id once made).
- Image prompts per asset: `docs/design/tripo-prompts.md` (style line plus
  one row per model).
- Intake gains `--length` (scale so the longest side matches, for snapping
  pieces like track, guard rail and fence) and `--folder` (write straight to
  `assets/models/<folder>/`).
- F-76 and F-77 plans changed to build from manifests (see Steps).

Not in (non-goals, and where each one goes instead):

- Halcyon Labs kit, doors, machines, guns, player body and zombies: they stay
  code-built (done features; a later plan can move them).
- Shared map materials on Tripo props (`prop_import.gd` slots): Tripo props
  keep their own baked material; snow or clean comes from the prompt.
- Animation in Tripo: our clips stay (they play on Tripo bodies, F-78).
- Buying credits or the plan, adding the API key: the person.

## Ready to build

```
### Ready to build
- Foundations touched: none (asset tools and asset files only).
- Decision records that apply: ADR 0008 (asset stages) and AGENTS rule 8:
  ADR 0016 in step 1 records the exception before any Tripo model lands.
  ADR 0015 (baked maps) covers the map set.
- Co-op: n.a. (models only; vendors stay local-only per F-76).
- Data: budgets from check_models.py / character_checks.py (props 2,000 /
  4, props_large 12,000 / 6, characters 16,000 / 4). No ids in code.
  Code compares against a specific id anywhere: no
- Save: no
- Events and UI: none
- Input through InputFrame, gameplay in _physics_process, session RNG: n.a.
- Tests: tools/assets/tests/test_tripo_make.py (API calls faked), existing
  test_tripo_intake.py, check_models / character_checks / validator in Assets CI.
- Logging: n.a. (offline tool prints a summary).
- Performance: same budgets as code-built; each Tripo prop adds 3 textures
  (about 3 MB video memory at 1024), watched in each map's perf capture.
- Out of scope: placing props in maps (each map's own F-row).
```

## Design references

- docs/design/reviews/tripo-trial/README.md (trial report, what works and not)
- docs/design/lore.md#the-stall-keepers
- docs/design/look-rules.md (palette, value bands, bio-green rule)
- docs/plans/prop-library.md (family list, sizes, folders)
- docs/plans/lantern-post-vendors.md (vendor steps, clips, Vendor node)

## Systems touched

| Folder or file | New / changed | What changes |
|---|---|---|
| docs/adr/0016-tripo-models.md | new | Tripo exception, source of truth, licence |
| tools/assets/tripo_make.py | new | API client + manifest runner |
| tools/assets/tripo/*.json | new | One manifest per family |
| tools/assets/tripo_intake.py | changed | `--length`, `--folder` |
| tools/assets/tests/test_tripo_make.py | new | Faked API tests |
| docs/design/tripo-prompts.md | new | Image prompts per asset |
| docs/plans/lantern-post-vendors.md, prop-library.md | changed | Build from manifests |
| docs/CREDITS.md | changed | One Tripo line |

Autoloads, managers or base classes added: none.

## Data

Manifest rows (JSON, tools only). Source `.glb` and images in
`/mnt/project-files/tripo/sources/<family>/`, not committed (size). The
game-ready `.glb` and its maps are committed in `assets/models/` like any
model.

- Save format change: none
- Content checks to add in `tests/content/`: none

## Co-op behaviour

- Who owns the state: not networked (models only).
- What clients send, what the server sends back: nothing.
- What a client sees that the host sees too: the same models.
- Late joiner: n.a.
- Dedicated server: loads the same `.glb` files, no change.

## Performance

Same budgets as code-built models. Watch draw calls: one material per Tripo
prop, so a family of 10 props is up to 10 draw calls where code-built props
shared slots. Each map's perf capture decides on atlases or LODs if needed.

## Steps

### Step 1: ADR, API tool and prompts

- Build: ADR 0016, CREDITS line, `tripo_make.py` (image to model, rig for
  characters, wait, download, intake), intake `--length` / `--folder`,
  `docs/design/tripo-prompts.md`, the vendor and family 2 manifests.
- Tests: `test_tripo_make.py` with a faked HTTP session: request body for a
  prop and a rigged character, polling until success, download to the
  sources folder, failed task stops with the Tripo message, missing key stops
  with a clear message. `--length` test in `test_tripo_intake.py`.
- Done when: CI green; with the key and `api.tripo3d.ai` allowed, one test
  prop goes end to end in the cloud.

### Step 2: Vendors (changes F-76 steps 1-2)

- Build: Odile (F-78 output) becomes `npc_quartermaster.glb`; Teun Maes,
  Dr. Lien Corvelyn and Lieutenant Raes from their prompts, image approved
  by the person first, then `tripo_make.py`. Line-up render of all four.
  F-76 steps 3-5 (clips, Vendor node, close-out) stay as planned.
- Tests: character checks on the four files (22 bones, budget, Eyes).
- Done when: line-up approved by the person.

### Step 3: Prop families (changes F-77 steps 2-9)

- Build: per F-77 step, the family manifest instead of
  `library_<family>.py`; image sheet first (one image per model, the person
  approves or asks for redos), then models, catalogue rows and lineup board
  as F-77 already says. Barriers from #349 are replaced when family 1 runs.
- Tests: as F-77 step 2 (catalogue rows, budgets, load test).
- Done when: each family board approved (one thread per family).

## Acceptance

- [ ] ADR 0016 and the CREDITS line merged before the first Tripo model.
- [ ] `tripo_make.py` makes a model end to end from a manifest row.
- [ ] Four vendors from Tripo pass character checks and play our clips.
- [ ] Every F-77 family is built from a manifest, boards approved.

## Risks

- Licence: commercial use needs the paid plan; API terms must be checked by
  the person before step 1 merges (ADR records what they confirm).
- Cost: credits per model (about 165 for a rigged character, props fewer);
  retries for bad generations double it. Manifests keep the task id so a good
  model is never paid for twice.
- AI lettering and baked snow (trial report): prompts ask for no text and
  clean surfaces; signs and marks are added as our own decals.
- Network: the cloud environment must allow `api.tripo3d.ai` and the model
  download host; until then the person can run `tripo_make.py` locally.

## Open decisions

- The person confirms the Tripo API licence covers commercial use, adds
  `TRIPO_API_KEY` and allows `api.tripo3d.ai` in the cloud environment.
