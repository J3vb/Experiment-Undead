## Enter world opens this PC's own world: a listen server on the saved port, or offline
## when friends cannot join, and a lone restart keeps the port (F-66 step 2).
extends GutTest

const SETTINGS_PATH: String = "user://test_own_world_settings.cfg"

var _settings_path: String
var _settings_values: Dictionary
var _real_router: Callable = Net.world.ports.make_router


func before_each() -> void:
	_settings_path = Settings.config_path
	_settings_values = Settings._values.duplicate(true)
	Settings.config_path = SETTINGS_PATH
	Settings.reset_to_defaults()
	Settings.set_value(&"network", &"upnp", false)  # CI never asks a real router


func after_each() -> void:
	Net.changing_place = false
	Net.leave()
	Net.world.close()
	Net.world.ports.close()
	Net.world.ports.make_router = _real_router
	Settings._values = _settings_values
	Settings.config_path = _settings_path
	Settings._apply_all()
	if FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))


func test_a_world_is_open_to_friends_by_default() -> void:
	assert_true(Net.world is OwnWorld)
	Net.world.open(24682)
	assert_true(Net.is_online(), "the world listens for friends")
	assert_true(Net.is_authority())
	assert_false(Net.is_coop(), "alone it still plays solo")
	assert_eq(Net.world.state.status, &"open")
	assert_eq(Net.world.state.port, 24682)
	assert_eq(Net.world.state.router, &"off", "router setting off: nothing asked")


func test_friends_off_keeps_the_world_offline() -> void:
	Settings.set_value(&"network", &"open_to_friends", false)
	Net.world.open(24683)
	assert_false(Net.is_online())
	assert_eq(Net.world.state, {"status": &"offline_off", "port": 24683})


func test_a_busy_port_runs_offline_and_says_why_without_a_menu_error() -> void:
	var holder: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	assert_eq(holder.create_server(24684, 1), OK)
	Net.world.open(24684)
	assert_engine_error_count(1, "ENet refuses the occupied port")
	assert_false(Net.is_online())
	assert_eq(Net.world.state, {"status": &"offline_busy", "port": 24684})
	assert_true(Net.last_error.is_empty(), "the menu shows no error: the world just runs offline")
	holder.close()


func test_the_pause_line_says_whether_friends_can_join() -> void:
	assert_eq(PauseScreen.world_text({"status": &"open", "port": 7777}), "Friends can join on port 7777")
	assert_true(
		PauseScreen.world_text({"status": &"open", "port": 7777, "router": &"off"}).contains("To let others in")
	)
	assert_eq(
		PauseScreen.world_text({"status": &"offline_busy", "port": 7777}), "Port 7777 is in use, friends can't join"
	)
	assert_eq(PauseScreen.world_text({"status": &"offline_off", "port": 7777}), "", "setting off: no line")
	assert_eq(PauseScreen.world_text({}), "", "a friend's game: no line")


func test_the_router_answer_reaches_the_world_state() -> void:
	var router: RefCounted = (load("res://tests/unit/test_port_opener.gd") as GDScript).StandInRouter.new()
	Net.world.ports.make_router = func() -> Object: return router
	Settings.set_value(&"network", &"upnp", true)
	watch_signals(Net.world)
	Net.world.open(24686)
	assert_eq(Net.world.state.router, &"pending", "the router is asked in a thread")
	await wait_until(func() -> bool: return Net.world.state.router != &"pending", 5.0, "router answered")
	assert_eq(Net.world.state.router, &"opened")
	assert_eq(Net.world.state.address, "81.2.3.4")
	assert_signal_emitted(Net.world, "changed")
	assert_eq(PauseScreen.world_address(Net.world.state), "81.2.3.4:24686", "what Copy puts on the clipboard")


func test_the_pause_line_names_the_address_or_why_internet_friends_cannot_join() -> void:
	var open: Dictionary = {"status": &"open", "port": 7777, "address": "81.2.3.4", "router": &"opened"}
	assert_eq(PauseScreen.world_text(open), "Friends add you at 81.2.3.4:7777")
	open.merge({"router": &"cgnat", "address": "192.168.1.20"}, true)
	assert_string_contains(PauseScreen.world_text(open), "192.168.1.20:7777")
	assert_string_contains(PauseScreen.world_text(open), "internet provider shares your address")
	open.router = &"no_router"
	assert_string_contains(PauseScreen.world_text(open), "did not answer")
	assert_string_contains(PauseScreen.world_text(open), "UDP 7777 and 8777")
	open.router = &"failed"
	assert_string_contains(PauseScreen.world_text(open), "refused")
	open.router = &"pending"
	assert_string_contains(PauseScreen.world_text(open), "Checking your router")
	assert_eq(PauseScreen.world_address({"status": &"offline_busy", "port": 7777}), "", "nothing to copy offline")
