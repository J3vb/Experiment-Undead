## Bottom-centre item drop feed: "<Rarity> <name>" in rarity colour, shape included, each row fades after 4 s.
## Only the drop's owner sees it (personal loot).
class_name LootFeed
extends VBoxContainer

const MAX_ROWS: int = 3
const SHOW_TIME: float = 4.0
const FADE_TIME: float = 0.3
const FONT_SIZE: int = 24


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Events.loot_dropped.connect(_on_loot_dropped)


func row_texts() -> Array[String]:
	var texts: Array[String] = []
	for row: Node in get_children():
		if not row.is_queued_for_deletion():
			texts.append((row as Label).text)
	return texts


func _on_loot_dropped(player: Player, item: Dictionary) -> void:
	if player == null or not player.is_inside_tree() or not player.is_multiplayer_authority():
		return
	var rarity: StringName = StringName(item.get("rar", "common"))
	var rank: int = maxi(ItemRoller.RARITIES.find(rarity), 0)
	var data: RarityData = Content.get_item(&"loot", rarity) as RarityData
	var row: Label = Label.new()
	row.text = "%s %s %s" % [ItemTooltip.SHAPES[rank], String(rarity).capitalize(), LootDrop.item_name(item)]
	row.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_theme_font_size_override(&"font_size", FONT_SIZE)
	row.add_theme_color_override(&"font_color", data.colour if data else Color.WHITE)
	row.add_theme_constant_override(&"outline_size", 4)
	row.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.8))
	add_child(row)
	move_child(row, 0)
	while get_child_count() > MAX_ROWS:
		var oldest: Node = get_child(get_child_count() - 1)
		remove_child(oldest)
		oldest.queue_free()
	var tween: Tween = row.create_tween()
	tween.tween_interval(SHOW_TIME - FADE_TIME)
	tween.tween_property(row, "modulate:a", 0.0, FADE_TIME)
	tween.tween_callback(row.queue_free)
