# Characters — 2026-11-15

Baseline: `109bb6d`, rebuilt before editing. Scores are 1–5; compare with
`gear_sets.jpg`, `gear_fp.jpg`, `style_hub.jpg` and the rebuilt gun outlines.
The guns set the bar for deliberate contours, edge treatment and material separation.

| Model | Silhouette | Proportions | Shape detail | Surface finish | Colour/value | Distance/FP read |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Body, before | 3 | 3 | 2 | 3 | 3 | 3 |
| Body, after | 3 | 3 | 4 | 3 | 3 | 3 |
| Arms, before | 3 | 2 | 2 | 3 | 3 | 2 |
| Arms, after | 4 | 4 | 4 | 3 | 3 | 4 |

Priorities, greatest visual cost first:

1. **Smooth tubes look like a mannequin.** Shape the knees and calves; compress
   the actual fabric surface at elbows, knees and waist. Share the sleeve surface
   between body and arms, preserving the vest's fitted envelope.
2. **Gloves look assembled from beads and wires; their handedness is reversed.**
   Correct thumb/index orientation, flatten knuckle protection, articulate curls
   and seat reinforcement on fingers. Keep marker names, parents and the existing
   grip clearances; markers follow the corrected fingertips.
3. **Head reads as a featureless cylinder with round eyes.** Define the jaw and
   covered nose, give goggles a more deliberate outline and add balaclava seams.
4. **Boots lack construction cues.** Shape the toe reinforcement and heel/ankle
   support while retaining the sole height and the existing foot binding.

The initial 12,000 / 8,000 triangle caps left insufficient cloth support edges.
With the requested allowance to raise limits for quality, caps are now 16,000 /
10,000. Material counts remain four / three. Shared procedural finishes and
palette stay intact. Common lenses remain opaque and pale under the existing
rarity shader; changing that shared behavior would affect excluded gear.

The hidden chest chevrons were removed after their concave seam normals failed
the committed-vest clearance test. All three unchanged vests now pass the 3 mm
clearance requirement. Raised boot lacing is projected onto the actual vamp,
with regression tests against buried or floating detail.

The new arms replace the local gameplay hand meshes through the shared weapon
holder. One rig follows the active weapon through aiming, kick, reload and pump
motion; camera-relative shoulders prevent the entire arm moving like a rigid prop.
Ten authored grip profiles cover the twenty base/Reforged weapon definitions.
Nine glove morphs preserve the accepted rifle as the default shape. Common medium
cuffs are cosmetic; this adds no equipment or rarity gameplay.

Results: body **11,892 → 15,380** triangles; arms **7,628 → 9,828**.
The strongest gains are local cloth compression, shaped face covering, seated
boot construction and natural glove geometry. Broad body proportions and its
30 m silhouette are intentionally stable; shared procedural finish is unchanged.
The enlarged budgets are bounded, with rejection tests still enforced.

Hand placement uses proper rotations, unchanged bone lengths and the rifle's
actual cross-sections. The left hand supports the handguard; the right wraps the
slanted pistol grip. Oblique finger curls let both palms continue the forearms:
wrist bends are **3.19° left / 15.82° right**. Joint-angle tests check both wrists
and elbows, and shoulder positions are bounded relative to the imported body.
Minimum imported-vertex grip clearances are **1.724 mm left / 2.103 mm right**.
The right index clears the guard by 1.183 mm; both hands clear the adjacent
receiver, trigger and rail geometry. The camera and rifle stay at the runtime hip
placement. Rifle finger/thumb markers retain their 32/45 mm gaps; the other grips
stay within the existing 25–40 mm right / 40–50 mm left limits. Regression tests
also catch reversed anatomy, twisted sweep rings, buried reinforcement, grip
penetration and discontinuous elbow movement. Fingers use fixed authored curls;
individual trigger pulls and magazine-handling animation remain deferred.

| Model | Before: strip + Common/Legendary booth | After: strip + Common/Legendary booth |
| --- | --- | --- |
| Body | [Before](images/characters-2026-11-15/player_before.png) | [After](images/characters-2026-11-15/player_after.png) |
| Arms | [Before](images/characters-2026-11-15/player_arms_before.png) | [After](images/characters-2026-11-15/player_arms_after.png) |

Additional paired evidence: [first-person rifle](images/characters-2026-11-15/fp_rifle.png),
[right grip](images/characters-2026-11-15/grip_right.png),
[left support](images/characters-2026-11-15/grip_left.png),
[underside](images/characters-2026-11-15/grip_under.png),
[whole arm pose](images/characters-2026-11-15/pose_side.png),
[head](images/characters-2026-11-15/body_head.png),
[boots](images/characters-2026-11-15/body_boots.png),
[body silhouette](images/characters-2026-11-15/body_silhouette.png).
The same image directory contains Common/Legendary cuff views, arm silhouettes,
and uncropped 10/30 m images at 110° horizontal FOV. These software OpenGL
captures verify shape, colour and fit, not Forward+ performance.

Gameplay comparisons use the original placeholder hands before and the imported
rig after, with identical cameras and lighting. Each sheet includes Common and
Legendary at hip (110° horizontal FOV) and ADS (the weapon's vertical FOV):
[rifle](images/characters-2026-11-15/runtime_rifle_ar.png),
[Talon](images/characters-2026-11-15/runtime_talon_dmr.png),
[Kestrel](images/characters-2026-11-15/runtime_kestrel_smg.png),
[Mako](images/characters-2026-11-15/runtime_mako_pdw.png),
[Atlas](images/characters-2026-11-15/runtime_atlas_auto.png),
[Halberd](images/characters-2026-11-15/runtime_halberd_lmg.png),
[Corvid](images/characters-2026-11-15/runtime_corvid_338.png),
[Brenner](images/characters-2026-11-15/runtime_brenner_trench.png),
[Hollis](images/characters-2026-11-15/runtime_hollis_44.png),
[service pistol](images/characters-2026-11-15/runtime_pistol_service.png).

Reproduce after building/importing the project:

```sh
python tools/render_turnarounds.py player player_arms --out /tmp/characters-turnarounds
godot --path . --rendering-driver opengl3 tools/gear_booth.tscn -- --rarity all --out /tmp/characters-booth
godot --path . --rendering-driver opengl3 tools/character_review.tscn -- /tmp/characters-inspection
godot --path . --rendering-driver opengl3 tools/weapon_arm_review.tscn -- /tmp/characters-runtime
```

Use `--rarity all` and compare Common/Legendary: the existing single-rarity booth
argument path has a typed-array error. No excluded category or shared shader was
changed to address it. Approved turnaround PNGs are committed separately.
