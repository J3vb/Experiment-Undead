# Experiment Undead: Controls and Accessibility

Source: copy of the design doc as of Nov 14, 2026. Where this file and the code differ, the code and `docs/DECISIONS.md` win.

## Summary

Every input is a named action in Godot's InputMap, every option lives in one Settings file, and nothing important is shown by colour alone. Those three rules make the rest easy to add later.

Key decisions:

- **Physical keys, not letters.** Bindings save the key's position, so WASD becomes ZQSD on an AZERTY keyboard by itself, and the menu shows the right letter.
- **Visual feel is separate from gameplay.** Camera shake, head bob and flashes are sliders that never change recoil, spread or accuracy. Turning shake off is never a handicap.
- **Rarity has three signals:** colour, a shape, and pips (1 to 6). The rarity name is always one hover away.
- **Readable by default.** Atkinson Hyperlegible is the default font, with Lexend and OpenDyslexic as options. Text size and HUD size have their own sliders.
- **Controller players get aim assist, mouse players do not.** The game is co-op against zombies, so there is no fairness problem to solve.
- **A quick setup screen on first launch** asks about font, text size, subtitles, colour vision and motion comfort before the main menu.

## Keyboard and mouse

The layout follows what military-shooter players already expect, so nobody has to relearn their hands. Keys are listed as on a QWERTY keyboard; AZERTY players see their own letters.

| Action | Default key | Hold or toggle (default) | Notes |
| --- | --- | --- | --- |
| Move | W A S D | - | Physical keys, so AZERTY gets Z Q S D |
| Look | Mouse | - | Raw mouse input, no acceleration |
| Fire | Left mouse | - |  |
| Alt fire (`alt_fire`) | Middle mouse | Press | Both barrels on Coachman and Grubber; with one round left, fires it normally |
| Aim down sights | Right mouse | Hold |  |
| Reload | R | - |  |
| Interact, buy, repair barrier | E | Hold 0.3 s | Tap option in settings |
| Jump, mantle | Space | - |  |
| Sprint | Left Shift | Hold | Double tap for tactical sprint |
| Crouch, slide | C | Toggle | Press while sprinting to slide |
| Melee | V | - |  |
| Lethal (grenade) | G | - | Hold to cook |
| Tactical | Q | - |  |
| Field ability | F | - | From the skill tree |
| Weapon slot 1, 2, 3 | 1, 2, 3 | - |  |
| Next or previous weapon | Mouse wheel | - |  |
| Ping | Unbound | - | Planned; middle mouse is used by alt fire |
| Scoreboard | Tab | Hold |  |
| Inventory | I | - | Town and between rounds only |
| Map | M | - |  |
| Text chat | T | - | Co-op (P7) |
| Push to talk | Left Alt | Hold | Co-op (P7) |
| Pause, back | Esc | - | Cannot be rebound |

Mouse buttons 4 and 5 are left free on purpose, because many players move melee or tactical there.

## Controller

The game shows Xbox or PlayStation button icons to match the controller that is plugged in. It switches icons the moment the player touches a different device.

| Action | Xbox | PlayStation | Notes |
| --- | --- | --- | --- |
| Move | Left stick | Left stick |  |
| Look | Right stick | Right stick |  |
| Fire | RT | R2 |  |
| Alt fire (`alt_fire`) | Right stick click | R3 | Both barrels on Coachman and Grubber |
| Aim down sights | LT | L2 | Hold by default |
| Jump, mantle | A | Cross |  |
| Crouch, slide | B | Circle | Toggle by default |
| Reload | X (tap) | Square (tap) |  |
| Interact, buy, repair | X (hold) | Square (hold) | Can move to its own button |
| Swap weapon | Y | Triangle | Hold for third slot |
| Sprint | Left stick click | L3 | Toggle by default; auto sprint option |
| Melee | Unbound | Unbound | Planned; right stick click is used by alt fire |
| Lethal | RB | R1 | Hold to cook |
| Tactical | LB | L1 |  |
| Field ability | D-pad down | D-pad down |  |
| Ping | D-pad up | D-pad up |  |
| Map | D-pad right | D-pad right |  |
| Scoreboard | View | Touchpad | Hold |
| Pause | Menu | Options |  |

Presets on top of full remapping:

- **Default:** the table above.
- **Tactical:** crouch on the right stick click, melee on B or Circle. Lets you slide without taking a thumb off the right stick.
- **Separate interact:** reload stays on X or Square, interact moves to D-pad left. This fixes the classic problem of reloading when you meant to buy.
- **Southpaw and Legacy:** swap the sticks, or swap the sticks and triggers.

DualSense touchpad swipes are not used for anything important, because not every controller has one.

## Rebinding

Game code only ever asks about action names like `fire` or `interact`, never about keys. That one rule is what makes full rebinding cheap.

How it works:

1. All actions are defined in `project.godot` with their default keys and buttons. Names are short and lowercase: `move_forward`, `aim`, `fire`, `reload`, `interact`, `sprint`, `crouch`, `melee`, `lethal`, `tactical`, `field_ability`, `ping`. Match the names the prototype already uses where they exist.
2. Each action gets two keyboard or mouse slots (main and backup) and one controller slot.
3. Keyboard bindings save `physical_keycode`, never `keycode`. The menu shows the local letter with `DisplayServer.keyboard_get_label_from_physical()`.
4. The `Settings` autoload saves bindings to `user://settings.cfg` as plain values, for example `{"type": "key", "physical": 87}`. On start it clears each action with `InputMap.action_erase_events()` and adds the saved events back.
5. Holding Esc for 1 second cancels a rebind. Esc and the controller Menu button are locked so a player can never lock themselves out of the menus.

Conflicts:

- Actions belong to a context: on foot, menus, or always. Two actions in the same context cannot share a key.
- When a new key is already taken, the menu says which action uses it and offers "Swap" or "Cancel". Nothing is silently unbound.
- Reload and interact on the same controller button is the one allowed overlap, because tap and hold tell them apart.

Reset buttons exist per action, per page and for everything. The binding file has a version number, so a later update can add actions without wiping a player's custom layout.

Built in F-05 (see `docs/DECISIONS.md`): keyboard and mouse only, one global "one key, one action" rule instead of contexts, and a plain Esc press cancels a rebind. Controller rebinding, presets and per-page reset come later.

In co-op, bindings stay on the player's PC. The server only receives the actions (the InputFrame from the multiplayer rules), so rebinding never touches networking.

## Aim, camera and assists

Mouse aim is 1 to 1 with no smoothing. Controller aim gets curves, dead zones and a light aim assist, because a thumb stick cannot match a mouse.

**Field of view**

- The menu shows horizontal FOV, from 70 to 120 degrees, default 95. Godot's camera uses vertical FOV, so the Settings code converts it for the screen's aspect ratio.
- A separate weapon FOV slider (60 to 90) sets how big the gun looks on screen.
- ADS zoom can follow the main FOV or stay fixed per weapon.

**Mouse**

| Setting | Range | Default |
| --- | --- | --- |
| Sensitivity | 0.1 to 10 | 2.0 |
| ADS sensitivity multiplier | 0.2 to 2.0 | 1.0, scaled by zoom |
| Invert vertical | on or off | off |

**Controller**

| Setting | Range | Default |
| --- | --- | --- |
| Horizontal and vertical sensitivity | 1 to 20 each | 6 and 6 |
| ADS multiplier | 0.2 to 2.0 | 1.0 |
| Inner dead zone, per stick | 0 to 30% | 8% |
| Outer dead zone | 70 to 100% | 95% |
| Response curve | Linear, Standard, Dynamic | Standard |
| Turn acceleration delay | 0 to 0.5 s | 0.15 s |
| Vibration and trigger effects | 0 to 100% | 100% |
| Invert vertical | on or off | off |

**Aim assist (controller only)**

Aim assist helps the player's thumb, it never aims for them. It looks for the zombie closest to the crosshair, within 6 degrees from the hip or 4 degrees in ADS, up to 40 m, in line of sight. It always targets the chest, so headshots still take skill.

| Part | What it does | Standard | Precision |
| --- | --- | --- | --- |
| Slowdown | Look speed drops while the crosshair is on a target | 35% | 20% |
| Follow | Camera turns a little with a moving target, only while the player is also moving or aiming | 25% | 10% |
| ADS snap | A small pull toward the target when ADS starts, at most 3 degrees, once per 1.5 s | on | off |

Modes: Standard (default), Precision, Off. Aim assist changes the camera on the player's own PC before the InputFrame is sent, so the server needs nothing new.

**Toggle or hold**

Every one of these has its own setting: aim down sights, sprint, crouch, scoreboard, push to talk, and the field ability if it is a channelled one. Other assists:

- Hold time for buy and repair: 0.1 to 1.0 s, default 0.3 s. "Tap to buy" sets it to 0 and asks for a second tap on items over 5,000 points.
- Repair barrier by holding interact instead of pressing it again for each board.
- Auto sprint, auto mantle, auto reload when the magazine is empty.
- Hold fire on semi-auto guns keeps firing at the gun's top rate, for players who cannot click fast.

## Seeing and reading

Nothing important is shown by colour alone. Every colour signal also has a shape, an icon, a sound or a word.

**Loot rarity**

| Rarity | Colour | Shape | Pips | Drop beam | Sound on drop |
| --- | --- | --- | --- | --- | --- |
| Common | Grey | Circle | 1 | None | None |
| Uncommon | Green | Square | 2 | Short | None |
| Rare | Blue | Diamond | 3 | Medium | Soft chime |
| Epic | Purple | Hexagon | 4 | Tall | Two-note chime |
| Legendary | Gold | Star | 5 | Tall with a spinning ring | Rising chord |
| Prototype | Cyan | Hazard triangle | 6 | Tall, pulsing stripes | Unique hum |

- Green and gold, and blue and purple, look alike to many colour-blind players. The shape and pip count settle it without colour.
- The shape sits on the item icon corner, the item tooltip, the drop beam's base and the ground label.
- An option shows the rarity name as text on every ground label.

**Colour vision modes**

Modes for Protanopia, Deuteranopia and Tritanopia swap the UI and effect colours from a palette file. They do not put a filter over the whole screen, because that makes the game look washed out. A strength slider (0 to 100%) and a preview of all rarity, enemy and teammate colours sit on the same page. The same swap covers hit markers, teammate outlines, low ammo and objective markers.

**Fonts and text**

- Font choice: Atkinson Hyperlegible (default), Lexend, OpenDyslexic. All three are free under the Open Font License.
- Text size: 80 to 200%, default 100%. At 100%, body text is at least 24 px at 1080p, and at least 28 px when a controller is in use (people sit further away).
- Rules for all UI text: left aligned, no justified text, no long text in capitals, no italics, line spacing 1.4, short sentences.
- Text background opacity: 0 to 100%, default 70%, for any text drawn over the game world.
- Important words get an icon beside them, so the player can scan icons instead of reading.

**HUD**

- HUD size (70 to 130%) and HUD opacity sliders, plus a safe zone setting for TVs.
- Crosshair: style, colour, size, opacity, and an always-on centre dot.
- Hit markers: normal hits are a cross, headshots add a small diamond in the middle, and kills turn the cross into an X with a sound. Shape and sound tell them apart, not only colour.
- Low health uses a pulse at the screen edge, a heartbeat sound and the health bar flashing, not only a red tint.
- Optional enemy outline (off by default) for players who have trouble seeing zombies in dark rooms.

## Hearing and sound

Every sound that matters for survival also has a picture. A deaf player should never be surprised by a zombie that a hearing player would have heard.

**Subtitles and captions**

- Subtitles for all spoken lines (radio, story, characters). On by default.
- Captions for important sounds, with direction, for example `[Brute roar - behind]` or `[Barrier breaking - left]`. Off by default, offered in quick setup.
- Speaker name in front of each line, each speaker with their own colour and a small portrait icon.
- Size (Small, Medium, Large, Extra large), background opacity, and at most 2 lines on screen at once.
- Lines are written in the content files next to the sound, so a new zombie type comes with its caption by default.

**Sound visualizer**

A thin ring around the crosshair shows arcs pointing at important sounds. Each arc has an icon:

| Sound | Icon | Shown when |
| --- | --- | --- |
| Zombie footsteps | Footprint | Within 15 m and out of view |
| Special zombie cue | That zombie's icon | Any distance the player could hear it |
| Barrier being torn down | Broken plank | Within 25 m |
| Teammate down or calling for help | Cross | Always |
| Power-up spawned | Power-up icon | Always |
| Gunfire from teammates | Bullet | Off by default |

The ring has its own size and opacity sliders. Arc brightness follows how loud the sound is.

**Audio mix**

- Separate volume sliders: master, music, effects, voices, UI, hit and kill sounds, teammate voice chat.
- Mono audio for players who hear in one ear.
- Dynamic range: Full (default) or Night mode, which makes quiet sounds louder and loud sounds quieter.
- Text chat for all co-op messages. Speech to text and text to speech for voice chat are planned for P7 or later.

## Comfort and motion sickness

The game-feel thread will add a lot of shake, kick and flash. Every one of those effects goes through one scale in Settings, so a player can turn it down without losing any accuracy.

| Setting | Range | Default | "Comfort" preset |
| --- | --- | --- | --- |
| Camera shake from your own gun | 0 to 100% | 100% | 25% |
| Camera shake from explosions and hits | 0 to 100% | 100% | 25% |
| Head bob while moving | 0 to 100% | 60% | 0% |
| Weapon bob and sway | 0 to 100% | 100% | 50% |
| FOV change while sprinting | on or off | on | off |
| Landing dip | on or off | on | off |
| Motion blur | off, low, high | off | off |
| Depth of field in ADS | on or off | on | off |
| Chromatic aberration and film grain | on or off | on | off |
| Screen blood and damage effects | 0 to 100% | 100% | 50% |
| Flash reduction | on or off | off | on |
| Centre dot always on | on or off | off | on |

Rules for the code:

- Gameplay recoil (where the bullet goes) and visual camera punch (how the screen moves) live in two separate resources: RecoilData (aim, never scaled) and FeelData (view kick, shake, FOV punch). The sliders only scale FeelData. A test checks bullet direction is the same at 0% and 100% shake. See the [Game Feel doc](game-feel.md).
- Flash reduction caps muzzle flash and power-up flash brightness, and makes sure nothing flashes more than 3 times a second.
- Screen-wide colour changes (power-up effects, low health) fade in over at least 0.2 s instead of popping.
- The quick setup screen asks "Do you get motion sick in first person games?" and applies the Comfort preset on yes.

## Settings menu and file

One `Settings` autoload owns every option, saves it to one file, and tells the rest of the game when something changes.

**Menu pages:** Controls, Aim, Video, Audio, Accessibility, Comfort. Rules:

- Every setting has a one-line description, and visual settings show a live preview.
- Changes apply at once, also from the pause menu during a match. Only display mode and resolution ask "Keep these settings?" with a 15 second countdown.
- A search box at the top finds any setting by name.
- Quick setup runs once on first launch (font, text size, subtitles, captions, colour vision, motion comfort) and can be reopened from Accessibility.

**File:** `user://settings.cfg`, a Godot ConfigFile, readable in a text editor.

```
[meta]
version=1

[accessibility]
font="atkinson"
text_scale=1.0
color_mode="off"
subtitles=true
captions=false
sound_visualizer=false

[comfort]
shake_own_gun=1.0
head_bob=0.6
flash_reduction=false

[aim]
mouse_sens=2.0
fov_horizontal=95
aim_assist="standard"

[bindings]
fire=[{"type": "mouse", "button": 1}]
interact=[{"type": "key", "physical": 69}, {"type": "joy", "button": 2, "hold": true}]
```

Code rules:

- Defaults live in one resource, `content/settings/defaults.tres`, so adding a setting means adding one line there plus its menu row.
- Read a value with `Settings.get_value("comfort", "head_bob")`. Settings emit `Events.setting_changed(section, key)` so systems update live.
- The file is client only. A dedicated server never reads it and has its own `server.cfg`.
- Missing or broken values fall back to the default, so a bad file never stops the game from starting.

## Guideline checklist

This plan covers all the basic and most of the intermediate items in the common game accessibility guidelines. The rows below are the ones that apply to a first-person shooter, with the roadmap phase that delivers each one.

| Guideline | Our answer | Phase |
| --- | --- | --- |
| All controls can be remapped | InputMap actions, two keyboard slots, one controller slot, presets | P0 base, P4 menu |
| Works with keyboard and mouse or a controller alone | Every menu works with both; glyphs follow the active device | P4 |
| No action needs a hold or rapid presses | Toggle or hold per action, tap to buy, hold to keep firing | P1 |
| Sensitivity can be changed | Mouse, ADS and per-axis controller sensitivity, curves, dead zones | P1 |
| Field of view can be changed | Horizontal FOV 70 to 120, weapon FOV 60 to 90 | P1 |
| Nothing is shown by colour alone | Rarity shape and pips, hit marker shapes, low health pulse and sound | P1 and P6 |
| Colour-blind support | Palette swap for three types, with preview | P4 |
| Text is easy to read and big enough | Readable font, 24 px minimum at 1080p, size slider | P4 |
| Dyslexia-friendly text | Font choice, left aligned, no long capitals, icons beside key words | P4 |
| Subtitles for all speech | On by default, size and background settings, speaker names | P4 |
| Captions for important sounds | Directional captions written into content files | P4 |
| Sound cues have a visual version | Sound visualizer ring | P4 |
| Separate volume controls | Seven sliders, mono, night mode | P4 |
| Camera shake and bob can be reduced | Separate sliders, never changes accuracy | P1 |
| Motion blur and flashes can be turned off | Blur off by default, flash reduction mode | P4 |
| Settings can be changed at any time | Pause menu, live apply | P4 |
| Settings are shown before the game starts | Quick setup on first launch | P4 |
| Difficulty can be lowered | Solo difficulty levels from the design doc, aim assist modes | P5 |
| Text chat as well as voice chat | Text chat, pings | P7 |
| Speech to text and text to speech | Planned | P7 or later |
| Test with players with disabilities | Ask in the weekly play-test; check with colour-blind simulators before each release | From P4 |

This list is based on the [Game Accessibility Guidelines](https://gameaccessibilityguidelines.com/) and the [Xbox Accessibility Guidelines](https://learn.microsoft.com/en-us/gaming/accessibility/guidelines), written from memory. Check it line by line against both lists before v0.1.

## Build order and provisional decisions

The cheap foundations go in first, because adding them later means touching every system.

1. **P0 Foundation:** all InputMap actions, physical keys, the `Settings` autoload, `settings.cfg` and `defaults.tres`. No menu yet.
2. **P1 Gun feel:** sensitivity, FOV, toggle or hold, controller curves and aim assist, and the shake and bob sliders built into the first camera effects.
3. **P4 v0.1:** rebinding menu, quick setup, fonts and text size, subtitles and captions, sound visualizer, colour vision modes, comfort preset.
4. **P6 Loot:** rarity shapes, pips, beams and sounds.
5. **P7 Co-op:** text chat, pings, voice chat volume; speech to text later.
6. **Before v1.0:** go through the checklist line by line and test with colour-blind simulators.

Provisional decisions (made without the user, change any time):

- **Prone: out for now.** It slows the wave game down and frees a key. Can be added later as one more action.
- **Steam Deck: nice to have, not a v0.1 target.** Keep the 1280x800 layout in mind, test it later.
- **Dyslexia-friendly font: yes, ship it.** OpenDyslexic stays as an option next to Atkinson Hyperlegible and Lexend.
