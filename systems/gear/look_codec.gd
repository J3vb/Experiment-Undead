## Packs the three worn gear slots into 15 bytes using sorted content ids.
class_name LookCodec
extends RefCounted

const SLOT_BYTES: int = 5
const ENCODED_BYTES: int = SLOT_BYTES * 3

var _visuals: Array = []
var _rarities: Array[StringName] = []
var _dyes: Array = []
var _dye_colors: Dictionary[int, Color] = {}


func _init() -> void:
	_visuals = Content.sorted_ids(&"gear_visuals")
	for id: StringName in Content.sorted_ids(&"looks"):
		if Content.get_item(&"looks", id) is RarityLook:
			_rarities.append(id)
	_dyes = Content.sorted_ids(&"dyes")
	for index: int in _dyes.size():
		var color: Variant = Content.get_item(&"dyes", _dyes[index]).get("color")
		if color is Color:
			_dye_colors[index + 1] = color


func encode(look: CharacterLook) -> PackedByteArray:
	var bytes: PackedByteArray = PackedByteArray()
	for slot: StringName in CharacterLook.SLOTS:
		var entry: Dictionary = look.slots.get(slot, {}) if look != null else _fallback(slot)
		var encoded: PackedByteArray = _encode_slot(entry, slot)
		if encoded.is_empty():
			encoded = _encode_slot(_fallback(slot), slot)
		bytes.append_array(encoded)
	return bytes


func decode(bytes: PackedByteArray) -> CharacterLook:
	var look: CharacterLook = CharacterLook.new()
	for index: int in CharacterLook.SLOTS.size():
		var slot: StringName = CharacterLook.SLOTS[index]
		var entry: Dictionary = (
			_decode_slot(bytes, index * SLOT_BYTES, slot) if bytes.size() == ENCODED_BYTES else _fallback(slot)
		)
		if not entry.is_empty():
			look.slots[slot] = entry
	return look


func _encode_slot(entry: Dictionary, slot: StringName) -> PackedByteArray:
	var bytes: PackedByteArray = PackedByteArray([0, 0, 0, 0, 0])
	if entry.is_empty():
		return bytes
	var visual_index: int = _visual_index(entry.get("visual_id", &""), slot)
	var rarity: Variant = entry.get("rarity", &"common")
	var rarity_index: int = _rarities.find(StringName(rarity)) if _is_id(rarity) else -1
	if visual_index < 1 or rarity_index < 0 or rarity_index > 255:
		return PackedByteArray()
	var dyes: Variant = entry.get("dyes", [CharacterLook.DEFAULT_DYE_MAIN, CharacterLook.DEFAULT_DYE_ACCENT])
	if not dyes is Array or dyes.size() != 2:
		return PackedByteArray()
	var main: int = _dye_index(dyes[0], CharacterLook.DEFAULT_DYE_MAIN)
	var accent: int = _dye_index(dyes[1], CharacterLook.DEFAULT_DYE_ACCENT)
	if main < 0 or accent < 0:
		return PackedByteArray()
	bytes.encode_u16(0, visual_index)
	bytes[2] = rarity_index
	bytes[3] = main
	bytes[4] = accent
	return bytes


func _decode_slot(bytes: PackedByteArray, offset: int, slot: StringName) -> Dictionary:
	var visual_index: int = bytes.decode_u16(offset)
	var rarity_index: int = bytes[offset + 2]
	var main: int = bytes[offset + 3]
	var accent: int = bytes[offset + 4]
	if bytes.slice(offset, offset + SLOT_BYTES) == PackedByteArray([0, 0, 0, 0, 0]):
		return {}
	if visual_index <= 0 or visual_index > _visuals.size() or rarity_index >= _rarities.size():
		return _fallback(slot)
	var visual: GearVisual = GearVisual.find(_visuals[visual_index - 1])
	if visual == null or visual.slot != slot or not _valid_dye(main) or not _valid_dye(accent):
		return _fallback(slot)
	return {
		"visual_id": visual.id,
		"rarity": _rarities[rarity_index],
		"dyes":
		[
			_dye_colors.get(main, CharacterLook.DEFAULT_DYE_MAIN),
			_dye_colors.get(accent, CharacterLook.DEFAULT_DYE_ACCENT),
		],
	}


func _visual_index(value: Variant, slot: StringName) -> int:
	if not _is_id(value):
		return -1
	var visual: GearVisual = GearVisual.find(StringName(value))
	var index: int = _visuals.find(StringName(value)) + 1
	if visual == null or visual.slot != slot or index <= 0 or index > 65535:
		return -1
	return index


func _dye_index(value: Variant, default_color: Color) -> int:
	if not value is Color:
		return -1
	if value == default_color:
		return 0
	for index: int in _dye_colors:
		if index <= 255 and _dye_colors[index] == value:
			return index
	return -1


func _valid_dye(index: int) -> bool:
	return index == 0 or _dye_colors.has(index)


static func _is_id(value: Variant) -> bool:
	return value is StringName or value is String


static func _fallback(slot: StringName) -> Dictionary:
	return {
		"visual_id": GearVisual.BASES[slot],
		"rarity": &"common",
		"dyes": [CharacterLook.DEFAULT_DYE_MAIN, CharacterLook.DEFAULT_DYE_ACCENT],
	}
