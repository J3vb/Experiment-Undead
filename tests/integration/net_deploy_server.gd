## Real dedicated-server fixture that starts in the hub and readies every player who
## spawns there, so a joining client deploys to the match without pressing anything.
extends DedicatedServer


func _ready() -> void:
	super()
	Events.player_spawned.connect(_ready_up)


func _ready_up(player: Player) -> void:
	if is_instance_valid(session) and session.is_hub:
		session.deploy_vote.toggle_ready.call_deferred(player, &"match")
