## Global signal hub for game-wide facts. Signals only, no logic.
## Signals are past-tense facts, never commands.
extends Node

## A round began spawning. count = total enemies this round.
signal round_started(round_number: int, count: int)
## The last enemy of a round died.
signal round_ended(round_number: int)
## Countdown to the next round started.
signal intermission_started(next_round: int, duration: float)

## An enemy entered the world.
signal enemy_spawned(enemy: Node3D)
## An enemy took damage (not lethal or lethal).
signal enemy_damaged(enemy: Node3D, info: DamageInfo)
## An enemy died.
signal enemy_killed(enemy: Node3D, info: DamageInfo)

## A player joined the session.
signal player_spawned(player: Player)
## A player took damage.
signal player_damaged(player: Player, info: DamageInfo)
## A player's health changed (damage or regen).
signal player_health_changed(player: Player, current: float, maximum: float)
## A player died.
signal player_died(player: Player)
## A player's points changed.
signal points_changed(player: Player, total: int, delta: int)

## A player's weapon fired one shot.
signal weapon_fired(player: Player, weapon: Weapon)
## A player switched to (or picked up) a weapon.
signal weapon_switched(player: Player, weapon: Weapon)
## A player's active weapon ammo changed.
signal ammo_changed(player: Player, in_mag: int, reserve: int)
## A player's reload started.
signal reload_started(player: Player, duration: float)
## A player's shot landed on an enemy.
signal hit_confirmed(player: Player, is_kill: bool, is_headshot: bool)

## The match ended.
signal game_over(stats: Dictionary)
