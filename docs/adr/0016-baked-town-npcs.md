# 0016. Town NPC bodies may use baked texture maps

- **Status:** superseded by [ADR 0017](0017-tripo-models.md) (the stall keepers are Tripo models since F-80 step 3, 2026-11-19)
- **Date:** 2026-11-18
- **Decided by:** the person (approved the Lantern Post vendors plan, PR #339)

## Context

ADR 0015 lets only the player body (`characters/player.glb`) carry baked maps.
The four Lantern Post stall keepers (F-76) are built on the same survivor body
pipeline and need the same cloth weave, knit, hair strands and skin detail. A
shader-only finish next to the baked player would make them look flat and
cheaper than the player standing in front of them.

## Decision

Town NPC bodies (`characters/npc_*.glb`) may carry the same three baked maps
(colour, normal, roughness) as the player body, built by
`tools/assets/town_npcs/build.py` from procedural Blender materials and stored
as JPEG inside the `.glb`. They share the player's builder
(`tools/assets/player_body/build.py`, which takes a look), the 22-bone
skeleton, the 16,000-triangle and four-material budget and the material names
`BodySkin`, `BodyHair`, `BodyCloth` and `BodyRubber`.

## Consequences

- The script stays the source; each `npc_*.glb` is bake output, never
  hand-edited. `build_models.py` builds the NPCs without maps for the checks
  and points to the bake script when writing into `assets/`.
- `gear_import.gd` already keeps materials that carry a colour map, so NPCs use
  Godot's standard material like the player.
- Each NPC `.glb` is about 3 MB (JPEG maps, no Git LFS); four of them add about
  12 MB. Maps can drop to 1024 px if repo size becomes a problem.
- A change to the player body builder can change the NPCs too; the player stays
  the default look and a test proves its build is unchanged.

## Links

`docs/plans/lantern-post-vendors.md`, ADR 0015, ADR 0008.
