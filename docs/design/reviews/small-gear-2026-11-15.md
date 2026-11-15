# Small gear visual review — 2026-11-15

Fresh CPU turnarounds and Common/Legendary Godot booth captures compared with
[gear_fp.jpg](../images/gear_fp.jpg) and the [rebuilt rifle](../turnarounds/weapons/rifle_ar.png).
Scores are **before → after**, from 1 (placeholder) to 5 (target quality).
S/P/D/F/C/R = silhouette, proportions, shape detail, surface finish, colour/value,
and combined close-up/10 m read. Image links contain both turnaround strips and
both rarity booth shots for that model.

| Model / comparison | S | P | D | F | C | R | Triangles before → after / cap |
|---|---:|---:|---:|---:|---:|---:|---:|
| [Dog tags](small-gear-2026-11-15/charm_dog_tags.png) | 3→4 | 4→4 | 2→4 | 3→4 | 4→4 | 3→3 | 768→1232 / 1300 |
| [Vial](small-gear-2026-11-15/charm_vial.png) | 4→4 | 4→4 | 2→4 | 2→4 | 3→4 | 3→3 | 712→1200 / 1200 |
| [Keycard](small-gear-2026-11-15/charm_keycard.png) | 3→4 | 4→4 | 2→4 | 3→4 | 4→4 | 3→3 | 664→974 / 1000 |
| [Dosimeter](small-gear-2026-11-15/charm_dosimeter.png) | 4→4 | 4→4 | 2→3 | 3→3 | 3→3 | 2→2 | 640→976 / 1000 |
| [Coin](small-gear-2026-11-15/charm_coin.png) | 4→4 | 4→4 | 2→4 | 3→4 | 4→4 | 3→3 | 636→1160 / 1200 |
| [Reflex](small-gear-2026-11-15/implant_reflex.png) | 2→4 | 3→4 | 2→4 | 3→3 | 4→4 | 2→3 | 1280→1364 / 1500 |
| [Lung](small-gear-2026-11-15/implant_lung.png) | 2→4 | 3→4 | 2→4 | 3→3 | 4→4 | 2→3 | 1208→1496 / 1500 |
| [Spine](small-gear-2026-11-15/implant_spine.png) | 2→3 | 3→4 | 2→4 | 3→3 | 4→4 | 2→3 | 1368→1588 / 1600 |
| [Ocular](small-gear-2026-11-15/implant_ocular.png) | 2→4 | 3→4 | 2→4 | 2→4 | 4→4 | 2→3 | 1392→1756 / 1800 |
| [Relay](small-gear-2026-11-15/implant_relay.png) | 3→4 | 3→4 | 2→4 | 3→3 | 4→4 | 3→3 | 1256→1384 / 1500 |

Changes, in priority order:

1. **Repeated implant boxes:** cut distinct taper, waist, vertebra, spool and
   asymmetric shell outlines; fit shaped housings, filter cages and optical wells.
   Entire source/exported triangles clear the forearm bore by the tested radius.
2. **Applied-looking marks:** cut real serial strokes, screw slots and socket
   recesses; add local planar topology so baked shading stays near engravings.
3. **Weak charm construction:** interlock rounded links, add open tag bails,
   clip the credential outline, round the token bezel and flute the dosimeter cap.
4. **Opaque specimen and optics:** add hollow glass, separate polished liquid
   with a meniscus, and clear ocular lenses over recessed optical hardware.

The revised limits above pay for those visible features. The four-material cap
remains: only vial/ocular use four; other pieces use three. Palette values remain
from the look rules; glow stays below 5%. Existing node names, hierarchy and pivot
transforms are identical. Vests, player, guns and zombies are untouched.

[Black silhouettes](small-gear-2026-11-15/silhouettes.png),
[Common lineup](small-gear-2026-11-15/lineup-common.png),
[Legendary lineup](small-gear-2026-11-15/lineup-legendary.png),
[10 m native-pixel crops](small-gear-2026-11-15/distance-10m.png).
Inspect shots use the same booth, 25° view and frozen pulse; distance shots use
10 m and 110° horizontal FOV. Turnarounds use default 256 px/32 samples.

Remaining limits: the slim dosimeter and spine outline are subtler than the other
types. At 10 m these tiny objects occupy only a few pixels; no size inflation was
used. Small gear hides beyond 25 m, so the 30 m teammate rule does not apply.
The shared opaque wear shader can mark faceted seams; its wider material changes
are outside this category. Glass has transparency/specular highlights without
screen refraction. Chain motion and liquid slosh remain runtime work. Software
OpenGL confirms shape/material read, but final glow and GPU frame time need a GPU.
