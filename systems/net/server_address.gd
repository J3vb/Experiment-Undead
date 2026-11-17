## Server addresses as players type them: "host", "host:port", "[ipv6]:port". The menu, the
## server list and Net all read them the same way.
class_name ServerAddress
extends RefCounted


## "1.2.3.4:7777" -> ["1.2.3.4", 7777]. Missing or bad port uses Net.DEFAULT_PORT.
static func parse(text: String) -> Array:
	var address: String = text.strip_edges()
	var port: int = Net.DEFAULT_PORT
	var colon: int = address.rfind(":")
	if colon > 0 and address.substr(colon + 1).is_valid_int():
		port = address.substr(colon + 1).to_int()
		address = address.substr(0, colon)
	if address.is_empty():
		address = "127.0.0.1"
	return [address, port]


## "host:port" ready for Net.join, or "" when the text is not a valid address, so malformed
## input never opens a connection.
static func normalized(text: String) -> String:
	var parts: PackedStringArray = _address_parts(text.strip_edges())
	if parts.size() != 2 or not _valid_host(parts[0]) or not parts[1].is_valid_int():
		return ""
	var port: int = parts[1].to_int()
	if port < 1 or port > 65535:
		return ""
	return "%s:%d" % [parts[0], port]


static func _address_parts(address: String) -> PackedStringArray:
	if address.begins_with("["):
		return _bracketed_address_parts(address)
	var colon: int = address.rfind(":")
	if colon < 0:
		return PackedStringArray([address, str(Net.DEFAULT_PORT)])
	var host: String = address.substr(0, colon)
	var port: String = address.substr(colon + 1)
	# Keep legacy IPv6 host:port parsing; brackets disambiguate a literal's last group.
	if address.count(":") == 1 or (host.is_valid_ip_address() and port.is_valid_int()):
		return PackedStringArray([host, port])
	return PackedStringArray([address, str(Net.DEFAULT_PORT)])


static func _bracketed_address_parts(address: String) -> PackedStringArray:
	var close: int = address.find("]")
	if close < 0:
		return PackedStringArray()
	var host: String = address.substr(1, close - 1)
	var suffix: String = address.substr(close + 1)
	if not host.contains(":") or not host.is_valid_ip_address():
		return PackedStringArray()
	if suffix.is_empty():
		return PackedStringArray([host, str(Net.DEFAULT_PORT)])
	if not suffix.begins_with(":"):
		return PackedStringArray()
	return PackedStringArray([host, suffix.substr(1)])


static func _valid_host(host: String) -> bool:
	if host.is_empty() or host.length() > 253:
		return false
	if host.is_valid_ip_address():
		return true
	if host.replace(".", "").is_valid_int():
		return false
	var label_pattern: RegEx = RegEx.create_from_string("^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?$")
	for label: String in host.split("."):
		if label_pattern.search(label) == null:
			return false
	return true
