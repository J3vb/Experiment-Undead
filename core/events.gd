## Global signal hub for game-wide facts. Signals only, no logic.
## Signals are past-tense facts, never commands.
## Every signal says on which peers it fires ("Peers:"). Server = the host or the
## dedicated server. Owner = the peer that controls that player. Every peer =
## the server and all clients. Solo play is the server, so everything fires there.
extends Node

## A round began spawning. count = total enemies this round.
## Peers: server only. Clients do not get round state yet (#216).
signal round_started(round_number: int, count: int)
## The last enemy of a round died.
## Peers: server only. Clients do not get round state yet (#216).
signal round_ended(round_number: int)
## Countdown to the next round started.
## Peers: server only. Clients do not get round state yet (#216).
signal intermission_started(next_round: int, duration: float)

## An enemy entered the world.
## Peers: every peer (clients when the spawner replicates the zombie).
signal enemy_spawned(enemy: Node3D)
## An enemy took damage (not lethal or lethal).
## Peers: server only. Clients send hit claims; their zombie copies take no damage.
signal enemy_damaged(enemy: Node3D, info: DamageInfo)
## An enemy died.
## Peers: server only. Clients show the death through ZombieSync, without this event.
signal enemy_killed(enemy: Node3D, info: DamageInfo)

## A player joined the session.
## Peers: every peer, once for each player.
signal player_spawned(player: Player)
## A player took damage.
## Peers: server, and the owner when the synced health drops.
signal player_damaged(player: Player, info: DamageInfo)
## A player's health changed (damage or regen).
## Peers: every peer (clients from the synced player state).
signal player_health_changed(player: Player, current: float, maximum: float)
## A downed player got back up (Second Wind).
## Peers: every peer (clients from the synced player state).
signal player_revived(player: Player)
## A player died.
## Peers: every peer (clients from the synced player state).
signal player_died(player: Player)
## A player reached a new level.
## Peers: server for every player; the owner for its own player when the server sends XP.
signal player_leveled_up(player: Player, level: int)
## A player's points changed.
## Peers: every peer (clients from the synced player state).
signal points_changed(player: Player, total: int, delta: int)

## A player's weapon fired one shot.
## Peers: owner only. Other peers see the shot through RemoteShots.
signal weapon_fired(player: Player, weapon: Weapon)
## A player gained a weapon (loadout, wall buy, crate, loot).
## Peers: every peer for the starting loadout, the downed sidearm and the respawn pistol;
## other guns (buys, Vault, loot) only on the owner. Not a sign that the player is local.
signal weapon_acquired(player: Player, weapon_id: StringName)
## A player's active weapon changed.
## Peers: every peer for the starting loadout, going down, getting up and respawning;
## the player's own switches only on the owner. Not a sign that the player is local.
signal weapon_switched(player: Player, weapon: Weapon)
## A player's active weapon ammo changed.
## Peers: owner; the server too when a power-up refills that player's ammo.
signal ammo_changed(player: Player, in_mag: int, reserve: int)
## A player's reload started.
## Peers: owner only.
signal reload_started(player: Player, duration: float)
## A player bought a Serum.
## Peers: every peer (clients from the synced player state).
signal serum_gained(player: Player, serum: SerumData)
## A player picked up a power-up (its effect has already been applied).
## Peers: server only.
signal power_up_collected(player: Player, power_up: PowerUpData)
## A player's shot landed on an enemy.
## Peers: the shooter's owner (on the claim, then again on the kill), and the
## server for Gravity Well hits it applies.
signal hit_confirmed(player: Player, is_kill: bool, is_headshot: bool)

## The exfil hatch opened for this round.
## Peers: every peer (clients from the synced hatch state).
signal exfil_opened
## A player called the exfil; the squad must now hold the hatch.
## Peers: every peer (clients from the synced hatch state).
signal exfil_called(hatch: ExfilHatch)

## The match ended.
## Peers: every peer (the server sends the match end to all).
signal game_over(stats: Dictionary)
