## Owner-side Legendary traits change the owner's own gun, and never the server's copy of a client.
extends GutTest

const PLAYER: PackedScene = preload("res://systems/player/player.tscn")

var player: Player


func before_each() -> void:
	player = PLAYER.instantiate() as Player
	add_child_autofree(player)
	player.set_physics_process(false)


func _gun(base: StringName, legendary: String, q: float = 1.0) -> Weapon:
	var weapon: Weapon = player.weapons.give(Content.weapon(base))
	weapon.item = ItemInstance.new(
		{"uid": legendary, "base": String(base), "rar": "legendary", "trait": [legendary, q]}
	)
	return weapon


func test_bottomless_refills_on_the_tenth_kill_only() -> void:
	var smg: Weapon = _gun(&"kestrel_smg", "bottomless")
	player.weapons.equip(player.weapons.weapons.find(smg))
	smg.instance.ammo_in_mag = 3
	var reserve: int = smg.instance.ammo_reserve
	for kill: int in 9:
		Events.hit_confirmed.emit(player, true, false)
	assert_eq(smg.instance.ammo_in_mag, 3, "nine kills")
	Events.hit_confirmed.emit(player, false, true)
	assert_eq(smg.instance.ammo_in_mag, 3, "a hit is not a kill")
	Events.hit_confirmed.emit(player, true, false)
	assert_eq(smg.instance.ammo_in_mag, smg.data.magazine_size, "the tenth kill refills")
	assert_eq(smg.instance.ammo_reserve, reserve - (smg.data.magazine_size - 3), "from reserve")
	assert_eq(smg.instance.trait_kills, 0)


func test_overpressure_fires_more_pellets_once_after_a_reload() -> void:
	var shotgun: Weapon = _gun(&"brenner_trench", "overpressure")
	var pellets: int = shotgun.data.pellets
	assert_eq(OwnerTraits.take_pellets(shotgun.item, shotgun.instance, true), pellets, "no reload yet")
	shotgun.instance.ammo_in_mag = 0
	assert_true(shotgun.start_reload())
	for tick: int in 40:
		shotgun.tick(0.1)
		if shotgun.instance.charged:
			break
	assert_true(shotgun.instance.charged, "one shell charges it")
	assert_eq(OwnerTraits.take_pellets(shotgun.item, shotgun.instance, true), pellets * 2)
	assert_eq(OwnerTraits.take_pellets(shotgun.item, shotgun.instance, true), pellets, "only the first shot")


func test_overpressure_full_magazine_reload_charges_too() -> void:
	var rifle: Weapon = _gun(&"rifle_ar", "tidewater")
	rifle.instance.ammo_in_mag = 0
	rifle.start_reload()
	rifle.tick(10.0)
	assert_true(rifle.instance.charged)
	assert_eq(
		OwnerTraits.take_pellets(rifle.item, rifle.instance, true), rifle.data.pellets, "no trait, no extra pellets"
	)


func test_dead_mans_hand_multiplies_only_the_last_round() -> void:
	var revolver: Weapon = _gun(&"hollis_44", "dead_mans_hand", 0.0)
	revolver.instance.ammo_in_mag = 1
	assert_eq(OwnerTraits.last_round_scale(revolver.item, revolver.instance, revolver._owns()), 1.0)
	revolver.instance.ammo_in_mag = 0
	assert_eq(OwnerTraits.last_round_scale(revolver.item, revolver.instance, revolver._owns()), 3.0)


func test_owner_traits_skip_the_server_copy_of_a_client() -> void:
	var revolver: Weapon = _gun(&"hollis_44", "dead_mans_hand")
	var smg: Weapon = _gun(&"kestrel_smg", "bottomless")
	player.set_multiplayer_authority(7, false)
	revolver.instance.ammo_in_mag = 0
	assert_eq(OwnerTraits.last_round_scale(revolver.item, revolver.instance, revolver._owns()), 1.0)
	player.weapons.equip(player.weapons.weapons.find(smg))
	for kill: int in 10:
		Events.hit_confirmed.emit(player, true, false)
	assert_eq(smg.instance.trait_kills, 0)
