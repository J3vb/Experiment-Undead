# Plan: Real sounds and music

Status: Review
Roadmap: F-89 / issue none (play-test 2026-11-20: "replace the self-made sounds with actual music or sounds")
Phase: P1
Size: L
Approved by:
Lore link: none: the same sounds play at the same moments, just recorded or produced instead of synthesised. Music stays the moods already set in docs/design/sound.md (cold synth in rounds, warm breather between them).

## Goal

The game sounds like a real game: recorded guns, zombies and rooms, and proper music on the menu, in rounds and between rounds, instead of the numpy-made placeholders. It serves the "tight, modern gunplay" and "dread" pillars: you can hear what is happening and where.

## Scope

In:

- One audio intake tool (`tools/audio/process.py`) and one manifest (`tools/audio/manifest.csv`): trim, loop points, loudness per category, 48 kHz, Ogg for loops and anything over 2 s, WAV for short one-shots.
- A licence log: every shipped file in `assets/audio/` has a manifest row (source, licence, author or tool, prompt and seed for AI music). A content test fails on a missing row.
- An audition page (an Artifact with audio players) per step, so the person picks between 2 to 3 candidates by ear. Agents cannot judge sound by listening.
- Swap, 1 to 1, every current sound file: guns and reloads, hits and impacts, zombies, player, world and ambience, UI and round sounds.
- Music: menu theme (new), breather, Halcyon bed and drive, made with Stable Audio on the person's GPU, same loop lengths and file names so `MusicPlayer` needs no change.

Not in (non-goals, and where each one goes instead):

- 4-stem adaptive music, stingers, Stinger and Tells buses, SoundManager pooling (later: the sound foundation and music steps in docs/design/sound.md Build order; DECISIONS lines 61-62 stay).
- New sound events that have no sound today (later: per feature).
- Voice chat (open question in sound.md).

## Ready to build

- Foundations touched (numbers from docs/FOUNDATIONS.md): none; asset files only, plus one new content test. Nothing shaky in the way.
- Decision records that apply (docs/adr/): none for audio. Does this go against one? no
- Co-op:
  - Who decides: each client plays its own sounds from events that already exist; nothing changes.
  - How a client triggers it: unchanged.
  - What other players see: unchanged.
  - Works on a dedicated server with no local player: yes (Dummy audio driver, unchanged).
- Data: sound files keep their names in `assets/audio/`; where each came from lives in `tools/audio/manifest.csv`. Code compares against a specific id anywhere: no
- Save: changes what is saved? no
- Events and UI: no new Events or screens.
- Input through InputFrame, gameplay in _physics_process, randomness from the session RNG: yes (no gameplay code changes)
- Tests: `tests/content/test_audio_sources.gd` (new), `tests/content/test_music.gd`, existing sound tests stay green.
- Logging: none; the manifest test fails the build instead of warning at run time.
- Performance: nothing created per frame; same players and voice counts as today.
- Lore link: none, same sounds at the same moments (see header).
- Out of scope: stems, stingers, SoundManager, new sound events (see Scope).
- Source files: waits on the person (Person tasks). Each step starts only when its files are in `/mnt/project-files/audio-raw/`.

## Design references

- docs/design/sound.md "Where sounds come from", "AI music", "Packs to evaluate", "Mixing priorities", "Music and round stingers" (100 BPM D minor combat, 70 BPM breather, music never above -14 LUFS short-term)
- docs/DECISIONS.md lines 61-63 (music, sound, ambience simplifications stay as they are)
- AGENTS.md code rule 8 (every third-party file gets a CREDITS line, CC0 first, no non-commercial, no Git LFS)
- Licences re-checked 2026-11-20: Sonniss GDC bundles (royalty-free, commercial, no attribution, ship only inside the game); Kenney (CC0); Stable Audio 3 Community License (you own the output, free under $1M yearly revenue, open weights Small, Small SFX and Medium run locally); ElevenLabs Music (indie games under $500k lifetime revenue, terms 09 Oct 2026); Suno (commercial use on paid plans, Suno keeps ownership, 20 downloads a month on Pro).

## Systems touched

| Folder or file | New / changed | What changes |
|---|---|---|
| tools/audio/process.py | new | Reads the manifest, processes raw files to `assets/audio/`, sets Godot import loop flags |
| tools/audio/manifest.csv | new | One row per shipped sound: id, game file, raw file, source, licence, category, trim, loop, target loudness, AI prompt/seed/model |
| tools/audio/audition.py | new | Builds the audition page (HTML with players) from candidate files |
| tools/audio/music_prompts.md | new | Paste-ready prompts for the person's GPU agent (Stable Audio) |
| assets/audio/** | changed | Same file names, new contents. Generated files stay until replaced |
| systems/ui/main_menu.tscn | changed | Menu Music node points to the new `menu_theme.ogg` (step 5) |
| docs/CREDITS.md, MainMenu.CREDITS | changed | One line per pack or tool (the credits test already ties the two) |
| tools/generate_sfx.py, tools/generate_music.py, tools/assets/*_sfx.py | changed | Each step deletes the generator code for sounds it replaced (Keep it simple 11) |

Autoloads, managers or base classes added: none.
Files over 300 lines this plan grows: none.

## Data

- No new Resource types, save fields or network messages.
- `tools/audio/manifest.csv` is the source of truth for where a sound came from.
- Content checks in `tests/content/test_audio_sources.gd` (new): every `.wav`/`.ogg` under `assets/audio/` has a manifest row; every row names a licence from an allow list (CC0, CC-BY, Sonniss, Stable Audio Community, own); loops import with loop on; one-shots under 3 s; total audio under a size cap (start: 60 MB, no LFS).
- Save format change: none.

## Co-op behaviour

- Who owns the state: nothing new; sounds play locally from events that already exist.
- What clients send / server sends: unchanged.
- What everyone hears: same as today.
- Late joiner: nothing extra.
- Dedicated server: Dummy audio driver, sounds are never loaded for play. Unchanged.

## Performance

Same number of players and voices as today. Ogg loops stream; one-shots stay WAV (no decode cost). File size, not CPU, is the limit: the size cap test guards the repo.

## Steps

Each step: the agent picks 2 to 3 candidates per sound from the raw files (by name, length, loudness and spectrum), builds an audition page, the person picks, the agent processes and commits. Each step leaves the game playable and CI green.

### Step 1: Intake tool, licence log, UI and round sounds

- Build: `process.py`, `manifest.csv` (rows for all current generated files, source "own"), `audition.py`, licence test. Swap UI and round sounds (buy, denied, hitmarker, level_up, wave_start, round_end, power_up) from Kenney / Sonniss.
- Files: tools/audio/*, tests/content/test_audio_sources.gd, assets/audio/ (7 files), docs/CREDITS.md, main_menu.gd CREDITS.
- Tests: test_audio_sources.gd fails on a file with no row and on a non-allowed licence.
- Done when: the person picked the 7 UI sounds on the audition page; CI green.

### Step 2: Guns and reloads

- Build: fire sounds for all guns with a `*_fire.wav`, dry fire, reload parts (mag out/in, bolt, pump, shell in), from the Sonniss GDC bundles (all years), layered and filtered in process.py for punch and far tails.
- Files: assets/audio/*_fire.wav, reload_*.wav, dry_fire.wav, manifest rows.
- Tests: test_audio_sources.gd rows; existing weapon tests still pass.
- Done when: audition picked; solo play-test "do the guns feel punchy".

### Step 3: Zombies, hits and player

- Build: zombie groans, attacks, deaths, steps; Bloater set; flesh impacts, head hits; player hurt, downed, revived, bled out, footsteps, landing.
- Files: assets/audio/zombie_*, bloater_*, impact_*, hit_*, player_*, footstep_*, land.wav.
- Tests: test_audio_sources.gd; existing zombie sound tests (variation counts) still pass.
- Done when: audition picked; play-test "could you tell where the danger was".

### Step 4: World and ambience

- Build: room beds (base, corridor, mess hall, labs), drips, steam, hum, klaxon, vent clang, distant groan, doors, power on, plank tear and repair, radio.
- Files: assets/audio/ambience/*, door_open, power_on, plank_*, radio_*.
- Tests: test_audio_sources.gd (beds import as loops).
- Done when: audition picked; generator scripts for replaced sounds deleted.

### Step 5: Music

- Build: the person's GPU agent runs `music_prompts.md` with Stable Audio (open weights, local): menu theme (calm, about 90 s loop), breather (70 BPM warm pad), Halcyon bed and drive (100 BPM D minor, 38.4 s, sample-aligned). 3 takes each on the audition page. Then `generate_music.py` is deleted.
- Files: assets/audio/music/*.ogg, systems/ui/main_menu.tscn, tools/audio/music_prompts.md.
- Tests: tests/content/test_music.gd keeps lengths and loop checks; add menu_theme loop check.
- Done when: the person picked each track.

### Step 6: Mix pass

- Build: set loudness per category from sound.md Mixing priorities, check menu, hub and a round with the person's play-test.
- Tests: test_audio_sources.gd checks each file's measured loudness is within 2 LU of its category target (process.py writes it in the manifest).
- Done when: play-test signed off.

## Acceptance

- [ ] No file in `assets/audio/` comes from the numpy generators (manifest source column)
- [ ] Every shipped audio file has a licence row and a CREDITS line for its source
- [ ] Music loops cleanly and the combat stems stay aligned (test_music.gd)
- [ ] Play-test: guns, zombies, menu and breather music signed off

## Risks

- Picking by ear needs the person: audition pages keep it to a few clicks per sound; a step waits for picks instead of guessing.
- Repo size without LFS: Ogg for long files and the size cap test.
- Licence drift (AI tools change terms often): the licence date goes in each manifest row, recheck before each release.
- Free packs may lack good zombie voices or gun punch: layer several free sources, then pitched home-recorded vocals (sound.md "Home recording"); spending money comes back to the person as a card only if an audition shows a gap free files cannot fill.

## Open decisions

- [x] Sourcing route: free only, no spend (person's pick on the card, 2026-11-20). Sonniss GDC bundles, Kenney, Freesound CC0 (CC-BY with a credit line only when nothing CC0 fits), Stable Audio open weights for music. No paid packs or subscriptions.

## Person tasks

- Download the free Sonniss GDC bundles and Kenney packs into `/mnt/project-files/audio-raw/<pack>/`, or let a thread download the free ones if the network allows.
- Run the music prompts on the GPU machine (step 5).
- Listen and pick on each audition page.
