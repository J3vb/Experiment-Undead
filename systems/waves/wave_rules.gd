## All round scaling in one data file, so balancing never touches code.
## Formulas follow docs/design/game-design.md#round-scaling.
class_name WaveRules
extends Resource

@export var enemy_mix: Array[EnemySpawnEntry] = []

@export_group("Timing")
@export var first_round_delay: float = 4.0
@export var intermission_time: float = 10.0
@export var spawn_interval_start: float = 2.0
## Each round's spawn delay is the previous one times this.
@export var spawn_interval_factor: float = 0.95
@export var spawn_interval_min: float = 0.3

@export_group("Count")
## Fixed counts for the first rounds; after them count = floor(a*r^2 + b*r + c).
@export var early_counts: PackedInt32Array = PackedInt32Array([6, 8, 13, 18])
@export var count_a: float = 0.09
@export var count_b: float = 0.6
@export var count_c: float = 15.0
## Co-op: count x (1 + this per extra player).
@export var coop_count_per_player: float = 0.5
@export var max_alive: int = 24
@export var max_alive_per_extra_player: int = 6

@export_group("Health")
## Round health: base, plus step per round up to linear_until_round, then x growth per round.
@export var base_health: float = 120.0
@export var health_step: float = 90.0
@export var linear_until_round: int = 9
@export var health_growth: float = 1.09
## Zombie attack damage growth per round (the design has none: 0).
@export var damage_growth_per_round: float = 0.0

@export_group("Speed mix")
## Speeds in m/s a speed-mix zombie can roll (Shamble, Jog, Run, Sprint).
@export var speed_tiers: PackedFloat64Array = PackedFloat64Array([1.2, 2.6, 4.2, 5.6])
## Sorted by first_round; the last band at or below the round applies.
@export var speed_bands: Array[SpeedBand] = []

@export_group("Spawning")
@export var min_spawn_distance: float = 10.0

@export_group("Blackout")
## Only this enemy spawns in a Blackout round, in packs from one spawn point. None = no Blackouts.
@export var blackout_enemy: EnemyData
@export var blackout_first_round: int = 6
## Rounds between Blackouts, rolled from the session RNG.
@export var blackout_gap_min: int = 5
@export var blackout_gap_max: int = 7
## A Blackout round's count is the normal count times this.
@export var blackout_count_mult: float = 1.5
@export var pack_min: int = 4
@export var pack_max: int = 6
## Dropped where the last zombie of a Blackout round died.
@export var blackout_reward: PowerUpData


func get_enemy_count(round_number: int, players: int = 1) -> int:
	var count: int = 0
	if round_number <= early_counts.size():
		count = early_counts[maxi(round_number, 1) - 1]
	else:
		var r: float = float(round_number)
		count = floori(count_a * r * r + count_b * r + count_c + 0.000001)
	return floori(count * (1.0 + coop_count_per_player * maxi(players - 1, 0)))


## The Blackout rounds up to `up_to`: blackout_first_round, then a gap of blackout_gap_min..max each time.
func roll_blackouts(rng: RandomNumberGenerator, up_to: int) -> PackedInt32Array:
	var rounds: PackedInt32Array = PackedInt32Array()
	if blackout_enemy == null:
		return rounds
	var next: int = blackout_first_round
	while next <= up_to:
		rounds.append(next)
		next += maxi(rng.randi_range(blackout_gap_min, maxi(blackout_gap_max, blackout_gap_min)), 1)
	return rounds


func get_blackout_count(round_number: int, players: int = 1) -> int:
	return floori(get_enemy_count(round_number, players) * blackout_count_mult + 0.000001)


func get_max_alive(players: int = 1) -> int:
	return max_alive + max_alive_per_extra_player * maxi(players - 1, 0)


func get_spawn_interval(round_number: int) -> float:
	return maxf(spawn_interval_start * pow(spawn_interval_factor, round_number - 1), spawn_interval_min)


## Round health divided by round-one health; EnemyData.max_health is the round-one health.
func get_health_multiplier(round_number: int) -> float:
	return get_round_health(round_number) / base_health


func get_round_health(round_number: int) -> float:
	var linear_round: int = clampi(round_number, 1, linear_until_round)
	var health: float = base_health + health_step * (linear_round - 1)
	if round_number > linear_until_round:
		health *= pow(health_growth, round_number - linear_until_round)
	return health


func get_damage_multiplier(round_number: int) -> float:
	return 1.0 + damage_growth_per_round * (round_number - 1)


## Rolls a speed in m/s from the round's band with the session RNG.
func roll_speed(round_number: int, rng: RandomNumberGenerator) -> float:
	var band: SpeedBand = _band_for(round_number)
	if speed_tiers.is_empty():
		return 0.0
	if band == null:
		return speed_tiers[0]
	var roll: float = rng.randf()
	for tier: int in mini(band.weights.size(), speed_tiers.size()):
		roll -= band.weights[tier]
		if roll < 0.0:
			return speed_tiers[tier]
	return speed_tiers[mini(band.weights.size(), speed_tiers.size()) - 1]


func _band_for(round_number: int) -> SpeedBand:
	var found: SpeedBand = null
	for band: SpeedBand in speed_bands:
		if band != null and band.first_round <= round_number:
			found = band
	return found


func pick_enemy(round_number: int, rng: RandomNumberGenerator) -> EnemyData:
	var total: float = 0.0
	for entry: EnemySpawnEntry in enemy_mix:
		total += entry.get_weight(round_number)
	if total <= 0.0:
		return null
	var roll: float = rng.randf() * total
	for entry: EnemySpawnEntry in enemy_mix:
		var w: float = entry.get_weight(round_number)
		if w <= 0.0:
			continue
		roll -= w
		if roll <= 0.0:
			return entry.enemy
	return enemy_mix.back().enemy
