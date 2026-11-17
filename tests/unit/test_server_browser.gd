## The Servers screen: rows from the saved list and from replies, tabs, tags, errors and edits.
extends GutTest

const SCENE: PackedScene = preload("res://systems/ui/server_browser.tscn")
const LIST_PATH: String = "user://test_server_browser.cfg"
const SETTINGS_PATH: String = "user://test_server_browser_settings.cfg"
const SAVED: String = "192.168.1.40:7777"

var browser: ServerBrowser
var _settings_path: String
var _settings_values: Dictionary


func before_each() -> void:
	_settings_path = Settings.config_path
	_settings_values = Settings._values.duplicate(true)
	Settings.config_path = SETTINGS_PATH
	Settings.reset_to_defaults()
	Net.pending_join = ""
	ServerList.new(LIST_PATH).record_join(SAVED, "Friday Night Dead")
	browser = _open()


func after_each() -> void:
	Net.info.stop()
	Settings._values = _settings_values
	Settings.config_path = _settings_path
	Settings._apply_all()
	Net.pending_join = ""
	for path: String in [LIST_PATH, SETTINGS_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _open() -> ServerBrowser:
	var screen: ServerBrowser = SCENE.instantiate() as ServerBrowser
	screen.servers = ServerList.new(LIST_PATH)
	add_child_autofree(screen)
	return screen


func _info(players: int = 3, version: String = Build.version) -> Dictionary:
	return {
		"name": "Night shift",
		"players": players,
		"max": 8,
		"playing": "Halcyon Labs, round 12",
		"version": version,
		"protocol": Build.PROTOCOL_VERSION,
	}


func _item(index: int) -> TreeItem:
	return browser.list.get_root().get_child(index)


func _select(index: int) -> void:
	_item(index).select(0)


func _key(keycode: Key) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	browser._unhandled_key_input(event)


func test_saved_servers_are_listed_and_asked() -> void:
	assert_true(browser.rows.has(SAVED))
	assert_eq(browser.rows[SAVED].state, &"asking")
	assert_eq(_item(0).get_text(1), "Friday Night Dead")
	assert_eq(_item(0).get_text(2), "Asking...")
	assert_true(browser.list.has_focus())


func test_a_reply_fills_players_now_playing_and_ping() -> void:
	browser.take_reply(SAVED, _info(), 34, false)
	assert_eq(_item(0).get_text(2), "Halcyon Labs, round 12")
	assert_eq(_item(0).get_text(3), "3 / 8")
	assert_eq(_item(0).get_text(4), "34 ms")
	assert_eq(_item(0).get_custom_color(4), ServerBrowser.PING_GOOD)
	assert_eq(_item(0).get_text(1), "Friday Night Dead", "your name for it wins over the server's")


func test_silent_servers_say_not_responding() -> void:
	browser.query.timed_out.emit()
	assert_eq(browser.rows[SAVED].state, &"silent")
	assert_eq(_item(0).get_text(2), "Not responding")


func test_rows_sort_by_ping_and_slow_pings_are_orange() -> void:
	browser.take_reply(SAVED, _info(), 96, false)
	browser.take_reply("192.168.1.41:7777", _info(), 18, true)
	assert_eq(_item(0).get_metadata(0), "192.168.1.41:7777")
	assert_eq(_item(1).get_custom_color(4), ServerBrowser.PING_SLOW)


func test_full_and_other_version_rows_are_tagged_and_say_why_before_joining() -> void:
	browser.take_reply(SAVED, _info(8), 20, false)
	_select(0)
	assert_eq(_item(0).get_text(5), "Full")
	browser.join_selected()
	assert_eq(browser.error_dialog.message_label.text, "The server is full (8 of 8 players).")
	browser.error_dialog.action_button.pressed.emit()
	browser.take_reply(SAVED, _info(3, "0.0.1-old"), 20, false)
	assert_eq(_item(0).get_text(5), "v0.0.1-old")
	browser.join_selected()
	assert_string_contains(browser.error_dialog.message_label.text, "different builds", "dev builds have no order")
	assert_eq(Net.pending_join, "")


func test_other_version_names_the_side_to_update() -> void:
	assert_eq(ServerBrowser.version_details("0.1.0")["server_version"], "0.1.0")
	assert_eq(ServerBrowser.version_details("0.1.0")["client_version"], Build.version)
	var text: String = NetErrorDialog.message_for(
		&"wrong_version",
		{"server_version": "0.1.1", "client_version": "0.1.0", "older": Handshake.older_side("0.1.0", "0.1.1")}
	)
	assert_string_contains(text, "Update your game")


func test_a_bad_address_shows_the_error_and_joins_nothing() -> void:
	watch_signals(Net)
	browser.address_field.text = "https://not a server:banana"
	(browser.get_node("%AddJoin") as Button).pressed.emit()
	assert_true(browser.error_dialog.visible)
	assert_eq(
		browser.error_dialog.message_label.text,
		"That address doesn't look right. Use something like 192.168.1.20:7777."
	)
	assert_signal_not_emitted(Net, "join_started")
	assert_eq(Net.pending_join, "")
	assert_false(ServerList.new(LIST_PATH).has("https://not a server:banana"))
	browser.error_dialog.action_button.pressed.emit()
	assert_true(browser.list.has_focus())


func test_the_last_address_is_remembered() -> void:
	Settings.set_value(&"network", &"last_address", "192.168.1.20:24640")
	assert_eq(_open().address_field.text, "192.168.1.20:24640")


func test_lan_worlds_show_in_the_lan_tab_and_stay_after_remove() -> void:
	browser.take_reply("192.168.1.77:7778", _info(), 2, true)
	browser.show_tab(&"lan")
	assert_eq(browser.list.get_root().get_child_count(), 1)
	assert_eq(_item(0).get_text(5), "LAN")
	_select(0)
	_key(KEY_F)
	assert_true(ServerList.new(LIST_PATH).entry("192.168.1.77:7778").favourite, "F saves a LAN world")
	_key(KEY_DELETE)
	assert_false(ServerList.new(LIST_PATH).has("192.168.1.77:7778"))
	assert_true(browser.rows.has("192.168.1.77:7778"), "still answering, so still on the LAN tab")


func test_favourites_and_recent_tabs() -> void:
	_select(0)
	_key(KEY_F)
	browser.show_tab(&"recent")
	assert_eq(browser.list.get_root().get_child_count(), 0)
	browser.show_tab(&"favourites")
	assert_eq(browser.list.get_root().get_child_count(), 1)
	assert_eq(_item(0).get_text(0), "★")


func test_rename_and_remove_a_saved_server() -> void:
	_select(0)
	(browser.get_node("%Rename") as Button).pressed.emit()
	assert_true(browser.name_field.visible)
	browser.name_field.text_submitted.emit("Attic Bunker")
	assert_eq(_item(0).get_text(1), "Attic Bunker")
	assert_eq(ServerList.new(LIST_PATH).entry(SAVED).name, "Attic Bunker")
	_select(0)
	_key(KEY_DELETE)
	assert_false(browser.rows.has(SAVED))
	assert_false(ServerList.new(LIST_PATH).has(SAVED))
	assert_false((browser.get_node("%Detail") as Control).visible)


func test_the_detail_panel_shows_the_selected_server() -> void:
	browser.take_reply(SAVED, _info(), 34, false)
	_select(0)
	assert_true((browser.get_node("%Detail") as Control).visible)
	assert_eq((browser.get_node("%ServerName") as Label).text, "Friday Night Dead")
	assert_eq((browser.get_node("%Players") as Label).text, "3 / 8")
	assert_eq((browser.get_node("%Ping") as Label).text, "Ping 34 ms")
	assert_string_contains((browser.get_node("%Line") as Label).text, SAVED)


func test_a_running_world_answers_the_browser() -> void:
	ServerList.new(LIST_PATH).record_join("127.0.0.1:24680")
	Net.info.start(24680, "Next door")
	var screen: ServerBrowser = _open()
	await wait_until(func() -> bool: return screen.rows["127.0.0.1:24680"].state == &"answered", 3.0)
	assert_eq(screen.rows["127.0.0.1:24680"].info.name, "Next door")
	assert_false(screen.rows["127.0.0.1:24680"].lan)


func test_lan_broadcast_finds_a_world_without_typing() -> void:
	Net.info.start(24680, "Found by broadcast")
	browser.query.lan_ports = PackedInt32Array([24680 + ServerInfo.PORT_OFFSET])
	browser.refresh()
	var found: Callable = func() -> bool:
		for row: Dictionary in browser.rows.values():
			if row.lan:
				return true
		return false
	await wait_until(found, 3.0)
	if not found.call():
		pending("This machine has no broadcast route")
		return
	var names: Array = browser.rows.values().map(
		func(row: Dictionary) -> String: return ServerBrowser.display_name(row)
	)
	assert_has(names, "Found by broadcast")
