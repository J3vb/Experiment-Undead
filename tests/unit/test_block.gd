## Checks the grey-box Block hands LightmapGI a box mesh it can bake.
extends GutTest


func test_block_offers_a_uv2_box_to_the_lightmapper() -> void:
	var block: Block = Block.new()
	block.size = Vector3(2, 1, 3)
	add_child_autofree(block)
	var bake: Array = block.get_bake_meshes()
	assert_eq(bake.size(), 2, "one mesh and its transform")
	var box: BoxMesh = bake[0] as BoxMesh
	assert_not_null(box, "baked mesh is the box")
	if box:
		assert_true(box.add_uv2, "box has UV2 for lightmaps")
		assert_eq(box.size, Vector3(2, 1, 3), "box matches the block size")
	assert_true(block.get_bake_mesh_instance(0).is_valid(), "lightmap can be applied to the box")
