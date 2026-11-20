## Timed power-ups in solo: the server timer starts, counts down, ends and resets on a
## re-pickup; Payday doubles hit and kill points while it runs; the HUD ring follows it.
extends GutTest

const PAYDAY: PowerUpData = preload("res://content/power_ups/payday.tres")
const RESUPPLY: PowerUpData = preload("res://content/power_ups/resupply.tres")

var session: GameSession
var drops: PowerUpDrops
var player: Player
var rules: EconomyRules


func before_each() -> void:
	session = CoopSide.make(self, "Solo")
	drops = session.power_up_drops
	drops.set_physics_process(false)
	rules = session.economy.rules
	player = CoopSide.add_player(session, 1)
	player.wallet.set_points(0)


func after_each() -> void:
	CoopSide.close(session)


func _hit(kill: bool) -> void:
	var enemy: Node3D = Node3D.new()
	add_child_autofree(enemy)
	var info: DamageInfo = DamageInfo.create(10.0, player)
	Events.enemy_damaged.emit(enemy, info)
	if kill:
		Events.enemy_killed.emit(enemy, info)


func _timers() -> PowerUpTimers:
	return session.hud.get_node(^"Root/PowerUpTimers") as PowerUpTimers


func test_payday_is_a_30_second_timer() -> void:
	assert_eq(PAYDAY.effect, PowerUpData.Effect.PAYDAY)
	assert_eq(PAYDAY.duration, 30.0)
	assert_eq(RESUPPLY.duration, 0.0, "Resupply acts once")


func test_timer_starts_counts_down_and_ends() -> void:
	watch_signals(Events)
	drops.start_timer(PAYDAY)
	assert_signal_emitted_with_parameters(Events, "power_up_timer_started", [PAYDAY, 30.0])
	assert_true(drops.is_active(PowerUpData.Effect.PAYDAY))
	drops._physics_process(20.0)
	assert_almost_eq(drops.time_left(PAYDAY), 10.0, 0.001)
	drops._physics_process(10.5)
	assert_false(drops.is_active(PowerUpData.Effect.PAYDAY), "over after 30 s")
	assert_eq(drops.time_left(PAYDAY), 0.0)


func test_re_pickup_resets_to_full_time() -> void:
	drops.start_timer(PAYDAY)
	drops._physics_process(25.0)
	drops.start_timer(PAYDAY)
	assert_almost_eq(drops.time_left(PAYDAY), 30.0, 0.001, "not stacked, back to full")


func test_payday_doubles_hit_and_kill_points_then_stops() -> void:
	_hit(true)
	var normal: int = player.wallet.points
	assert_eq(normal, rules.points_per_hit + rules.points_per_kill)
	player.wallet.set_points(0)
	drops.start_timer(PAYDAY)
	_hit(true)
	assert_eq(player.wallet.points, normal * Economy.PAYDAY_MULTIPLIER)
	drops._physics_process(30.5)
	player.wallet.set_points(0)
	_hit(true)
	assert_eq(player.wallet.points, normal, "normal points once Payday ends")


func test_payday_does_not_double_repairs() -> void:
	drops.start_timer(PAYDAY)
	session.economy.pay_repair(player)
	assert_eq(player.wallet.points, rules.points_per_plank)


func test_collecting_payday_starts_the_timer_and_grants_no_ammo() -> void:
	player.spawn(session, [Content.weapon(&"pistol_service")])
	var gun: Weapon = player.weapons.current
	gun.instance.ammo_reserve = 0
	var pickup: PowerUp = drops._spawn(PAYDAY, Vector3.ZERO)
	pickup.collect(player)
	assert_true(drops.is_active(PowerUpData.Effect.PAYDAY))
	assert_eq(gun.instance.ammo_reserve, 0, "Payday is not an ammo pickup")


func test_hud_ring_counts_down_and_goes() -> void:
	drops.start_timer(PAYDAY)
	var row: PowerUpTimers = _timers()
	assert_almost_eq(row.time_left(PAYDAY), 30.0, 0.001)
	row._process(12.0)
	assert_almost_eq(row.time_left(PAYDAY), 18.0, 0.001)
	drops.start_timer(PAYDAY)
	assert_almost_eq(row.time_left(PAYDAY), 30.0, 0.001, "ring refills on a re-pickup")
	row._process(31.0)
	assert_eq(row.time_left(PAYDAY), 0.0, "ring gone")


func test_overtime_lengthens_the_collectors_timed_power_ups() -> void:
	player.skill_ranks = {&"overtime": 2}
	player.equip_gear([])
	var pickup: PowerUp = drops.drop(PAYDAY, Vector3(40, 0, 40))
	drops.on_collected(pickup, player)
	assert_almost_eq(drops.time_left(PAYDAY), 36.0, 0.001, "30 s + 3 s per rank")
