## The servers this PC added or joined, saved in user://servers.cfg: one section per "address:port"
## (URI-encoded, so IPv6 colons are safe) with name, favourite and last_joined. Favourites stay;
## the newest 20 others are kept as recent. Unknown keys are kept for later versions.
class_name ServerList
extends RefCounted

const PATH: String = "user://servers.cfg"
const RECENT_LIMIT: int = 20

var path: String
var _file: ConfigFile = ConfigFile.new()


func _init(file_path: String = PATH) -> void:
	path = file_path
	if FileAccess.file_exists(path):
		_file.load(path)


func has(address: String) -> bool:
	return _file.has_section(address.uri_encode())


## Favourites first, then the most recently joined. Each entry: address, name, favourite, last_joined.
func entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for section: String in _file.get_sections():
		out.append(entry(section.uri_decode()))
	out.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			if a.favourite != b.favourite:
				return a.favourite
			return a.last_joined > b.last_joined
	)
	return out


func entry(address: String) -> Dictionary:
	return {
		"address": address,
		"name": str(_file.get_value(address.uri_encode(), "name", "")),
		"favourite": bool(_file.get_value(address.uri_encode(), "favourite", false)),
		"last_joined": int(_file.get_value(address.uri_encode(), "last_joined", 0)),
	}


## A join (or an Add and join): the server moves to the top of Recent. Keeps a name given before.
func record_join(address: String, shown_name: String = "") -> void:
	if not shown_name.is_empty() and str(_file.get_value(address.uri_encode(), "name", "")).is_empty():
		_file.set_value(address.uri_encode(), "name", shown_name.left(ServerInfo.NAME_LENGTH))
	_file.set_value(address.uri_encode(), "last_joined", int(Time.get_unix_time_from_system()))
	_trim()
	save()


func set_favourite(address: String, on: bool) -> void:
	_file.set_value(address.uri_encode(), "favourite", on)
	_trim()
	save()


func rename(address: String, shown_name: String) -> void:
	if has(address):
		_file.set_value(address.uri_encode(), "name", shown_name.strip_edges().left(ServerInfo.NAME_LENGTH))
		save()


func remove(address: String) -> void:
	if has(address):
		_file.erase_section(address.uri_encode())
		save()


func save() -> void:
	_file.save(path)


func _trim() -> void:
	var recent: Array[Dictionary] = entries().filter(func(item: Dictionary) -> bool: return not item.favourite)
	for item: Dictionary in recent.slice(RECENT_LIMIT):
		_file.erase_section(str(item.address).uri_encode())
