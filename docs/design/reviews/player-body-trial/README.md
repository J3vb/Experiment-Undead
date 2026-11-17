# Player body trial (2026-11-17)

A second take on the survivor body from `docs/plans/player-gear-concept.md`, step 1,
built to compare with the shipped body. It is **not** used by the game: nothing in
`assets/models/` or the real body scripts changed.

![comparison](comparison.jpg)

Rows, top to bottom: the F-70 step 1 body from PR #314 (read from its branch at 45b669a, not changed),
the trial body, both in the run clip, the body on main, and the concept.

- Source: `tools/assets/body_trial/` (`build.py` builds and checks, `compare.py` renders this sheet).
- Output: `characters/player.glb` in this folder. Same 22 bones, facing, scale and clips as
  the shipped body, 15,824 triangles (budget 16,000), materials BodySkin, BodyHair, BodyCloth, BodyRubber.
- Checks run on it: `check_models.py --dir docs/design/reviews/player-body-trial` and the glTF validator, both pass.

## How it is built

Every part is a "tube": a few key rings (width, front depth, back depth, squareness) along a
straight axis, with a smooth curve through them. The face is the head tube plus small bumps and
dents (nose, brow, eye sockets, lips). Hair and beard are the same head surface pushed out where
hair grows and sunk under the skin where it does not. Pockets, knee pads and straps are pads that
follow the tube they sit on, so they never float or clip.

## Known weak spots

- Hair reads as a cap and the hair and beard edges are stair-stepped.
- One cloth colour for jacket and trousers (the 4-material limit); skin `#8F6A50` and hair
  `#1E1915` are picked by eye, they are not in look-rules.md yet.
- The torso is bulkier than the shipped body, so today's vests would clip (the plan restyles them in step 4).
- Not imported into Godot: the new material names need finishes in `gear_import.gd` first.
