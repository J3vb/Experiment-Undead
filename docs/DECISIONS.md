# Decisions

Three short lists: where the game differs from `docs/design/` on purpose, what
is simplified on purpose, and agent picks the person may change. One line per
entry, at most 300 characters (CI rule `decisions-short`); the linked plan, ADR
or doc has the detail. What is built: `docs/ROADMAP.md` and `docs/plans/`.
Read the entries for the systems you touch, not the whole file.

## Differs from the design on purpose

These win over the design docs (see `docs/design/README.md`).

- **Gun damage:** every gun deals balance-sheet damage x 0.57 (AR 60 -> 34), the prototype's scale, until a balance pass resets the TTK targets. [gun-roster](design/gun-roster.md)
- **Prices:** doors and Serums use the design doc's base prices, not the balance sheet's provisional x2.5. Reforger 5000, refill 2500, Reforged wall ammo 4000 (sheet).
- **Look reference:** AgX instead of ACES; ambient energy 0.2 instead of 0.35 (baked bounce fills shadows); fog albedo light teal-grey, because Godot's fog albedo is the scatter colour. [look-rules](design/look-rules.md)
- **Co-op gear looks:** each client builds its own look and `LookSync` relays it (trusted cosmetics), replacing the server-built appearance model in gear-visuals.md. [ADR 0003](adr/0003-trusted-client-co-op.md)
- **Gear budgets:** vests light 3,000-4,500, medium 4,000-5,500, heavy 4,500-6,000 tris; charms 600-1,300; implants 1,000-1,800; first-person arms up to 10,000. Replaces gear-visuals.md's 3,000 / 300 / 500 estimates.
- **Screens folder:** screen data lives in `content/screens/`, not ui-hud.md's `content/ui/screens/`, because `Content` treats each top folder as one type. [ui-router](plans/ui-router.md)
- **Knife:** lives in `content/melee/`, not `content/weapons/`, so gun-only code (Vault, loot, grips, viewmodels) never sees it. [core-loop-gaps](plans/core-loop-gaps.md)
- **Synapse:** 50% damage to up to 3 other zombies within 6 m, replacing the roster's 60% chain; its repeated-target ramp is deferred. Cryo Lance: 3 hits freeze 2 s, the next bullet shatters for 50% within 3 m.
- **Ironwood .50:** loot only, overriding the roster's "every base is in the Vault" rule.
- **Double barrels and belts:** Reforged Coachman and Grubber keep two shells and Bastion keeps a fixed belt, overriding the +50% magazine rule; magazine affixes skip them.
- **Alt fire:** `InputFrame.ALT_FIRE` on middle mouse and R3; the planned ping and controller melee bindings are unbound. [controls](design/controls.md)
- **Wren MP:** the Long shot affix stays eligible; the roster's machine-pistol exclusion is deferred because shared affix data stays unchanged.
- **Regen delay affix:** 0.01 s step instead of the design's 0.1 s, so the equal 0.14 s tier boundaries hold.
- **Text size:** 80 to 150%, not 200%, until layouts are checked at that size. Font options (Lexend, OpenDyslexic) wait. [full-settings](plans/full-settings.md)
- **Shotgun hitstop:** the "< 4 m" condition is dropped (`hit_confirmed` has no distance); the "shake from your gun" slider at 0 also turns hitstop off. [game-feel-slice](plans/game-feel-slice.md)
- **Log autoload:** `Log` is an autoload although the architecture doc's table does not list it. [LOGGING](LOGGING.md)
- **Second Wind:** solo only; "solo" means alone in the world (`Net.is_coop()` false), so a lone listen server plays as solo. [join-any-game](plans/join-any-game.md)

## Simplified on purpose

Each says when to fix it.

- **Navmesh** bakes at load from the blocks. Fix when: the Halcyon layout settles (switch to a baked `.tres`).
- **Specimen Vault:** a fixed per-map `pool` weighted by `crate_weight`, no rarity, affixes or unlock levels; no navmesh rebake when it moves. Fix when: loot reaches the Vault.
- **Zombie AI tiers:** only the re-path interval is tiered. Fix when: the performance pass adds frame-skip and off-screen checks.
- **No Pool autoload:** impacts reuse a 48-node ring; zombies are freed after the corpse fades. Fix when: a stutter is measured. [hot-path-allocations](plans/hot-path-allocations.md)
- **Viewmodel** is a normal mesh at near plane 0.03, not a depth shader, so it can poke into walls. Fix when: wall clipping is reported in play-tests.
- **Procedural animation** for zombies and first-person guns (bob, sway, kick, reload dip). Fix when: real clips are made.
- **Range falloff** uses start and end distances, not a Curve. Fix when: a gun needs a curve.
- **Head hit zone** follows a bone posed in `_process`. Fine for trusted-client hits. Fix when: server-side hit checks or rewind need it on the physics tick.
- **Crawler** is not spawned: by design it is made when explosives take a Shambler's legs. Fix when: grenades exist (F-24, F-27).
- **Whole-tube reloads:** Brenner, Hollis and Atlas reload in one timed action. Fix when: real reload animations exist.
- **Reforger** has Tier I only and swaps instantly. Fix when: Tiers II (ammo mods) and III get a roadmap row.
- **Power-ups:** only Resupply and the Scavenger ammo pack; Scavenger's +1 grenade waits. Fix when: F-24 grenades and F-26 power-ups.
- **Window barriers:** no slot timeout (move to another barrier after 4 s), no real sill. Fix when: co-op crowding at a window needs it.
- **Emergency lighting:** dimmed red ceiling lights only, no separate fixtures or sound. Fix when: the sound world step.
- **Stuck zombies:** relocate replaces the AI doc's repath sidestep and navmesh snap; no louder groan for the last zombies (voice is local). Fix when: relocates show in soak logs.
- **Slide** keeps the normal 0.18 s sprint-out block before hip fire (weapon.gd was at its size limit). Fix when: weapon.gd is split (F-79 step 7).
- **Co-op hit bounds** use Content weapon data, not the held inventory (weapon switching is local). Fix when: a server checks loadouts (P8).
- **Loadout trust:** the server does not check that a client owns the gear it sends (friends-only servers). Fix when: public servers (P8). [item-effects-server](plans/item-effects-server.md)
- **Hold-to-buy** stays a tap. Fix when: accidental buys show in play-tests.
- **Loot extras:** no supply or exfil caches, no gun comparison in the pickup prompt, no trading; traits, sets and `proc` lines save but do not run. Fix when: their loot batches.
- **Run loadout:** the equipped Primary is not given at spawn (the round-5 Drop Locker is not built). Fix when: the Drop Locker.
- **Skill tree:** no stat effects, Trainer screen or prerequisites; the 15/25-point gates cannot be reached with only the named nodes. Fix when: the skills feature.
- **Teammate animations:** one two-handed rifle pose and one reload clip for every gun; a remote muzzle flash plays at the owner's first-person muzzle. Fix when: F-41 follow-ups.
- **First-person hands:** fingers are fixed curls, no trigger-pull or magazine clips; the Corvid bolt only kicks back. Fix when: real clips.
- **Player body:** some cloth clipping in motion, a soft face, a ragged beard bit near the ear. Fix when: F-70 step 6. [ADR 0015](adr/0015-baked-player-body.md)
- **Gear looks:** set counts, crests, dyes content and effects are not built; zombies have no dye or rarity. Fix when: their gear steps. [player-gear-concept](plans/player-gear-concept.md)
- **Music:** one generated bed and drive, no stems, stingers, ducking or `music_config.tres`. Fix when: the music step.
- **Sound:** remote players' footsteps are silent; no Foley or Tells bus, horde loop or occlusion; clients do not hear plank tears. Fix when: the sound foundation step.
- **Ambience** sends to SFX, so the Effects slider covers it; no separate Ambience slider and no power-off or Blackout bed swaps. Fix when: the audio settings pass.
- **Gore:** no stump cap, limb loss or wound decals; blood pools are quads, not Decals (Compatibility renderer). Fix when: a gore follow-up.
- **Settings:** controller rebinding, presets and action contexts wait; one key, one action everywhere; a plain Esc cancels a rebind. Fix when: controller support. [control-rebinding](plans/control-rebinding.md)
- **Hub:** one place per server, one Deploy board per map, the whole server is one squad, a listen host decides when to return. Fix when: a second map. [coop-full-match](plans/coop-full-match.md)
- **Server browser:** no Map, Players or search filters, no map picture, no password; a server goes into Recent when a join starts. Fix when: P8 servers. [join-any-game](plans/join-any-game.md)
- **Launcher:** no Windows-runner check, no drain file, no install-size readout. Fix when: F-65 step 8. [client-server-updates](plans/client-server-updates.md)
- **Game feel:** the gun in hand when a kill confirm arrives picks the hitstop class; the killed zombie's pose does not freeze; viewmodel kick stays in WeaponData. Fix when: F-42.
- **Character screen:** no drag and drop, junk marking or extra tabs. Fix when: the stash UI pass.
- **Debug console:** no god mode. Fix when: a public damage-immunity API exists.
- **Halcyon surfaces:** no lettered stencils or arrows, one planar projection instead of triplanar. Fix when: signage. [halcyon-surfaces](plans/halcyon-surfaces.md)
- **Lightmaps:** Halcyon Labs at texel scale 1.5 (not 2), F-68 bake 19.3 MiB, test budget 20 MiB (the person's call); 197-439 avg fps at 1440p High, 24 zombies. Lantern Post first bake 17.9 MiB. Fix when: Git LFS or the GPU bake step. [plan](plans/halcyon-concept-pass.md)
- **Lantern Post to the concept art:** bake ambient is the look colour, not the sky; avg fps 302-468 baked High. Street view 2,639 draw calls, not 600: each player's flashlight keeps its shadow (person's pick 2026-11-19, fps is 2.5x target). [plan](plans/lantern-post-concept.md)
- **Lantern Post stalls:** Technician, Gunsmith and Trader are Tripo models with our own sign boards; Missions keeps the code-built frame until a Tripo version exists; the Deploy gate stays code-built (person's pick 2026-11-19). [tripo-models](plans/tripo-models.md)
- **Lantern Post walls:** the whole town wall is the concrete Deploy gate wall (gate_wall sections), not the palisade of the concept; the sky mountains are three peaked ranges (person's pick 2026-11-19). [hub plan](plans/lantern-post-hub.md)
- **Wall guns:** BR-12 keeps its stock wrist (no pistol grip); surface detail is the shared shader at 8,000 tris. Fix when: F-75 baked gun textures. [guns-concept](plans/guns-concept.md)
- **Damage numbers:** Siphon shows none (damage is server-side); a host can show overkill from later pellets. Fix when: a player asks for them.
- **No Git LFS:** binaries in plain git; the lines to switch it on are in `.gitattributes`. Fix when: asset packs arrive.

## Provisional picks

Agent picks the person may change.

- **Gun feel:** falloff ranges, spread, recoil and empty reloads not in `roster.csv` (Kestrel, Talon, vault batch A1, Bastion, batch B rifles, Wren, Siphon, Cryo Lance, Synapse). Talon head x3.0 and Atlas Auto's strong DPS wait for play-tests.
- **Siphon:** 10 m/s orb, 3 s well, at most 12 zombies, 6 m pull, two live wells per player, Vault weight 0.05.
- **Wearing gear mid-run:** the piece you take off goes into the same Pack slot; swaps never heal; vest icons show the rest-pose shoulder pads ([plan](plans/wear-gear-mid-run.md)).
- **FOV:** horizontal degrees at 16:9, 70-120, default 110 (about 78 vertical); ADS FOV stays vertical.
- **Serums:** every Med Dispenser needs power; no limit on Serums held. Scavenger ammo pack chance 5% (10% gave too much ammo in the first play-test).
- **Exfil and sprint:** the 60 s exfil hold pauses, not resets, when nobody is in range; sprint refills over 3 s after stopping early.
- **Crouch** stays a toggle by default; aim and sprint default to hold.
- **Gear bases:** names (Lantern Rig ... Pell Relay), all unlocked at level 1 with drop weight 100. Skill tree rows and columns are provisional too.
- **Signal in the Static:** pitches 0.75 / 1.0 / 1.3, an 8 s hum gap, no hint text.
- **Halcyon atmosphere:** spark gaps 3-9 s and a 30 s Containment klaxon. Emergency lights at 30% red-orange, back on in a 0.6 s ragged wave.
- **Footsteps:** one step per 0.5 s walking, 0.34 s sprinting, 0.72 s crouched; landings silent under 3 m/s.
- **HUD:** XP bar placement, the 90 px / 0.6 s level-up ring, a 3-row drop feed; "Crits only" damage numbers show headshots until a crit stat exists.
- **Halcyon concept pass (F-68):** kitchen fires as the Mess Hall's warm accent, the existing hazard orange (not yellow) on the tank railings, the catwalk office not walkable, pods at leak-glow strength, one steel material on the ceiling models. Look signed off 2026-11-19.
- **Model looks:** skinned zombies, gear finishes, vest frames, first-person arms, teammate clips and the launcher screen are agent looks until the person sees them.
- **Tripo settings:** `tripo_make.py` asks for model v3.1, PBR, detailed texture, standard geometry (a 0.9 m prop: 40 credits); `body_tarp` goes in `props/`, not `dressing/` (intake prop budget 2,000). [tripo-models](plans/tripo-models.md)
- **Power-up drops:** 1% per kill, at most 1 a round (GDD 2.5%, 4), while Resupply is the deck's only power-up; raise with F-26. Resupply glows big and green, the ammo pack small and orange.
- **Hold to repair:** one plank every 0.6 s while interact is held, tap still works; the 0.3 s hold-to-buy in `controls.md` is not built.
- **Player names:** up to 16 Latin letters, digits, spaces and - _ . ' ; default "Survivor"; duplicates allowed; set on the Character screen before joining. See [player-names](plans/player-names.md).
- **Reload motion (F-85):** empty reloads press the bolt catch above the well for every gun (no charging-handle pull: crossing the receiver flipped the elbow); the tactical swap shows the same magazine low in frame. Feel check in step 4. [reload-animations](plans/reload-animations.md)
- **BR-12 Reforged reload (F-85):** keeps the base shell times like every Reforged gun keeps its reload, so its 9 shells take 5.1 s from empty (was 3.6 s for a full reload). [reload-animations](plans/reload-animations.md)
