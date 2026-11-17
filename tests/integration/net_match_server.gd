## Real dedicated-server fixture: records the authoritative kill and payout.
extends DedicatedServer


func _ready() -> void:
	start_place = &"match"
	super()
	session.rng_seed = 7
	var rules: WaveRules = session.wave_rules.duplicate(true) as WaveRules
	rules.first_round_delay = 0.2
	session.wave_rules = rules
	session.ready.connect(func() -> void: session.loot.drop_chance_override = 1.0)
	Events.enemy_killed.connect(_on_test_kill)


func _on_test_kill(enemy: Node3D, info: DamageInfo) -> void:
	var player: Player = info.attacker as Player
	if player:
		_record_kill.call_deferred(enemy.name, player)


func _record_kill(zombie_name: StringName, player: Player) -> void:
	(
		Log
		. info(
			&"net",
			&"test_enemy_killed",
			{
				"zombie": zombie_name,
				"attacker": player.net_id,
				"points": player.wallet.points,
			}
		)
	)
