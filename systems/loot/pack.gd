## One client's six carried loot items. Item dictionaries stay private to the Pack.
class_name Pack
extends RefCounted

signal changed

const CAPACITY: int = 6

var items: Array[Dictionary]:
	get:
		return _items.duplicate(true)

var _items: Array[Dictionary] = []


func is_full() -> bool:
	return _items.size() >= CAPACITY


func add(item: Dictionary) -> bool:
	if item.is_empty() or is_full():
		return false
	_items.append(item.duplicate(true))
	changed.emit()
	return true


func remove(index: int) -> Dictionary:
	if index < 0 or index >= _items.size():
		return {}
	var item: Dictionary = _items.pop_at(index)
	changed.emit()
	return item
