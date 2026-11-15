# Experiment Undead: Gun Roster

The plan for every base gun in version 1: what each one is for, where you get it, when it starts dropping, which affixes and Legendary it leans on, and the order to build them. Numbers are in [balance/roster.csv](balance/roster.csv). Where this file and the code or `docs/DECISIONS.md` differ, the code and DECISIONS win.

## Decisions

| Decision | Choice | Status |
| --- | --- | --- |
| Roster size | **22 base guns**: the 12 in the design doc plus 10 new | Chosen 2026-11-15 |
| Projectile weapons (crossbow, grenade launcher) | **No, bullets only.** Every gun is hitscan, so no projectile system is needed. Explosives stay with grenades and the Siphon | Chosen 2026-11-15 |
| Everything else in this file (names, stats, sources, unlock levels, traits, build order) | Recommended picks | Provisional |

## How loot uses the roster

A base gun is a model, a handling feel and a niche. Loot does not add new guns; it rolls versions of these bases: rarity, item level, affixes, an ammo line and on Legendaries a fixed trait (see [affixes.md](affixes.md)). So two Kestrels can play very differently, but a Kestrel never plays like a Talon. More bases means more kinds of drops worth reading, which is why 22 and not 5.

- **Wall guns** are always Common, item level 1. They are the safety net and the point farm, never the endgame.
- **Every non-Prototype base also drops as loot**, wall guns included, and every base can roll from the Specimen Vault.
- **Prototypes** (Cryo Lance, Siphon, Synapse) only come from the Vault (0.5%), zombie drops (0.1%) and map secrets.

## The 22 guns

Status: **designed** = already in the design doc and `weapons.csv`; **new** = added by this plan. Damage is balance-sheet damage (the game uses x 0.57 for now, see the README).

### Sidearms (4)

The loadout has a Sidearm slot, so it needs real choice, not just the start pistol.

| Gun | Status | Class | Niche: why you pick it | Source |
| --- | --- | --- | --- | --- |
| Warden P9 | designed | Pistol, semi | Free start gun, cheap points per hit early | Start |
| Hollis .44 | designed | Revolver | One huge shot, staggers, slow | Loot / Vault |
| Wren MP | new | Machine pistol, auto | Panic spray in a sidearm slot; empties a 20 mag in 1.2 s | Wall on Grauwald; loot |
| Grubber | new | Sawn-off double shotgun | A shotgun in the sidearm slot: two blasts, then reload | Loot / Vault |

### SMGs (3)

| Gun | Status | Class | Niche | Source |
| --- | --- | --- | --- | --- |
| Kestrel SMG | designed | SMG, auto | Mobile hip fire, best point farm | Wall, all maps |
| Mako PDW | designed | SMG, burst | Burst headshots up close, big mag | Loot / Vault |
| Nightjar SD | new | Suppressed SMG | Head x3, low recoil and **no muzzle flash**, so it keeps your view clear in Blackout rounds | Loot / Vault |

### Rifles (4)

| Gun | Status | Class | Niche | Source |
| --- | --- | --- | --- | --- |
| Vanguard AR | designed | Assault rifle, auto | The all-rounder everything is measured against | Wall, all maps |
| Sentry | new | Burst rifle | Three-round bursts; rewards mid-range headshots more than the AR | Loot / Vault |
| Rampart BR | new | Battle rifle, auto | Heavy 95-damage rounds at 480 rpm, big stagger, slower to move and aim | Wall on Marrow Junction; loot |
| Fieldhand | new | Lever-action rifle | Hard hits (150, head x3) that pierce one zombie, full move speed, rounds load one by one | Wall on Kessel Dam; loot |

### Marksman and snipers (3)

| Gun | Status | Class | Niche | Source |
| --- | --- | --- | --- | --- |
| Talon DMR | designed | Marksman, semi | Fast precise headshots at range | Wall, all maps |
| Corvid .338 | designed | Bolt sniper | 600 damage, head x4: kills specials and Brutes | Loot / Vault (Rare or better) |
| Ironwood .50 | new | Anti-materiel, semi | 450 damage, pierces 2 zombies, breaks the Brute head plate in one hit | Loot / Vault (Rare or better) |

### Shotguns (3)

| Gun | Status | Class | Niche | Source |
| --- | --- | --- | --- | --- |
| Brenner Trench | designed | Pump shotgun | Close panic gun, one-shots early rounds | Wall, all maps |
| Coachman | new | Double-barrel | Two 10-pellet barrels; alt fire shoots both at once and knocks zombies back | Wall on Halcyon Labs; loot |
| Atlas Auto | designed | Auto shotgun | Crowd shredder that eats ammo | Loot / Vault |

### Machine guns (2)

| Gun | Status | Class | Niche | Source |
| --- | --- | --- | --- | --- |
| Halberd LMG | designed | LMG, mag-fed | 100-round mag to hold a lane, slow | Loot / Vault (Rare or better) |
| Bastion | new | Belt-fed LMG | 150-round belt, fire rate spins up over 0.5 s, slowest gun to move with and reload | Loot / Vault (Rare or better) |

### Prototypes (3)

Oriel test weapons with live Fenlight. Fixed signature traits, no random affixes, always Fabricator 9%.

| Gun | Status | Signature | Source |
| --- | --- | --- | --- |
| Cryo Lance | designed | Freezes, then shatters | Vault, drops, Halcyon secret |
| Siphon | designed | Gravity well pulls and crushes up to 12 zombies | Vault, drops |
| Synapse | new | A continuous beam that jumps along the Fenlight in the nerves: hits chain to up to 3 nearby Lit, and the beam ramps damage while it stays on target. Hitscan, so it fits "bullets only" | Vault, drops |

## Wall guns per map

Every map keeps the same four shared wall guns, so players always know their safety net: Brenner Trench 750, Kestrel SMG 1000, Vanguard AR 1200, Talon DMR 1500. The maps doc already allows 4 to 5 wall guns, so each map adds **one signature wall gun** that suits its layout:

| Map | Signature wall gun | Cost | Why it fits |
| --- | --- | --- | --- |
| Halcyon Labs | Coachman | 900 | Tight corridors and the Mess Hall loop |
| Kessel Dam | Fieldhand | 1300 | Long sightlines and the 120 m Valve Gallery, where pierce lines zombies up |
| Marrow Junction | Rampart BR | 1400 | Wide freight yard with mid-range lanes |
| Grauwald Sanatorium | Wren MP | 900 | Wards and side rooms; a cheap sidearm upgrade |

Placement in each map (which area) belongs to the maps doc; this plan only names the gun. A signature wall gun teaches the gun on that map before it starts dropping everywhere.

## When guns start dropping (unlock levels)

A base only drops (zombies, caches, Vault, exfil) once your character reaches its unlock level. Wall guns can always be bought. This spreads "new gun" moments over the first 30 runs instead of dumping 22 bases on a level 1 player. Runs-to-level comes from `xp_and_levels.csv`.

| Level | About runs | Bases added to the drop pool |
| --- | --- | --- |
| 1 | 0 | Warden P9, Brenner Trench, Kestrel SMG, Vanguard AR, Talon DMR, Hollis .44, Mako PDW, Atlas Auto, and the 3 Prototypes |
| 5 | 1 | Wren MP, Coachman |
| 8 | 2 | Fieldhand, Halberd LMG |
| 10 | 3 | Sentry |
| 12 | 5 | Rampart BR, Corvid .338 |
| 16 | 10 | Grubber, Nightjar SD |
| 20 | 17 | Bastion |
| 25 | 29 | Ironwood .50 |

The first drop of a new base shows a short "New weapon" banner on pickup. Base pick inside the drop pool uses the Drop weight column (100 normal, lower for heavy guns); Prototypes use their own 0.1% / 0.5% rarity rolls. Before loot exists (v0.1), the Vault keeps its map `pool` from DECISIONS and ignores levels.

## Affixes and Legendaries per gun

Loot tags decide which affixes can roll (rules in [affixes.md](affixes.md), Exclusions). The new tags and what they exclude:

| Tag | On | Excludes |
| --- | --- | --- |
| `double` | Coachman, Grubber | Fire rate, Magazine size (a 2-round gun gains nothing), Headshot damage (shotgun rule) |
| `lever` | Fieldhand | Nothing extra; Penetration stacks with its innate pierce |
| `burst` | Sentry, Mako PDW | Nothing extra |
| `suppressed` | Nightjar SD | Nothing extra |
| `belt` | Bastion | Magazine size (belt length is fixed) |
| `anti_materiel` | Ironwood .50 | Fire rate, Hip-fire, Magazine size (like bolt snipers) |
| `machine_pistol` | Wren MP | Long shot |

Proposed Legendary traits for the new bases, written as hooks like the existing twelve. Ranges follow the same "a good roll is still a chase" rule.

| Name | Base | Trait | Range | Branch |
| --- | --- | --- | --- | --- |
| Last Word | Wren MP | Swapping to this gun refills X% of its magazine from reserve | 50-100% | Survivor |
| Gravedigger | Grubber | A shot that kills X zombies reloads both barrels instantly | 3-2 | Survivor |
| Kicking Mule | Coachman | Both-barrel alt fire knocks zombies back X m and staggers Brutes | 2-4 m | Survivor |
| Long Furrow | Fieldhand | Each kill without reloading adds +X% damage for the rest of the tube | 6-10% | Marksman |
| Breakwater | Rampart BR | Hits slow by X%, stacking 5 times; at 5 stacks the zombie is rooted for 1 s | 6-10% | Tinkerer |
| Triple Tap | Sentry | If all 3 rounds of a burst hit the head, the next burst is free and deals +X% | 20-40% | Marksman |
| Hush | Nightjar SD | Kills with this gun do not draw the next spawn toward you for X s | 3-6 s | Survivor |
| Iron Rain | Bastion | At full spin-up, every Xth bullet chains shock to 2 zombies | 10th-6th | Tinkerer |
| Plate Splitter | Ironwood .50 | Hits on Brutes and specials leave a weak spot: +X% damage from the whole squad for 4 s | 20-35% | Marksman |

Hush needs the spawner to steer spawns toward players (zombie-ai doc); if it does not, swap the trait for one that does not.

**Sets.** Set guns are fixed bases. Each later map's set should use that map's signature wall gun as its set primary (Kessel Dam set on the Fieldhand, Marrow Junction on the Rampart BR, Grauwald on the Coachman or Wren MP), so farming a map and learning its gun go together. Provisional.

## Balance shape

From `roster.csv` (hs_ratio 0.3, every shot hits, reloads included):

- **Sustained DPS bands.** Starter and sidearms 210-310. Wall primaries 280-560. Loot-only primaries 440-725. Heavy rare guns (Halberd 702, Bastion 834) sit on top but are the slowest to move, aim and reload. This keeps the GDD rule: a fresh wall gun is fine to round 10, loot is what carries you past it.
- **Burst guns lie in DPS.** Coachman shows 1,267 body DPS for 0.3 s, then a 2.6 s reload; sustained it is 344, like the Brenner. Judge shotguns by sustained DPS and pellets per kill, not the burst column.
- **Signature wall prices** follow DPS per 1000 points of the shared walls (400-640), with the Coachman and Fieldhand outside the band on purpose: the Coachman is cheap but only two shots, the Fieldhand is weak on paper but pierces.
- **To check in play:** Fieldhand may need more damage if pierce does not make up for its low DPS; Bastion may need a smaller belt if it makes the Halberd pointless.

When a gun gets built, move its row into the balance workbook's Weapons tab (`build_balance_sheet.py` in the project files) so TTK, ammo and price tabs pick it up.

## Build order and cost per gun

Each gun needs: a model script using `tools/assets/gun_parts.py` (PR #65), a `WeaponData` .tres and its `*_reforged.tres`, a viewmodel scene, a generated fire sound, a `FeelData` entry, an approved turnaround render, and tests (content test + model checks). A plain hitscan gun on existing mechanics is about one thread (S). A gun that needs a new mechanic is M.

| Batch | When | Guns | New mechanic | Size |
| --- | --- | --- | --- | --- |
| A0 | Done or in PR #65 | Warden P9 (as M-9), Brenner Trench, Kestrel SMG, Vanguard AR (as AR-7), Talon DMR | - | - |
| A1 | P3, Vault pool for v0.1 | Hollis .44, Mako PDW, Atlas Auto, Halberd LMG, Corvid .338 | None (burst and scope exist) | 5 x S |
| A2 | P3 | Cryo Lance, Siphon | Freeze/shatter, gravity well | 2 x M |
| B | P6 loot, after A | Wren MP, Coachman, Fieldhand, Rampart BR, Grubber, Sentry, Nightjar SD | Shell-by-shell reload (also fixes the Brenner), both-barrels alt fire, innate pierce, no-flash flag | 4 x S, 3 x M |
| C | P6 to P10 | Bastion, Ironwood .50, Synapse | Fire-rate ramp (shared with the Furnace trait), pierce 2 + plate break, continuous beam with chain | 3 x M |

Build A1 first: the Vault in v0.1 needs those guns and they need no new code. Signature wall guns in batch B land with their map, except the Coachman, which can go on Halcyon Labs as soon as it is built.

## Open items

- The game uses prototype names that differ from the design: `rifle_ar` "AR-7" (design: Vanguard AR) and `pistol_service` "M-9 Service Pistol" (design: Warden P9). Decide whether to rename in game; `sync.csv` already flags the pistol.
- The 12 designed guns keep their GDD numbers here; only the 10 new rows are new numbers.
- Map threads place the signature wall guns; the Halcyon Labs Coachman needs a wall spot outside the Loading Dock (the start already has the Brenner).
