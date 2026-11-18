# 0015. The player body may use baked texture maps

- **Status:** accepted
- **Date:** 2026-11-18
- **Decided by:** the person (picked the textured survivor body trial for F-70 step 1)

## Context

ADR 0014 lets guns use baked maps and keeps every other model under ADR 0008
(shader-only finish). The F-70 survivor body needs cloth weave, wrinkles,
stitching, hair strands and skin detail that the shared gear shader cannot draw
on a 16,000-triangle mesh. The person compared a shader-only body with a baked
one and picked the baked one.

## Decision

The player body (`characters/player.glb`) may carry three baked maps (colour,
normal, roughness), built by `tools/assets/player_body/build.py` from
procedural Blender materials and stored as JPEG inside the `.glb`. The four
body materials (`BodySkin`, `BodyHair`, `BodyCloth`, `BodyRubber`) share one
set of maps. The character budget stays 16,000 triangles and four materials.

## Consequences

- The script stays the source; the `.glb` is bake output, never hand-edited.
  `build_models.py` builds the body without maps for checks and skips it when
  writing into `assets/` (it points to the bake script instead).
- `gear_import.gd` keeps materials that carry a colour map, so the body uses
  Godot's standard material, not the gear shader. Gear, zombies and props are
  unchanged.
- The `.glb` grows from under 1 MB to about 3 MB (JPEG maps, no Git LFS).
- First-person arms keep their own build until F-70 step 6.

## Links

`docs/plans/player-gear-concept.md`, ADR 0008, ADR 0014.
