## The Servers screen: servers you added or joined (ServerList) plus worlds found on your network,
## each asked for its name, players, what it is playing and ping when the screen opens and on
## Refresh. There is no master server. Joining goes through Net.pending_join like the menu did.
class_name ServerBrowser
extends PanelContainer

signal closed

const SLOW_PING: int = 80
const PING_GOOD: Color = Color("3FE0C8")
const PING_SLOW: Color = Color("FF8A1C")
const TEXT_DIM: Color = Color(0.561, 0.639, 0.659, 1)
const TABS: Array[StringName] = [&"all", &"favourites", &"recent", &"lan"]

var servers: ServerList = ServerList.new()
## address -> {address, name, favourite, saved, lan, info, ping, state (&"asking" | &"answered" | &"silent")}.
var rows: Dictionary[String, Dictionary] = {}
var tab: StringName = &"all"
var query: ServerQuery = ServerQuery.new()

@onready var list: Tree = %List
@onready var address_field: LineEdit = %Address
@onready var name_field: LineEdit = %NameField
@onready var join_button: Button = %Join
@onready var error_dialog: NetErrorDialog = $NetErrorDialog


func _ready() -> void:
	var menu_theme: Theme = theme
	theme = preload("res://systems/ui/theme.tres").duplicate() as Theme
	theme.merge_with(menu_theme)
	_setup_list()
	for id: StringName in TABS:
		(get_node("%" + String(id).capitalize()) as Button).pressed.connect(show_tab.bind(id))
	%Refresh.pressed.connect(refresh)
	%AddJoin.pressed.connect(add_and_join)
	address_field.text_submitted.connect(func(_text: String) -> void: add_and_join())
	address_field.text = str(Settings.get_value(&"network", &"last_address"))
	join_button.pressed.connect(join_selected)
	%Favourite.pressed.connect(toggle_favourite)
	%Rename.pressed.connect(_start_rename)
	%Remove.pressed.connect(remove_selected)
	name_field.text_submitted.connect(rename_selected)
	list.item_selected.connect(_show_detail)
	list.item_activated.connect(join_selected)
	error_dialog.closed.connect(func() -> void: list.grab_focus())
	query.answered.connect(take_reply)
	query.timed_out.connect(_stop_asking)
	for item: Dictionary in servers.entries():
		rows[item.address] = _row(item.address, item.name, item.favourite, true)
	refresh()
	list.grab_focus()


func _exit_tree() -> void:
	query.close()


func _setup_list() -> void:
	var titles: PackedStringArray = ["", "Server name", "Now playing", "Players", "Ping", "Tags"]
	for column: int in titles.size():
		list.set_column_title(column, titles[column])
		list.set_column_title_alignment(column, HORIZONTAL_ALIGNMENT_LEFT)
		list.set_column_expand(column, column in [1, 2])
	list.set_column_custom_minimum_width(0, 40)
	list.set_column_custom_minimum_width(3, 110)
	list.set_column_custom_minimum_width(4, 110)
	list.set_column_custom_minimum_width(5, 200)


## Asks every listed server again and broadcasts on the LAN. Found-only LAN rows are found again.
func refresh() -> void:
	for address: String in rows.keys():
		if rows[address].saved:
			rows[address].merge({"info": {}, "ping": -1, "state": &"asking"}, true)
		else:
			rows.erase(address)
	var addresses: Array[String] = []
	addresses.assign(rows.keys())
	query.start(addresses)
	show_rows()


func _process(_delta: float) -> void:
	query.poll()


func _stop_asking() -> void:
	for row: Dictionary in rows.values():
		if row.state == &"asking":
			row.state = &"silent"
	show_rows()


## A checked reply; a world that answered the LAN broadcast gets a LAN row keyed by its address.
func take_reply(address: String, info: Dictionary, ping: int, lan: bool) -> void:
	if not rows.has(address):
		rows[address] = _row(address, "", false, false)
	if lan:
		rows[address].lan = true
	rows[address].merge({"info": info, "ping": ping, "state": &"answered"}, true)
	show_rows()


func _row(address: String, shown_name: String, favourite: bool, saved: bool) -> Dictionary:
	return {
		"address": address,
		"name": shown_name,
		"favourite": favourite,
		"saved": saved,
		"lan": false,
		"info": {},
		"ping": -1,
		"state": &"asking",
	}


func show_tab(id: StringName) -> void:
	tab = id
	show_rows()


## The rows of this tab: answering servers by ping, then the rest by name.
func visible_rows() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for row: Dictionary in rows.values():
		if tab == &"all" or (tab == &"favourites" and row.favourite) or (tab == &"lan" and row.lan):
			out.append(row)
		elif tab == &"recent" and row.saved and not row.favourite:
			out.append(row)
	out.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			if (a.ping >= 0) != (b.ping >= 0):
				return a.ping >= 0
			if a.ping != b.ping:
				return a.ping < b.ping
			return display_name(a) < display_name(b)
	)
	return out


func show_rows() -> void:
	var keep: String = selected().get("address", "")
	list.clear()
	var root: TreeItem = list.create_item()
	for row: Dictionary in visible_rows():
		var item: TreeItem = list.create_item(root)
		_fill(item, row)
		if row.address == keep:
			item.select(0)
	_show_detail()


func _fill(item: TreeItem, row: Dictionary) -> void:
	var info: Dictionary = row.info
	item.set_metadata(0, row.address)
	item.set_text(0, "★" if row.favourite else "☆")
	item.set_text(1, display_name(row))
	item.set_text(2, info.get("playing", "Asking..." if row.state == &"asking" else "Not responding"))
	item.set_text(3, "%d / %d" % [info.players, info.max] if not info.is_empty() else "-")
	item.set_text(4, "%d ms" % row.ping if row.ping >= 0 else "-")
	item.set_text(5, "  ".join(tags(row)))
	if row.ping >= 0:
		item.set_custom_color(4, PING_SLOW if row.ping > SLOW_PING else PING_GOOD)
	if info.is_empty():
		item.set_custom_color(2, TEXT_DIM)
	if is_other_version(info):
		item.set_custom_color(5, PING_SLOW)


static func display_name(row: Dictionary) -> String:
	if not str(row.name).is_empty():
		return row.name
	return str(row.info.get("name", row.address))


static func is_other_version(info: Dictionary) -> bool:
	return not info.is_empty() and (info.version != Build.version or info.protocol != Build.PROTOCOL_VERSION)


static func tags(row: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	var info: Dictionary = row.info
	if row.lan:
		out.append("LAN")
	if not info.is_empty() and info.players >= info.max:
		out.append("Full")
	if is_other_version(info):
		out.append("v%s" % info.version)
	return out


func selected() -> Dictionary:
	var item: TreeItem = list.get_selected() if list else null
	return rows.get(item.get_metadata(0), {}) if item else {}


func _show_detail() -> void:
	var row: Dictionary = selected()
	%Detail.visible = not row.is_empty()
	name_field.hide()
	if row.is_empty():
		return
	var info: Dictionary = row.info
	%ServerName.text = display_name(row)
	%Players.text = "%d / %d" % [info.players, info.max] if not info.is_empty() else ""
	%Ping.text = "Ping %d ms" % row.ping if row.ping >= 0 else "Not responding"
	var version: String = ""
	if not info.is_empty():
		version = "Version %s %s" % [info.version, "(not yours)" if is_other_version(info) else "✓"]
	var parts: PackedStringArray = [info.get("playing", ""), version, row.address]
	%Line.text = " · ".join(Array(parts).filter(func(part: String) -> bool: return not part.is_empty()))
	%Favourite.text = "Unfavourite" if row.favourite else "Favourite"


## Join the selected row; a full server or another version says so in plain words first.
func join_selected(_unused: Variant = null) -> void:
	var row: Dictionary = selected()
	if row.is_empty():
		return
	var info: Dictionary = row.info
	if is_other_version(info):
		_show_error(&"wrong_version", {"server_version": info.version, "client_version": Build.version})
	elif not info.is_empty() and info.players >= info.max:
		_show_error(&"server_full", {"players": info.players, "max_players": info.max})
	else:
		_start_join(row.address, str(info.get("name", "")))


func add_and_join() -> void:
	var target: String = ServerAddress.normalized(address_field.text)
	if target.is_empty():
		_show_error(&"bad_address")
		return
	Settings.set_value(&"network", &"last_address", address_field.text.strip_edges())
	_start_join(target, "")


func _start_join(address: String, shown_name: String) -> void:
	servers.record_join(address, shown_name)
	Net.pending_join = address
	error_dialog.reparent(get_tree().root)
	error_dialog.show_connecting(address)
	Net.place = &"hub"
	UI.replace(&"hub")


func toggle_favourite() -> void:
	var row: Dictionary = selected()
	if row.is_empty():
		return
	row.favourite = not row.favourite
	row.saved = true
	servers.set_favourite(row.address, row.favourite)
	show_rows()


func _start_rename() -> void:
	if selected().is_empty():
		return
	name_field.text = display_name(selected())
	name_field.show()
	name_field.grab_focus()
	name_field.select_all()


func rename_selected(shown_name: String) -> void:
	var row: Dictionary = selected()
	if row.is_empty():
		return
	if not servers.has(row.address):
		servers.set_favourite(row.address, row.favourite)
	servers.rename(row.address, shown_name)
	row.merge({"name": shown_name.strip_edges().left(ServerInfo.NAME_LENGTH), "saved": true}, true)
	show_rows()
	list.grab_focus()


## Removes a saved server; a LAN world that still answers stays as a LAN row.
func remove_selected() -> void:
	var row: Dictionary = selected()
	if row.is_empty():
		return
	servers.remove(row.address)
	if row.lan:
		row.merge({"name": "", "favourite": false, "saved": false}, true)
	else:
		rows.erase(row.address)
	show_rows()


func _show_error(reason: StringName, details: Dictionary = {}) -> void:
	error_dialog.show_error(reason, details)


func _unhandled_key_input(event: InputEvent) -> void:
	if error_dialog.visible:
		return
	var key: InputEventKey = event as InputEventKey
	var typing: bool = get_viewport().gui_get_focus_owner() is LineEdit
	if event.is_action_pressed(&"ui_cancel"):
		if name_field.visible:
			name_field.hide()
			list.grab_focus()
		else:
			closed.emit()
	elif not typing and key and key.pressed and not key.echo and key.keycode in [KEY_F, KEY_R, KEY_DELETE]:
		{KEY_F: toggle_favourite, KEY_R: refresh, KEY_DELETE: remove_selected}[key.keycode].call()
	else:
		return
	get_viewport().set_input_as_handled()
