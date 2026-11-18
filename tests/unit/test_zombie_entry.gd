## ZombieEntry: the zombie's window vault state, and that clients can still
## receive it through ZombieSync's property path.
extends GutTest

const WALKER: String = "res://content/enemies/zombie_walker.tres"


func _spawn() -> Zombie:
	var data: EnemyData = load(WALKER) as EnemyData
	var zombie: Zombie = data.scene.instantiate() as Zombie
	zombie.setup(data, 1, 1.0, 1.0, 1.0, RandomNumberGenerator.new())
	add_child_autofree(zombie)
	zombie.set_physics_process(false)
	zombie.set_process(false)
	return zombie


func test_vault_progress_runs_from_zero_to_one_and_is_minus_one_otherwise() -> void:
	var entry: ZombieEntry = ZombieEntry.new()
	assert_eq(entry.vault_progress(), -1.0, "not vaulting")
	entry.vault_time = 0.0
	assert_eq(entry.vault_progress(), 0.0)
	entry.vault_time = ZombieEntry.VAULT_TIME * 0.5
	assert_almost_eq(entry.vault_progress(), 0.5, 0.0001)
	entry.vault_time = ZombieEntry.VAULT_TIME * 3.0
	assert_eq(entry.vault_progress(), 1.0, "clamped at the landing")


func test_every_synced_path_resolves_on_a_zombie() -> void:
	var zombie: Zombie = _spawn()
	for path: NodePath in ZombieSync.SYNCED:
		var property: NodePath = NodePath(path.get_concatenated_subnames())
		assert_ne(typeof(zombie.get_indexed(property)), TYPE_NIL, "%s resolves" % path)


func test_synced_vault_time_reaches_the_entry_and_the_rig() -> void:
	var zombie: Zombie = _spawn()
	zombie.set_indexed(^"entry:vault_time", ZombieEntry.VAULT_TIME * 0.5)
	assert_almost_eq(zombie.entry.vault_progress(), 0.5, 0.0001, "a client copy sees the vault")
	zombie.state = Zombie.State.CHASING
	zombie.state_time = 0.1
	zombie.visual.follow(zombie, 0.016)
	assert_almost_eq(zombie.visual.position.y, ZombieRig.VAULT_HEIGHT, 0.001, "rig shows the top of the hop")


func test_restart_chase_ends_the_vault() -> void:
	var zombie: Zombie = _spawn()
	zombie.entry.vault_time = 0.4
	zombie.restart_chase()
	assert_eq(zombie.entry.vault_progress(), -1.0)
	assert_eq(zombie.state, Zombie.State.CHASING)
