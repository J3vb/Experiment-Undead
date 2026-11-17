# 0014. Guns may use baked texture maps

- **Status:** accepted
- **Date:** 2026-11-17
- **Decided by:** the person (F-75, follow-up to F-72)

## Context

ADR 0008 builds every model with Blender scripts, and the gun finish shader
draws all wear from noise with no image textures. On a low-poly mesh that
cannot show what the weapon concept sheet shows: soft bevels, stippled grips,
engraved marks, dents and chipped paint.

## Decision

Guns may use three baked maps (albedo, normal, ORM) made by a bake script
from a high-detail source. The source is either the gun's Blender script
(a high-detail copy built during the bake, never shipped) or a detailed
`.glb` the person hands over, run through the intake script. The gun
triangle budget is 30,000.

## Consequences

- The script stays the source: maps and the low-poly `.glb` are bake output,
  never hand-edited. A handed-over `.glb` is the source for that gun and gets
  a `docs/CREDITS.md` line.
- Change a baked gun's script, then re-bake: CI checks the bake record.
- CI never bakes; it checks the committed output.
- Guns that are not baked keep the shader-only finish.
- Repo grows by about 10 to 14 MB per baked gun (no Git LFS); a CI cap holds
  each gun's maps under 16 MB.
- Other models (zombies, player, props) stay under ADR 0008 until a record
  says otherwise.

## Links

`docs/plans/baked-gun-textures.md`, ADR 0008, `docs/plans/guns-concept.md`.
