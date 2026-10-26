extends "res://tests/headless/test_case.gd"


func run() -> Dictionary:
	_test_3d_empty_space()
	_test_2d_empty_space()
	_test_invalid_inputs()
	return finish()


func _test_3d_empty_space() -> void:
	var root := Node3D.new()

	expect_true(
		attach_test_node(root),
		"3D placement query requires a live SceneTree.",
	)

	var shape := SphereShape3D.new()
	shape.radius = 0.5
	var candidates: Array[Transform3D] = [
		Transform3D(Basis.IDENTITY, Vector3(20000.0, 20000.0, 20000.0)),
	]
	var space_state := root.get_world_3d().direct_space_state

	expect_true(
		NucleusPlacementQueries3D.is_transform_free(
			space_state,
			shape,
			candidates[0],
		),
		"An isolated 3D candidate should be reported free.",
	)
	expect_equal(
		NucleusPlacementQueries3D.find_first_free_index(
			space_state,
			shape,
			candidates,
		),
		0,
		"3D placement search should return the first free candidate.",
	)

	free_test_node(root)


func _test_2d_empty_space() -> void:
	var root := Node2D.new()

	expect_true(
		attach_test_node(root),
		"2D placement query requires a live SceneTree.",
	)

	var shape := CircleShape2D.new()
	shape.radius = 8.0
	var candidates: Array[Transform2D] = [
		Transform2D(0.0, Vector2(20000.0, 20000.0)),
	]
	var space_state := root.get_world_2d().direct_space_state

	expect_true(
		NucleusPlacementQueries2D.is_transform_free(
			space_state,
			shape,
			candidates[0],
		),
		"An isolated 2D candidate should be reported free.",
	)
	expect_equal(
		NucleusPlacementQueries2D.find_first_free_index(
			space_state,
			shape,
			candidates,
		),
		0,
		"2D placement search should return the first free candidate.",
	)

	free_test_node(root)


func _test_invalid_inputs() -> void:
	var candidates_3d: Array[Transform3D] = [Transform3D.IDENTITY]
	var candidates_2d: Array[Transform2D] = [Transform2D.IDENTITY]

	expect_equal(
		NucleusPlacementQueries3D.find_first_free_index(
			null,
			SphereShape3D.new(),
			candidates_3d,
		),
		-1,
		"3D placement search should reject a missing direct-space state.",
	)
	expect_equal(
		NucleusPlacementQueries2D.find_first_free_index(
			null,
			CircleShape2D.new(),
			candidates_2d,
		),
		-1,
		"2D placement search should reject a missing direct-space state.",
	)
