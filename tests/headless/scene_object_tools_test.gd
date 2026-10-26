extends "res://tests/headless/test_case.gd"


func run() -> Dictionary:
	_test_node_listing_and_groups()
	_test_property_inspection_and_mutation()
	_test_transforms_and_runtime_switches()
	_test_scope_and_property_guards()
	return finish()


func _test_node_listing_and_groups() -> void:
	var root := Node.new()
	root.name = "World"
	var player := Node2D.new()
	player.name = "Player"
	player.add_to_group(&"actors")
	root.add_child(player)
	var camera := Camera2D.new()
	camera.name = "Camera"
	player.add_child(camera)

	var result := NucleusSceneObjectTools.list_nodes(root, "player", 10)
	expect_true(bool(result.get("ok", false)), "Scene node listing succeeds.")
	var matches: Array = result.get("data", [])
	expect_equal(matches.size(), 2, "Node search includes matching descendant paths.")

	var group_result := NucleusSceneObjectTools.list_group(root, "actors", 10)
	var group_matches: Array = group_result.get("data", [])
	expect_equal(group_matches.size(), 1, "Group query finds matching nodes.")
	expect_equal(group_matches[0].get("path"), "Player", "Group paths are scene-relative.")
	root.free()


func _test_property_inspection_and_mutation() -> void:
	var root := Node.new()
	root.name = "World"
	var sprite := Sprite2D.new()
	sprite.name = "Marker"
	root.add_child(sprite)

	var inspection := NucleusSceneObjectTools.inspect_node(root, "Marker", "position")
	expect_true(bool(inspection.get("ok", false)), "Node inspection succeeds.")
	var data: Dictionary = inspection.get("data", {})
	var properties: Array = data.get("properties", [])
	expect_true(not properties.is_empty(), "Inspection exposes position.")

	var set_position := NucleusSceneObjectTools.set_property(
		root,
		"Marker",
		"position",
		"12.5,-3",
	)
	expect_true(bool(set_position.get("ok", false)), "Vector2 properties can be set.")
	expect_equal(sprite.position, Vector2(12.5, -3.0), "Property mutation applies value.")

	var set_visible := NucleusSceneObjectTools.set_property(
		root,
		"Marker",
		"visible",
		"false",
	)
	expect_true(bool(set_visible.get("ok", false)), "Boolean properties can be set.")
	expect_false(sprite.visible, "Boolean mutation reaches the node.")
	root.free()


func _test_transforms_and_runtime_switches() -> void:
	var root := Node.new()
	root.name = "World"
	var node_2d := Node2D.new()
	node_2d.name = "Boat2D"
	root.add_child(node_2d)
	var node_3d := Node3D.new()
	node_3d.name = "Boat3D"
	root.add_child(node_3d)

	var move_2d := NucleusSceneObjectTools.set_position_2d(
		root, "Boat2D", 8.0, 4.0
	)
	expect_true(bool(move_2d.get("ok", false)), "Dedicated Node2D movement succeeds.")
	expect_equal(node_2d.position, Vector2(8.0, 4.0), "Node2D position is updated.")

	var move_3d := NucleusSceneObjectTools.set_position_3d(
		root, "Boat3D", 1.0, 2.0, 3.0
	)
	expect_true(bool(move_3d.get("ok", false)), "Dedicated Node3D movement succeeds.")
	expect_equal(node_3d.position, Vector3(1.0, 2.0, 3.0), "Node3D position is updated.")

	var hidden := NucleusSceneObjectTools.set_visible(root, "Boat3D", false)
	expect_true(bool(hidden.get("ok", false)), "Node3D visibility mutation succeeds.")
	expect_false(node_3d.visible, "Node3D visibility is updated.")

	var processing := NucleusSceneObjectTools.set_processing(root, "Boat2D", false)
	expect_true(bool(processing.get("ok", false)), "Processing mutation succeeds.")
	expect_false(node_2d.is_processing(), "Idle processing is disabled.")
	expect_false(node_2d.is_physics_processing(), "Physics processing is disabled.")
	root.free()


func _test_scope_and_property_guards() -> void:
	var root := Node.new()
	root.name = "World"
	var child := Node2D.new()
	child.name = "Player"
	root.add_child(child)

	expect_equal(
		NucleusSceneObjectTools.resolve_node(root, "/root/Other"),
		null,
		"Absolute paths cannot escape the current-scene boundary.",
	)
	var blocked := NucleusSceneObjectTools.set_property(
		root,
		"Player",
		"script",
		"res://anything.gd",
	)
	expect_false(bool(blocked.get("ok", false)), "Structural script mutation is blocked.")
	root.free()
