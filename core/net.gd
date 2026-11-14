## Network role. Solo play is always the authority. Gameplay that changes
## shared state (damage, deaths, spawns, points, XP, loot) checks
## Net.is_authority() so co-op can slot in later.
extends Node

var _next_net_id: int = 1

func is_authority() -> bool:
	return multiplayer.multiplayer_peer == null or multiplayer.is_server()

## Unique id for anything spawned during a session. Authority only.
func allocate_id() -> int:
	var id: int = _next_net_id
	_next_net_id += 1
	return id

func reset_ids() -> void:
	_next_net_id = 1
