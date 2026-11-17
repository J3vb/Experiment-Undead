## ServerList: saved and recent servers in a ConfigFile.
extends GutTest

const PATH: String = "user://test_server_list.cfg"


func before_each() -> void:
	_remove()


func after_each() -> void:
	_remove()


func _remove() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func test_a_missing_file_is_an_empty_list() -> void:
	assert_eq(ServerList.new(PATH).entries(), [] as Array[Dictionary])


func test_a_join_is_saved_with_its_name_and_kept_next_time() -> void:
	ServerList.new(PATH).record_join("192.168.1.40:7777", "Friday Night Dead")
	var again: ServerList = ServerList.new(PATH)
	assert_true(again.has("192.168.1.40:7777"))
	var item: Dictionary = again.entry("192.168.1.40:7777")
	assert_eq(item.name, "Friday Night Dead")
	assert_false(item.favourite)
	assert_gt(item.last_joined, 0)
	again.record_join("192.168.1.40:7777", "Renamed by the server")
	assert_eq(again.entry("192.168.1.40:7777").name, "Friday Night Dead", "a name given before stays")


func test_favourites_come_first_then_the_newest_join() -> void:
	var servers: ServerList = ServerList.new(PATH)
	servers.record_join("10.0.0.1:7777")
	servers.record_join("10.0.0.2:7777")
	servers.record_join("10.0.0.3:7777")
	servers._file.set_value("10.0.0.1%3A7777", "last_joined", 100)
	servers._file.set_value("10.0.0.2%3A7777", "last_joined", 300)
	servers._file.set_value("10.0.0.3%3A7777", "last_joined", 200)
	servers.set_favourite("10.0.0.1:7777", true)
	var order: Array = servers.entries().map(func(item: Dictionary) -> String: return item.address)
	assert_eq(order, ["10.0.0.1:7777", "10.0.0.2:7777", "10.0.0.3:7777"])


func test_rename_and_remove() -> void:
	var servers: ServerList = ServerList.new(PATH)
	servers.record_join("10.0.0.1:7777", "Attic Bunker")
	servers.rename("10.0.0.1:7777", "  " + "x".repeat(50))
	assert_eq(ServerList.new(PATH).entry("10.0.0.1:7777").name, "x".repeat(ServerInfo.NAME_LENGTH))
	servers.rename("10.0.0.9:7777", "Not saved")
	assert_false(servers.has("10.0.0.9:7777"), "rename never adds a server")
	servers.remove("10.0.0.1:7777")
	assert_false(ServerList.new(PATH).has("10.0.0.1:7777"))


func test_recent_keeps_the_newest_20_and_every_favourite() -> void:
	var servers: ServerList = ServerList.new(PATH)
	servers.set_favourite("10.0.1.1:7777", true)
	for i: int in 25:
		servers._file.set_value(("10.0.0.%d:7777" % i).uri_encode(), "last_joined", 1000 + i)
	servers.record_join("10.0.0.99:7777")
	var recent: Array[Dictionary] = servers.entries().filter(func(item: Dictionary) -> bool: return not item.favourite)
	assert_eq(recent.size(), ServerList.RECENT_LIMIT)
	assert_true(servers.has("10.0.1.1:7777"), "a favourite is never trimmed")
	assert_true(servers.has("10.0.0.99:7777"), "the newest join stays")
	assert_false(servers.has("10.0.0.0:7777"), "the oldest goes")


func test_unknown_keys_and_ipv6_addresses_survive_a_save() -> void:
	var file: ConfigFile = ConfigFile.new()
	file.set_value("%3A%3A1%3A7777", "name", "Loopback")
	file.set_value("%3A%3A1%3A7777", "password_hint", "from a later version")
	file.save(PATH)
	var servers: ServerList = ServerList.new(PATH)
	assert_eq(servers.entries()[0].address, "::1:7777")
	servers.set_favourite("::1:7777", true)
	var reread: ConfigFile = ConfigFile.new()
	reread.load(PATH)
	assert_eq(reread.get_value("%3A%3A1%3A7777", "password_hint"), "from a later version")
	assert_true(reread.get_value("%3A%3A1%3A7777", "favourite"))
