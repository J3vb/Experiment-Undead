## Real dedicated-server fixture that starts in the hub and readies every player who
## spawns there, so a joining client deploys to the match without pressing anything.
## The match ends as soon as round 1 starts, so the server returns to the hub.
extends DedicatedServer


func _ready() -> void:
	super()
	Events.player_spawned.connect(_ready_up)
	Events.round_started.connect(_end_first_match)


func _ready_up(player: Player) -> void:
	if is_instance_valid(session) and session.is_hub:
		session.deploy_vote.toggle_ready.call_deferred(player, &"match")


func _end_first_match(round_number: int, _count: int) -> void:
	if round_number == 1 and is_instance_valid(session) and not session.is_hub:
		session.match_end._end_match.call_deferred(false)
