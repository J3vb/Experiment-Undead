# Plan: Player and gear to the concept art

Status: Review
Roadmap: F-70 / issue none (follows the gear look work in DECISIONS.md)
Phase: P6 (pulled forward with the concept-art passes, 2026-11-17)
Size: L
Approved by:

## Goal

The player character and the gear they wear look like the player concept art
(`docs/design/images/player_gear_concept.jpg`): a bearded survivor in field
clothes and a plate carrier with pouches, a green Fenlight vial on the vest and
a glowing implant over one eye, in three readable outfit tiers. Common is plain
olive and black field kit, Rare adds blue-trimmed plates on shoulders, forearms
and knees, Legendary is full Oriel-grade armour. Serves the loot pillar: you see
how good someone's gear is from across the room.

## Scope

In:

- Concept image saved as the look target in `docs/design/images/` and linked
  from look-rules.md and gear-visuals.md (done in this plan PR).
- New survivor body: bearded head, field jacket with a hood and scarf collar,
  cargo trousers, gloves and boots, on the same 22-bone skeleton with the same
  bone names. Replaces the undersuit, balaclava and goggles.
- Outfit tiers: three new code-built outfit models (field, plated, Oriel), each
  one skinned file with headgear (beanie / headset half-helmet / visor helmet),
  glove plates, backpack, boot plates and shoulder, forearm and knee plates.
  Which tier shows is picked by the **vest's rarity**, through data.
- Vest frames (light, medium, heavy) restyled to the concept's plate carrier
  with rows of pouches and a vial clip.
- Implant: an eye plate on the head (one shape per implant type) plus a
  Fenlight vial on the vest clip, replacing the forearm module and neck port.
- First-person arms take the jacket sleeve and glove materials (colour and
  material only, grip geometry untouched).
- Turnarounds, model checks and booth renders for every new or changed model.

Not in (non-goals, and where each one goes instead):

- New loot slots for headgear, gloves, backpack or boots (open decision 1; if
  the person wants them, that is its own L feature with affixes, sets, save and
  network changes).
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
  no shaky ones touched: the change is models plus one Resource field.
- Decision records that apply (docs/adr/): 0003 trusted-client co-op (looks are
  cosmetic and client-built). Does this go against one? no
- Co-op:
  - Who decides: owning client builds its CharacterLook (as today).
  - How a client triggers it: equips gear; LookSync sends the existing 15-byte look.
  - What other players see: GearRig on each client derives the outfit tier from
    the vest rarity already in the look; no new bytes.
  - Works on a dedicated server with no local player: n.a. (server renders nothing).
- Data: outfit tier per rarity lives in content/looks/rarity/*.tres (new field
  `outfit`), outfit models in content/gear_visuals/outfit_*.tres.
  Code compares against a specific id anywhere: no
- Save: changes what is saved? no. Renames or removes a saved id: no
- Events and UI: none new. New screens: n.a.
- Input through InputFrame, gameplay in _physics_process, randomness from the session RNG: yes (no gameplay code)
- Tests: tools/assets/tests (model rules), tests/unit/test_gear_rig.gd,
  tests/content (rarity looks point at real outfit visuals).
- Logging: none new; GearRig's existing fallback to Common covers a missing outfit.
- Performance: outfit is instanced only in GearRig.apply(), never per frame.
- Out of scope: new loot slots, presets, first-person gear, dyes, effects.
```

## Design references

- docs/design/images/player_gear_concept.jpg: the look target (2026-11-17).
- docs/design/gear-visuals.md#rarity-and-set-visual-language: trim colour first,
  glow at most 5% of a piece, glow only from Rare up.
- docs/design/look-rules.md#loot-rarity: rarity hex codes. Rare `#3D7DFF`
  matches the concept's blue. Legendary `#FF8A1C` is orange, the concept is
  gold: open decision 2.
- docs/DECISIONS.md: "GearRig and LookBuilder", "Vest frames", "Co-op gear looks"
  (15-byte payload: vest, charm, implant, each with rarity).
- Memory of the 2026-11-15 decision: skinned body on one 22-bone skeleton.
- Budgets in `tools/assets/character_checks.py`: characters 16,000 tris / 4
  materials, gear 6,000 / 4, implants 1,500 to 1,800.

## Systems touched

| Folder or file | New / changed | What changes |
|---|---|---|
| tools/assets/player_body_model.py (+ new `player_head_model.py` if over 350 lines) | changed / new | Survivor head and field clothes |
| tools/assets/outfit_model.py | new | Field, plated and Oriel outfit tiers |
| tools/assets/vest_model.py | changed | Plate carrier, pouches, VialClip socket |
| tools/assets/implant_model.py | changed | Eye plate per type plus vial |
| tools/assets/player_arms_model.py | changed | Sleeve and glove materials only |
| tools/assets/character_models.py, character_checks.py, check_models.py | changed | Build hooks, budgets and joints for outfits |
| assets/models/characters/*.glb, assets/models/gear/*.glb (+ .import) | new / changed | Exported models |
| docs/design/turnarounds/characters, gear | changed | Approved renders |
| systems/gear/rarity_look.gd | changed | New field `outfit: StringName` |
| systems/gear/gear_rig.gd | changed | Attach outfit from vest rarity; implant to head and vest clip |
| content/looks/rarity/*.tres, content/gear_visuals/outfit_*.tres | changed / new | Tier per rarity, outfit visuals |

Autoloads, managers or base classes added: none.

## Data

- `RarityLook.outfit: StringName = &""`: the GearVisual id of the outfit this
  rarity shows. Read by GearRig only. Empty means no outfit pieces.
- Tier per rarity (provisional): Common and Uncommon = `outfit_field`, Rare and
  Epic = `outfit_plated`, Legendary and Prototype = `outfit_oriel`. Trim colour
  still comes from the rarity, so an Epic plated outfit has purple trim.
- New GearVisual files `outfit_field`, `outfit_plated`, `outfit_oriel` with
  slot `outfit`. No item ever has slot `outfit`; it is not a loot slot.
- No vest equipped: `outfit_field` (the beanie and pack still show).
- Implant vial liquid: Fenlight green at Common and Uncommon (like the concept's
  Common vial), the rarity colour from Rare up (provisional).
- Save format change: none.
- Network message change: none. The look payload already carries vest rarity.
- Content checks to add in `tests/content/`: every RarityLook's `outfit` names a
  GearVisual with slot `outfit`.

## Co-op behaviour

- Who owns the state: the owning client, as today (CharacterLook, ADR 0003).
- What clients send, what the server sends back: unchanged 15-byte look.
- What a client sees that the host sees too: the same outfit tier, because every
  client derives it from the same vest rarity and the same content.
- Late joiner: gets the cached looks as today; no new data.
- Dedicated server: renders nothing, so nothing is skipped beyond today.

## Performance

No per-frame cost: models are swapped only in `GearRig.apply()`. Each character
gains one skinned outfit mesh (up to 4 surfaces sharing the gear material).
Budgets: body 16,000 tris (unchanged cap), outfit 6,000 (gear cap), vest 6,000,
implant 1,800. Eight players stay well under the 120 fps target on the RTX 4080
Super; outfit pieces hide past 40 m with a visibility range like the charm.

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
- Tests: tools/assets/tests: player has the four materials and 22 named bones,
  stays under 16,000 tris; tests/unit/test_gear_rig.gd still binds every vest.
- Done when: turnaround and booth render beside the concept, sent to the person.

### Step 2: Outfit tiers and the tier pick

- Build: `outfit_model.py` builds `outfit_field` (beanie, glove cuffs, small
  pack, boot gaiters) as one rigidly skinned file; `RarityLook.outfit` field,
  the six rarity files point at it; GearRig attaches the outfit from the vest's
  rarity in the same skeleton holder the vest uses.
- Files: outfit_model.py, character_models.py, character_checks.py,
  check_models.py, rarity_look.gd, gear_rig.gd, content/looks/rarity/*.tres,
  content/gear_visuals/outfit_field.tres, assets/models/gear/outfit_field.glb.
- Tests: test_gear_rig.gd: a Rare vest look adds one Outfit node; no vest gives
  the field outfit; a bad outfit id falls back with no error. Content check:
  every rarity's outfit exists with slot `outfit`.
- Done when: the booth shows the field outfit on the new body.

### Step 3: Plated and Oriel tiers

- Build: `outfit_plated` (headset half-helmet, shoulder, forearm and knee plates,
  armoured pack, plated boots) and `outfit_oriel` (visor helmet, full plates,
  glow strips on pack and gauntlets at most 5% of area). Rare and Epic point at
  plated, Legendary and Prototype at Oriel.
- Files: outfit_model.py (split by tier if over 350 lines), two .tres, two .glb,
  four rarity .tres, turnarounds.
- Tests: model checks (budget, zones, glow at most 5%); test_gear_rig.gd: each
  rarity shows its tier.
- Done when: booth lineup of all six rarities beside the concept, sent to the person.

### Step 4: Plate carrier vests

- Build: light, medium and heavy frames restyled to the concept's plate carrier
  with pouch rows; add a `VialClip` socket on the left chest. Keep the 3 mm
  clearance and the frame triangle ranges in DECISIONS.md.
- Files: vest_model.py, gear_parts.py, three vest .glb, turnarounds.
- Tests: model checks find VialClip on every frame; clearance check passes.
- Done when: all three frames render on the new body with every outfit tier.

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
- [ ] Each rarity shows its outfit tier in the booth and on a co-op teammate,
      with no change to the look payload.
- [ ] The booth lineup reads Common, Rare and Legendary like the concept at a
      glance (person's eye).
- [ ] F-41 teammate clips play on the new body without errors.

## Risks

- A code-built bearded face can look odd: step 1 shows it to the person before
  anything else is built on it.
- Outfit plates may clip the vest or body when animated: rigid weights on the
  same bones as the vest, clearance check, and a clip playback render in step 3.
- Backpack and slung primary share the back: the slung gun moves out by the pack
  depth (one offset in GearRig) in step 2.
- Size: steps 1, 3 and 5 are close to 400 lines; split a model script by part
  if one passes the 350-line file limit.

## Open decisions

- [ ] Gear slots: keep the 5 loot slots and let vest rarity pick the outfit tier
      (recommended), or add headgear, gloves, backpack and boots as loot slots.
- [ ] Legendary colour: brass-gold armour plates with orange `#FF8A1C` trim
      (recommended), gold everywhere, or orange plates.
- [ ] Plan approval.
