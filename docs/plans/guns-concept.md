# Plan: The four starter guns to the concept art

Status: Review
Roadmap: F-72
Phase: P4 (v0.1 Vertical slice, look pass on built guns)
Size: M
Approved by:

## Goal

The four guns every map sells on its walls (rifle, Brenner, Kestrel, Talon)
look like the weapon concept sheet
([images/guns_concept.jpg](../design/images/guns_concept.jpg)): worn matte
black with tan and brass accents, Oriel Biotechnic marks, small Oriel red-dot
sights, yellow tape on the magazines, chipped paint and grime. These are the
guns players hold most, so they set the look of the whole game. Serves
"Guns feel great" and the Cold Containment look.

## Gaps: current models vs the concept

Current renders: `/mnt/project-files/gun-models/`, `gun-textures/`, and the
approved turnarounds in `docs/design/turnarounds/weapons/`.

| Gun (id) | Concept | Current model | Gap |
|---|---|---|---|
| All four | Worn black, heavy chipped edges, grime in corners, tan and brass accents | `gun_finish.gdshader`, light wear (PR #68), no grime | Heavier chipping, grime from the baked AO, a wear amount the import can set |
| All four | Oriel hex logo on the receiver side, small Oriel text on optics | No markings at all | A markings atlas (logo, tape, shell colours) on small UV quads |
| AR-17 (`rifle_ar`, "AR-7") | AR-style carbine: tan adjustable skeleton stock, tan grip, black quad-rail handguard, flat-top with Oriel red dot, flip front sight, birdcage flash hider, magazine with yellow tape | Angular receiver, solid tan stock, tan M-slot handguard, 1-4x scope with a `ScopeLens` | New stock, grip and handguard shapes; scope swapped for a red dot (open decision 2); tape on the mag |
| BR-12 (`brenner_trench`) | Black polymer pump gun: pistol-grip stock with a 4-shell side holder (red hulls, brass heads), tan stripe on the pump, top rail with red dot, magazine tube, no heat shield | Wood stock and wood pump, bare-metal receiver, perforated heat shield, bayonet lug, bead sight | Biggest change: polymer stock and pump, shell holder, red dot, black receiver; heat shield and bayonet lug go |
| VX-9 (`kestrel_smg`) | Compact SMG: skeleton folding stock with tan butt pad, red dot, vertical foregrip, flash hider, curved mag with tan and yellow tape | Olive fore-end, folding stock, flip-up aperture iron sights, straight mag | Red dot replaces the irons, vertical grip (left hand moves to it), curved mag, olive becomes black and tan |
| MR-28 (`talon_dmr`) | Precision AR-10: tan and black adjustable stock with yellow stripes, tan grip, long tan M-LOK handguard, large scope with big turrets, muzzle brake | Grey-green stock and handguard, scope, bipod | Closest already: tan instead of grey-green, new stock shape, bigger turrets; the folded `Bipod` stays (small, and tests name it) |

The concept's stat bars (damage, fire rate, accuracy, range, control) fit the
current data: shotgun high damage and low rate, SMG high rate, DMR high
damage and range. They guide a later stats panel (see Not in), not the models.

## Scope

In:

- The concept copy in `docs/design/images/guns_concept.jpg` (this plan's PR).
- Shared finish: heavier edge chips and grime in `gun_finish.gdshader`, and one
  generated markings atlas used by every rebuilt gun.
- A shared red-dot sight part in `gun_parts.py` and a reticle quad in the
  viewmodel scenes.
- New shapes for the four guns, in their existing scripts, keeping every node
  name and pivot that code and tests use.
- Updated grip poses where a hand moves (Kestrel left hand to the vertical
  grip, rifle and shotgun if the new shapes move the support hand).
- Re-approved turnarounds, a lineup render next to the concept, look-rules
  rule 6 updated for the tape and marks.
- Display names, only if open decision 1 picks a rename.

Not in (and where each goes):

- **Weapon stats panel** with the concept's five bars, shown on wall-buy
  prompts, the Vault and the inventory. Bars would be computed from
  `WeaponData` (damage per shot, `rounds_per_minute`, spread, `falloff_end`,
  recoil pattern) and scaled across the roster, never typed in by hand. New
  roadmap row F-73, plan needed (UI screen + ui-hud doc).
- The other 18 guns get the new finish and wear automatically (shared
  shader), but no markings, tape or reshaping: later, one batch per gun class
  if the person wants them matched too.
- Balance numbers: no change. `ads_fov`, recoil and damage stay as they are,
  except what open decision 2 needs for the rifle (F-07 owns balance).
- Third-person teammate clips: they hold the same `world_model`, so the new
  look reaches them for free; the clips are not re-posed.
- Real brand marks: never (look-rules rule 6). Oriel is our own company.

## Ready to build

```
### Ready to build
- Foundations touched: none of the code foundations; asset pipeline (model checks,
  turnarounds, gun finish import). All solid.
- Decision records that apply: none about guns. Does this go against one? no
- Co-op:
  - Who decides: nobody, visuals only. Same .glb on every peer.
  - How a client triggers it: n.a.
  - What other players see: the new world_model in teammates' hands and on wall racks.
  - Works on a dedicated server with no local player: yes (export strips visual resources;
    ScopeLens and reticle already bail out when their material is stripped)
- Data: no new ids or fields. Display names in content/weapons/*.tres only if decision 1 renames.
  Code compares against a specific id anywhere: no
- Save: changes what is saved? no (saves keep weapon ids, not names). Renames a saved id: no
- Events and UI: none. New screens: n.a.
- Input through InputFrame, gameplay in _physics_process, randomness from the session RNG: yes (no gameplay code)
- Tests: tests/content/test_generated_models.gd (node names, ADS lines, budgets),
  tools/assets/tests/test_gun_parts.py, check_models.py, turnarounds, a markings atlas test
- Logging: none (no runtime system)
- Performance: nothing per frame; see Performance
- Out of scope: stats panel (F-73), other 18 guns' shapes, balance
```

## Design references

- [images/guns_concept.jpg](../design/images/guns_concept.jpg): the look target.
- [look-rules.md](../design/look-rules.md) rule 6: matte black and gunmetal,
  one secondary colour, rarity only as a thin inlay strip and optic glass
  colour, no real brand marks. Step 1 adds: "yellow mag tape, brass and
  Oriel marks as small accents".
- [gun-roster.md](../design/gun-roster.md): names, and the open question
  "AR-7 vs Vanguard AR" (line 175).
- [lore.md](../design/lore.md): Oriel Biotechnic ran Project HALCYON; its kit
  is everywhere, so Oriel marks on the guns fit.
- `docs/design/balance/weapons.csv`: no number changes.
- Memory of earlier work: PR #65 (code-built guns), PR #68 (finish shader),
  PR #60 (turnarounds), PR #59 (model checks).

## Systems touched

| Folder or file | New / changed | What changes |
|---|---|---|
| `assets/materials/gun_finish.gdshader` | changed | Heavier edge chips, grime from AO, `wear` set per gun by the import |
| `tools/assets/gun_markings.py` | new | Pillow script that draws the markings atlas (Oriel logo, tape, shell red, brass) |
| `assets/textures/gun_markings.png` | new | Its 256 x 256 output (generated, never hand-edited) |
| `tools/assets/gun_finish_import.gd` | changed | `Markings` material: polymer finish with the atlas as albedo |
| `tools/assets/gun_parts.py` | changed | `red_dot()` builder and `marking()` UV quad helper |
| `tools/assets/rifle_model.py`, `shotgun_model.py`, `kestrel_model.py`, `talon_model.py` | changed | New shapes per the gaps table |
| `assets/models/weapons/*.glb` (the four) | changed | Rebuilt output |
| `systems/weapons/viewmodels/{rifle,shotgun,kestrel,talon}_viewmodel.tscn` | changed | Reticle quad on red-dot guns, aim offsets, `ScopeLens` removed from the rifle if decision 2 picks the red dot |
| `systems/weapons/viewmodels/reticle.tres` | new | Unshaded red dot material, shared |
| `content/grips/{kestrel_smg,rifle_ar,brenner_trench}.tres` | changed | Support-hand anchors |
| `docs/design/turnarounds/weapons/` | changed | Re-approved strips |
| `docs/design/look-rules.md` | changed | Rule 6 accents line |

Autoloads, managers or base classes added: none.

## Data

- No new Resource types or fields. `reticle.tres` is a plain
  `StandardMaterial3D` (unshaded, red #E0322B at emission 2.0, provisional).
- Display names change only if decision 1 says so; ids stay, so saves, loot
  dicts, maps and wall-buys keep working.
- Save format change: none.
- Content checks: `tests/content/test_generated_models.gd` gains red-dot and
  markings checks per step.

## Co-op behaviour

- Who owns the state: nobody; models and materials are local visuals.
- What clients send, what the server sends back: nothing new.
- What a client sees that the host sees too: the same models on teammates and
  wall racks.
- Late joiner: nothing extra.
- Dedicated server: the export strips meshes and materials; the reticle node
  is a `MeshInstance3D` with no script, so nothing runs.

## Performance

- Triangle budget stays 8,000 per weapon and 6 materials (`check_models.py`).
  Today: rifle 6,332, shotgun 4,740, Kestrel 4,836, Talon 7,452. The Talon is
  the tight one (548 triangles left): the bigger turrets are paid for by
  fewer handguard slot segments. The `test_gun_parts.py` detail floor of 4,000 stays.
- Materials per gun after the change: GunMetal, MatteBlack, Tan, OpticGlass,
  Markings = 5. The reticle lives in the viewmodel scene, not the glb.
- One shared 256 x 256 atlas for all four guns (one texture, about 256 KB of
  VRAM with mipmaps).
- Shader: two extra noise reads per pixel on viewmodel and held guns only.
- If decision 2 swaps the rifle scope for a red dot, the rifle no longer
  renders a second scope camera while aiming: cheaper.
- Budget: no measurable change at 24 zombies and 4 players; the next GPU
  agent run (F-09) covers it.

## Steps

Each step: build with the `blender-model` skill, import with
`godot-asset-import`, render with `look-check` next to the concept, approve
turnarounds, post the before/after in the thread.

### Step 1: Finish, markings and the red-dot part

- Build: heavier chips and grime in `gun_finish.gdshader` (`wear` default
  stays 1.0 for the other 18 guns at today's look; the four concept guns get
  a higher value through the import); `gun_markings.py` and its atlas;
  `Markings` in `FINISHES`; `gun_parts.red_dot()` (Oriel housing, OpticGlass
  window, `RedDot` node with a `ReticleMount` marker) and `gun_parts.marking()`;
  the shared `reticle.tres`. Put the red dot on the rifle first only if
  decision 2 says red dot, else on the Kestrel, so the risky part (ADS line
  through a red dot) is proven in this step. Update look-rules rule 6.
  Apply decision 1 (names) here if it renames.
- Files: as listed above, plus one viewmodel.
- Tests: `test_gun_parts.py` checks `red_dot()` makes a window, a
  `ReticleMount` and stays under 300 triangles; a Python test that the atlas
  script output matches the committed PNG; a GUT test that the ADS ray from
  the camera passes through the red-dot window and hits the reticle quad.
- Done when: one gun aims through a red dot in game; the finish render sits
  next to the concept.

### Step 2: AR-17 (rifle_ar)

- Build: new stock, tan grip, quad-rail handguard, flip front sight, flash
  hider, tape on the mag, Oriel logo; the optic per decision 2. Keep
  `Receiver`, `Magazine`, `Bolt`, `ChargingHandle`, `Muzzle` and pivots.
- Files: `rifle_model.py`, `rifle_ar.glb`, `rifle_viewmodel.tscn`,
  `content/grips/rifle_ar.tres`, turnaround.
- Tests: existing rifle tests stay green; new: red-dot ADS ray (or the scope
  test if the scope stays), triangle and material budget.
- Done when: turnaround approved, render next to the concept posted.

### Step 3: VX-9 (kestrel_smg)

- Build: red dot replaces `IronSights`, vertical foregrip, curved mag with
  tape, flash hider, black and tan instead of olive, logo. Left-hand anchor
  moves to the vertical grip; rerun the arm contact check
  (`tools/check_character_contacts.py`, needs bpy).
- Files: `kestrel_model.py`, `kestrel_smg.glb`, `kestrel_viewmodel.tscn`,
  `content/grips/kestrel_smg.tres`, turnaround.
- Tests: `test_kestrel_has_moving_parts_and_iron_sights` becomes a red-dot
  test; `test_kestrel_rear_sight_leaves_the_aiming_line_open` becomes the
  red-dot ADS ray test; contact check clean.
- Done when: turnaround approved, hand sits on the vertical grip in first
  person.

### Step 4: BR-12 (brenner_trench)

- Build: black polymer pistol-grip stock with a 4-shell side holder (shell
  colours from the atlas), polymer pump with a tan stripe, black receiver with
  top rail and red dot, magazine tube; drop the heat shield and bayonet lug.
  Keep `Pump` and `Muzzle`.
- Files: `shotgun_model.py`, `shotgun_brenner.glb`, `shotgun_viewmodel.tscn`,
  `content/grips/brenner_trench.tres`, turnaround.
- Tests: `test_brenner_heat_shield_stays_under_the_aiming_line` becomes the
  red-dot ADS ray test; pump test stays; budget.
- Done when: turnaround approved, render next to the concept posted.

### Step 5: MR-28 (talon_dmr) and close-out

- Build: tan and black adjustable stock with yellow stripes, tan grip, long
  tan handguard, bigger turrets, muzzle brake, logo; the folded `Bipod` node stays. Scope
  stays (`ScopeLens` Z rule from PR #65 kept). Then the four-gun lineup
  render next to the concept, `finish-feature` skill, roadmap row Done.
- Files: `talon_model.py`, `talon_dmr.glb`, `talon_viewmodel.tscn`,
  turnaround, `docs/ROADMAP.md`, `docs/DECISIONS.md`.
- Tests: `test_talon_has_rifle_parts_and_a_long_barrel` and
  `test_scope_display_sits_behind_the_rebuilt_eyepiece` stay green; budget
  under 8,000.
- Done when: lineup posted, the person has seen it.

## Acceptance

- [ ] The four guns' turnarounds are approved and a lineup render sits next
  to the concept.
- [ ] Every red-dot gun aims through its dot (GUT ray tests).
- [ ] Every gun is under 8,000 triangles and 6 materials (`check_models.py`).
- [ ] Hands sit on the guns: arm contact check clean.
- [ ] The person has looked at the lineup render.
- [ ] `quality`, `test` and `soak` green on every step.

## Risks

- **Red dot aiming feels off** (dot not centred, glass blocks the view): proven
  in step 1 on one gun with a ray test before the other guns copy it.
- **Talon over budget:** handguard slots drop to 6 segments and the scope
  tube loses lathe sides (24 to 16) before anything else.
- **Hand poses break** when shapes move: each step reruns the contact check,
  F-01 rules.
- **Heavier wear on the 18 other guns:** default `wear` stays at today's
  value, so only the four concept guns change.
- **Name change confusion:** ids never change, only display names.

## Open decisions

- [ ] Names: the concept says AR-17, BR-12, VX-9 and MR-28; the game says
  AR-7 Rifle, Brenner Trench, Kestrel SMG and Talon DMR, and the roster doc
  says Vanguard AR for the rifle. Recommended: keep the roster names and use
  the concept codes as model numbers (Vanguard AR-17, Brenner BR-12, Kestrel
  VX-9, Talon MR-28).
- [ ] Rifle optic: the concept rifle has a red dot, the game rifle has a 1-4x
  scope with a zoomed lens. Recommended: red dot, as in the concept; the
  Talon stays the scoped gun, so each wall gun aims differently.
