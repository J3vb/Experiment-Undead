# Tripo model trial (F-78), 2026-11-18

Plan: [docs/plans/tripo-trial.md](../../../plans/tripo-trial.md). One Tripo prop
(Oriel shipping crate) and one Tripo vendor (Odile Brandt) went through
`tools/assets/tripo_intake.py`. The output models are in the project files
(`tripo/output/`), not in the repo: they are trial models, about 4 MB each.

## Result

Both models pass our model checks and the glTF validator, import into
Godot 4.7.2 with their textures, and Odile plays every existing player clip
on our 22-bone skeleton. Both are much closer to the concept art than the
code-built versions.

| | Source from Tripo | After the intake | Checks |
|---|---|---|---|
| Oriel crate | 1,841,919 tris, 3 maps | 1,919 tris (props budget 2,000), albedo / normal / ORM at 1024 | check_geometry, check_origin, validator: pass |
| Odile Brandt | 18,418 tris, Mixamo rig (52 bones), T-pose | 15,358 tris (budget 16,000), our 22 bones, Tripo's own skin weights, 12 clips, maps at 2048 | check_geometry, character_checks, validator: pass |

- [crate_comparison.jpg](crate_comparison.jpg): source, our output, today's code-built `crate_large`.
- [odile_comparison.jpg](odile_comparison.jpg): code-built Quartermaster, Tripo + intake with clips, in Godot.
- [godot_forward_plus.jpg](godot_forward_plus.jpg): player body and Odile (idle, walk, reload) with the crate in Godot, imported as-is.

## What works

- **Look.** Wood grain, stencils, rust, snow, a real face, glasses, a fringed
  shawl. Code-built props and NPCs cannot get near this.
- **Budget.** A 1.8 million triangle crate comes down to 1,919 with almost no
  visible loss: the bake carries the detail into the normal map.
- **Rigging.** Tripo's Humanoid rig with the Mixamo preset maps one to one onto
  our skeleton. The intake swings the T-pose arms down to our A-pose with
  Tripo's own skin, then keeps that skin (fingers go to the hand, the three
  spine bones to ours). The long coat moves much better with Tripo's weights
  than with our segment weights.
- **Clips.** Every clip made for the player plays on her, because the rest pose
  and bone names match. Vendor clips (F-76) built the same way would play too.
- **Speed.** About 1 minute of machine time per model in the intake. Person
  time: making the image and running Tripo, a few minutes per model.

## What does not (yet)

- **Fake lettering.** AI text is half right: "ORIEL" reads, the side says
  "DIASO E" and the back has made-up glyphs. Fix: ask for no text and add our
  own decals, or accept it on props seen from afar.
- **Snow and wear are baked in.** The crate has snow on the lid for good.
  Fine in town, wrong in Halcyon Labs. One generation per setting, or ask for
  clean props.
- **Own material per model.** Tripo props skip our shared slot materials
  (`prop_import.gd`), so map-wide finish changes and snow-on-top do not reach
  them, and each prop adds three textures (about 3 MB of video memory at
  1024, compressed). Fine for 75 props on the target GPU; watch draw calls.
- **Clips are the armed player clips.** In the render she holds an invisible
  rifle. That is expected: vendors need their own unarmed clips (already in
  the F-76 plan).
- **Skirt between the legs** stretches a little in run and crouch. Vendors
  mostly stand, so it is minor.
- **Licence and Steam.** Commercial use needs a paid Tripo plan (private
  models with commercial rights; the free plan makes models public under
  CC BY 4.0). Steam asks for an AI-content disclosure on the store page.

## Fixes made while running the real files

All in `tools/assets/tripo_intake.py` / `tripo_rig.py`, with tests in
`tools/assets/tests/test_tripo_intake.py`:

- Skip the glTF importer's bone display shapes (an extra "Icosphere" mesh).
- Swing a T-posed body to our A-pose before anything else.
- Keep Tripo's skin weights, mapped to our bones.
- Strip ICC profiles from the embedded JPEGs: Godot's loader rejects them, and
  the albedo came out blank.
- No exported tangents: one degenerate UV gave a zero tangent the validator
  rejects; Godot makes its own.
- Twist the forearm after the swing so the hand sits like our player body's rest
  hand (palm forward and in, thumb up and out, measured off `player.glb`), and
  curl Tripo's flat, spread fingers into the player's relaxed curl. Our skeleton
  has no finger bones, so the curl has to be in the mesh. Without both, every
  clip showed open, wrongly turned hands
  ([hands_player_vs_odile.jpg](hands_player_vs_odile.jpg): rest pose on top,
  idle front and side below, player left).

## How to run

```bash
pip install -r tools/assets/requirements.txt
python tools/assets/tripo_intake.py crate.glb --kind prop --height 0.7 --name oriel_crate
python tools/assets/tripo_intake.py odile.glb --kind character --name odile_brandt
```

Tripo export settings: GLB, PBR textures on (HD), delight on, keep the full
detail (no Smart Low Poly, no face limit). Characters: an A- or T-pose image,
then Rig, Humanoid, preset Mixamo.
