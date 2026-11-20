# 0017. Models made in Tripo may go in assets/

- **Status:** accepted
- **Date:** 2026-11-19
- **Decided by:** the person ("Everything to Tripo" card 2026-11-18, "Stalls now, keep today's gate" card 2026-11-19)

## Context

ADR 0008 and AGENTS rule 8 say art is built in code up to v0.1. The F-78 trial
showed that Tripo (image to 3D) gets much closer to the concept art for props,
buildings and characters than our Blender scripts. The person moved vendors and
library props to Tripo (plan F-80), and the first Tripo models to land are three
Lantern Post market stalls.

## Decision

Models made in Tripo may go in `assets/models/` when they pass through
`tools/assets/tripo_intake.py` (and `tripo_rig.py` for characters): budget
decimation, one baked material with colour, normal and ORM maps, our origin,
facing and scale, and for characters our 22-bone skeleton and clips. The source
of truth is the source `.glb` from Tripo in the project files
(`tripo/sources/`) plus the intake settings in the plan or manifest, not a
Blender script. The game-ready `.glb` is intake output and is never edited by
hand.

## Consequences

- Each Tripo model gets a prop catalogue row with slots `Baked (Tripo)`; it does
  not use the shared map materials or `prop_import.gd` slots.
- Text, signs and logos are never taken from Tripo (its lettering is garbled):
  our own sign boards and labels go on top.
- Each model is about 3 MB (2048 px JPEG maps, no Git LFS).
- Models are made on the person's paid Tripo plan, which gives private models
  with commercial use. The Steam store page needs the AI-generated content
  disclosure.
- Code-built models stay where Tripo is weak (snap-together kit pieces) and for
  done features until a plan moves them. F-83
  ([halcyon-machines-fill.md](../plans/halcyon-machines-fill.md)) moves the
  Halcyon Labs Med Dispenser, Reforger, power switch and exfil hatch.
- The three v0.2 zombies (Glower, Stalker, Brute) are Tripo: `tripo_intake.py --kind zombie` puts them on our
  skeleton with one `ZombieBaked` material ([blackout-glowers](../plans/blackout-glowers.md) step 1).
- Input images may come from Tripo's own text to image (`tripo_make.py`, about
  5 credits each); the person approves them before any model is paid for.

## Links

`docs/plans/tripo-models.md` (F-80), `docs/design/reviews/tripo-trial/README.md`, ADR 0008.
