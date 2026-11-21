# Loot Affix System

Source: copy of the design doc as of Nov 14, 2026. Where this file and the code differ, the code and `docs/DECISIONS.md` win.

Every gun and gear piece rolls up to 4 affixes from slot pools, each affix in one of 5 tiers gated by item level, plus one named trait on Legendaries. Players read an item in 2 seconds: at most 5 lines under the name. This doc replaces the short affix table in the [game design doc](game-design.md) (Loot section). Item upgrading and crafting is designed in its own thread; this doc only defines the data it works on.

**Decisions in this doc.** Picks marked (provisional) are my recommendation and stand until play-tests or the person says otherwise. Three taste calls were decided by the person on 2026-11-14: affix count per rarity, full sets, and named Legendaries.

| Decision | Pick |
| --- | --- |
| Affixes per rarity | 0 / 1 / 2-3 / 3-4 / 4 + trait (chosen 2026-11-14) |
| Prefix and suffix | Prefixes = offence, suffixes = utility; at most half the lines of each kind, rounded up |
| Tiers | 5 tiers (I to V), gated at item level 1 / 8 / 15 / 22 / 30 |
| Legendaries | Named items with one fixed trait that rolls in a range (chosen 2026-11-14) |
| Sets | Full 5-piece sets, bonuses at 2/3/5, 3 sets at launch (chosen 2026-11-14) |
| Stacking | Two buckets: "increased" adds up, "more" multiplies (provisional) |
| Save format | Store tier + roll fraction, not the final number, so rebalancing updates old items (provisional) |
| Unknown affix on load | Kept as a greyed "dormant" line, never deleted (provisional) |

## Item model

An item is a base (which gun or gear piece), a rarity, an item level and a short list of rolled affixes. Nine slots carry affixes: Primary, Sidearm, Vest, Charm, Implant, Headgear, Gloves, Backpack and Boots.

- **Item level** = the round it dropped in, capped at 50 (unchanged from the design doc). It decides which affix tiers can roll.
- **Rarity** decides how many affixes, the tier bonus, and whether a trait rolls.
- **Prefix** = an offence line (damage, fire rate, elements, ability power). **Suffix** = a utility line (reload, handling, ammo, sustain, economy).
- An item holds at most half its lines as prefixes and half as suffixes, rounded up. A 3-affix item is 2+1 either way; a 4-affix item is always 2+2. This stops all-damage guns and keeps every item a trade-off.

| Rarity | Affixes | Tier bonus | Trait | Name shown |
| --- | --- | --- | --- | --- |
| Common | 0 | none | no | Base name |
| Uncommon | 1 | none | no | Base name |
| Rare | 2-3 (60% / 40%) | none | no | Generated: prefix word + base + suffix phrase |
| Epic | 3-4 (50% / 50%) | +1 tier (never above the item-level cap) | no | Generated |
| Legendary | 4 | +1 tier | 1 fixed trait, or a set bonus on set pieces | Fixed name, e.g. Tidewater |
| Prototype | 0 random | n/a | Fixed signature traits (Cryo Lance, Siphon) | Fixed name |

Generated Rare and Epic names use the highest-tier prefix and suffix, for example "Searing Vanguard AR of Quick Hands". The name is flavour only; the lines below it carry the facts.

## Weapon affixes

Weapons draw from 22 affixes: 12 prefixes and 10 suffixes, plus one free ammo line. Range = tier I low end to tier V high end; each tier owns one fifth of it. Weight is how often it rolls against the others (100 = normal). "New" marks lines not in the design doc yet.

**Prefixes (offence)**

| Affix | Text on item | Family | Range | Weight | Only on / never on |
| --- | --- | --- | --- | --- | --- |
| Damage | +X% damage | damage | 5-15% | 100 | all |
| Headshot damage | +X% headshot damage | headshot | 10-30% | 100 | never shotguns |
| Fire rate | +X% fire rate | fire\_rate | 4-10% | 80 | never bolt sniper, pump |
| Close quarters (new) | +X% damage within 8 m | range\_dmg | 8-20% | 70 | all |
| Long shot (new) | +X% damage beyond 25 m | range\_dmg | 8-20% | 70 | never shotguns, SMG |
| Elite hunter (new) | +X% damage to Brutes and specials | elite\_dmg | 10-30% | 60 | all |
| Executioner (new) | +X% damage to zombies under 30% health | execute | 15-40% | 50 | all |
| Incendiary | X% chance to ignite | element | 5-15% | 60 | all |
| Chain shock | X% chance to arc to 2 zombies | element | 5-12% | 60 | all |
| Frostbite (new) | X% chance to slow 40% for 2 s | element | 5-15% | 60 | all |
| Penetration (new) | Bullets pierce +1 zombie (X% damage after) | pierce | 40-70% | 40 | rifles, LMG, sniper, revolver only |
| Stopping power (new) | +X% stagger | stagger | 15-40% | 60 | all |

**Suffixes (utility)**

| Affix | Text on item | Family | Range | Weight | Only on / never on |
| --- | --- | --- | --- | --- | --- |
| Reload speed | +X% reload speed | reload | 8-20% | 100 | all |
| Magazine size | +X% magazine | mag | 10-30% | 100 | never bolt sniper |
| ADS speed | +X% aim speed | ads | 8-20% | 90 | all |
| Recoil control (new) | -X% recoil | recoil | 8-20% | 90 | all |
| Hip-fire (new) | -X% hip-fire spread | hipfire | 10-25% | 70 | never sniper |
| Swap speed (new) | +X% swap and sprint-to-fire speed | handling | 15-35% | 70 | all |
| Effective range (new) | +X% range before damage drop-off | falloff | 10-30% | 60 | all |
| Points per hit | +X points per hit | points | 1-3 | 60 | all |
| Leech | +X health per hit | leech | 1-3 | 60 | all |
| Shotgun pellets (new) | +X pellets | pellets | 1-2 | 50 | shotguns only |

**Ammo line (implicit, free).** Every Vault and loot gun also rolls one ammo affix that does not count toward its affix total: Deep Reserve (+30% to +200% reserve ammo), Reclaimer (kills return 15-60% of the bullets that hit) or Fabricator (refills 2-9% of a full load every 10 s). Its rarity sets its range and odds. The numbers live in the balance sheet's Loot ammo tab and the design doc; this system only treats them as kind = implicit, family = ammo, so they are never rerolled into a normal line or stacked twice. Prototypes always get Fabricator 9%.

The element family holds one element per gun, so a gun is fire, shock or frost, never two.

## Gear affixes

Each gear slot has its own job, so a player knows where to look for a stat. Vest = staying alive, Charm = economy and luck, Implant = abilities and skills, Headgear = head and aim, Gloves = handling, Backpack = carrying, Boots = moving. A small shared pool rolls on vest, charm and implant. Each of the four armour slots added by F-71 rolls exactly 2 prefixes and 2 suffixes (its pool below), with no All damage or Headshot focus. 27 gear affixes in total.

| Affix | Text on item | Kind | Slot | Range | Weight |
| --- | --- | --- | --- | --- | --- |
| Max health | +X max health | prefix | Vest, Headgear, Backpack, Boots | 10-40 | 100 |
| Damage reduction (new) | -X% damage taken from hits | prefix | Vest, Backpack, Boots | 3-10% | 70 |
| Explosion guard (new) | -X% damage from Bloaters and your own grenades | suffix | Vest | 15-50% | 60 |
| Regen delay | -X s before health regen | suffix | Vest, Headgear | 0.3-1.0 s | 100 |
| Grab escape (new) | Break free from grabs X% faster | suffix | Vest | 15-40% | 60 |
| Fast revive (new) | Revive teammates X% faster | suffix | Vest | 15-40% | 60 |
| Points earned (new) | +X% points earned | prefix | Charm | 3-10% | 80 |
| Loot luck | +X% loot luck | prefix | Charm | 5-20% | 80 |
| Power-up duration | +X s power-up duration | suffix | Charm | 2-5 s | 90 |
| Power-up chance (new) | +X% power-up drop chance | suffix | Charm | 5-15% | 60 |
| Scrap find (new) | +X% Scrap from salvage | suffix | Charm | 5-20% | 70 |
| Vault favour (new) | Vault spins have X% chance to roll one rarity higher | suffix | Charm | 2-6% | 30 |
| Ability power (new) | +X% field ability effect | prefix | Implant | 8-25% | 90 |
| Grenade damage | +X% grenade damage | prefix | Implant | 15-40% | 90 |
| Skill rank (new) | +1 rank to \[one named skill\] | prefix | Implant | +1 only, item level 15+ | 40 |
| Ability cooldown | -X% ability cooldown | suffix | Implant | 5-15% | 100 |
| Extra grenade (new) | +1 frag carried | suffix | Implant | +1 only, item level 22+ | 25 |
| Tactical recharge (new) | Tactical refills X% faster | suffix | Implant | 10-30% | 70 |
| Move speed | +X% move speed | suffix | Vest, Charm, Implant, Boots | 3-8% | 70 |
| Sprint duration (new) | +X% sprint time | suffix | Vest, Charm, Implant, Backpack, Boots | 15-40% | 60 |
| All damage (new) | +X% damage with all guns | prefix | Vest, Charm, Implant | 2-6% | 50 |
| Headshot focus (new) | +X% headshot damage, all guns | prefix | Vest, Charm, Implant | 4-12% | 50 |
| Reload focus (new) | +X% reload speed, all guns | suffix | Vest, Charm, Implant, Headgear, Gloves | 4-10% | 60 |
| Mule (new) | +X% reserve ammo, all guns | suffix | Vest, Charm, Implant, Backpack | 5-15% | 50 |
| Steady aim (F-71) | +X% aim speed, all guns | prefix | Headgear, Gloves | 3-8% | 90 |
| Recoil grip (F-71) | -X% recoil, all guns | prefix | Gloves | 3-8% | 90 |
| Quick hands (F-71) | +X% swap and sprint-to-fire speed, all guns | suffix | Gloves | 6-14% | 70 |

Gun stats on gear roll at about 40% of the gun version, so a gun's own lines always matter more. Steady aim and Recoil grip are prefixes on gear (the gun versions are suffixes) because the new slots have no damage lines. Skill rank and Extra grenade are "one value" lines: they show no range and no tier pips.

## Tiers, rolls and weights

An affix's range is cut into 5 equal tiers. Item level unlocks tiers; the roll prefers the best tier unlocked. A round 30 Epic usually shows tier IV-V lines; a round 5 Rare shows tier I.

| Tier | Unlocks at item level | Example: Damage (5-15%) | Pips on tooltip |
| --- | --- | --- | --- |
| I | 1 | 5-7% | ● |
| II | 8 | 7-9% | ●● |
| III | 15 | 9-11% | ●●● |
| IV | 22 | 11-13% | ●●●● |
| V | 30 | 13-15% | ●●●●● |

**How one item rolls** (all on the server, with the session RNG):

1. Pick rarity from the loot table and luck (as the design doc and balance sheet already define).
2. Pick the affix count for that rarity (Item model table).
3. For each line: build the pool = all AffixData whose tags fit this slot and weapon class, minus families already on the item, minus families excluded by lines already rolled, minus the kind (prefix or suffix) that is already full. Pick one by weight.
4. Pick the tier. Of the tiers unlocked by item level, the highest gets weight 40, then 30, 18, 8, 4. Epic and Legendary add +1 tier after the pick, never past the highest unlocked tier.
5. Roll q, a number from 0 to 1, evenly. Value = tier low + q × (tier high - tier low), rounded to the affix's step (1% or 0.1 s).
6. Legendary: add the fixed trait and roll its q the same way. Vault and loot guns: add the implicit ammo line.

**Weights by rarity.** Rarity changes count and tier, not which affixes appear, with one exception: lines with min\_rarity (Skill rank, Extra grenade, Vault favour, Penetration) need Rare or better. That keeps the strongest lines off early white-and-teal trash without a separate pool per rarity.

**Expected value.** At item level 30+ a line lands on average 69% of the way up the affix's full range (81% on Epic and Legendary); at item level 10 about 21%. The balance thread should model this curve next to the existing 2% damage per item level.

## Legendary traits

A Legendary is a named item with one fixed trait that changes how it plays, not just a bigger number (chosen 2026-11-14). The trait has its own range, so two copies of Tidewater are not equal and a good roll is still a chase. Traits are written as hooks (on hit, on kill, on reload, on downed) so new ones are one script plus one .tres file.

**Guns** (the four design-doc traits kept, eight added)

| Name | Base | Trait | Range |
| --- | --- | --- | --- |
| Lantern Fall | Vanguard AR | Chain Reaction: headshot kills explode for X% of weapon damage | 25-40% |
| Tidewater | Vanguard AR | Each hit on the same zombie adds +X% damage, up to 10 stacks; a new target keeps half | 3-5% |
| Bottomless | Kestrel SMG | Every Xth kill refills the magazine | 15th-10th |
| Ricochet | Mako PDW | Headshots bounce to the nearest zombie within 8 m for X% damage | 40-70% |
| Overpressure | Brenner Trench | First shot after a reload fires X× pellets | 1.6-2× |
| Cold Snap | Atlas Auto | Reloading an empty magazine freezes zombies within X m for 2 s | 3-5 m |
| Dead Man's Hand | Hollis .44 | The last round in the magazine deals X× damage and always staggers | 3-5× |
| Furnace | Halberd LMG | Fire rate ramps up to +X% over 3 s of firing; at full ramp bullets ignite | 25-45% |
| Choir Mark | Talon DMR | Kills mark zombies within 6 m for 4 s; marked zombies take +X% damage from the whole squad | 15-25% |
| Overkill | Corvid .338 | Damage left over after a kill carries into the next zombie in line, up to X zombies | 2-4 |
| Second Wind | Warden P9 | While downed, X kills with this gun revive you, once per round | 8-5 |
| Bloodline | Kestrel SMG | Hits heal X% of damage dealt while you are below half health | 2-4% |

**Gear**

| Name | Slot | Trait | Range |
| --- | --- | --- | --- |
| Quarantine Shell | Vest | The first hit every X s is fully blocked | 10-6 s |
| Iron Lung | Vest | Health regen starts instantly after a kill streak of X | 6-4 |
| Gambler's Coin | Charm | Vault spins cost 50% more but have X% chance to roll one rarity higher | 15-25% |
| Black Ledger | Charm | Carrying more than 10,000 points gives +X% damage | 5-10% |
| Overclock | Implant | X headshot kills within 3 s reset your field ability | 6-4 |
| Twin Pin | Implant | Frags split into 2 smaller frags at X% damage each | 55-70% |

Proposed traits for the 10 new bases are in [gun-roster.md](gun-roster.md) until they are built.

Ranges written high-to-low ("15th-10th", "10-6 s") are "lower is better". Each Legendary drops only on its base, so the base list in the balance sheet also sets which Legendaries exist in v0.2. Prototypes keep their fixed signature traits and no random lines.

## Sets

Full sets with 2, 3 and 5-piece bonuses (chosen 2026-11-14). A set has exactly 5 pieces, one per slot: Primary, Sidearm, Vest, Charm, Implant. Each set leans on one skill branch, so it sharpens a build instead of replacing it.

**How set pieces work**

- Set pieces are Legendary rarity with a green set name line under the item name. They roll 4 random affixes like any Legendary, but no trait: the set bonus is their trait.
- When a Legendary drops, 50% of the time it becomes a set piece instead (provisional). Each map drops only its own set (Lamplighter on map 1, and so on), so players choose which set to farm by choosing the map; which piece is weighted toward slots you don't own yet for that set (bad-luck protection, x2 weight per missing piece).
- Set guns are fixed bases (the set's AR is always a Vanguard AR), so the base list sets which guns a set uses.
- Bonuses are "more" multipliers or new behaviour, never bigger affix ranges, so a 5-piece build is strong but a well-rolled named Legendary still competes at 2 pieces.
- The tooltip shows the set block under the affixes: "Lamplighter 3/5" with each bonus lit or dimmed. Max 3 bonus lines.
- Count only distinct pieces: two copies of the same set Vest count once.

**Starter sets (v0.2)**

| Set | Branch | 2 pieces | 3 pieces | 5 pieces |
| --- | --- | --- | --- | --- |
| Lamplighter | Marksman | +15% headshot damage (more) | Headshot kills mark nearby zombies for 3 s; marked take +20% damage | Every 5th headshot is a guaranteed kill on non-elites and refunds the bullet |
| Containment Detail | Survivor | -10% damage taken (more) | Kills during a 3-kill streak heal 5 health | When you would go down, become untouchable for 3 s and heal to 50%, once per round |
| Fenlight Circuit | Tinkerer | -15% ability cooldown | Your gun's element also triggers on grenade and ability hits | Every 20 elemental procs overcharge your field ability: next use is doubled |

Three sets ship first; each map gets one, so map 4 and later maps add theirs. Balance sheet check (2026-11-14): at 30% share with all sets mixed, one set took about 150 runs, longer than reaching level 50. With one set per map and a 50% share it is about 8 set drops, roughly 30 runs on that map. Data: SetData resource plus a `set_id` on the item (see Data section).

## Skill-branch synergies

Every affix and trait carries at most one branch tag: Marksman, Survivor or Tinkerer. Skill nodes boost tagged lines by a percentage of their value, so the right loot feels better in the right build without being useless elsewhere.

| Branch | Tagged affixes and traits | Example skill node hook |
| --- | --- | --- |
| Marksman | Headshot damage, Long shot, Penetration, Recoil control, ADS speed, Choir Mark, Overkill, Lantern Fall | "Specialist": Marksman-tagged lines on your guns are 25% stronger |
| Survivor | Max health, Damage reduction, Leech, Regen delay, Grab escape, Fast revive, Close quarters, Quarantine Shell, Second Wind | "Hardened": Survivor-tagged gear lines are 25% stronger |
| Tinkerer | Elements, Ability power, Ability cooldown, Grenade damage, Tactical recharge, Extra grenade, Overclock, Twin Pin, Cold Snap | "Conductor": your field ability applies your primary gun's element |

**Skill rank affix.** The Implant line "+1 rank to \[skill\]" names one skill from the 54-point tree. It can raise a skill past its normal max by 1, and the total bonus ranks from gear are capped at +3. It only rolls skills you could have unlocked by level, so it never points at a dead node.

The skill design (P5) owns the node list; this doc only fixes the tag field and the "X% stronger" hook so skills can read it.

## Exclusions, stacking and caps

**On one item**

- One affix per family. Families are listed in the weapon table; each gear affix is its own family.
- Exclusive families: element (one of fire, shock, frost); Close quarters and Long shot share range\_dmg; Hip-fire never with Long shot on the same gun.
- Weapon class tags decide what can roll (pellets only on shotguns, no Penetration on shotguns, no Fire rate on bolt or pump).
- The implicit ammo line never counts toward the prefix or suffix limit.

**Across items (stacking).** Every stat has two buckets. "Increased" values (all affixes, skills, gear) add together. "More" values (Legendary traits, Reforger tiers, serums, Double Damage power-up) multiply. Final = base × (1 + sum of increased) × each more. Players can read a total without a calculator, and big multipliers stay rare.

**Hard caps** (in one StatCaps resource)

| Stat | Cap from all sources |
| --- | --- |
| Move speed | +15% |
| Damage reduction | 30% |
| Ability cooldown reduction | 40% |
| Loot luck | +100% (design doc) |
| Bonus skill ranks from gear | +3 |
| Fire rate (increased bucket) | +30% |
| Leech per hit | 6 |
| Max health (flat part: gear and skills) | +100; Ironhide still multiplies the base |

The character screen shows a stat in amber when it hits its cap, so wasted rolls are visible.

## Tooltips

Two views: a pickup card you read mid-wave in under 2 seconds, and a full card in menus. Numbers come first on every line, in Atkinson Hyperlegible, so the eye catches "+12%" before the words.

**Pickup card (in the world, mid-wave)**

- Line 1: name in rarity colour + item level.
- Line 2: up to 3 green or red arrows against the gun in the same slot: damage per second, handling, ammo. No affix text.
- Hold the interact key for 0.4 s to swap; tap Inspect to open the full card without picking up.

**Full card (Pack, stash, Workbench)**

```
TIDEWATER                      Legendary  iLvl 31
Vanguard AR                    DPS 812  ▲ +96
◆ Each hit on the same zombie: +4.2% dmg (10x)
  +13% damage                         ●●●●●
  +24% headshot damage                ●●●●
  +16% reload speed                   ●●●●
  -14% recoil                         ●●●
  Reclaimer: kills return 52% of hits
```

- Trait on top in Legendary orange with a diamond; random lines below, prefixes first.
- Tier pips on the right; a line at the top 5% of tier V gets a small star ("perfect").
- Ammo line last, in grey, with no pips.
- Branch tags show as a small icon only when the matching skill is learned, so the card stays short for players who don't care.
- Holding Alt shows the exact range for each line ("+13% (11-15)"), Diablo-style, for players who want it.
- A dormant line (unknown affix after an update) shows struck through in grey: "Inactive bonus".

The UI spec thread's mockups (pack\_overlay, character\_screen) should get this card layout when the loot UI is built in P6.

## Data as Godot Resources

All loot content is .tres files; adding an affix, trait or set is one file and needs no code change unless it adds new behaviour. The Content autoload builds the pools at startup by reading tags, so there is no pool list to keep in sync.

```
content/loot/affixes/weapon/dmg_pct.tres
content/loot/affixes/gear/max_health.tres
content/loot/traits/tidewater.tres        + systems/loot/traits/tidewater_trait.gd
content/loot/legendaries/tidewater.tres
content/loot/sets/lamplighter.tres
content/loot/rarities/epic.tres
content/loot/stat_caps.tres
```

| Resource | Key fields |
| --- | --- |
| AffixData | id, kind (prefix / suffix / implicit), family, exclusive\_families, slots, allowed\_tags, blocked\_tags, min\_rarity, branch\_tag, stat, op (increased / more / flat / proc), tiers: Array\[AffixTier\], weight, step, text ("+{v}% damage"), single\_value |
| AffixTier | min\_ilvl, low, high |
| TraitData | id, text, low, high, step, lower\_is\_better, allowed\_tags, branch\_tag, behaviour: Script (extends TraitBehaviour) |
| LegendaryData | id, display\_name, base\_id, trait\_id, flavour |
| SetData | id, display\_name, branch\_tag, pieces: {slot: base\_id}, bonuses: Array\[SetBonus\] |
| SetBonus | pieces\_needed (2 / 3 / 5), text, modifiers or behaviour script |
| RarityData | id, colour, affix\_count\_weights, tier\_bonus, has\_trait, set\_chance |
| StatCaps | stat to cap map |

**Runtime.** An item dict becomes an ItemInstance that turns each line into Modifier objects (stat, op, value, source). StatBlock sums the increased bucket, multiplies the more bucket, then applies caps. TraitBehaviour and set-bonus scripts subscribe to hit, kill, reload and downed signals on the owning player only, so they work the same solo and in co-op.

**Content checks** (GUT tests, run in CI): every affix has 5 tiers in rising order, tier gates match 1/8/15/22/30, no two affixes share id, every trait id used by a Legendary or Set exists, every set has exactly 5 slots filled, text has a {v} unless single\_value.

## Network and save format

The server rolls every item and sends it as a small dict; clients and save files hold only ids and roll fractions. Values are always computed from the current .tres files, so a balance patch updates every existing item (provisional; this is how Diablo-style games keep old loot in line).

```json
{
  "v": 1,
  "uid": "c3f1a9e2-7b44",
  "base": "vanguard_ar",
  "rar": "legendary",
  "ilvl": 31,
  "aff": [["dmg_pct", 5, 0.62], ["hs_pct", 4, 0.18], ["reload_pct", 4, 0.90], ["recoil_pct", 3, 0.40]],
  "imp": ["reclaimer", 0.71],
  "trait": ["tidewater", 0.55],
  "set": null,
  "craft": {}
}
```

- `aff` = \[affix\_id, tier 1-5, q 0-1\]. `imp` = the implicit ammo line. `trait` = \[trait\_id, q\]. `set` = set id or null.
- `craft` is owned by the crafting thread (rerolled line lock, upgrades). Unknown keys are kept as-is on load and save.
- `uid` is made by the server at drop time; personal loot means it is only ever sent to its owner.
- **Network.** Drops go through ProgressionService as one RPC per item, about 120 bytes as a packed array (strings become content indexes after the handshake checks both sides have the same content hash). The client never rolls.
- **Save.** Items live in `user://characters/<id>.json` inside the stash and loadout arrays, as above. No anti-cheat for now (project decision), so editing the file is possible and accepted.
- **Content changes.** A renamed id is mapped in `content/loot/id_migrations.tres` on load. A removed affix or trait stays in the dict and shows as a greyed "Inactive bonus" line; the item is never deleted. `v` bumps only when the dict shape changes, with one migration function per version.

## Hand-offs and open questions

| To | What |
| --- | --- |
| Balance sheet thread | Model the tier curve (69% / 81% of range at item level 30), the new affix counts, gear lines at 40% of gun lines, the caps table, and runs needed to finish a 5-piece set (done: about 30 runs with one set per map and a 50% share) |
| Crafting thread | Item dict fields and reroll filters (kind, family, exclusive\_families, tags, min\_rarity, tier gate); counts are now 1 / 2-3 / 3-4 / 4 + trait; set pieces have no trait to archive |
| Design doc | Replace the Loot affix table and rarity column with a link to this doc after review |
| P5 skills | Add branch-tag hooks ("tagged lines X% stronger") and allow +1 bonus rank from Implants |
| P6 build | Build order: AffixData + RarityData + roller with seeded tests, then tooltips, then traits, then sets |

Open (tuning, settled in play-tests, not blocking):

- Set share of Legendary drops: 50% and about 30 runs per set are a target, to confirm in play-tests.
- Whether Executioner and Overkill together make bosses too easy.
- Whether the pickup card needs a 4th arrow for ammo sustain.
