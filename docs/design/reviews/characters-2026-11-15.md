# Characters — 2026-11-15

Initial baseline: `109bb6d`, rebuilt before editing. Final comparisons use
`2865d38` so intervening gun and vest changes appear on both sides. Scores are 1–5; compare with
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
Authored grip profiles cover every current weapon family and its upgraded variants.
Glove morphs preserve the accepted rifle as the default shape. Common medium
cuffs are cosmetic; this adds no equipment or rarity gameplay.
The fitted palms, fingers and glove reinforcement follow the hand bones rigidly;
the sleeves and wrist fabric retain blended weights. This prevents wrist motion
during reload from pulling a palm through the receiver.

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
Contact checks export the actual imported morphs, full skin weights, cuffs and
weapon triangles in hip, ADS and reload poses. They detect surface intersections
and enclosed geometry; reported clearances are sampled, not exact minimum distances.
The camera and rifle stay at the runtime hip placement. The default rifle retains
its 32/45 mm tip gaps and original clearance
checks. Other profiles place markers on their actual fingertips; stock grips use
wider gaps so thumbs can stay a natural length, and support gloves cup the firing
hand on pistols. Regression tests
also catch reversed anatomy, twisted sweep rings, buried reinforcement, grip
penetration and discontinuous elbow movement. Fingers use fixed authored curls;
individual trigger pulls and magazine-handling animation remain deferred.

Two stock contacts keep this review in draft: Coachman's right upper sleeve
overlaps the stock by about 10 mm during sprint, and Bastion's right upper sleeve
by about 12 mm at hip, mid-ADS and shot peak. Hand, wrist and cuff corrections
remain in place; joint limits and collision checks have not been relaxed.
Bastion uses an overhand brace at the receiver/barrel-base collar to route the
support arm clear of its side ammunition box. Resolving the two remaining sleeve
contacts is required before marking the character pass ready.

**Follow-up 2026-11-17:** both sleeve contacts are fixed in grip data, not in the checker.
Coachman's sprint shoulder drops 30 mm lower and 10 mm wider (`right_sprint_offset` 0.01, -0.07, -0.1) and
Bastion's right shoulder sits 30 mm wider and 40 mm lower (`right_shoulder` 0.22, -0.115, -0.274).
The contact check now clears all 115 sampled poses; the closest right upper sleeve samples are
11 mm (Coachman sprint) and 12 mm (Bastion sprint). Both stay inside the anatomy test's shoulder allowances. `tests/integration/test_arm_sleeve_contacts.gd`
fails if a right upper sleeve edge crosses either stock again. The character pass is ready.

Final validation: 692 asset tests; all 41 fresh and committed GLBs pass Khronos
and model checks; all 41 approved turnarounds match. Imported contact checks cover
115 sampled poses: 111 clear, with only the four upper-sleeve cases above failing.
All hands, wrist fabric, forearms and armour cuffs clear those samples. Reported
residual contact samples lie behind the first-person camera; this does not erase
the geometric intersections. GUT and CI results are recorded on the PR.

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
Actual lowered GearRig teammate poses at 30 m are also saved at native scale:
[Common before](images/characters-2026-11-15/teammate_30m_before_common.png),
[Common after](images/characters-2026-11-15/teammate_30m_after_common.png),
[Legendary before](images/characters-2026-11-15/teammate_30m_before_legendary.png),
[Legendary after](images/characters-2026-11-15/teammate_30m_after_legendary.png).
At 110° horizontal FOV, the 1.80 m avatar is about 27 pixels tall in these captures.

Gameplay comparisons use the original viewmodels before and the imported
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
[service pistol](images/characters-2026-11-15/runtime_pistol_service.png),
[Fieldhand](images/characters-2026-11-15/runtime_fieldhand_lever.png),
[Ironwood](images/characters-2026-11-15/runtime_ironwood_50.png),
[Wren](images/characters-2026-11-15/runtime_wren_mp.png),
[Siphon](images/characters-2026-11-15/runtime_siphon.png),
[Sentry](images/characters-2026-11-15/runtime_sentry_br3.png),
[Nightjar](images/characters-2026-11-15/runtime_nightjar_sd.png),
[Rampart](images/characters-2026-11-15/runtime_rampart_br.png),
[Cryo Lance](images/characters-2026-11-15/runtime_cryo_lance.png),
[Synapse](images/characters-2026-11-15/runtime_synapse.png),
[Coachman](images/characters-2026-11-15/runtime_coachman_2b.png),
[Grubber](images/characters-2026-11-15/runtime_grubber_sawnoff.png),
[Bastion](images/characters-2026-11-15/runtime_bastion_lmg.png).
Close-up contact sheets show the
[stock, pistol and support grips](images/characters-2026-11-15/runtime_contacts.png) and
[cage, angled-stop and double-barrel grips](images/characters-2026-11-15/runtime_contacts_new.png).

Actual GameSession camera captures also verify the integrated rig:
[rifle hip](images/characters-2026-11-15/gameplay_rifle_ar_hip.png),
[rifle ADS](images/characters-2026-11-15/gameplay_rifle_ar_ads.png),
[pistol hip](images/characters-2026-11-15/gameplay_pistol_service_hip.png),
[pistol ADS](images/characters-2026-11-15/gameplay_pistol_service_ads.png).

The Linux client PCK loads all 22 profiles and 21 morphs. Server metadata is also
present, but dedicated export startup encounters the existing stripped
`PlaceholderMesh`/`QuadMesh` mismatch in `remote_shot_effects.gd`; it reproduces on
the unchanged `2865d38` baseline. No unrelated networking or gun files were edited.

Reproduce after building/importing the project:

```sh
python tools/render_turnarounds.py player player_arms --out /tmp/characters-turnarounds
godot --path . --rendering-driver opengl3 tools/gear_booth.tscn -- --rarity all --out /tmp/characters-booth
godot --path . --rendering-driver opengl3 tools/character_review.tscn -- /tmp/characters-inspection
godot --path . --rendering-driver opengl3 tools/weapon_arm_review.tscn -- /tmp/characters-runtime
CONTACT_OUT=/tmp/character-contacts godot --headless --path . -s addons/gut/gut_cmdln.gd -gconfig= -gtest=res://tools/character_contact_export.gd -gexit
python tools/check_character_contacts.py /tmp/character-contacts
```

Use `--rarity all` and compare Common/Legendary: the existing single-rarity booth
argument path has a typed-array error. No excluded category or shared shader was
changed to address it. Approved turnaround PNGs are committed separately.
