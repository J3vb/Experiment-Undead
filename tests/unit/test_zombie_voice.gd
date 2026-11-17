## Zombie voice caps (sound.md voice limits): at most 8 mouths and 6 feet play
## at once; a closer zombie steals the farthest voice, a farther one stays quiet.
extends GutTest

const STREAM: AudioStream = preload("res://assets/audio/zombie_groan_1.wav")


func before_each() -> void:
	var camera: Camera3D = Camera3D.new()
	add_child_autofree(camera)
	camera.make_current()


func _voice(distance: float) -> ZombieVoice:
	var voice: ZombieVoice = ZombieVoice.new()
	voice.position = Vector3(distance, 1.6, 0.0)
	add_child_autofree(voice)
	voice.set_process(false)
	voice.footsteps = [STREAM]
	return voice


func _playing(voices: Array[ZombieVoice]) -> int:
	var count: int = 0
	for voice: ZombieVoice in voices:
		if voice.playing:
			count += 1
	return count


func test_no_more_than_eight_zombies_vocalise() -> void:
	var voices: Array[ZombieVoice] = []
	for index: int in 12:
		voices.append(_voice(2.0 + index))
		voices[-1].say(STREAM)
	assert_eq(_playing(voices), ZombieVoice.MAX_VOCALS)


func test_closer_zombie_steals_the_farthest_voice() -> void:
	var voices: Array[ZombieVoice] = []
	for index: int in ZombieVoice.MAX_VOCALS:
		voices.append(_voice(10.0 + index))
		voices[-1].say(STREAM)
	var far: ZombieVoice = _voice(30.0)
	far.say(STREAM)
	assert_false(far.playing, "a zombie farther than all playing voices stays quiet")
	var near: ZombieVoice = _voice(1.0)
	near.say(STREAM)
	assert_true(near.playing, "the closest zombie is heard")
	assert_false(voices[-1].playing, "the farthest voice was stolen")
	assert_eq(_playing(voices), ZombieVoice.MAX_VOCALS - 1)


func test_footsteps_are_capped_and_limited_to_range() -> void:
	var voices: Array[ZombieVoice] = []
	for index: int in 9:
		voices.append(_voice(2.0 + index))
		voices[-1].step()
	var playing: int = 0
	for voice: ZombieVoice in voices:
		if voice.feet.playing:
			playing += 1
	assert_eq(playing, ZombieVoice.MAX_STEPS)
	var distant: ZombieVoice = _voice(ZombieVoice.STEP_RANGE + 2.0)
	distant.step()
	assert_false(distant.feet.playing, "steps past 15 m are not played")


func test_a_playing_voice_keeps_its_slot_when_it_speaks_again() -> void:
	var voices: Array[ZombieVoice] = []
	for index: int in ZombieVoice.MAX_VOCALS:
		voices.append(_voice(2.0 + index))
		voices[-1].say(STREAM)
	voices[-1].say(STREAM)
	assert_eq(_playing(voices), ZombieVoice.MAX_VOCALS, "speaking again steals nobody")


func test_freed_voices_leave_the_caps() -> void:
	var voice: ZombieVoice = _voice(2.0)
	voice.say(STREAM)
	assert_true(ZombieVoice._vocals.has(voice))
	remove_child(voice)
	assert_false(ZombieVoice._vocals.has(voice), "a voice that leaves the tree frees its slot")
	voice.free()
