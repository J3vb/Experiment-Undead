## Generated music imports as loops with aligned combat stems and Music routing.
extends GutTest


func test_loops_load_and_combat_lengths_match() -> void:
	var bed: AudioStreamOggVorbis = load("res://assets/audio/music/halcyon_bed.ogg") as AudioStreamOggVorbis
	var drive: AudioStreamOggVorbis = load("res://assets/audio/music/halcyon_drive.ogg") as AudioStreamOggVorbis
	var rest: AudioStreamOggVorbis = load("res://assets/audio/music/breather.ogg") as AudioStreamOggVorbis
	assert_not_null(bed)
	assert_not_null(drive)
	assert_not_null(rest)
	assert_true(bed.loop)
	assert_true(drive.loop)
	assert_true(rest.loop)
	assert_almost_eq(bed.get_length(), 38.4, 1.0 / 44100.0)
	assert_eq(bed.get_length(), drive.get_length())
	assert_between(rest.get_length(), 30.0, 40.0)
	var total: int = 0
	for track: String in ["halcyon_bed", "halcyon_drive", "breather"]:
		total += FileAccess.open("res://assets/audio/music/%s.ogg" % track, FileAccess.READ).get_length()
	assert_lt(total, 8000000)


func test_music_routing_menu_autoplay_and_scene_isolation() -> void:
	var scene: PackedScene = load("res://systems/audio/music_player.tscn") as PackedScene
	var first: MusicPlayer = scene.instantiate() as MusicPlayer
	var second: MusicPlayer = scene.instantiate() as MusicPlayer
	autofree(first)
	autofree(second)
	var combat: AudioStreamPlayer = first.get_node("Combat") as AudioStreamPlayer
	var other: AudioStreamPlayer = second.get_node("Combat") as AudioStreamPlayer
	assert_eq(combat.bus, &"Music")
	assert_ne(combat.stream, other.stream)
	assert_eq((first.get_node("Breather") as AudioStreamPlayer).bus, &"Music")
	var menu: Node = (load("res://systems/ui/main_menu.tscn") as PackedScene).instantiate()
	autofree(menu)
	var music: AudioStreamPlayer = menu.get_node("Music") as AudioStreamPlayer
	assert_eq(music.bus, &"Music")
	assert_true(music.autoplay)
