## Med Burst and Adrenal Rush (docs/plans/field-abilities.md, step 4): heals, the rush past the
## caps and its end, and the wider hit claim window that faster fire needs.
extends GutTest

const PLAYER: PackedScene = preload("res://systems/player/player.tscn")
const MED_BURST: AbilityData = preload("res://content/abilities/med_burst.tres")
const ADRENAL_RUSH: AbilityData = preload("res://content/abilities/adrenal_rush.tres")
const RIFLE: WeaponData = preload("res://content/weapons/rifle_ar.tres")

var root: Node3D
var player: Player
var ability: FieldAbility


func before_each() -> void:
	root = Node3D.new()
	add_child_autofree(root)
	player = PLAYER.instantiate() as Player
	root.add_child(player)
	player.set_physics_process(false)
	player.local_input.enabled = false
	ability = player.abilities


func _mate(at: Vector3) -> Player:
	var mate: Player = PLAYER.instantiate() as Player
	root.add_child(mate)
	mate.set_physics_process(false)
	mate.local_input.enabled = false
	mate.global_position = at
	mate.health.current = 20.0
	return mate


func test_med_burst_heals_self_to_full_and_near_teammates_by_fifty() -> void:
	ability.ability = MED_BURST
	player.health.current = 10.0
	var near: Player = _mate(Vector3(8, 0, 0))
	var far: Player = _mate(Vector3(12, 0, 0))
	var nearly_full: Player = _mate(Vector3(0, 0, 4))
	nearly_full.health.current = nearly_full.health.max_health - 10.0
	assert_true(ability.use())
	assert_eq(player.health.current, player.health.max_health, "the user heals to full")
	assert_eq(near.health.current, 70.0, "a teammate at 8 m heals 50")
	assert_eq(far.health.current, 20.0, "not one at 12 m")
	assert_eq(nearly_full.health.current, nearly_full.health.max_health, "never past max")


func test_med_burst_does_not_revive() -> void:
	ability.ability = MED_BURST
	var downed: Player = _mate(Vector3(3, 0, 0))
	downed.is_downed = true
	assert_true(ability.use())
	assert_eq(downed.health.current, 20.0)


func test_adrenal_rush_speeds_movement_and_fire_past_the_caps() -> void:
	ability.ability = ADRENAL_RUSH
	player.stats.add_modifier(&"move_speed", "increased", 0.5, &"vest")
	var capped_move: float = player.get_stat(&"move_speed")
	var fire: float = player.get_stat(&"fire_interval")
	assert_true(ability.use())
	assert_almost_eq(player.get_stat(&"move_speed"), capped_move * 1.3, 0.0001, "x1.3 on top of the 15% cap")
	assert_almost_eq(player.get_stat(&"fire_interval"), fire / 1.3, 0.0001, "30% faster fire")
	ability._physics_process(7.9)
	assert_almost_eq(player.get_stat(&"move_speed"), capped_move * 1.3, 0.0001, "still on at 7.9 s")
	ability._physics_process(0.2)
	assert_almost_eq(player.get_stat(&"move_speed"), capped_move, 0.0001, "over after 8 s")
	assert_almost_eq(player.get_stat(&"fire_interval"), fire, 0.0001)


func test_adrenal_rush_ends_when_downed() -> void:
	ability.ability = ADRENAL_RUSH
	assert_true(ability.use())
	player.is_downed = true
	ability._physics_process(0.1)
	assert_eq(ability.multiplier(&"move_speed"), 1.0)


func _claims_taken(claims: HitClaims, sender: int, rate: float) -> int:
	var taken: int = 0
	for index: int in 40:
		if claims.take_claim(sender, RIFLE, rate):
			taken += 1
	return taken


func test_faster_fire_widens_the_hit_claim_window_but_slower_never_narrows_it() -> void:
	var claims: HitClaims = HitClaims.new()
	autofree(claims)
	var normal: int = _claims_taken(claims, 2, 1.0)
	assert_eq(normal, floori(RIFLE.rounds_per_minute / 60.0 * HitClaims.SLACK + 2.0))
	assert_eq(_claims_taken(claims, 3, 1.3), floori(RIFLE.rounds_per_minute / 60.0 * HitClaims.SLACK * 1.3 + 2.0))
	assert_eq(_claims_taken(claims, 4, 0.5), normal)
