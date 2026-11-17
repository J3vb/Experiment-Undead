extends GutTest

const SCENE: PackedScene = preload("res://systems/launcher/launcher_screen.tscn")
const WORK: String = "user://test_launcher_screen"
const NOWHERE: String = "--releases-api=http://127.0.0.1:9/releases.json"

var versions: String = ""
var saved_config: String = ""


func before_each() -> void:
	versions = ProjectSettings.globalize_path(WORK.path_join("versions"))
	VersionInstaller.remove_tree(ProjectSettings.globalize_path(WORK))
	DirAccess.make_dir_recursive_absolute(versions)
	saved_config = FileAccess.get_file_as_string(VersionInstaller.CONFIG)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(VersionInstaller.CONFIG))


func after_each() -> void:
	VersionInstaller.remove_tree(ProjectSettings.globalize_path(WORK))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(VersionInstaller.CONFIG))
	if not saved_config.is_empty():
		var file: FileAccess = FileAccess.open(VersionInstaller.CONFIG, FileAccess.WRITE)
		file.store_string(saved_config)


func _screen() -> LauncherScreen:
	var screen: LauncherScreen = SCENE.instantiate() as LauncherScreen
	screen.args = PackedStringArray([NOWHERE])
	(screen.get_node("Installer") as VersionInstaller).versions_dir = versions
	add_child_autofree(screen)
	return screen


func test_opens_only_for_release_builds_in_the_install_folder() -> void:
	var none: PackedStringArray = PackedStringArray()
	assert_true(LauncherScreen.should_open(none, "0.1.0", true, "/games/eu"))
	assert_true(LauncherScreen.should_open(none, "0.2.0-test.1", true, "/games/eu"))
	assert_false(LauncherScreen.should_open(none, "0.1.1-dev.4+abc1234", true, "/games/eu"), "dev build")
	assert_false(LauncherScreen.should_open(none, "0.1.0", false, "/games/eu"), "editor")
	assert_false(LauncherScreen.should_open(none, "0.1.0", true, "/games/eu/versions/0.1.0"), "started copy")
	for flag: String in ["--from-launcher", "--join=1.2.3.4:7777", "--host", "--server"]:
		assert_false(LauncherScreen.should_open(PackedStringArray([flag]), "0.1.0", true, "/games/eu"), flag)
	assert_true(LauncherScreen.should_open(PackedStringArray(["--launcher"]), "dev", false, "/x"), "smoke test hook")


func test_picks_newest_local_version() -> void:
	DirAccess.make_dir_recursive_absolute(versions.path_join("99.0.0"))
	DirAccess.make_dir_recursive_absolute(versions.path_join("99.1.0-test.1"))
	var screen: LauncherScreen = _screen()
	assert_eq(screen.best_local(), "99.0.0", "stable skips installed test builds")
	screen.channel = ReleaseFeed.TEST
	assert_eq(screen.best_local(), "99.1.0-test.1")


func test_root_copy_when_nothing_is_installed() -> void:
	var screen: LauncherScreen = _screen()
	assert_eq(screen.best_local(), Build.version)


func test_plays_offline_without_network() -> void:
	var screen: LauncherScreen = _screen()
	await wait_until(func() -> bool: return screen.play_button.text == "PLAY OFFLINE", 10.0, "offline")
	assert_false(screen.online)
	assert_false(screen.play_button.disabled)
	assert_string_contains(screen.status_label.text, "Offline")


func test_saves_channel_and_root_version() -> void:
	var screen: LauncherScreen = _screen()
	assert_eq(VersionInstaller.launcher_value(&"root_version", ""), Build.version)
	screen.channel_button.select(1)
	screen.channel_button.item_selected.emit(1)
	assert_eq(screen.channel, ReleaseFeed.TEST)
	assert_eq(LauncherScreen.load_channel(), ReleaseFeed.TEST)


func test_shows_newest_release_for_channel() -> void:
	var json: JSON = JSON.new()
	json.parse(FileAccess.get_file_as_string("res://tests/fixtures/releases.json"))
	var screen: LauncherScreen = _screen()
	screen.releases = json.data
	screen.newest = ReleaseFeed.newest(screen.releases, ReleaseFeed.STABLE, "-windows.zip")
	screen._show_release(screen.newest)
	screen._fill_news()
	assert_eq(screen.headline_label.text, "v0.1.1")
	assert_eq(screen.kicker_label.text, "LATEST RELEASE")
	assert_eq(screen.notes_label.text, "Stable notes")
	await get_tree().process_frame
	assert_eq(screen.news_list.get_child_count(), 2, "stable news skips the test build and the draft")


func test_server_panel_toggles_and_shows_state() -> void:
	var screen: LauncherScreen = _screen()
	var tab: Button = screen.get_node("%ServerTab")
	tab.button_pressed = true
	assert_true(screen.get_node("%ServerPanel").visible)
	assert_false(screen.get_node("%Hero").visible)
	assert_eq((screen.get_node("%ServerStatus") as Label).text, "Not running")
	assert_false((screen.get_node("%StartServer") as Button).disabled)
	assert_true((screen.get_node("%StopServer") as Button).disabled)
	assert_eq(screen.exe_for(Build.version), OS.get_executable_path())
	assert_string_ends_with(screen.exe_for("99.0.0"), "versions/99.0.0/" + VersionInstaller.exe_name())
