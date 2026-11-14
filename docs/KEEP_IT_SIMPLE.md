# Keep it simple: examples and deferred work

The rules are in the "Keep it simple" section of `AGENTS.md`. This file shows
what they mean in this codebase.

## Examples

**Good: direct call for a request.** `Economy.try_spend(player, cost) -> bool`.
One function, one owner, returns an answer. No `SpendRequest` object, no signal
plus callback.

**Good: state machine as an enum.** `zombie.gd` uses `enum State` and a
`match` in `_physics_process`. No `State` node per state, no generic
`StateMachine` class. Keep it this way until a single enemy has more than about
8 states.

**Good: round scaling as data.** `WaveRules` is one Resource with a few
formulas. Balancing never touches code, and there is no "difficulty strategy"
class hierarchy.

**Good: content lookup.** `Content.weapon(&"rifle_ar")`. Do not add a
`WeaponFactory`, `WeaponRegistry` or `ContentManager` on top of it.

**Over-built (removed): interface with one implementation.** The prototype
had `ProgressionService` as a base class with empty methods and
`LocalProgressionService` as its only subclass. Solo and online both apply
grants through the same service, so a second version may never exist. It is
now one concrete `ProgressionService`. Split it only when a second real
version is written.

**Over-built (removed): hooks for features that don't exist yet.** The
prototype had
`Wallet.earn_multiplier` (power-ups are P3), `EconomyRules.barrier_repair`
(barriers are P3), `DamageInfo.Type.EXPLOSIVE` and `FIRE` (no explosives or
fire yet), `InputFrame.to_dict()/from_dict()` (network is P7),
`Net.is_solo()` and `Content.all()` (never called). Each was small, but this
is exactly how a codebase fills up with guesses. The phase that needs them adds
them back.

**Over-built (do not write this):**

```gdscript
# A manager that only forwards
class_name PointsManager
extends Node
func add_points(player: Player, amount: int) -> void:
    player.wallet.add(amount)
```

```gdscript
# A generic framework for one use
class_name StateMachine
extends Node
var states: Dictionary[StringName, State] = {}
func transition_to(name: StringName) -> void: ...
```

```gdscript
# Speculative network code before P7
@rpc("authority", "unreliable")
func sync_ammo(in_mag: int, reserve: int) -> void: ...
```

## Deferred until there is a real need

These are in the architecture doc. Build them in their phase, and only when the
trigger below is true, not just because the doc lists them.

| Thing | Build it when |
|---|---|
| Pool autoload | The F3 overlay or stress test shows spawn/free stutter. Pooled zombies with nav agents need careful reset; plain spawn and free may be fast enough. |
| Settings, Audio, Game autoloads | The first menu, the voice cap or the main menu is built. |
| Save version upgrades and backups | The first build goes to other players. Before that there are no old saves to upgrade. |
| Import scripts per asset type | The first real asset of that type is imported. One script per type, written then. |
| Debug console commands | A test or tuning task needs the command. Start with the few you use. |
| Zombie AI tiers (frame skipping) | Profiling with 24+ zombies shows the AI over budget. |
| StatBlock "more" modifiers and caps | P5. Before then, P3 perks use plain add / multiply modifiers. |
