# Lore audit, 2026-11-18

Question: does everything built or planned have a story reason, and does it
all agree? Checked against [lore.md](../lore.md): Halcyon Labs rooms, props,
signs and secret; Lantern Post buildings, gate, props and stall keepers; the
22-gun roster; zombie types; serums, power-ups, gear, Legendaries, sets and
abilities; the prop library plan (F-77); the Act I maps and campaign.

## Already linked well

- **The core idea holds everywhere.** Cold is safe, warmth wakes Fenlight,
  green is Fenlight, orange sodium is safety. Halcyon's lighting, the town's
  sodium lamps and the Cold Containment look all follow it.
- **Machines** (power, Serums, Specimen Vault, Reforger, Prototypes, exfil,
  keeping loot on death) each have a reason.
- **Maps and campaign.** Each Act I map, secret, event and boss has a place in
  the story, and the "new chapter" checklist keeps future maps linked.
- **Halcyon Labs rooms** each tell a small story, and the concept-pass signs
  (HALCYON LABS, ORIEL, sector codes) use lore names.
- **Stall keepers** have names, faces and lines tied to the lore.

## Gaps found, now filled (provisional picks)

All written into lore.md, "Story links for game content", unless noted.

| Gap | Fix |
| --- | --- |
| Zombie types had no story (why Bloaters burst, Stalkers climb, Brutes have a head plate, Glowers come in the dark) | One line each. Brute = riot troops whose helmet fused into a bone plate; Stalkers follow warm air under ceilings. |
| Guns had no origin, and the name styles were mixed (codes vs names) | Three sources: army and Cordon issue, Oriel security, valley civilians, plus Oriel prototypes. The source sets the name style. |
| Power-ups, points and wall buys had no reason | Recommended pick written, waiting on the person (decision card). |
| Vests, charms, implants, abilities, skill branches and Scrap had no reason | One line each. Implants = HALCYON's soldier program, fitted by Dr. Corvelyn. |
| Fenlight vines, pods and spill pools in Halcyon were not in the lore (it only lived in bodies) | Fenlight grows outside bodies where it is warm and damp. |
| Army trucks, cases and checkpoints inside the zone (props, F-77) had no owner: the Cordon only exists from Day 9 | The Cordon is the army force that ran the evacuation, then pulled back to seal the zone. |
| Lantern Post's concrete wall, Deploy tunnel and blast door made no sense for a village | The village grew round an old customs post; the tunnel is a 1960s border tunnel through the ridge. |
| Lantern Post's name: founded by 1954 nurses, but also "an old border-post village" | Both: the village existed; the nurses settled there and hung their lantern, and the name stuck. |
| The maroon banner emblem was never described | A lantern over a ridge line, light grey on maroon. |
| FENLIGHT SAMPLES crates in a warm town | Dr. Corvelyn's cure research, kept in the snow so the cold keeps them asleep. |
| A misplaced change-log row sat inside the speed-mix table in game-design.md | Moved back to the change log. |

## Contradictions still open

| Contradiction | Where | Suggested fix |
| --- | --- | --- |
| Green strip lights and chevrons in the town's Deploy tunnel break "green means Fenlight" | lantern-post-assets.md, F-74 step 4 | Kept, with a reason: green points the way into the zone. Change to orange if the person prefers. |
| Four name clashes: Overclock (Serum and Implant Legendary), Second Wind (Serum and Warden P9 Legendary), Overkill (power-up and Corvid Legendary), Sentry (burst rifle and field ability) | affixes.md, game-design.md, roster | Rename the Legendaries and the ability before loot ships (design-change skill). |
| The TECHNICIAN stall says "Serums / Gear", but Serums are run items bought in maps | game-design.md Town hub | Decide with F-45; implants and gear fit, town Serums would break the run layer. |
| The Trainer (skill respec) has no keeper since the stall cast moved Dr. Corvelyn to the Technician stall | game-design.md Town hub, lore.md | Provisional: Dr. Corvelyn still does it. Decide with F-45. |
| Set per map: "Lamplighter on map 1", but the lamplighters are Grauwald's night nurses | affixes.md Sets | Proposed: Containment Detail = Halcyon, Fenlight Circuit = Kessel, Lamplighter = Grauwald. Change when sets are built. |

## Missing backstory to write later

- **Playable survivors** (F-67 character select: preset survivors with name,
  role and bio). None are in the lore yet. Write them as Lantern Post
  salvagers when F-67 is planned, one per town trade.
- **Act II and III newcomers** in town (already an open question).
- **Lore notes and radio lines**: about 12 notes and 8 radio lines per map
  are planned but none are written yet, Halcyon Labs included.

## The rule from now on

- Every new plan has a `Lore link:` line under its header (template, CI
  check in `tools/ci/check_plans.py` for Draft and Review plans).
- The Ready to build checklist, the write-plan and review-plan skills and
  AGENTS.md ask for it.
- No reason yet: add a provisional row to lore.md "Story links for game
  content" in the same PR. Story or tone choices go to the person.

No lore field on content `.tres` files: that would be data no code reads
(Keep it simple rule 1). The rule lives in plans and review instead.
