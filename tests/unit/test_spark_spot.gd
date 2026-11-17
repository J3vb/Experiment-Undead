## SparkSpot: a burst restarts the sparks and lights the flash, the flash goes
## out again quickly, the crackle plays, and the next burst is scheduled inside
## its interval.
extends GutTest

const SCENE: String = "res://systems/effects/spark_spot.tscn"


func _spot() -> SparkSpot:
	var spot: SparkSpot = (load(SCENE) as PackedScene).instantiate() as SparkSpot
	add_child_autofree(spot)
	spot.set_process(false)
	return spot


func test_starts_dark_with_a_burst_scheduled() -> void:
	var spot: SparkSpot = _spot()
	assert_false(spot.flash.visible)
	assert_between(spot.time_to_next(), spot.min_interval, spot.max_interval)


func test_burst_lights_the_flash_and_emits() -> void:
	var spot: SparkSpot = _spot()
	spot.burst()
	assert_true(spot.flash.visible, "flash on")
	assert_true(spot.particles.emitting, "sparks emitting")
	assert_between(spot.time_to_next(), spot.min_interval, spot.max_interval)


func test_flash_goes_out_after_its_time() -> void:
	var spot: SparkSpot = _spot()
	spot.burst()
	spot._process(SparkSpot.FLASH_SECONDS + 0.01)
	assert_false(spot.flash.visible, "flash off again")


func test_bursts_again_when_the_wait_runs_out() -> void:
	var spot: SparkSpot = _spot()
	spot._process(spot.time_to_next() + 0.01)
	assert_true(spot.flash.visible, "next burst fired")


func test_burst_plays_the_crackle() -> void:
	var spot: SparkSpot = _spot()
	assert_not_null(spot.crackle, "scene has a crackle player")
	spot.burst()
	assert_true(spot.crackle.playing, "crackle plays with the sparks")
