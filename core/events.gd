## Global signal hub for game-wide facts. Signals only, no logic.
## Signals are past-tense facts, never commands.
## Every signal says on which peers it fires ("Peers:"). Server = the host or the
## dedicated server. Owner = the peer that controls that player. Every peer =
## the server and all clients. Solo play is the server, so everything fires there.
## Player events carry the player: always check which one, never assume it is the local one.
extends Node

## A round began spawning. count = total enemies this round.
## Peers: every peer. The server emits it; WaveDirector relays it to clients and late joiners.
signal round_started(round_number: int, count: int)
## The last enemy of a round died.
## Peers: every peer. The server emits it; WaveDirector relays it to clients and late joiners.
signal round_ended(round_number: int)
## Countdown to the next round started.
## Peers: every peer. The server emits it; WaveDirector relays it to clients and late joiners.
signal intermission_started(next_round: int, duration: float)
## The lights failed: a Blackout round (or the debug console) turned the facility dark.
## Peers: every peer. The server emits it; WaveDirector relays it to clients and late joiners.
signal blackout_started(round_number: int)
## The lights came back after a Blackout.
## Peers: every peer. The server emits it; WaveDirector relays it to clients.
signal blackout_ended(round_number: int)

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
## Peers: every peer whenever an equip runs there (starting loadout, going down, getting up,
## respawning); the owner for shots and reloads; the server for power-up ammo refills.
signal ammo_changed(player: Player, in_mag: int, reserve: int)
## A player's reload started.
## Peers: owner only.
signal reload_started(player: Player, duration: float)
## A player bought a Serum.
## Peers: every peer (clients from the synced player state).
signal serum_gained(player: Player, serum: SerumData)
## A player picked up a power-up (its effect runs on the PC that owns the guns).
## Peers: every peer. The server emits it; PowerUpDrops relays it to clients.
signal power_up_collected(player: Player, power_up: PowerUpData)
## A timed power-up (Payday) started or was reset, with seconds left; drives the HUD ring.
## Peers: every peer. The server emits it; PowerUpDrops relays it to clients and late joiners.
signal power_up_timer_started(power_up: PowerUpData, seconds: float)
## A player's shot landed on an enemy.
## Peers: the shooter's owner (on the claim, then again on the kill), and the
## server for Gravity Well hits it applies.
signal hit_confirmed(player: Player, is_kill: bool, is_headshot: bool)
## A player's own shot or swing hit an enemy; info.amount is the zone-scaled damage.
## Peers: the shooter's owner only (on clients from its hit prediction, like hit markers).
signal damage_dealt(player: Player, target: Node3D, info: DamageInfo)
## A personal loot drop appeared in the world for this player (item is the item dict).
## Peers: the drop's owner only (LootService receives it from the server).
signal loot_dropped(player: Player, item: Dictionary)

## The exfil hatch opened for this round.
## Peers: every peer (clients from the synced hatch state).
signal exfil_opened
## A player called the exfil; the squad must now hold the hatch.
## Peers: every peer (clients from the synced hatch state).
signal exfil_called(hatch: ExfilHatch)

## The hub's deploy vote changed. Empty place = no vote. countdown_left is 0 until everyone is ready.
## Peers: every peer (the server sends it to all, and once to a late joiner).
signal deploy_vote_changed(place: StringName, ready_ids: Array[int], countdown_left: float)

## The match ended.
## Peers: every peer (the server sends the match end to all).
signal game_over(stats: Dictionary)
