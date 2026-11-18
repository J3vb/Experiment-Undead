# Plan: Player and gear to the concept art

Status: Building
Roadmap: F-70 / issue none (follows the gear look work in DECISIONS.md)
Phase: P6 (pulled forward with the concept-art passes, 2026-11-17)
Size: L
Approved by: the person on decision cards (new loot slots, Legendary colour, plan; 2026-11-17), plan PR #307

## Goal

The player character and the gear they wear look like the player concept art
(`docs/design/images/player_gear_concept.jpg`): a bearded survivor in field
clothes and a plate carrier with pouches, a green Fenlight vial on the vest and
a glowing implant over one eye, with headgear, gloves, backpack and boots, in
three readable tiers. Common is plain olive and black field kit, Rare adds
blue-trimmed plates on shoulders, forearms and knees, Legendary is full
Oriel-grade armour in brass-gold with orange trim. Serves the loot pillar: you see
how good someone's gear is from across the room.

## Scope

In:

- Concept image saved as the look target in `docs/design/images/` and linked
  from look-rules.md and gear-visuals.md (done in this plan PR).
- New survivor body: bearded head, field jacket with a hood and scarf collar,
  cargo trousers, gloves and boots, on the same 22-bone skeleton with the same
  bone names. Replaces the undersuit, balaclava and goggles.
- Models for the four new gear slots (decided 2026-11-17: they become real loot
  slots): headgear, gloves, backpack and boots. Each base type has three tier
  models, and the piece's **own rarity** picks the tier through data:
  field (Common, Uncommon), plated (Rare, Epic), Oriel (Legendary, Prototype).
  Headgear: beanie / headset half-helmet / visor helmet. Gloves own the forearm
  guards, boots own the knee and shin plates.
- Vest frames (light, medium, heavy) restyled to the concept's plate carrier
  with rows of pouches and a vial clip, also in the three tiers (shoulder plates
  from plated up).
- Appearance plumbing for the new slots: CharacterLook, LookBuilder, LookCodec
  (look payload grows from 3 to 7 slots) and GearRig.
- Implant: an eye plate on the head (one shape per implant type) plus a
  Fenlight vial on the vest clip, replacing the forearm module and neck port.
- First-person arms take the jacket sleeve and glove materials (colour and
  material only, grip geometry untouched).
- Turnarounds, model checks and booth renders for every new or changed model.

Not in (non-goals, and where each one goes instead):

- The loot side of the four new slots: item bases, affix pools, drops, sets
  (today exactly 5 pieces), save, inventory and character screen slots. That is
  its own plan, F-71. This plan only fixes the slot ids it must share:
  `headgear`, `gloves`, `backpack`, `boots`.
- Other survivor presets and face options (F-67 character select).
- Implant and outfit pieces in first person (F-42 gear in first person).
- Dyes (F-46), set crests and Legendary signature effects (their own steps in
  gear-visuals.md).
- Image textures: the gear finish stays the procedural `gear.gdshader` with
  vertex-colour zones, as for the guns.

## Ready to build

```
### Ready to build
- Foundations touched (numbers from docs/FOUNDATIONS.md): content ids in data (4);
  no shaky ones touched: models, two Resource fields and the look payload.
- Decision records that apply (docs/adr/): 0003 trusted-client co-op (looks are
  cosmetic and client-built). Does this go against one? no
- Co-op:
  - Who decides: owning client builds its CharacterLook (as today).
  - How a client triggers it: equips gear; LookSync sends the look, now 35 bytes
    (7 slots x 5 bytes), protocol bump.
  - What other players see: GearRig on each client picks each piece's tier model
    from the rarity already in its slot entry.
  - Works on a dedicated server with no local player: n.a. (server renders nothing).
- Data: tier per rarity lives in content/looks/rarity/*.tres (new field `tier`),
  tier models in content/gear_visuals/*.tres (new field `tier_scenes`).
  Code compares against a specific id anywhere: no
- Save: changes what is saved? no. Renames or removes a saved id: no
- Events and UI: none new. New screens: n.a.
- Input through InputFrame, gameplay in _physics_process, randomness from the session RNG: yes (no gameplay code)
- Tests: tools/assets/tests (model rules), tests/unit/test_gear_rig.gd,
  tests/content (rarity looks point at real outfit visuals).
- Logging: none new; GearRig's existing fallback to the slot base in Common covers
  a missing model.
- Performance: pieces are instanced only in GearRig.apply(), never per frame.
- Out of scope: loot side of the new slots (F-71), presets, first-person gear, dyes, effects.
```

## Design references

- docs/design/images/player_gear_concept.jpg: the look target (2026-11-17).
- docs/design/gear-visuals.md#rarity-and-set-visual-language: trim colour first,
  glow at most 5% of a piece, glow only from Rare up.
- docs/design/look-rules.md#loot-rarity: rarity hex codes. Rare `#3D7DFF`
  matches the concept's blue. Legendary stays orange `#FF8A1C` for trim, beams
  and UI; its Oriel plates are a brass-gold metal finish (decided 2026-11-17).
- docs/DECISIONS.md: "GearRig and LookBuilder", "Vest frames", "Co-op gear looks"
  (15-byte payload: vest, charm, implant, each with rarity).
- Memory of the 2026-11-15 decision: skinned body on one 22-bone skeleton.
- Budgets in `tools/assets/character_checks.py`: characters 16,000 tris / 4
  materials, gear 6,000 / 4, implants 1,500 to 1,800.

## Systems touched

| Folder or file | New / changed | What changes |
|---|---|---|
| tools/assets/player_body_model.py (+ new `player_head_model.py` if over 350 lines) | changed / new | Survivor head and field clothes |
| tools/assets/headgear_model.py, glove_model.py, backpack_model.py, boot_model.py | new | Three tiers per piece |
| tools/assets/vest_model.py | changed | Plate carrier, pouches, VialClip socket |
| tools/assets/implant_model.py | changed | Eye plate per type plus vial |
| tools/assets/player_arms_model.py | changed | Sleeve and glove materials only |
| tools/assets/character_models.py, character_checks.py, check_models.py | changed | Build hooks, budgets and joints for the new pieces |
| assets/models/characters/*.glb, assets/models/gear/*.glb (+ .import) | new / changed | Exported models |
| docs/design/turnarounds/characters, gear | changed | Approved renders |
| systems/gear/rarity_look.gd | changed | New field `tier: int` |
| systems/gear/gear_visual.gd | changed | New field `tier_scenes`; BASES gets the four new slots |
| systems/gear/character_look.gd, look_builder.gd, look_codec.gd | changed | Seven slots; 35-byte payload |
| core/build.gd | changed | PROTOCOL_VERSION bump with the payload change |
| systems/gear/gear_rig.gd | changed | Attach new slots; tier scene pick; implant to head and vest clip |
| content/looks/rarity/*.tres, content/gear_visuals/*.tres | changed / new | Tier per rarity, new piece visuals |

Autoloads, managers or base classes added: none.

## Data

- `RarityLook.tier: int = 0`: 0 field, 1 plated, 2 Oriel. Common and Uncommon
  0, Rare and Epic 1, Legendary and Prototype 2 (provisional). Trim colour
  still comes from the rarity, so an Epic plated piece has purple trim.
- `GearVisual.tier_scenes: Array[PackedScene] = []`: one scene per tier. Empty
  means `scene` for every tier (charms keep working as today). GearRig picks
  `tier_scenes[min(tier, size - 1)]`.
- New GearVisual files, one base type per new slot to start, each with three
  tier scenes: `headgear_cap`, `gloves_tactical`, `backpack_pack`, `boots_field`.
  F-71 adds the item bases that point at them.
- Legendary finish: the Oriel tier models paint their plates in a GearBrass
  material zone (brass-gold metal); trim stays the rarity colour.
- Empty slots: no headgear shows the body's hair, no gloves the body's bare
  hands, no boots the body's plain shoes, no backpack nothing.
- Implant vial liquid: Fenlight green at Common and Uncommon (like the concept's
  Common vial), the rarity colour from Rare up (provisional).
- Save format change: none in this plan (F-71 owns item and save changes).
- Network message change: LookCodec grows from 15 to 35 bytes (same 5 bytes per
  slot, slots in CharacterLook.SLOTS order); `Build.PROTOCOL_VERSION` goes up so
  older builds are refused before any player spawns.
- Content checks to add in `tests/content/`: every RarityLook has a tier 0-2;
  every GearVisual with tier scenes has exactly 3.

## Co-op behaviour

- Who owns the state: the owning client, as today (CharacterLook, ADR 0003).
- What clients send, what the server sends back: the 35-byte look, relayed and
  cached by the server as today.
- What a client sees that the host sees too: the same pieces and tiers, because
  every client picks them from the same slot entries and the same content.
- Late joiner: gets the cached looks as today.
- Dedicated server: renders nothing, so nothing is skipped beyond today.

## Performance

No per-frame cost: models are swapped only in `GearRig.apply()`. Each character
gains up to four rigid pieces (about 4 more draw calls, sharing the gear
material). Budgets per tier model: headgear 1,500, gloves 2,000 (pair),
backpack 2,500, boots 2,000 (pair), vest 6,000, implant 1,800, body 16,000.
About 33,000 tris per character before guns, so eight players stay well under
the 120 fps target on the RTX 4080 Super. Gloves, boots and headgear hide past
40 m with a visibility range like the charm.

## Steps

### Step 1: Survivor head and body

- Build: rebuild the body as the concept's survivor: bearded head with a shaped
  beard and brows (no hat; the outfit brings the beanie), field jacket with hood
  and scarf collar, cargo trousers with knee pads, gloves, boots. Same 22 bones
  and names, so F-41 clips and GearRig keep working. Materials: BodySkin,
  BodyHair, BodyCloth, BodyRubber. Riskiest part first: if the code-built face
  does not read, stop and show the person before step 2.
- Files: player_body_model.py (split head into player_head_model.py if needed),
  character_checks.py, assets/models/characters/player.glb, turnaround.
- As built (2026-11-18): the person picked the separate Fable trial body over
  the first step 1 build. It lives in `tools/assets/player_body/` (MakeHuman CC0
  head, baked colour/normal/roughness maps in the .glb, ADR 0015); the old
  module became `player_arm_shapes.py` for the first-person arms until step 6.
- Tests: tools/assets/tests: player has the four materials and 22 named bones,
  stays under 16,000 tris; tests/unit/test_gear_rig.gd still binds every vest.
- Done when: turnaround and booth render beside the concept, sent to the person.

### Step 2: Tier plumbing and headgear

- Build: `RarityLook.tier`, `GearVisual.tier_scenes`; CharacterLook.SLOTS adds
  `headgear`, `gloves`, `backpack`, `boots`; LookCodec 35 bytes; protocol bump;
  GearRig attaches a rigid piece per new slot and picks its tier scene.
  `headgear_model.py` builds beanie, headset half-helmet and visor helmet
  (`headgear_cap`, three tiers, on `head`).
- Files: rarity_look.gd, gear_visual.gd, character_look.gd, look_builder.gd,
  look_codec.gd, gear_rig.gd, core/build.gd, content/looks/rarity/*.tres,
  content/gear_visuals/headgear_cap.tres, headgear_model.py, character_models.py,
  character_checks.py, check_models.py, three headgear .glb, turnarounds.
- Tests: test_look_sync.gd / codec test: 7-slot look encodes to 35 bytes and
  back; a 15-byte payload resets all slots. test_gear_rig.gd: Common, Rare and
  Legendary headgear pick tier 0, 1, 2; bad id falls back with no error.
  Content checks from Data.
- Done when: the booth shows the three helmets on the new body.

### Step 3: Gloves, boots and backpack

- Build: `glove_model.py` (gloves plus forearm guards from plated up),
  `boot_model.py` (boots plus knee and shin plates from plated up),
  `backpack_model.py` (field pack, armoured pack, Oriel pack with glow strips
  at most 5% of area), three tiers each. The slung primary moves out by the
  pack depth (one offset in GearRig).
- Files: the three model scripts, three .tres, nine .glb, character_checks.py,
  check_models.py, gear_rig.gd, turnarounds.
- Tests: model checks (budget, zones, glow at most 5%, pair pieces on both
  sides); test_gear_rig.gd: each slot attaches to its bones, empty slots attach
  nothing.
- Done when: booth lineup Common, Rare, Legendary beside the concept, sent to the person.

### Step 4: Plate carrier vests

- Build: light, medium and heavy frames restyled to the concept's plate carrier
  with pouch rows, each in three tiers (shoulder plates from plated up, brass
  plates on Oriel); add a `VialClip` socket on the left chest. Keep the 3 mm
  clearance and the frame triangle ranges in DECISIONS.md.
- Files: vest_model.py, gear_parts.py, nine vest .glb, three vest .tres
  (tier scenes), turnarounds.
- Tests: model checks find VialClip and Shell on every frame and tier;
  clearance check passes; test_gear_rig.gd binds every tier's Shell.
- Done when: all three frames render on the new body in all three tiers.

### Step 5: Eye implant and Fenlight vial

- Build: each of the five implant types becomes an eye plate on the head (its own
  shape, glow lens) plus one shared vial that sits in the vest's VialClip. Vial
  liquid follows the rule in Data. GearRig binds the Plate to `head` and the Vial
  to VialClip (on spine_3 when no vest).
- Files: implant_model.py, gear_rig.gd, five implant .glb, turnarounds,
  DECISIONS.md (implant placement line).
- Tests: model checks: every implant has Plate and Vial nodes, under 1,800 tris;
  test_gear_rig.gd: Plate follows head, Vial follows the vest clip and falls
  back to spine_3 with no vest.
- Done when: booth close-up of the face matches the concept's implant panel.

### Step 6: First-person sleeves and close-out

- Build: player_arms gets the jacket sleeve and glove materials (no geometry
  change, so the 115 grip contact poses stay clear). Booth lineup look-check
  against the concept, gear-visuals.md updated (body, outfit tiers, implant),
  roadmap row Done.
- Files: player_arms_model.py, player_arms.glb, docs.
- Tests: arms contact check still passes; arms material names test.
- Done when: acceptance ticked, renders sent to the person.

## Acceptance

- [ ] Player body, all outfit tiers, vests and implants pass model checks and
      have approved turnarounds.
- [ ] Each new slot's piece shows its tier by rarity in the booth and on a co-op
      teammate through the 35-byte look.
- [ ] The booth lineup reads Common, Rare and Legendary like the concept at a
      glance (person's eye).
- [ ] F-41 teammate clips play on the new body without errors.

## Risks

- A code-built bearded face can look odd: step 1 shows it to the person before
  anything else is built on it.
- Plates may clip the vest or body when animated: pieces ride the same bones,
  clearance check, and a clip playback render in step 3.
- Backpack and slung primary share the back: the slung gun moves out by the pack
  depth (one offset in GearRig) in step 3.
- F-71 may pick other slot ids: this plan fixes them first; F-71 uses these.
- Size: steps 1, 3 and 5 are close to 400 lines; split a model script by part
  if one passes the 350-line file limit.

## Open decisions

- [x] Gear slots: add headgear, gloves, backpack and boots as loot slots (the
      person, 2026-11-17). Loot side planned in F-71.
- [x] Legendary colour: brass-gold armour plates with orange `#FF8A1C` trim
      (the person, 2026-11-17).
- [x] Plan approval: approved, start step 1 (the person, 2026-11-17).
