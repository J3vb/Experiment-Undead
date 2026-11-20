# Fenlight: Sound Design

Source: copy of the design doc as of Nov 14, 2026. Where this file and the code differ, the code and `docs/DECISIONS.md` win.

## At a glance

Sound has one job above all others: tell you where the danger is before you see it. Guns come second and must feel heavy and loud. Everything else (music, ambience, UI) sits under those two and ducks out of the way when they speak.

- **Mood:** cold, clinical, industrial. Humming machines and dripping concrete, broken by close, dry, violent gunfire.
- **Guns:** 4 layers per shot (mechanical, body, low-end punch, room tail) plus a far layer heard by other players. Tail picked by the room you stand in.
- **Zombies:** 5 vocal sets. Every attack has a 3D warning sound that cuts through the mix. Only the 8 nearest zombies may vocalise at once.
- **Music:** 4 stacked stems that fade in as a round gets harder, plus stingers for round start, round end, Brute and Blackout.
- **Loot:** one drop sound per rarity, rising in pitch and length. Legendary and Prototype get a beacon loop you can hear through walls.
- **Tech:** Godot 4 bus tree with sidechain ducking, Area3D reverb zones, a pooled `SoundManager` with priorities and a hard cap of 48 voices.
- **Sourcing:** CC0 and royalty-free packs first, Python synth scripts for UI and stingers, small home recordings for foley. Every file logged in `ASSET_SOURCES.md`.

## Audio pillars and mood

Four audio pillars, each tied to a game pillar. When two sounds fight for space, the higher pillar wins.

1. **Danger is always readable** (pressure always builds). Any zombie that can hurt you in the next second makes a sound you can locate with headphones. No silent attacks, ever.
2. **Guns hit hard** (guns feel great). Every shot has weight, every hit and kill has a clear confirm sound. Guns are the loudest thing you make.
3. **The world breathes cold** (Cold Containment). Rooms hum, drip and creak. Mostly mid and low frequencies, little high sparkle, so the danger cues have room on top.
4. **Progress sounds rewarding** (every run makes you stronger). Level-ups, loot and buys are warm and bright, the only warm sounds in a cold world, the same way the warm lamps break the teal.

**Mood words:** sterile, pressurised, failing machinery, quarantine. **Not:** horror-movie jump scares, orchestral heroics, cartoon splats.

**Palette.** Cold side: teal-coloured sounds such as fluorescent buzz, HVAC, metal resonance, sub hums. Warm side: tape-saturated synth pads and soft bells for rewards. Bio-green accent: wet, organic, bubbling textures reserved for serums, Bloaters, Prototype loot and the Specimen Vault.

## Gun sounds

A shot is built from separate layers that play together, not one baked file. That lets one set of tails serve every gun, and lets a new gun reuse the body and punch of its class.

| Layer | What it is | Length | Heard by | Variations |
| --- | --- | --- | --- | --- |
| Mechanical | Bolt, hammer, action clack. Gives the gun its identity | 50-150 ms | Shooter only (2D) | 4 |
| Body | The crack of the shot itself | 100-250 ms | Shooter 2D, others 3D up to 40 m | 6 |
| Punch | Sub thump below 120 Hz | 80-150 ms | Shooter only | 2 per class |
| Room tail | Reflections of the room you are in | 0.4-2.5 s | Shooter 2D, others 3D | 3 per room type per class |
| Far | Dull, low-passed pop for distant shots | 0.5-1.5 s | Others beyond 40 m | 3 per class |

**Variation.** Each layer picks a random file (never the same one twice in a row), plus ±3% pitch and ±1.5 dB volume. Full-auto adds a subtle pitch drop of 2% over the first 10 shots, then holds, so long sprays feel heavier without sounding like a different gun.

**Classes.** Pistol, SMG, rifle, shotgun, LMG, sniper, launcher, Prototype. A new gun picks a class and only needs its own mechanical layer. Prototype guns (Cryo Lance, Siphon) skip the crack and use designed energy sounds, but keep a punch and a tail so they still feel physical.

**Room tails.** Five room types, set on reverb Area3D zones (see the Godot section). The tail of the zone the shooter stands in plays.

| Room type | Example | Tail length | Character |
| --- | --- | --- | --- |
| Small | Offices, train carriages, cells | 0.4 s | Dry, boxy slap |
| Corridor | Halcyon corridors, sanatorium wards | 0.8 s | Bright flutter echo |
| Hall | Mess hall, turbine hall, Rotunda | 1.6 s | Big, metallic bloom |
| Outdoor open | Rail yard, dam crest | 2.0 s | Thin slap, long rolling decay |
| Outdoor gorge | Kessel spillway and gorge | 2.5 s | Distinct echo off the far wall at about 300 ms |

**Reload foley.** 4 to 6 short sounds per gun, fired by animation keyframes, never by a timer, so they always line up. Standard set: mag release, mag out, mag pouch rustle, mag in, bolt or slide, plus a cloth and armour rustle on every reload start. Empty reloads add the bolt release as a separate, louder sound because it means "ready to fire". Shotgun: one shell-in sound per shell with 4 variations.

**Other gun cues.**

- Low ammo: the last 25% of a mag adds a thin, higher click to the mechanical layer (from the design doc, now 25% instead of 5 rounds so it scales with magazine size).
- Dry fire: a hollow click, plus the ammo counter flashing.
- Hitmarker: a short, dry tick on body hits, a brighter ping on headshots, a deep thud on kills. Kills on Brutes and Specimens add a heavy crunch. These are the loudest 2D sounds after the shot itself, ±4% pitch, at most one every 45 ms. Cue ids are shared with the game feel doc: hit\_body, hit\_head, hit\_armour, hit\_crit, kill\_confirm, kill\_head, kill\_multi, player\_hurt, hit\_taken, revived, round\_last\_kill, level\_up, weapon\_get.
- Bullet impacts: impact\_concrete, impact\_metal, impact\_glass, impact\_wood, impact\_dirt, impact\_water, impact\_flesh, impact\_armour, plus impact\_snow for Grauwald. 4 variations each, played at the hit point in 3D.
- Casings: 3 bounce sounds per surface, quiet, only for the local player.
- ADS: a short cloth and metal rustle in and out.

## Zombie sounds and danger tells

Each zombie type has a vocal set with a clear silhouette: you should name the type with your eyes closed. Tells are separate from idle vocals, use the Tell bus (never ducked, never voice-stolen) and are 4 to 6 dB louder than anything else at the same distance.

| Type | Idle and chase | Tell (warning) | Attack | Death | Footsteps |
| --- | --- | --- | --- | --- | --- |
| Shambler | Low groans, wet breaths, 8 variations, 3-7 s apart | Short snarl 0.4 s before a swipe | Swipe whoosh + grunt | Collapse gurgle | Dragging shuffle |
| Crawler | Rasping hiss, 4 variations | Constant scrape loop on the floor (the tell is always on) | Bite snap | Choked hiss | Hand slaps and scrape |
| Bloater | Deep gurgling, belly sloshing, slow 2-4 s cycle | Gurgle rises in pitch below 25% health; a 0.5 s inhale before it bursts | Belch spray | Wet burst + gas hiss loop for the 6 s cloud | Heavy, wet thuds |
| Stalker | Clicks and chitter on walls and ceilings, 6 variations | Rising shriek exactly 1.0 s before a pounce | Pounce scream + impact | Snapped shriek | Fast scratching on surfaces |
| Brute | Slow, huge breaths, chain rattles | Ground-shaking roar + foot stamp 1.2 s before a charge | Charge thunder + impact crunch | Long roar into a body slam | Thuds you feel (sub bass) |

**Telegraphing rules.**

- Every attack plays its tell first. Tell timing matches the gameplay wind-up in the design doc and is driven by the same animation event.
- Tells come from the zombie's exact 3D position, with full panning. Ceiling and wall Stalkers use a slight high-shelf boost so height reads as "above".
- A zombie within 2 m behind you plays a close breath layer. This is the main "behind you" warning.
- Brute spawn: a distant roar plus a ground rumble on the whole map, then the Brute stinger. Footsteps carry 40 m so you track it.
- Window and barricade breaks: wood crack, metal tear, each audible 30 m away, so you know which window fell.
- Specimen Vault release: an alarm klaxon plus pressure hiss at the vault, heard across the map.
- Pressure ramp: from round 15, more zombies per vocal cycle and shorter gaps (3-7 s down to 2-4 s). The horde gets denser by ear, not just by count.

**Hit reactions.** Flesh impact on every hit, a bone crack on headshots, a meaty splat on limb loss (creates Crawlers). Shared by all types, pitched down for Bloater and Brute.

**Variety.** Plan 120 to 160 zombie vocal files for v1.0: about 30 per type. A vocal never repeats on the same zombie twice in a row, and two nearby zombies never start the same file within 0.5 s.

## Music and round stingers

Music is dark synth plus industrial percussion, at 100 BPM in D minor for every combat track so stems and stingers always line up. Each map has its own track built from the same 4-stem recipe, so the system never changes per map.

**Adaptive layers.** One `AudioStreamSynchronized` per map with 4 stems that all loop together. Each stem's volume follows a single intensity value from 0 to 1, smoothed over 2 s so it never jumps.

| Stem | Fades in at intensity | What it adds |
| --- | --- | --- |
| 1. Bed | 0.0 (always on in rounds, -18 dB) | Drone, sub pulse, map texture |
| 2. Pulse | 0.3 | Arpeggio and hi-hat ticks |
| 3. Drive | 0.6 | Industrial drums and bass line |
| 4. Peak | 0.85 | Distorted lead and metal hits |

**Intensity formula** (tuned in `music_config.tres`, not code): 40% from zombies within 15 m (0 at none, full at 8), 30% from round number (full at round 25), 30% from your missing health. Blackout rounds and a living Brute add a flat 0.25. Downed or alone in co-op locks the Peak stem off and boosts Bed, so the music goes cold and lonely.

**Between rounds.** The combat stems fade out over 3 s. A separate calm breather loop (warm pad, slow, 70 BPM) plays at low volume while you shop. It is the only warm music in a run.

**Stingers** (one-shots on the Stinger bus, quantised to the next beat where they overlap music):

| Event | Sound | Length |
| --- | --- | --- |
| Round start | Low taiko-style drum + metal scrape + a short alarm tone. Pitched up 1 semitone every 5 rounds, capped at round 30 | 2.5 s |
| Round end | Rising choir-like synth swell resolving to a warm chord, then the breather loop | 3 s |
| Every 5th round end | Same swell plus a deeper bell, a small "milestone" moment | 4 s |
| Brute spawn | Distorted brass hit and sub drop, music jumps to Drive | 2 s |
| Blackout start | Power-down whine, all ambience cuts, a heartbeat-like pulse replaces the Bed | 3 s |
| Power on | Big relay clunk, generators spin up, lights hum on | 3 s |
| Exfil open | Siren + radio crackle, music switches to an exfil-only track | 4 s |
| Run over | Music cuts, single low drone and a tape-stop | 4 s |

**Rules.** Music never plays louder than -14 LUFS short-term in combat, and is ducked 6 dB under gunfire and tells. A music volume slider and a "music off in combat" toggle are in the audio settings.

## UI, buys and loot

UI sounds are short, dry and soft-edged so they never mask a tell. Rewards are the warm exception.

**Loot drops by rarity.** Each tier is higher, longer and wider than the one below, so you know the rarity before you look. Sound plays in 3D at the drop point when it lands.

| Rarity | Drop sound | Length | Extra |
| --- | --- | --- | --- |
| Common (white) | Soft cloth and plastic thud | 0.3 s | None |
| Uncommon (teal) | Thud + single glassy tick | 0.5 s | None |
| Rare (blue) | Thud + two-note chime, rising | 0.8 s | None |
| Epic (purple) | Thud + three-note chime + shimmer tail | 1.2 s | Quiet hum loop until picked up, 10 m range |
| Legendary (orange) | Heavy metal clank + warm brass-like chord + shimmer | 2.0 s | Beacon pulse loop every 2 s, heard through walls up to 30 m, plus a 2D sting for whoever it belongs to |
| Prototype (bio-green) | Pressure hiss + wet, bubbling chord + choir note | 2.5 s | Bio beacon loop, 40 m, plus a unique 2D sting |

Pick-up sound mirrors the tier: one short version of the drop chime. Salvage: a short metal crunch.

**Buys and machines.**

| Event | Sound |
| --- | --- |
| Wall buy, door, debris | A heavy mechanical latch + a warm confirm blip. Doors add their own servo or hinge |
| Not enough points | Low two-note buzz, quiet |
| Serum machine | A looping machine hum + bubbling, no jingle. Drink: glass clink, gulp, warm swell |
| Reforger | Industrial press, sparks, 4 s build then a resonant hit |
| Power-up drop | Bright synth arpeggio loop at the drop point, with a pickup sting and a UI swoosh for the team |
| Points earned | Very quiet tick, rate-limited to 10 per second |

**Menus and HUD.** Hover tick, confirm click, back click, tab swipe, error buzz. Level-up: a warm rising chord plus a soft bell, the most rewarding sound in the game. Skill point spent: a short locked-in clunk. All UI goes through the UI bus and plays when the game is paused.

## Map ambience

Each map has 3 ambience layers: a **bed** (one long 2D stereo loop, 60 to 120 s), **emitters** (3D loops placed on machines, pipes, water), and **one-shots** (random 3D sounds every 8 to 25 s from points around the player). Power-on and Blackout swap the bed, which is the main way the map sounds alive or dead.

| Map | Bed before power | Bed after power | Emitters | One-shots | Blackout |
| --- | --- | --- | --- | --- | --- |
| Halcyon Labs | Emergency-light buzz, low air hiss | Generator hum, HVAC, server fans | Fluorescent tubes, coolant pipes, specimen tanks bubbling | Distant alarm, dripping, vent clangs, PA static | All hum cuts, only drips and zombie breathing remain |
| Kessel Dam | Wind in the gorge, distant water | Turbine drone, transformer buzz | Spillway roar (louder by the water), pipe groans, cable creak | Falling debris, steel creak, wind gusts | Turbines spin down, wind and water take over |
| Marrow Junction | Open wind, distant city hum, rail ticking | Signal box hum, yard lights buzz | Loco idle, hissing brakes, PA horn on the hospital train | Freight car bangs, chain clank, distant train horn | Lights pop off one by one, wind rises |
| Grauwald Sanatorium | Snow wind on windows, old radiators knocking | Boiler roar, old electric lights hum | Radiators, iron-lung style pumps, a gramophone loop in one ward | Floorboard creaks, doors swinging, distant cough-like echoes | Wind howl, the heaviest Blackout of the four |

**Events.** Kessel spillway flood: a rising roar over 6 s, then rushing water emitters along the flood path. Marrow loco ride: engine loop, rail clatter in 4-beat pattern, brake screech on stop. Grauwald lockdown shuffle: bolt slams on each door that changes, with a PA chime first.

**Town hub (Lantern Post).** No combat bed. Warm lamps buzzing, a low murmur from vendors, a radio playing the breather music, footsteps on wood. The safest-sounding place in the game.

**Rule.** Ambience sits at -28 to -32 LUFS, under everything. It is never silenced fully in combat, only ducked 4 dB, because silence makes zombie sounds feel cheap.

## Godot setup: buses, 3D sound, reverb

All of this lives in `audio/default_bus_layout.tres` and `audio/sound_config.tres`, so tuning is data, not code.

**Bus tree.**

- **Master**: HardLimiter at -1 dB ceiling
  - **Music**: compressor sidechained from Duck\_Key, -6 dB under guns and tells
  - **Stinger**: no ducking
  - **UI**: no ducking, keeps playing when paused
  - **Ambience**: compressor sidechained from Duck\_Key, -4 dB
  - **SFX**: light glue compressor (2:1)
    - **Weapons\_Local**: your own gun and reload. Sends to Duck\_Key. Hitmarkers sit on their own Hitmarkers bus beside it, for the Hit and kill slider
    - **Weapons\_World**: teammates' guns, far layers, explosions
    - **Tells**: zombie warnings, Brute roar, vault alarm. Never ducked. Sends to Duck\_Key
    - **Zombies**: idle, attack, death, footsteps. Compressor sidechained from Weapons\_Local, -3 dB
    - **Impacts**: bullet hits, gore, breakables
    - **Foley**: your footsteps, movement, cloth
    - **World**: ambience emitters, doors, machines, events
  - **Reverb\_Small, Reverb\_Corridor, Reverb\_Hall, Reverb\_Outdoor, Reverb\_Gorge**: one AudioEffectReverb each, fed by Area3D zones, output to SFX
  - **Duck\_Key**: muted bus used only as the sidechain source

**3D attenuation** (AudioStreamPlayer3D settings per category, Doppler off everywhere):

| Category | Model | unit\_size | max\_distance | High-cut by distance |
| --- | --- | --- | --- | --- |
| Tells | Logarithmic | 6 | 45 m | Mild, keeps clarity far away |
| Brute steps, roars | Logarithmic | 8 | 60 m | Mild |
| Zombie vocals | Inverse | 3 | 25 m | Default |
| Zombie footsteps | Inverse square | 2 | 15 m | Strong |
| Others' gunfire (body) | Logarithmic | 10 | 40 m, then far layer to 150 m | Strong past 20 m |
| Bullet impacts | Inverse | 2 | 20 m | Default |
| Loot beacons | Logarithmic | 4 | 30 to 40 m | None |
| Ambience emitters | Inverse | 2 to 6 | 10 to 30 m | Default |

**Reverb zones.** Every room in a map's blockout gets an Area3D on physics layer 9 with `reverb_bus_enabled = true`, the right Reverb bus, and `reverb_bus_amount` 0.3 to 0.6. The map validation test fails if a walkable area has no reverb zone. Room type also tells the gun system which baked tail to play. Your own gun and its tail use a 2D player and skip the zone reverb, so tails are never doubled.

**Occlusion.** Godot has no built-in occlusion, so `SoundManager` casts one ray from the camera to each Tell, Brute and gunfire voice, 10 times per second, spread across frames. Blocked: -6 dB and the high-cut drops to 1.5 kHz over 0.15 s. Other categories skip this to save CPU.

## Voice limits and performance

A hard cap of 48 sound-effect voices at once, split into the category caps below (they add up to 48; music and the ambience bed are extra and fixed). Zombies never own an audio player: they ask `SoundManager` for one, and it hands out a pooled player or refuses. That keeps audio cost flat whether there are 24 zombies or 60 with 8 players. Target: audio thread under 0.5 ms per frame at 120 fps.

| Category | Max voices | Priority (high wins) | When full |
| --- | --- | --- | --- |
| Your gun, reload, hitmarkers | 8 | 100 | Steal your own oldest tail |
| Tells | 6 | 95 | Never stolen. A 7th tell steals the farthest idle zombie voice instead |
| Stingers, UI | 4 | 90 | Drop the new one |
| Others' gunfire | 6 | 70 | Steal the farthest |
| Zombie vocals (idle, attack, death) | 8 | 50 | Steal the farthest or quietest |
| Zombie footsteps | 6 | 30 | Only the 6 nearest zombies make steps |
| Impacts and gore | 4 | 40 | Steal the oldest |
| Ambience emitters | 6 | 20 | Only the 6 nearest emitters play |
| Music and bed | 6 streams (fixed) | n/a | Always on |

**The horde trick.** Only the 8 nearest zombies vocalise. Everything beyond them becomes one stereo **horde loop** (a crowd of groans) whose volume and low-pass follow how many zombies are within 30 m. One voice sounds like 40 zombies, and the count you hear still rises with pressure.

**Other rules.**

- Players are made once at load: 64 AudioStreamPlayer3D and 16 AudioStreamPlayer in a pool. No `new()` or `queue_free()` during play.
- Same sound within 40 ms of itself is merged (for example 6 shotgun pellets hitting concrete play 2 impacts, not 6).
- Sounds below -60 dB after distance are not started at all.
- Formats: short sounds as WAV with QOA compression (Godot 4.3+), loops, music and long ambience as Ogg Vorbis at quality 6. 48 kHz mix rate.
- Dedicated servers run headless with the Dummy audio driver: no sound work on the server, events are replicated and played on clients.
- A debug overlay (F9) shows active voices per category, steals per second and audio thread time.

## Mixing priorities

When the mix gets crowded, this order decides who stays clear. Higher rows duck lower rows, never the other way round.

1. **Tells** (Stalker shriek, Brute roar, Bloater inhale, close breath behind you)
2. **Your gunshot and hit confirms**
3. **Damage taken and low-health heartbeat**
4. **Stingers and loot beacons** (Legendary and up)
5. **Teammates' guns and pings**
6. **Zombie vocals and footsteps**
7. **Impacts, gore, foley**
8. **Music**
9. **Ambience**

**Target levels** (measured on a 30 s round-15 capture, headphones): full mix -16 LUFS integrated, true peak below -1 dBTP. Your gunshot peaks around -3 dBFS. Ambience sits 14 to 16 dB under the full mix.

**Frequency lanes.** Tells own 2 to 5 kHz, so ambience and music have a gentle cut there. Gun punch owns below 120 Hz, so music bass is high-passed at 80 Hz during combat. Zombie groans live in 150 to 600 Hz.

**Low health.** Under 40% HP: a heartbeat on the UI bus, everything except tells gets a 2.5 kHz low-pass that opens as you heal (same numbers as the game feel doc). Tells stay crisp so you can still save yourself.

**Settings menu.** Sliders for Master, Music, Effects, Voices, UI, Hit and kill sounds, and Voice chat (matching the controls and accessibility plan), so Hitmarkers get their own bus under SFX. Presets: Headphones (default, full panning), Speakers (narrower), Night mode (stronger compression, louder tells). A Mono toggle. For deaf and hard-of-hearing players, every important sound carries a directional caption in its sound data (for example "\[Brute roar - behind\]"), and the sound visualizer ring from the controls and accessibility plan shows icons for zombie footsteps within 15 m, special zombie tells, barriers breaking within 25 m, teammate down and power-up spawns. SoundManager raises these events, so captions and icons always match what plays.

## Where sounds come from

Three sources, used in this order: **packs** for anything recorded (guns, zombies, impacts, ambience), **code** for anything designed (UI, stingers, beacons, music synth parts), **recording** only to fill gaps. Everything passes one processing script so the game sounds like one game, not a mix of packs.

| Source | Use it for | License rule |
| --- | --- | --- |
| Royalty-free packs (bought or free) | Guns, zombie vocals, impacts, foley, ambience beds | Royalty-free for games, no attribution required preferred. Keep the license file or receipt in `audio/licenses/` |
| CC0 sites (Freesound with CC0 filter, Kenney) | Fills: drips, doors, small foley, UI clicks | CC0 only. No CC-BY-NC, no "free for personal use" |
| Python synth scripts | UI, loot chimes, stingers, beacon loops, drones, arps, the horde loop layering | Our own output, no license needed |
| Home recording (phone or handheld recorder) | Cloth, gear rattle, wet gore (vegetables), metal hits, extra zombie vocals from a pitched voice | Our own output |

**AI-drivable tools.** Everything below runs from the command line, so an AI can make and remake sounds from scripts kept in the repo under `tools/audio/`:

- **Python with numpy, scipy and soundfile**: synth scripts that render UI blips, chimes, sub drops, drones and arps to WAV. Each sound is a small recipe file, so "make the Epic chime a bit brighter" is a one-line change and a re-render.
- **jsfxr-style parameter files**: quick variants of clicks and blips, softened afterwards so they don't sound retro.
- **Pedalboard (Python audio effects)**: reverb, EQ, compression, distortion and pitch chains for layering and designing tails. Used as a tool only, nothing of it ships.
- **SoX and ffmpeg**: batch trim, fade, resample to 48 kHz, loudness normalise (ffmpeg `loudnorm`).
- **Music**: AI music generators are allowed (decided 14 Nov 2026). See the AI music section below for which tools and how.

**Processing pipeline.** Raw files go in `audio/raw/` (not shipped). `tools/audio/process.py` reads `audio/manifest.csv` (one row per game sound: id, source file, category, trim, target loudness, loop points), and writes game-ready files to `audio/game/` with fixed loudness per category: one-shots peak-normalised to -1 dBFS, loops to their category LUFS. Godot import settings are set by the same script.

**License log.** Every shipped file has a row in `ASSET_SOURCES.md` (file, source, author, license, URL, date). A GUT test fails the build if any file in `audio/game/` has no row. This replaces the credits file named in the design doc.

### AI music

**Main tool: Stable Audio, run locally from the open weights.** It runs on the RTX 4080 Super from a script, makes loops to a set length, tempo and key, and its Community License allows commercial use of the output for free while yearly revenue stays under $1M. Suno Pro is the backup for full-length pieces like the menu theme. Licences checked 14 Nov 2026; check again before each release, because these terms change often.

| Tool | Commercial use for a game | Cost | Fit for us | Verdict |
| --- | --- | --- | --- | --- |
| [Stable Audio (Stability AI)](https://stability.ai/explainers/stable-audio-vs-competitors-licensing-export-rights-and-self-hosting-compared) | Yes. Community License is free under $1M yearly revenue, including self-hosting. Above that, an Enterprise licence is needed. You own the output | Free locally (open Small and Medium models), or $12 to $199 a month hosted | Best. Scriptable, makes loops and SFX, runs offline, no download cap | Use |
| [Suno](https://dynamoi.com/learn/ai-music-distribution/suno-commercial-rights-explained) | Yes on Pro or Premier only, and only for songs made while subscribed. Free plan is non-commercial | Pro about $10 a month, 20 downloads a month | Good full tracks, weaker for exact loops and stems. Web app, not scriptable | Backup for menu, hub and exfil tracks |
| [ElevenLabs Music](https://elevenlabs.io/eleven-music-model-specific-terms) | Yes on paid plans for Indie Games (under $500k lifetime game revenue and under $1M developer revenue). Studio games need Enterprise. 60 days to upgrade if you outgrow it | Paid plan needed to download | Has an API, so scriptable. The revenue cap is lower than Stable Audio's | Second choice if Stable Audio quality falls short |
| [Udio](https://dynamoi.com/learn/ai-music-distribution/can-i-distribute-udio-music) | No. Downloads stopped in October 2025 | n/a | Can't export | Don't use |

**How we make the stems.** Generate each of the 4 layers (Bed, Pulse, Drive, Peak) as its own loop at 100 BPM in D minor with the same prompt base, rather than splitting one finished track. Then `process.py` trims to whole bars, sets loop points and loudness. The prompt, seed, model and date go into `ASSET_SOURCES.md` next to each file, so any track can be remade.

**Rules.** Never name a real artist, song, band or label in a prompt. Keep the subscription receipt for any Suno or ElevenLabs track. Fully AI-made music probably can't be copyrighted, so others could copy it. That is acceptable for game music. If a track needs protecting, a human edit or added parts makes it our own.

## Packs to evaluate

Start free, then buy one gun library and one zombie library once the free baseline shows the gaps. Prices and licenses checked on 14 Nov 2026; read each license again before buying.

| Pack | Covers | Cost | License notes | Verdict |
| --- | --- | --- | --- | --- |
| [Sonniss GDC 2026 Game Audio Bundle](https://rekkerd.org/sonniss-releases-gdc-2026-game-audio-bundle/) (plus earlier years) | Ambience, impacts, foley, some weapons and creatures | Free, 7.5 GB+ this year | Royalty-free, unlimited projects, no attribution | Get first. Mine it for ambience beds and impacts |
| [Kenney Interface Sounds](https://kenney.nl/assets/interface-sounds) and [Sci-fi Sounds](https://kenney.nl/assets/sci-fi-sounds) | UI clicks, beeps, machine blips | Free | CC0 | Get first. Placeholder UI until synth UI is made |
| Freesound, CC0 filter only | Drips, doors, small fills | Free | CC0 per file, check each | Use for gaps |
| [Epic Stock Media: Game Weapons](https://epicstockmedia.com/product/game-weapons-gun-firearm-sound-effects) | 1,557 sounds: guns, shotguns, explosions, gun handling, 39 reloads | $56 on sale ($96 list) | Royalty-free, single user | Best budget gun pick for v0.1. No separate far layers listed, so far layers are made by filtering |
| [BOOM Library: GUNS](https://www.boomlibrary.com/?p=720) | Close to very distant tails, dry fire, handling. Designed edition 436 sounds, full bundle 6,295 | $139 to $269 | Royalty-free, single user. Page mentions a separate developer license: confirm a game counts as normal use before buying | Upgrade pick for v1.0 gun sound |
| [ShotgunMike: The Undead](https://www.asoundeffect.com/sound-library/the-undead-2) | 618 zombie vocals by intensity plus horde ambiences (urban, interior, tunnel) | Price not shown on page, check cart | Royalty-free | Top zombie pick: covers vocals and the horde loop |
| [Dark Fantasy Studio: Zombie Voices](https://darkfantasystudio.itch.io/zombie-voices) | 40 groans, snarls, vocals | From €2.99 | Royalty-free, commercial use | Cheap starter set for v0.1 Shamblers |

**Recommendation for v0.1:** Sonniss + Kenney + Freesound CC0 (free), plus Epic Stock Media Game Weapons and Dark Fantasy Zombie Voices. About $60 total. Re-evaluate BOOM GUNS and The Undead after the first play-test on sound.

## Build order

Sound work follows the v0.1 slice (Halcyon Labs, 3 guns, rounds 1 to 10). Each step ends with a quick play-test question: "Could you tell where the danger was?"

1. **Foundation:** bus layout, `SoundManager` with pooling, priorities and caps, debug overlay. Swap the current placeholder sounds onto it.
2. **Guns:** layered shot system, 3 guns, reload foley on animation events, hitmarkers, impacts. Room types and reverb zones for Halcyon Labs.
3. **Zombies:** Shambler and Crawler sets with tells, the horde loop, Bloater and Stalker after.
4. **Round flow:** start and end stingers, 4-stem Halcyon music with the intensity value, breather loop.
5. **World:** Halcyon ambience beds (power off, power on, Blackout), emitters, one-shots, doors and buys.
6. **Rewards:** loot drops per rarity, power-ups, level-up.
7. **Pass:** mix to the target levels, audio settings menu, accessibility markers.

**Open questions**

- [ ] Decided 14 Nov 2026: AI music generators are OK. Stable Audio is the main tool, see AI music.
- [ ] Positional voice chat in co-op later: proximity voice in rounds, or team radio only?
- [ ] Budget ceiling for bought packs beyond the $60 v0.1 picks.
