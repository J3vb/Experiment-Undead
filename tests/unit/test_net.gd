extends GutTest

const NetScript: GDScript = preload("res://core/net.gd")


func test_allocated_ids_are_unique_and_restart_from_one() -> void:
	var net_node: Node = NetScript.new()
	assert_eq(net_node.allocate_id(), 1)
	assert_eq(net_node.allocate_id(), 2)
	assert_eq(net_node.allocate_id(), 3)
	net_node.reset_ids()
	assert_eq(net_node.allocate_id(), 1)
	assert_eq(net_node.allocate_id(), 2)
	net_node.free()


func test_solo_is_authority() -> void:
	var net_node: Node = NetScript.new()
	add_child_autofree(net_node)
	assert_true(net_node.is_authority())
