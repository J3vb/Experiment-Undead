## One runtime stat contribution; sources let equipment bonuses be removed together.
class_name Modifier
extends RefCounted

var stat: StringName
var op: String
var value: float
var source: StringName


func _init(p_stat: StringName, p_op: String, p_value: float, p_source: StringName) -> void:
	stat = p_stat
	op = p_op
	value = p_value
	source = p_source
